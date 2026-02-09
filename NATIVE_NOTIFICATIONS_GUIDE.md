# Native Mobile Notifications Setup Guide

## Overview
The app now uses native Android/iOS notifications instead of in-app banners for meal logging reminders and nutrition tracking.

## Features

### 1. **Automatic Daily Reminders**
Two notifications are scheduled daily:
- **12:00 PM** - Streak reminder to log meals
- **6:00 PM** - Evening nutrition check

### 2. **On-Demand Notifications**
When you open the daily log screen:
- **Streak reminder** - If you haven't logged meals today
- **Macro reminder** - After 6 PM if you haven't met your goals

## Installation Steps

### 1. Install Dependencies
Run in terminal:
```bash
flutter pub get
```

This will install:
- `flutter_local_notifications` - Native notification support
- `timezone` - For scheduling notifications at specific times

### 2. Android Configuration (Already Done)
The following permissions have been added to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

### 3. iOS Configuration
**Important**: Add the following to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### 4. Test the Notifications

**Option A - Immediate Test:**
```dart
// Trigger a test notification immediately
await NotificationService.showNotification(
  id: 999,
  title: 'Test Notification',
  message: 'Notifications are working!',
);
```

**Option B - Schedule Test:**
```dart
// Schedule a notification 1 minute from now
await NotificationService.scheduleDailyNotification(
  id: 998,
  title: 'Scheduled Test',
  message: 'This was scheduled 1 minute ago',
  hour: DateTime.now().hour,
  minute: DateTime.now().minute + 1,
);
```

## How It Works

### Initialization
Notifications are initialized when the app starts in `main.dart`:
```dart
await NotificationService.initialize();
await NotificationService.scheduleStreakReminder();  // Daily at 12 PM
await NotificationService.scheduleMacroCheckReminder();  // Daily at 6 PM
```

### Notification Channels
**Android:**
- Channel ID: `nutrition_reminders`
- Channel Name: `Nutrition Reminders`
- Importance: High (shows as heads-up notification)

**iOS:**
- Requests permissions for: Alert, Badge, Sound

### On-Demand Triggers
In `daily_log_calendar.dart`, notifications are checked when the screen loads:
1. If no meals logged today → Show streak reminder
2. If after 6 PM and goals not met → Show macro reminder

## API Reference

### Show Immediate Notification
```dart
await NotificationService.showNotification(
  id: 1,
  title: 'Title',
  message: 'Message text',
  payload: 'optional_data',
);
```

### Schedule Daily Notification
```dart
await NotificationService.scheduleDailyNotification(
  id: 10,
  title: 'Daily Reminder',
  message: 'This happens every day',
  hour: 14,  // 2:00 PM
  minute: 30,
);
```

### Cancel Notifications
```dart
// Cancel specific notification
await NotificationService.cancelNotification(id);

// Cancel all notifications
await NotificationService.cancelAllNotifications();
```

## Customization

### Change Notification Times
Edit in `main.dart`:
```dart
// Currently: 12:00 PM
await NotificationService.scheduleStreakReminder();

// To change, modify notification_service.dart:
static Future<void> scheduleStreakReminder() async {
  await scheduleDailyNotification(
    id: 10,
    title: '🔥 Time to Log Your Meals',
    message: 'Keep your streak going! Log your meals for today.',
    hour: 14,  // Change to 2:00 PM
    minute: 0,
  );
}
```

### Customize Messages
Edit these methods in `notification_service.dart`:
- `getStreakReminderMessage(int currentStreak)`
- `getMacroReminderMessage(Map<String, double> remaining)`

## Troubleshooting

### Notifications Not Showing

**Android:**
1. Check app settings → Notifications → Ensure enabled
2. For Android 13+, permission is requested at runtime
3. Check if "Do Not Disturb" is on

**iOS:**
1. Settings → App Name → Notifications → Ensure Allow Notifications is ON
2. Check notification style (Banners, Alerts, etc.)
3. Permission must be granted when first requested

### Scheduled Notifications Not Firing

**Android:**
1. Check battery optimization settings
2. Ensure app is not being killed in background
3. Verify SCHEDULE_EXACT_ALARM permission

**iOS:**
1. App must have been opened at least once
2. Check Background App Refresh settings

### Testing in Debug Mode
Scheduled notifications work in both debug and release modes, but:
- iOS simulator may not always show notifications
- Test on physical device for best results

## Migration Notes

### Removed Components
- `notification_banner.dart` widget (no longer needed)
- In-app banner display from `daily_log_calendar.dart`

### Changed Files
- `notification_service.dart` - Complete rewrite for native notifications
- `daily_log_calendar.dart` - Removed banner UI, added native notification triggers
- `main.dart` - Added notification initialization
- `pubspec.yaml` - Added dependencies
- `AndroidManifest.xml` - Added permissions

## Future Enhancements
- [ ] User preferences for notification times
- [ ] Snooze functionality
- [ ] Custom notification sounds
- [ ] Rich notifications with action buttons
- [ ] Weekly summary notifications
- [ ] Achievement unlocked notifications
