import 'package:json_annotation/json_annotation.dart';
import 'preferences.dart';

part 'meal_profile.g.dart';

// -----------------------------------------------------------------------------
// MEAL PROFILE
// -----------------------------------------------------------------------------

@JsonSerializable(explicitToJson: true)
class MealProfile {
  final List<String> dietaryHabits;
  final List<String> healthRestrictions;
  final Preferences preferences;
  final Map<String, double> macroGoals; // {protein: g, carbs: g, fat: g}
  final int dailyCalorieGoal;
  final String dietaryGoal;

  MealProfile({
    required this.dietaryHabits,
    required this.healthRestrictions,
    required this.preferences,
    required this.macroGoals,
    required this.dailyCalorieGoal,
    required this.dietaryGoal,
  });

  factory MealProfile.fromJson(Map<String, dynamic> json) =>
      _$MealProfileFromJson(json);
  Map<String, dynamic> toJson() => _$MealProfileToJson(this);

  MealProfile copyWith({
    List<String>? dietaryHabits,
    List<String>? healthRestrictions,
    Preferences? preferences,
    Map<String, double>? macroGoals,
    int? dailyCalorieGoal,
    String? dietaryGoal,
  }) {
    return MealProfile(
      dietaryHabits: dietaryHabits ?? this.dietaryHabits,
      healthRestrictions: healthRestrictions ?? this.healthRestrictions,
      preferences: preferences ?? this.preferences,
      macroGoals: macroGoals ?? this.macroGoals,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      dietaryGoal: dietaryGoal ?? this.dietaryGoal,
    );
  }
}




// -----------------------------------------------------------------------------
// MEAL Plan
// -----------------------------------------------------------------------------

// @JsonSerializable(explicitToJson: true)
// class MealPlan {
//   final String planName;
//
//   @JsonKey(fromJson: AppUser._dateFromJson, toJson: AppUser._dateToJson)
//   final DateTime startDate;
//
//   @JsonKey(fromJson: AppUser._dateFromJson, toJson: AppUser._dateToJson)
//   final DateTime endDate;
//
//   final Map<String, MealPlanItem> mealPlanItems;
//
//   MealPlan({
//     required this.planName,
//     required this.startDate,
//     required this.endDate,
//     required this.mealPlanItems,
//   });
//
//   factory MealPlan.fromJson(Map<String, dynamic> json) =>
//       _$MealPlanFromJson(json);
//
//   Map<String, dynamic> toJson() => _$MealPlanToJson(this);
// }
//
// @JsonSerializable()
// class MealPlanItem {
//   final String mealType;
//   final String foodId;
//   final String description;
//   final String portionSize; // in grams
//
//   MealPlanItem({
//     required this.mealType,
//     required this.foodId,
//     required this.description,
//     required this.portionSize,
//   });
//
//   factory MealPlanItem.fromJson(Map<String, dynamic> json) =>
//       _$MealPlanItemFromJson(json);
//
//   Map<String, dynamic> toJson() => _$MealPlanItemToJson(this);
// }
