// import 'food.dart';
// import 'user.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';




// class DailyLog {
//   final 
//   final DateTime date;
//   final List<Food> foods; // List of foods consumed on this date
//   final double totalCalories;
//   final double totalProtein;
//   final double totalFat;
//   final double totalCarbs;
//   final double totalFiber;

//   DailyLog({
//     required this.date,
//     required this.foods,
//     required this.totalCalories,
//     required this.totalProtein,
//     required this.totalFat,
//     required this.totalCarbs,
//     required this.totalFiber,
//   });

//   factory DailyLog.fromMap(Map<String, dynamic> map) {
//     return DailyLog(

//     )
//   }

//   if (dotenv.env['USDA_API_KEY'] != null) {
//   print(USDA API Key successfully loaded.");
// } else {
//   print("USDA API Key missing or not found.");
// }

// }

import 'food.dart';
import 'user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// DailyLog tracks a user's food intake and nutrition totals for a single day
class DailyLog {
  // Date string in YYYY-MM-DD format (e.g. "2025-11-04") used as document ID
  final String id;
  
  /// User's email (matches AppUser.email) - used as foreign key to Users collection
  final String email; // Foreign key to AppUser
  final DateTime date;
  final List<Food> foods; // List of foods consumed on this date
  final double totalCalories;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;
  final double totalFiber;

  DailyLog({
    required this.id,
    required this.email,
    required this.date,
    required this.foods,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    required this.totalFiber,
  });

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      date: DateTime.parse(map['date']),
      foods: (map['foods'] as List)
          .map((item) => Food.fromJson(item as Map<String, dynamic>, item['id'] as String))
          .toList(),
      totalCalories: map['totalCalories'] ?? 0.0,
      totalProtein: map['totalProtein'] ?? 0.0,
      totalFat: map['totalFat'] ?? 0.0,
      totalCarbs: map['totalCarbs'] ?? 0.0,
      totalFiber: map['totalFiber'] ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'date': date.toIso8601String(),
      'foods': foods.map((f) => f.toJson()).toList(),
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
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    return DailyLog(
      id: dateStr,
      email: user.email,
      date: now,
      foods: [],
      totalCalories: 0,
      totalProtein: 0,
      totalFat: 0,
      totalCarbs: 0,
      totalFiber: 0,
    );
  }

  /// Check if the daily totals are within the user's goals
  bool isWithinGoals(AppUser user) {
    if (totalCalories > user.dailyCalorieGoal) return false;
    
    final proteinGoal = user.macroGoals['protein'] ?? 0.0;
    final fatGoal = user.macroGoals['fat'] ?? 0.0;
    final carbsGoal = user.macroGoals['carbs'] ?? 0.0;
    
    return totalProtein <= proteinGoal &&
           totalFat <= fatGoal &&
           totalCarbs <= carbsGoal;
  }
}
