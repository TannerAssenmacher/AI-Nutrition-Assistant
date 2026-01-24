import 'meal.dart';
import 'food.dart';
import 'user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// DailyLog tracks a user's food intake and nutrition totals for a single day
class DailyLog {
  // Date string in YYYY-MM-DD format (e.g. "2025-11-04") used as document ID
  final String id;

  /// User's ID (matches AppUser.id) - used as foreign key to Users collection
  final String userId; // Foreign key to AppUser
  final DateTime date;
  final List<FoodItem> foods; // List of foods consumed on this date
  final List<String> mealIds;
  final double totalCalories;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;
  final double totalFiber;

  DailyLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.foods,
    required this.mealIds, // add to constructor
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    required this.totalFiber,
  });

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      date: DateTime.parse(map['date']),
      foods: (map['foods'] as List? ?? [])
          .map((item) => FoodItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      mealIds: (map['mealIds'] as List? ?? []).cast<String>(), // add this
      totalCalories: map['totalCalories'] ?? 0.0,
      totalProtein: map['totalProtein'] ?? 0.0,
      totalFat: map['totalFat'] ?? 0.0,
      totalCarbs: map['totalCarbs'] ?? 0.0,
      totalFiber: map['totalFiber'] ?? 0.0,
    );
  }

  static DailyLog fromMeals({
    required String id,
    required String userId,
    required DateTime date,
    required List<Meal> meals,
  }) {
    double calories = 0, protein = 0, fat = 0, carbs = 0, fiber = 0;
    for (final m in meals) {
      calories += m.calories;
      protein += m.protein;
      fat += m.fat;
      carbs += m.carbs;
      fiber += m.fiber;
    }
    return DailyLog(
      id: id,
      userId: userId,
      date: date,
      foods: const [],
      mealIds: meals.map((m) => m.id).toList(),
      totalCalories: calories,
      totalProtein: protein,
      totalFat: fat,
      totalCarbs: carbs,
      totalFiber: fiber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'foods': foods.map((f) => f.toJson()).toList(),
      'mealIds': mealIds, // add this
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalFat': totalFat,
      'totalCarbs': totalCarbs,
      'totalFiber': totalFiber,
    };
  }

  void verifyApiKey() {
    if (dotenv.env['USDA_API_KEY'] != null) {
      print("USDA API Key successfully loaded.");
    } else {
      print("USDA API Key missing or not found.");
    }
  }

  /// Creates a DailyLog for today for the given user
  static DailyLog createForToday(AppUser user) {
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return DailyLog(
      id: dateStr,
      userId: user.id,
      date: now,
      foods: [],
      mealIds: [],
      totalCalories: 0,
      totalProtein: 0,
      totalFat: 0,
      totalCarbs: 0,
      totalFiber: 0,
    );
  }

  /// Check if the daily totals are within the user's goals
  bool isWithinGoals(AppUser user) {
    if (totalCalories > user.mealProfile.dailyCalorieGoal) return false;

    final proteinGoal = user.mealProfile.macroGoals['protein'] ?? 0.0;
    final fatGoal = user.mealProfile.macroGoals['fat'] ?? 0.0;
    final carbsGoal = user.mealProfile.macroGoals['carbs'] ?? 0.0;

    return totalProtein <= proteinGoal &&
        totalFat <= fatGoal &&
        totalCarbs <= carbsGoal;
  }
}
