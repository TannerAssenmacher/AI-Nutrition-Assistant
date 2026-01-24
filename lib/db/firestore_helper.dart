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
  }

  static Future<void> updateUser(AppUser user) async {
    final docRef = _db.collection(usersCollection).doc(user.id);
    final snap = await docRef.get();
    if (!snap.exists) throw StateError('User ${user.id} does not exist.');
    await docRef.update(user.toJson());
  }

  static Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _db.collection(usersCollection).doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromJson(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteUser(String userId) async {
    await _db.collection(usersCollection).doc(userId).delete();
  }

  static Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _db.collection(usersCollection).get();
      return snapshot.docs.map((d) => AppUser.fromJson(d.data(), d.id)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> userExists(String userId) async {
    final doc = await _db.collection(usersCollection).doc(userId).get();
    return doc.exists;
  }

  static Future<void> _updateDailyLogForDate(String email, DateTime date) async {
    final meals = await getMealsForUserOnDate(email, date);
    final logId = _dateId(date);
    final dailyLog =
        DailyLog.fromMeals(id: logId, email: email, date: date, meals: meals);
    await _db.collection(dailyLogsCollection).doc(logId).set(dailyLog.toMap());
  }

  // ---------------------------------------------------------------------------
  // FOOD CRUD
  // ---------------------------------------------------------------------------

  static Future<void> createFood(Food food) async {
    final docRef = _db.collection(foodCollection).doc(food.id);
    if ((await docRef.get()).exists) {
      throw StateError('Food ${food.id} already exists.');
    }
    await docRef.set(food.toJson());
  }

  static Future<void> updateFood(Food food) async {
    final docRef = _db.collection(foodCollection).doc(food.id);
    if (!(await docRef.get()).exists) {
      throw StateError('Food ${food.id} does not exist.');
    }
    await docRef.update(food.toJson());
  }

  static Future<Food?> getFood(String foodId) async {
    try {
      final doc = await _db.collection(foodCollection).doc(foodId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Food.fromJson(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteFood(String foodId) async {
    await _db.collection(foodCollection).doc(foodId).delete();
  }

  static Future<List<Food>> getAllFoods() async {
    try {
      final snapshot = await _db.collection(foodCollection).get();
      return snapshot.docs.map((d) => Food.fromJson(d.data(), d.id)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> foodExists(String foodId) async {
    final doc = await _db.collection(foodCollection).doc(foodId).get();
    return doc.exists;
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

  static Future<void> printAllData() async {
    try {
      final usersSnap = await _db.collection(usersCollection).get();
      for (final doc in usersSnap.docs) {
        print('User ${doc.id}: ${doc.data()}');
      }

      final foodsSnap = await _db.collection(foodCollection).get();
      for (final doc in foodsSnap.docs) {
        print('Food ${doc.id}: ${doc.data()}');
      }
    } catch (e) {
      print('Error printing database: $e');
    }
  }
}
