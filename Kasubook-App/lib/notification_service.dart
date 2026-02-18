// ─── notification_service.dart ───────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Background FCM handler (top-level, required by FCM) ──────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Mark receipt when notification received in background
  await NotificationService._markReceipt(message);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  // ── FCM Setup ─────────────────────────────────────────────────────────────
  Future<void> initFCM() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Save token so Cloud Function can reach this device
    await _saveFcmToken();
    messaging.onTokenRefresh.listen(_updateFcmToken);

    // Foreground: show local notification + mark receipt
    FirebaseMessaging.onMessage.listen((msg) async {
      if (msg.notification != null) {
        await showNotification(
          msg.notification!.title ?? 'KasuBook',
          msg.notification!.body  ?? '',
        );
      }
      await _markReceipt(msg);
    });

    // Background tap: app opened via notification banner
    FirebaseMessaging.onMessageOpenedApp.listen(_markReceipt);
  }

  // ── Receipt: write to Notification/{notifId}/receipts/{uid} ──────────────
  // Called when user receives a notification (foreground, background, or tap)
  static Future<void> _markReceipt(RemoteMessage message) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // notif_id must be sent in FCM data payload from Cloud Function
      final notifId = message.data['notif_id'] as String?;
      if (notifId == null || notifId.isEmpty) return;

      final receiptRef = FirebaseFirestore.instance
          .collection('Notification')
          .doc(notifId)
          .collection('receipts')
          .doc(uid);

      // Only write once — idempotent
      final existing = await receiptRef.get();
      if (existing.exists) return;

      await receiptRef.set({
        'uid':         uid,
        'received_at': DateTime.now().toIso8601String(),
      });

      debugPrint('[Receipt] Marked received for notif=$notifId uid=$uid');
    } catch (e) {
      debugPrint('[Receipt] Error: $e');
    }
  }

  // ── Foreground Firestore listener (app open) ──────────────────────────────
  // Handles notifications that arrive via Firestore directly
  // (backup for when FCM is delayed or token not yet updated)
  void startAdminNotificationListener(String userId) {
    _notificationSubscription?.cancel();
    _notificationSubscription = FirebaseFirestore.instance
        .collection('Notification')
        .where('Notification_send', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Check if this user already received it
        final receipt = await doc.reference
            .collection('receipts')
            .doc(userId)
            .get();
        if (receipt.exists) continue; // already received — skip

        await showNotification(
          data['title']   ?? 'KasuBook',
          data['message'] ?? '',
        );

        // Write receipt
        await doc.reference
            .collection('receipts')
            .doc(userId)
            .set({
          'uid':         userId,
          'received_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  void stopAdminNotificationListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  // ── Show local notification ───────────────────────────────────────────────
  Future<void> showNotification(String title, String body) async {
    const android = AndroidNotificationDetails(
      'kasubook_alerts', 'KasuBook Alerts',
      channelDescription: 'KasuBook notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true,
    );
    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title, body,
      const NotificationDetails(android: android, iOS: ios),
    );
  }

  // ── FCM Token Management ──────────────────────────────────────────────────
  Future<void> _saveFcmToken() async {
    try {
      final uid   = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcm_token': token});
      debugPrint('[FCM] Token saved uid=$uid');
    } catch (e) {
      debugPrint('[FCM] Token save failed: $e');
    }
  }

  Future<void> _updateFcmToken(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcm_token': token});
    } catch (e) {
      debugPrint('[FCM] Token refresh failed: $e');
    }
  }

  // ── Permissions ───────────────────────────────────────────────────────────
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _localNotif
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (Platform.isAndroid) {
      final result = await _localNotif
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    return false;
  }

  Future<void> cancelAll() async => _localNotif.cancelAll();

  void dispose() => _notificationSubscription?.cancel();
}