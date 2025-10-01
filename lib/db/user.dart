class User
{
  final String id;
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

  User({
    required this.id,
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
  });

  factory User.fromJson(Map<String, dynamic> json, String id)
  {
    // Ensure nested objects are typed maps before parsing
    final profileRaw = Map<String, dynamic>.from(
      (json['meal_profile'] ?? const {})['profile'] ?? const {},
    );

    final mealPlansRaw = Map<String, dynamic>.from(
    json['meal_plans'] ?? const {},
    );

    return User(
      id: id,
      firstname: json['firstname'] ?? '',
      lastname: json['lastname'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      age: json['age'] ?? 0,
      sex: json['sex'] ?? '',
      height: (json['height'] ?? 0).toDouble(),
      weight: (json['weight'] ?? 0).toDouble(),
      activityLevel: json['activity_level'] ?? '',
      dietaryGoal: json['dietary_goal'] ?? '',
      mealProfile: MealProfile.fromJson(profileRaw),
      mealPlans: mealPlansRaw.map<String, MealPlan>((key, value) {
      final item = MealPlan.fromJson(Map<String, dynamic>.from(value ?? {}));
      return MapEntry(key, item);
      }),
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'firstname': firstname,
      'lastname': lastname,
      'email': email,
      'password': password,
      'age': age,
      'sex': sex,
      'height': height,
      'weight': weight,
      'activity_level': activityLevel,
      'dietary_goal': dietaryGoal,
      'meal_profile': {'profile': mealProfile.toJson()},
      'meal_plans':
      mealPlans.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

class MealProfile {
  final List<String> dietaryHabits;
  final List<String> allergies;
  final Preferences preferences;

  MealProfile({
    required this.dietaryHabits,
    required this.allergies,
    required this.preferences,
  });

  factory MealProfile.fromJson(Map<String, dynamic> json) {
    return MealProfile(
      dietaryHabits: List<String>.from(json['dietary_habits'] ?? const []),
      allergies: List<String>.from(json['allergies'] ?? const []),
      preferences: Preferences.fromJson(
      Map<String, dynamic>.from(json['preferences'] ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dietary_habits': dietaryHabits,
      'allergies': allergies,
      'preferences': preferences.toJson(),
    };
  }
}

class Preferences {
  final List<String> likes; // food ids
  final List<String> dislikes; // food ids

  Preferences({required this.likes, required this.dislikes});

  factory Preferences.fromJson(Map<String, dynamic> json) {
    return Preferences(
      likes: List<String>.from(json['likes'] ?? []),
      dislikes: List<String>.from(json['dislikes'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'likes': likes,
      'dislikes': dislikes,
    };
  }
}

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

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final itemsRaw = Map<String, dynamic>.from(
      json['meal_plan_items'] ?? const {},
    );
    return MealPlan(
      planName: json['plan_name'] ?? '',
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      mealPlanItems: itemsRaw.map<String, MealPlanItem>((key, value) {
        final item = MealPlanItem.fromJson(
          Map<String, dynamic>.from(value ?? const {}),
        );
        return MapEntry(key, item);
      }),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_name': planName,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'meal_plan_items':
      mealPlanItems.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

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

  factory MealPlanItem.fromJson(Map<String, dynamic> json) {
    return MealPlanItem(
      mealType: json['meal_type'] ?? '',
      foodId: json['food_id'] ?? '',
      description: json['description'] ?? '',
      portionSize: json['portion_size'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meal_type': mealType,
      'food_id': foodId,
      'description': description,
      'portion_size': portionSize,
    };
  }
}
