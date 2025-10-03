
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable(explicitToJson: true)
class User {
  @JsonKey(includeFromJson: false, includeToJson: false)
  late String id;
  final String firstname;
  final String lastname;
  final String email;
  final String password; // should be hashed!
  final int age;
  final String sex;
  final double height; // in inches
  final double weight; // in pounds
  final String activityLevel;
  final String dietaryGoal;
  final MealProfile mealProfile;
  final Map<String, MealPlan> mealPlans;
  final int dailyCalorieGoal;
  final Map<String, double> macroGoals;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.password,
    required this.age,
    required this.sex,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.dietaryGoal,
    required this.mealProfile,
    required this.mealPlans,
    required this.dailyCalorieGoal,
    required this.macroGoals,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json, String id) {
    final user = _$UserFromJson(json);
    user.id = id;
    return user;
  }

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? firstname,
    String? lastname,
    String? email,
    String? password,
    int? age,
    String? sex,
    double? height,
    double? weight,
    String? activityLevel,
    String? dietaryGoal,
    MealProfile? mealProfile,
    Map<String, MealPlan>? mealPlans,
    int? dailyCalorieGoal,
    Map<String, double>? macroGoals,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final user = User(
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      email: email ?? this.email,
      password: password ?? this.password,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      dietaryGoal: dietaryGoal ?? this.dietaryGoal,
      mealProfile: mealProfile ?? this.mealProfile,
      mealPlans: mealPlans ?? this.mealPlans,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      macroGoals: macroGoals ?? this.macroGoals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
    user.id = id ?? this.id;
    return user;
  }
}

@JsonSerializable(explicitToJson: true)
class MealProfile {
  final List<String> dietaryHabits;
  final List<String> allergies;
  final Preferences preferences;

  MealProfile({
    required this.dietaryHabits,
    required this.allergies,
    required this.preferences,
  });

  factory MealProfile.fromJson(Map<String, dynamic> json) =>
      _$MealProfileFromJson(json);

  Map<String, dynamic> toJson() => _$MealProfileToJson(this);
}

@JsonSerializable()
class Preferences {
  final List<String> likes; // food ids
  final List<String> dislikes; // food ids

  Preferences({required this.likes, required this.dislikes});

  factory Preferences.fromJson(Map<String, dynamic> json) =>
      _$PreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$PreferencesToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MealPlan {
  final String planName;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, MealPlanItem> mealPlanItems;

  MealPlan({
    required this.planName,
    required this.startDate,
    required this.endDate,
    required this.mealPlanItems,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) =>
      _$MealPlanFromJson(json);

  Map<String, dynamic> toJson() => _$MealPlanToJson(this);
}

@JsonSerializable()
class MealPlanItem {
  final String mealType;
  final String foodId;
  final String description;
  final String portionSize; // in grams

  MealPlanItem({
    required this.mealType,
    required this.foodId,
    required this.description,
    required this.portionSize,
  });

  factory MealPlanItem.fromJson(Map<String, dynamic> json) =>
      _$MealPlanItemFromJson(json);

  Map<String, dynamic> toJson() => _$MealPlanItemToJson(this);
}
