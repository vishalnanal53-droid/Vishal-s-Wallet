import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Top-level Background Handler ──
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Stream subscription for Firebase listener
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        showNotification(
          message.notification!.title ?? 'KasuBook',
          message.notification!.body ?? '',
        );
      }
    });
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? result = await androidImplementation?.requestNotificationsPermission();
      return result ?? false;
    }
    return false;
  }

  /// Listen for admin notifications from Firebase
  /// When Notification_send is true, show alert and update to false
  void startAdminNotificationListener(String userId) {
    _notificationSubscription?.cancel();
    
    _notificationSubscription = FirebaseFirestore.instance
        .collection('Notification')
        .where('Notification_send', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Show notification
        await showNotification(
          data['title'] ?? 'KasuBook Alert',
          data['message'] ?? 'You have a new notification',
        );
        
        // Update Firebase to false to prevent repeated alerts
        await doc.reference.update({
          'Notification_send': false,
          'delivered_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Stop listening to admin notifications
  void stopAdminNotificationListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'kasubook_alerts',
      'KasuBook Alerts',
      channelDescription: 'Important notifications from KasuBook',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Generates a unique ID based on current time
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      details,
    );
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<bool> areNotificationsScheduled() async {
    final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return pending.isNotEmpty;
  }
  
  void dispose() {
    _notificationSubscription?.cancel();
  }
}