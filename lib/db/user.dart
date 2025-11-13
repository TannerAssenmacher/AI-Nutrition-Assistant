import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user.g.dart';

@JsonSerializable(explicitToJson: true)
class AppUser {
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id; // Primary key (unique, never changes)

  final String firstname;
  final String lastname;
  final DateTime dob;
  final String sex;
  final double height; // inches
  final double weight; // pounds
  final String activityLevel;

  final MealProfile mealProfile;
  final List<FoodItem> loggedFoodItems;

  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime createdAt;

  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime updatedAt;

  AppUser({
    String? id,
    required this.firstname,
    required this.lastname,
    required this.dob,
    required this.sex,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.mealProfile,
    required this.loggedFoodItems,
    required this.createdAt,
    required this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  // 🔹 Generate Firestore-safe unique ID
  static Future<String> generateUniqueUserId() async {
    final usersRef = FirebaseFirestore.instance.collection('Users');
    final uuid = Uuid();

    while (true) {
      final id = uuid.v4();
      final doc = await usersRef.doc(id).get();
      if (!doc.exists) return id;
    }
  }

  // 🔹 Async factory for creation
  static Future<AppUser> create({
    required String firstname,
    required String lastname,
    required DateTime dob,
    required String sex,
    required double height,
    required double weight,
    required String activityLevel,
    required MealProfile mealProfile,
  }) async {
    final id = await generateUniqueUserId();
    final now = DateTime.now();

    return AppUser(
      id: id,
      firstname: firstname,
      lastname: lastname,
      dob: dob,
      sex: sex,
      height: height,
      weight: weight,
      activityLevel: activityLevel,
      mealProfile: mealProfile,
      loggedFoodItems: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  // 🔹 Firestore DateTime helpers
  static DateTime _dateFromJson(dynamic date) =>
      date is Timestamp ? date.toDate() : date as DateTime;

  static dynamic _dateToJson(DateTime date) => Timestamp.fromDate(date);

  // 🔹 JSON serialization
  factory AppUser.fromJson(Map<String, dynamic> json, String id) {
    final user = _$AppUserFromJson(json);
    return AppUser(
      id: id,
      firstname: user.firstname,
      lastname: user.lastname,
      dob: user.dob,
      sex: user.sex,
      height: user.height,
      weight: user.weight,
      activityLevel: user.activityLevel,
      mealProfile: user.mealProfile,
      loggedFoodItems: user.loggedFoodItems,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => _$AppUserToJson(this);

  // 🔹 Copy with
  AppUser copyWith({
    String? id,
    String? firstname,
    String? lastname,
    DateTime? dob,
    String? sex,
    double? height,
    double? weight,
    String? activityLevel,
    MealProfile? mealProfile,
    List<FoodItem>? loggedFoodItems,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      dob: dob ?? this.dob,
      sex: sex ?? this.sex,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      mealProfile: mealProfile ?? this.mealProfile,
      loggedFoodItems: loggedFoodItems ?? this.loggedFoodItems,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

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
}

// -----------------------------------------------------------------------------
// PREFERENCES
// -----------------------------------------------------------------------------
@JsonSerializable()
class Preferences {
  final List<String> likes;
  final List<String> dislikes;

  Preferences({required this.likes, required this.dislikes});

  factory Preferences.fromJson(Map<String, dynamic> json) =>
      _$PreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$PreferencesToJson(this);
}

// -----------------------------------------------------------------------------
// FOOD ITEM
// -----------------------------------------------------------------------------
@JsonSerializable()
class FoodItem {
  final String name;
  final double mass_g;
  final double calories_g;
  final double protein_g;
  final double carbs_g;
  final double fat;
  final String mealType; // breakfast/lunch/etc.

  @JsonKey(fromJson: AppUser._dateFromJson, toJson: AppUser._dateToJson)
  final DateTime consumedAt;

  FoodItem({
    required this.name,
    required this.mass_g,
    required this.calories_g,
    required this.protein_g,
    required this.carbs_g,
    required this.fat,
    required this.mealType,
    required this.consumedAt,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) =>
      _$FoodItemFromJson(json);
  Map<String, dynamic> toJson() => _$FoodItemToJson(this);
}

// -----------------------------------------------------------------------------
// COPYWITH EXTENSIONS
// -----------------------------------------------------------------------------

extension MealProfileCopy on MealProfile {
  MealProfile copyWith({
    List<String>? dietaryHabits,
    List<String>? allergies,
    Preferences? preferences,
    Map<String, double>? macroGoals,
    int? dailyCalorieGoal,
    String? dietaryGoal,
  }) {
    return MealProfile(
      dietaryHabits: dietaryHabits ?? this.dietaryHabits,
      healthRestrictions: allergies ?? this.healthRestrictions,
      preferences: preferences ?? this.preferences,
      macroGoals: macroGoals ?? this.macroGoals,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      dietaryGoal: dietaryGoal ?? this.dietaryGoal,
    );
  }
}

extension PreferencesCopy on Preferences {
  Preferences copyWith({
    List<String>? likes,
    List<String>? dislikes,
  }) {
    return Preferences(
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
    );
  }
}

extension FoodItemCopy on FoodItem {
  FoodItem copyWith({
    String? name,
    double? mass_g,
    double? calories_g,
    double? protein_g,
    double? carbs_g,
    double? fat,
    String? mealType,
    DateTime? consumedAt,
  }) {
    return FoodItem(
      name: name ?? this.name,
      mass_g: mass_g ?? this.mass_g,
      calories_g: calories_g ?? this.calories_g,
      protein_g: protein_g ?? this.protein_g,
      carbs_g: carbs_g ?? this.carbs_g,
      fat: fat ?? this.fat,
      mealType: mealType ?? this.mealType,
      consumedAt: consumedAt ?? this.consumedAt,
    );
  }
}
