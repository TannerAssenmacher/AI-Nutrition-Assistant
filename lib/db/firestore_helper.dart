import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';
import 'food.dart';
import 'meal.dart';
import 'daily_log.dart';

class FirestoreHelper {
  static FirebaseFirestore _db = FirebaseFirestore.instance;
  static void useDb(FirebaseFirestore db) => _db = db;
  static const String usersCollection = 'Users';
  static const String foodCollection = 'Food';
  static const String mealsCollection = 'Meals';
  static const String dailyLogsCollection = 'DailyLogs';

  // ---------------------------------------------------------------------------
  // USER CRUD
  // ---------------------------------------------------------------------------

  static Future<void> createUser(AppUser user) async {
    final docRef = _db.collection(usersCollection).doc(user.id);
    final snap = await docRef.get();
    if (snap.exists) throw StateError('User ${user.id} already exists.');
    await docRef.set(user.toJson());
    print('Created user ${user.id}.');
  }

  static Future<void> updateUser(AppUser user) async {
    final docRef = _db.collection(usersCollection).doc(user.id);
    final snap = await docRef.get();
    if (!snap.exists) throw StateError('User ${user.id} does not exist.');
    await docRef.update(user.toJson());
    print('Updated user ${user.id}.');
  }

  static Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _db.collection(usersCollection).doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromJson(doc.data()!, doc.id);
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  static Future<void> deleteUser(String userId) async {
    await _db.collection(usersCollection).doc(userId).delete();
    print('Deleted user $userId.');
  }

  /// Get a list of all users.
  static Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _db.collection(usersCollection).get();
      return snapshot.docs
          .map((d) => AppUser.fromJson(d.data(), d.id))
          .toList();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  static Future<bool> userExists(String userId) async {
    final doc = await _db.collection(usersCollection).doc(userId).get();
    return doc.exists;
  }

  static Future<void> _updateDailyLogForDate(
      String email, DateTime date) async {
    final meals = await getMealsForUserOnDate(email, date);
    final logId = _dateId(date);
    final dailyLog =
        DailyLog.fromMeals(id: logId, email: email, date: date, meals: meals);
    await _db.collection(dailyLogsCollection).doc(logId).set(dailyLog.toMap());
  }

  // ---------------------------------------------------------------------------
  // FOOD CRUD
  // ---------------------------------------------------------------------------

  // Add a food item to logged foods for a user
  static Future<void> addFoodItem(String userId, FoodItem food) async {
    final docRef = _db.collection(usersCollection).doc(userId);
    final snap = await docRef.get();

    if (!snap.exists) throw StateError('User $userId does not exist.');

    await docRef.update({
      'loggedFoodItems': FieldValue.arrayUnion([food.toJson()])
    });

    print('Added food ${food.id} to user $userId.');
  }

  // Update existing food item for already logged meal for a user
  static Future<void> updateFoodItem(String userId, FoodItem updated) async {
    final docRef = _db.collection(usersCollection).doc(userId);
    final snap = await docRef.get();

    if (!snap.exists) throw StateError('User $userId does not exist.');

    final data = snap.data()!;
    final List<dynamic> items = data['loggedFoodItems'] ?? [];

    final index = items.indexWhere((item) => item['id'] == updated.id);
    if (index == -1) throw StateError('Food ${updated.id} does not exist.');

    items[index] = updated.toJson();

    await docRef.update({'loggedFoodItems': items});
    print('Updated food ${updated.id} for user $userId.');
  }

  // Delete a food item from logged foods for a user
  static Future<void> deleteFoodItem(String userId, String foodId) async {
    final docRef = _db.collection(usersCollection).doc(userId);
    final snap = await docRef.get();

    if (!snap.exists) throw StateError('User $userId does not exist.');

    final data = snap.data()!;
    final List<dynamic> items = data['loggedFoodItems'] ?? [];

    items.removeWhere((item) => item['id'] == foodId);

    await docRef.update({'loggedFoodItems': items});
    print('Deleted food $foodId from user $userId.');
  }

  // Returns a list of all logged food items for a user
  static Future<List<FoodItem>> getAllFoodItems(String userId) async {
    final doc = await _db.collection(usersCollection).doc(userId).get();
    if (!doc.exists) return [];

    final List<dynamic> items = doc.data()!['loggedFoodItems'] ?? [];
    return items.map((e) => FoodItem.fromJson(e)).toList();
  }

  // Returns a single food item in a user's logged food items
  static Future<FoodItem?> getFoodItem(String userId, String foodId) async {
    final doc = await _db.collection(usersCollection).doc(userId).get();
    if (!doc.exists) return null;

    final List<dynamic> items = doc.data()!['loggedFoodItems'] ?? [];
    final match = items.firstWhere(
      (item) => item['id'] == foodId,
      orElse: () => null,
    );

    return match == null ? null : FoodItem.fromJson(match);
  }

  // ---------------------------------------------------------------------------
  // MEAL CRUD
  // ---------------------------------------------------------------------------

  static Future<void> createMeal(Meal meal) async {
    final docRef = _db.collection(mealsCollection).doc(meal.id);
    if ((await docRef.get()).exists) {
      throw StateError('Meal ${meal.id} already exists.');
    }
    await docRef.set(meal.toJson());
  }

  static Future<void> updateMeal(Meal meal) async {
    final docRef = _db.collection(mealsCollection).doc(meal.id);
    if (!(await docRef.get()).exists) {
      throw StateError('Meal ${meal.id} does not exist.');
    }
    await docRef.update(meal.toJson());
  }

  static Future<Meal?> getMeal(String id) async {
    final doc = await _db.collection(mealsCollection).doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Meal.fromJson(doc.data()!, doc.id);
  }

  static Future<void> deleteMeal(String id) async {
    await _db.collection(mealsCollection).doc(id).delete();
  }

  static Future<List<Meal>> getMealsForUserOnDate(
    String email,
    DateTime date,
  ) async {
    final snap = await _db
        .collection(mealsCollection)
        .where('userEmail', isEqualTo: email)
        .where(
          'date',
          isEqualTo:
              Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        )
        .get();
    return snap.docs.map((d) => Meal.fromJson(d.data(), d.id)).toList();
  }

  // ---------------------------------------------------------------------------
  // DAILY LOG HELPERS
  // ---------------------------------------------------------------------------

  /// Fetch totals (calories + macros) for a specific date.
  /// - Looks up DailyLogs/{yyyy-MM-dd}; if missing, builds it from Meals on that date.
  /// - Returns null when nothing is logged for that date.
  static Future<DailyLog?> getDailyLogForDate(
    String email,
    DateTime date,
  ) async {
    final logId = _dateId(date);
    final doc = await _db.collection(dailyLogsCollection).doc(logId).get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!..['id'] = doc.id;
      return DailyLog.fromMap(data);
    }

    final meals = await getMealsForUserOnDate(email, date);
    if (meals.isEmpty) return null;
    return DailyLog.fromMeals(
      id: logId,
      email: email,
      date: date,
      meals: meals,
    );
  }

  static String _dateId(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  // ---------------------------------------------------------------------------
  // UTILITIES
  // ---------------------------------------------------------------------------

  // Print all data in Users database
  static Future<void> printAllData() async {
    try {
      print('Dumping all Firestore data...');

      final usersSnap = await _db.collection(usersCollection).get();
      for (final doc in usersSnap.docs) {
        print('User ${doc.id}: ${doc.data()}');
      }

      print('Finished printing database.');
    } catch (e) {
      print('Error printing database: $e');
    }
  }
}
