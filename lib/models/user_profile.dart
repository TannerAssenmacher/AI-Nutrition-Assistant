class UserProfile {
  final String id;
  final String name;
  final int age;
  final double weight; // in kg
  final double height; // in cm
  final String activityLevel; // sedentary, lightly_active, moderately_active, very_active
  final String goal; // lose_weight, maintain_weight, gain_weight
  final int dailyCalorieGoal;

  const UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.activityLevel,
    required this.goal,
    required this.dailyCalorieGoal,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    int? age,
    double? weight,
    double? height,
    String? activityLevel,
    String? goal,
    int? dailyCalorieGoal,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
    );
  }

  double get bmi => weight / ((height / 100) * (height / 100));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.name == name &&
        other.age == age &&
        other.weight == weight &&
        other.height == height &&
        other.activityLevel == activityLevel &&
        other.goal == goal &&
        other.dailyCalorieGoal == dailyCalorieGoal;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, age, weight, height, activityLevel, goal, dailyCalorieGoal);
  }
}