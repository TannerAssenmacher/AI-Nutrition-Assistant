import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../db/food.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Request permissions for iOS
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request permissions for Android 13+
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Check if user has logged any meal today
  static bool hasLoggedToday(List<FoodItem> foodLog) {
    final now = DateTime.now();
    return foodLog.any((item) =>
        item.consumedAt.year == now.year &&
        item.consumedAt.month == now.month &&
        item.consumedAt.day == now.day);
  }

  /// Calculate remaining macros needed to meet goals
  static Map<String, double> calculateRemainingMacros({
    required Map<String, double> currentTotals,
    required Map<String, double> goals,
  }) {
    final remaining = <String, double>{};
    
    // Calculate what's already logged
    final loggedCalories = currentTotals['calories'] ?? 0;
    final loggedProtein = currentTotals['protein'] ?? 0;
    final loggedCarbs = currentTotals['carbs'] ?? 0;
    final loggedFat = currentTotals['fat'] ?? 0;

    // Calculate remaining
    remaining['calories'] = (goals['calories'] ?? 0) - loggedCalories;
    remaining['protein'] = (goals['protein'] ?? 0) - loggedProtein;
    remaining['carbs'] = (goals['carbs'] ?? 0) - loggedCarbs;
    remaining['fat'] = (goals['fat'] ?? 0) - loggedFat;

    return remaining;
  }

  /// Check if it's after 6 PM
  static bool isAfter6PM() {
    final now = DateTime.now();
    return now.hour >= 18;
  }

  /// Show immediate notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String message,
    String? payload,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'nutrition_reminders',
      'Nutrition Reminders',
      channelDescription: 'Reminders for meal logging and nutrition goals',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, message, details, payload: payload);
  }

  /// Schedule daily notification at specific time
  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String message,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    await initialize();

    await _notifications.zonedSchedule(
      id,
      title,
      message,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'nutrition_reminders',
          'Nutrition Reminders',
          channelDescription: 'Reminders for meal logging and nutrition goals',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// Helper to get next instance of a specific time
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Show streak reminder notification
  static Future<void> showStreakReminder(int currentStreak) async {
    final message = getStreakReminderMessage(currentStreak);
    await showNotification(
      id: 1,
      title: '🔥 Daily Streak Reminder',
      message: message,
      payload: 'streak_reminder',
    );
  }

  /// Show macro reminder notification
  static Future<void> showMacroReminder(Map<String, double> remaining) async {
    final message = getMacroReminderMessage(remaining);
    await showNotification(
      id: 2,
      title: '🍽️ Evening Nutrition Check',
      message: message,
      payload: 'macro_reminder',
    );
  }

  /// Schedule daily streak reminder (e.g., at 12:00 PM)
  static Future<void> scheduleStreakReminder() async {
    await scheduleDailyNotification(
      id: 10,
      title: '🔥 Time to Log Your Meals',
      message: 'Keep your streak going! Log your meals for today.',
      hour: 12,
      minute: 0,
      payload: 'daily_streak_reminder',
    );
  }

  /// Schedule daily macro check (e.g., at 6:00 PM)
  static Future<void> scheduleMacroCheckReminder() async {
    await scheduleDailyNotification(
      id: 11,
      title: '🍽️ Evening Nutrition Check',
      message: 'Time to review your daily nutrition goals!',
      hour: 18,
      minute: 0,
      payload: 'daily_macro_reminder',
    );
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Generate streak reminder message
  static String getStreakReminderMessage(int currentStreak) {
    if (currentStreak == 0) {
      return "Start your logging streak today! 🎯";
    } else if (currentStreak < 3) {
      return "Keep it going! You're on a $currentStreak-day streak 🔥";
    } else if (currentStreak < 7) {
      return "Amazing! $currentStreak days strong! Don't break the streak 💪";
    } else {
      return "Incredible $currentStreak-day streak! Keep crushing it! 🏆";
    }
  }

  /// Generate macro reminder message
  static String getMacroReminderMessage(Map<String, double> remaining) {
    final needsCalories = remaining['calories']! > 0;
    final needsProtein = remaining['protein']! > 0;
    final needsCarbs = remaining['carbs']! > 0;
    final needsFat = remaining['fat']! > 0;

    if (!needsCalories && !needsProtein && !needsCarbs && !needsFat) {
      return "Great job! You've met all your daily goals! 🎉";
    }

    final parts = <String>[];
    if (needsProtein) {
      parts.add("${remaining['protein']!.round()}g protein");
    }
    if (needsCarbs) {
      parts.add("${remaining['carbs']!.round()}g carbs");
    }
    if (needsFat) {
      parts.add("${remaining['fat']!.round()}g fat");
    }
    if (needsCalories) {
      parts.add("${remaining['calories']!.round()} calories");
    }

    if (parts.isEmpty) {
      return "You're doing great! Keep it up! ✨";
    }

    return "To meet your goals, you still need: ${parts.join(', ')}";
  }
}
