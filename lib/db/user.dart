import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'meal_profile.dart';
import 'preferences.dart';

part 'user.g.dart';

// -----------------------------------------------------------------------------
// APP USER
// -----------------------------------------------------------------------------

@JsonSerializable(explicitToJson: true)
class AppUser {
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id; // Primary key (unique, never changes)

  @JsonKey(fromJson: _stringFromJson)
  final String firstname;
  @JsonKey(fromJson: _stringFromJson)
  final String lastname;
  final DateTime? dob; // nullable - some users may not have DOB set
  @JsonKey(fromJson: _stringFromJson)
  final String sex;
  @JsonKey(fromJson: _doubleFromJson)
  final double height; // inches
  @JsonKey(fromJson: _doubleFromJson)
  final double weight; // pounds
  @JsonKey(fromJson: _stringFromJson)
  final String activityLevel;

  @JsonKey(fromJson: _mealProfileFromJson)
  final MealProfile mealProfile;

  @JsonKey(fromJson: _dateFromJson, toJson: dateToJson)
  final DateTime createdAt;

  @JsonKey(fromJson: _dateFromJson, toJson: dateToJson)
  final DateTime updatedAt;

  static String _stringFromJson(dynamic value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return '';
  }

  static double _doubleFromJson(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  static MealProfile _mealProfileFromJson(dynamic value) {
    if (value is Map<String, dynamic>) return MealProfile.fromJson(value);
    return MealProfile(
      dietaryHabits: [],
      healthRestrictions: [],
      preferences: Preferences(likes: [], dislikes: []),
      macroGoals: {'protein': 150.0, 'carbs': 200.0, 'fat': 65.0},
      dailyCalorieGoal: 2000,
      dietaryGoal: '',
    );
  }

  static DateTime _dateFromJson(dynamic date) {
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    return DateTime.now();
  }

  AppUser({
    String? id,
    required this.firstname,
    required this.lastname,
    this.dob, // nullable
    required this.sex,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.mealProfile,
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
      createdAt: now,
      updatedAt: now,
    );
  }

  // Firestore DateTime helpers
  static DateTime dateFromJson(dynamic date) {
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    return DateTime.now();
  }

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
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => _$AppUserToJson(this);

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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
