# In-App Notification System Guide

## Overview
The notification system provides real-time reminders to help users maintain their logging streak and meet their daily nutrition goals.

## Features

### 1. **Streak Reminder Notification**
- **When**: Shown when the user hasn't logged any meals for the current day
- **Purpose**: Encourages users to maintain their daily logging streak
- **Display**: Orange banner with fire icon at the top of the daily log screen
- **Message**: Adaptive based on current streak length (0, 1-2, 3-6, 7+ days)

### 2. **Evening Macro Reminder**
- **When**: Shown after 6:00 PM if daily nutrition goals haven't been met
- **Purpose**: Alerts users about remaining macros needed to reach their goals
- **Display**: Blue banner with restaurant icon
- **Calculations**: Includes both logged meals AND scheduled meals for the day
- **Message**: Lists specific macros still needed (protein, carbs, fat, calories)

## Implementation

### Files Created
1. **`lib/services/notification_service.dart`**
   - Core notification logic and calculations
   - Streak calculation
   - Macro remainder calculation
   - Message generation

2. **`lib/widgets/notification_banner.dart`**
   - Reusable notification banner UI component
   - Dismissible with swipe gesture
   - Customizable colors, icons, and messages

### Integration in `daily_log_calendar.dart`
- Notifications appear at the top of the screen
- Automatically checked when data loads or changes
- Users can dismiss notifications by swiping or tapping the X button
- State persists until dismissed or conditions change

## Usage Examples

### Show a Custom Notification
```dart
NotificationService.showInAppNotification(
  context,
  title: 'Achievement Unlocked!',
  message: 'You\'ve logged meals for 7 days straight!',
  icon: Icons.emoji_events,
  color: Colors.green,
);
```

### Calculate Current Streak
```dart
final streak = NotificationService.calculateStreak(foodLog);
print('Current streak: $streak days');
```

### Check Remaining Macros
```dart
final remaining = NotificationService.calculateRemainingMacros(
  currentTotals: dayTotals,
  goals: goals,
  scheduledMeals: scheduledMeals,
);
print('Still need: ${remaining['protein']}g protein');
```

## Customization

### Adjust Notification Timing
Edit the `isAfter6PM()` method in `notification_service.dart`:
```dart
static bool isAfter6PM() {
  final now = DateTime.now();
  return now.hour >= 18; // Change to desired hour (24-hour format)
}
```

### Modify Streak Messages
Edit `getStreakReminderMessage()` in `notification_service.dart` to customize messages based on streak length.

### Change Notification Colors
In `daily_log_calendar.dart`, modify the `NotificationBanner` widgets:
```dart
NotificationBanner(
  color: Colors.purple.shade700, // Change color here
  // ...
)
```

## Future Enhancements
- [ ] Push notifications (requires `flutter_local_notifications` package)
- [ ] Notification scheduling at specific times
- [ ] Weekly/monthly achievement notifications
- [ ] Goal completion celebrations
- [ ] Customizable notification preferences in settings
