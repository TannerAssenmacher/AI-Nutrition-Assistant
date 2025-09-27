import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

@JsonSerializable()
class UserProfile {
  final String id;
  final String name;
  final int age;
  final double weight; // in kg
  final double height; // in cm
  final String activityLevel; // sedentary, lightly_active, moderately_active, very_active
  final int dailyCalorieGoal;
  final Map<String, double> macroGoals;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.activityLevel,
    required this.dailyCalorieGoal,
    required this.macroGoals,
    required this.createdAt,
    required this.updatedAt,
  });

  // JSON serialization methods
  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  // CopyWith method for easy updates
  UserProfile copyWith({
    String? id,
    String? name,
    int? age,
    double? weight,
    double? height,
    String? activityLevel,
    int? dailyCalorieGoal,
    Map<String, double>? macroGoals,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      activityLevel: activityLevel ?? this.activityLevel,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      macroGoals: macroGoals ?? this.macroGoals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}