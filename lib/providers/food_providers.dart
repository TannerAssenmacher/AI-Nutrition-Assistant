import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/food.dart';
import 'firestore_providers.dart';

part 'food_providers.g.dart';

@Riverpod(keepAlive: true)
class FoodLog extends _$FoodLog {
  @override
  List<FoodItem> build() {
    return [];
  }

  void addFoodItem(FoodItem item) {
    state = [...state, item];
  }

  void removeFoodItem(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clearLog() {
    state = [];
  }

  void updateFoodItem(FoodItem updatedItem) {
    state = state.map((item) {
      return item.id == updatedItem.id ? updatedItem : item;
    }).toList();
  }
}

@riverpod
int totalDailyCalories(Ref ref) {
  final foodLog = ref.watch(foodLogProvider);
  final today = DateTime.now();

  return foodLog
      .where((item) =>
          item.consumedAt.year == today.year &&
          item.consumedAt.month == today.month &&
          item.consumedAt.day == today.day)
      .fold(
          0, (total, item) => total + (item.calories_g * item.mass_g).round());
}

@riverpod
Map<String, double> totalDailyMacros(Ref ref) {
  final foodLog = ref.watch(foodLogProvider);
  final today = DateTime.now();

  double protein = 0;
  double carbs = 0;
  double fat = 0;

  for (final item in foodLog.where((i) =>
      i.consumedAt.year == today.year &&
      i.consumedAt.month == today.month &&
      i.consumedAt.day == today.day)) {
    protein += item.protein_g * item.mass_g;
    carbs += item.carbs_g * item.mass_g;
    fat += item.fat * item.mass_g;
  }

  return {
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
}

@riverpod
Future<List<String>> foodSuggestions(Ref ref) async {
  await Future.delayed(const Duration(seconds: 1));

  return [
    'Apple (80 calories)',
    'Banana (105 calories)',
    'Chicken Breast (165 calories)',
    'Brown Rice (110 calories)',
    'Greek Yogurt (100 calories)',
    'Salmon (206 calories)',
    'Broccoli (34 calories)',
    'Sweet Potato (112 calories)',
  ];
}

@riverpod
Future<int> dailyStreak(Ref ref, String userId) async {
  final foodLogAsync = ref.watch(firestoreFoodLogProvider(userId));

  return foodLogAsync.when(
    data: (foodLog) {
      if (foodLog.isEmpty) {
        return 0;
      }

      // Get unique dates from food log (sorted in descending order)
      final datesWithFood = <DateTime>{};
      for (final item in foodLog) {
        datesWithFood.add(DateTime(item.consumedAt.year, item.consumedAt.month, item.consumedAt.day));
      }

      final sortedDates = datesWithFood.toList()..sort((a, b) => b.compareTo(a));

      if (sortedDates.isEmpty) {
        return 0;
      }

      // Check if today has any food logged
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final yesterdayDate = todayDate.subtract(const Duration(days: 1));

      // If the most recent day with food is not today or yesterday, streak is broken
      if (sortedDates.first != todayDate && sortedDates.first != yesterdayDate) {
        return 0;
      }

      // Count consecutive days
      int streak = 0;
      DateTime expectedDate = sortedDates.first;

      for (final date in sortedDates) {
        if (date == expectedDate) {
          streak++;
          expectedDate = expectedDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    },
    error: (_, __) => 0,
    loading: () => 0,
  );
}
