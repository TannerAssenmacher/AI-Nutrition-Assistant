import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food.dart';
import 'meal_profile.dart';

part 'user.g.dart';

// -----------------------------------------------------------------------------
// APP USER
// -----------------------------------------------------------------------------

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

  @JsonKey(fromJson: dateFromJson, toJson: dateToJson)
  final DateTime createdAt;

  @JsonKey(fromJson: dateFromJson, toJson: dateToJson)
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

  // Generate Firestore-safe unique ID
  static Future<String> generateUniqueUserId() async {
    final usersRef = FirebaseFirestore.instance.collection('Users');
    final uuid = Uuid();

    while (true) {
      final id = uuid.v4();
      final doc = await usersRef.doc(id).get();
      if (!doc.exists) return id;
    }
  }

  // Async factory for creation
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

  // Firestore DateTime helpers
  static DateTime dateFromJson(dynamic date) =>
      date is Timestamp ? date.toDate() : date as DateTime;

  static dynamic dateToJson(DateTime date) => Timestamp.fromDate(date);

  // JSON serialization
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

  // Copy with
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