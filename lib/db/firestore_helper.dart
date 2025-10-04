import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';
import 'food.dart';

class FirestoreHelper {
  static FirebaseFirestore _db = FirebaseFirestore.instance;
  static void useDb(FirebaseFirestore db) => _db = db;

  static const String usersCollection = 'Users';
  static const String foodCollection  = 'Food';

  // ---------------------------------------------------------------------------
  // USER CRUD
  // ---------------------------------------------------------------------------

  /// Create a new user. Fails if the document already exists.
  static Future<void> createUser(AppUser user) async {
    final docRef = _db.collection(usersCollection).doc(user.id);
    final snap = await docRef.get();
    if (snap.exists) {
      throw StateError('User ${user.id} already exists.');
    }
    await docRef.set(user.toJson());
    // ignore: avoid_print
    print('✅ Created user ${user.id}.');
  }

  /// Update an existing user. Fails if the document does not exist.
  static Future<void> updateUser(AppUser user) async {
    final docRef = _db.collection(usersCollection).doc(user.id);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw StateError('User ${user.id} does not exist.');
    }
    await docRef.update(user.toJson());
    // ignore: avoid_print
    print('✅ Updated user ${user.id}.');
  }

  /// Read user by ID.
  static Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _db.collection(usersCollection).doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromJson(doc.data()!, doc.id);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching user: $e');
      return null;
    }
  }

  /// Delete user by ID.
  static Future<void> deleteUser(String userId) async {
    await _db.collection(usersCollection).doc(userId).delete();
    // ignore: avoid_print
    print('✅ Deleted user $userId.');
  }

  /// Get all users.
  static Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _db.collection(usersCollection).get();
      return snapshot.docs
          .map((d) => AppUser.fromJson(d.data(), d.id))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching users: $e');
      return [];
    }
  }

  /// Check if a user document exists.
  static Future<bool> userExists(String userId) async {
    final doc = await _db.collection(usersCollection).doc(userId).get();
    return doc.exists;
  }

  // ---------------------------------------------------------------------------
  // FOOD CRUD
  // ---------------------------------------------------------------------------

  /// Create a new food item. Fails if the document already exists.
  static Future<void> createFood(Food food) async {
    final docRef = _db.collection(foodCollection).doc(food.id);
    final snap = await docRef.get();
    if (snap.exists) {
      throw StateError('Food ${food.id} already exists.');
    }
    await docRef.set(food.toJson());
    // ignore: avoid_print
    print('✅ Created food ${food.id}.');
  }

  /// Update an existing food item. Fails if the document does not exist.
  static Future<void> updateFood(Food food) async {
    final docRef = _db.collection(foodCollection).doc(food.id);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw StateError('Food ${food.id} does not exist.');
    }
    await docRef.update(food.toJson());
    // ignore: avoid_print
    print('✅ Updated food ${food.id}.');
  }

  /// Read food by ID.
  static Future<Food?> getFood(String foodId) async {
    try {
      final doc = await _db.collection(foodCollection).doc(foodId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Food.fromJson(doc.data()!, doc.id);
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching food: $e');
      return null;
    }
  }

  /// Delete food by ID.
  static Future<void> deleteFood(String foodId) async {
    await _db.collection(foodCollection).doc(foodId).delete();
    // ignore: avoid_print
    print('✅ Deleted food $foodId.');
  }

  /// Get all foods.
  static Future<List<Food>> getAllFoods() async {
    try {
      final snapshot = await _db.collection(foodCollection).get();
      return snapshot.docs
          .map((d) => Food.fromJson(d.data(), d.id))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching foods: $e');
      return [];
    }
  }

  /// Check if a food document exists.
  static Future<bool> foodExists(String foodId) async {
    final doc = await _db.collection(foodCollection).doc(foodId).get();
    return doc.exists;
  }

  // ---------------------------------------------------------------------------
  // UTILITIES
  // ---------------------------------------------------------------------------

  /// Print all data from Users and Food (basic dump).
  static Future<void> printAllData() async {
    try {
      // ignore: avoid_print
      print('📦 Dumping all Firestore data...');

      final usersSnap = await _db.collection(usersCollection).get();
      for (final doc in usersSnap.docs) {
        // ignore: avoid_print
        print('👤 User ${doc.id}: ${doc.data()}');
      }

      final foodsSnap = await _db.collection(foodCollection).get();
      for (final doc in foodsSnap.docs) {
        // ignore: avoid_print
        print('🍎 Food ${doc.id}: ${doc.data()}');
      }

      // ignore: avoid_print
      print('✅ Finished printing database.');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error printing database: $e');
    }
  }
}
