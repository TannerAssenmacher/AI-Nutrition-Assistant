import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user.g.dart';

@JsonSerializable(explicitToJson: true)
class AppUser {
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id; // always unique, never changed

  final String firstname;
  final String lastname;
  final String email;
  final String password; // should be hashed
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

  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime createdAt;

  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime updatedAt;

  AppUser({
    String? id,
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
  }) : id = id ?? const Uuid().v4(); // generate once if not passed

  /// 🔹 Generate unique ID from Firestore + UUID
  static Future<String> generateUniqueUserId() async {
    final usersRef = FirebaseFirestore.instance.collection('Users');
    final uuid = Uuid();

    while (true) {
      final id = uuid.v4();
      final doc = await usersRef.doc(id).get();
      if (!doc.exists) return id;
    }
  }

  /// 🔹 Async factory that creates a user with unique ID
  static Future<AppUser> create({
    required String firstname,
    required String lastname,
    required String email,
    required String password,
    required int age,
    required String sex,
    required double height,
    required double weight,
    required String activityLevel,
    required String dietaryGoal,
    required MealProfile mealProfile,
    required Map<String, MealPlan> mealPlans,
    required int dailyCalorieGoal,
    required Map<String, double> macroGoals,
  }) async {
    final id = await generateUniqueUserId();
    final now = DateTime.now();

    return AppUser(
      id: id,
      firstname: firstname,
      lastname: lastname,
      email: email,
      password: password,
      age: age,
      sex: sex,
      height: height,
      weight: weight,
      activityLevel: activityLevel,
      dietaryGoal: dietaryGoal,
      mealProfile: mealProfile,
      mealPlans: mealPlans,
      dailyCalorieGoal: dailyCalorieGoal,
      macroGoals: macroGoals,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Firestore DateTime helpers
  static DateTime _dateFromJson(dynamic date) =>
      date is Timestamp ? date.toDate() : date as DateTime;

  static dynamic _dateToJson(DateTime date) => Timestamp.fromDate(date);

  /// JSON serialization
  factory AppUser.fromJson(Map<String, dynamic> json, String id) {
    final user = _$AppUserFromJson(json);
    return AppUser(
      id: id,
      firstname: user.firstname,
      lastname: user.lastname,
      email: user.email,
      password: user.password,
      age: user.age,
      sex: user.sex,
      height: user.height,
      weight: user.weight,
      activityLevel: user.activityLevel,
      dietaryGoal: user.dietaryGoal,
      mealProfile: user.mealProfile,
      mealPlans: user.mealPlans,
      dailyCalorieGoal: user.dailyCalorieGoal,
      macroGoals: user.macroGoals,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }


  Map<String, dynamic> toJson() => _$AppUserToJson(this);

  /// Copy with updates
  AppUser copyWith({
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
    return AppUser(
      id: id ?? this.id,
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
  final List<String> likes;
  final List<String> dislikes;

  Preferences({required this.likes, required this.dislikes});

  factory Preferences.fromJson(Map<String, dynamic> json) =>
      _$PreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$PreferencesToJson(this);
}

@JsonSerializable(explicitToJson: true)
class MealPlan {
  final String planName;

  @JsonKey(fromJson: AppUser._dateFromJson, toJson: AppUser._dateToJson)
  final DateTime startDate;

  @JsonKey(fromJson: AppUser._dateFromJson, toJson: AppUser._dateToJson)
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
