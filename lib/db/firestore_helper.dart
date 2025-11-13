import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';

class FirestoreHelper {
  static FirebaseFirestore _db = FirebaseFirestore.instance;
  static void useDb(FirebaseFirestore db) => _db = db;

  static const String usersCollection = 'Users';

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
  // LOGGED FOOD ITEMS (inside AppUser)
  // ---------------------------------------------------------------------------

  /// Add a food item to a user's logged list.
  static Future<void> addFoodToUser(String userId, FoodItem foodItem) async {
    try {
      final userDoc = _db.collection(usersCollection).doc(userId);
      final snap = await userDoc.get();

      if (!snap.exists || snap.data() == null) {
        throw StateError('User $userId does not exist.');
      }

      final user = AppUser.fromJson(snap.data()!, snap.id);
      final updatedList = [...user.loggedFoodItems, foodItem];
      final updatedUser = user.copyWith(
        loggedFoodItems: updatedList,
        updatedAt: DateTime.now(),
      );

      await userDoc.update(updatedUser.toJson());
      // ignore: avoid_print
      print('🍎 Added food item "${foodItem.name}" for user $userId.');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error adding food: $e');
    }
  }

  /// Remove a food item by name and timestamp.
  static Future<void> removeFoodFromUser(String userId, FoodItem foodItem) async {
    try {
      final userDoc = _db.collection(usersCollection).doc(userId);
      final snap = await userDoc.get();

      if (!snap.exists || snap.data() == null) {
        throw StateError('User $userId does not exist.');
      }

      final user = AppUser.fromJson(snap.data()!, snap.id);
      final updatedList = user.loggedFoodItems.where((f) {
        return !(f.name == foodItem.name &&
            f.consumedAt == foodItem.consumedAt);
      }).toList();

      final updatedUser = user.copyWith(
        loggedFoodItems: updatedList,
        updatedAt: DateTime.now(),
      );

      await userDoc.update(updatedUser.toJson());
      // ignore: avoid_print
      print('🗑️ Removed food item "${foodItem.name}" from user $userId.');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error removing food: $e');
    }
  }

  /// Fetch all logged foods for a user.
  static Future<List<FoodItem>> getLoggedFoods(String userId) async {
    try {
      final doc = await _db.collection(usersCollection).doc(userId).get();
      if (!doc.exists || doc.data() == null) return [];
      final user = AppUser.fromJson(doc.data()!, doc.id);
      return user.loggedFoodItems;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error fetching logged foods: $e');
      return [];
    }
  }

  /// Clear all logged food items for a user.
  static Future<void> clearLoggedFoods(String userId) async {
    try {
      final userDoc = _db.collection(usersCollection).doc(userId);
      await userDoc.update({
        'loggedFoodItems': [],
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      // ignore: avoid_print
      print('🧹 Cleared logged foods for user $userId.');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error clearing logged foods: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // UTILITIES
  // ---------------------------------------------------------------------------

  /// Print all data from Users (basic dump).
  static Future<void> printAllData() async {
    try {
      // ignore: avoid_print
      print('📦 Dumping all Firestore user data...');

      final usersSnap = await _db.collection(usersCollection).get();
      for (final doc in usersSnap.docs) {
        // ignore: avoid_print
        print('👤 User ${doc.id}: ${doc.data()}');
      }

      // ignore: avoid_print
      print('✅ Finished printing database.');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error printing database: $e');
    }
  }
}
