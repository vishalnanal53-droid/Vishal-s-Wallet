import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Motivational Messages for different times of the day
  final List<String> _messages = [
    "Kaalai Vanakkam! ☀️ Start fresh. Did you spend anything yet?",
    "Tea break-ah? ☕ Coffee or snacks expense irundha update pannunga!",
    "Lunch time! 🍱 Don't forget to log your meal expenses.",
    "KasuBook check! 📝 Chinna expense-ah irundhalum note pannunga.",
    "Evening vibes! 🌆 Any travel or shopping costs to add?",
    "Day ends here! 🌙 Check your wallet and finish today's entries."
  ];

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

  /// Schedules notifications every 3 hours starting from 6 AM to 9 PM
  Future<void> scheduleDailyReminders() async {
    // Hours: 6 AM, 9 AM, 12 PM, 3 PM, 6 PM, 9 PM
    final List<int> reminderHours = [6, 9, 12, 15, 18, 21];

    for (int i = 0; i < reminderHours.length; i++) {
      int hour = reminderHours[i];
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        i, // Unique ID for each time slot (0 to 5)
        'KasuBook Reminder 💰',
        _messages[i], // Picks the specific message for that time
        _nextInstanceOfHour(hour),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'kasubook_reminders',
            'Daily Budget Reminders',
            channelDescription: 'Notifications sent every 3 hours to log expenses',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeats daily
      );
    }
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Helper to calculate the next occurrence of a specific hour
  tz.TZDateTime _nextInstanceOfHour(int hour) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}