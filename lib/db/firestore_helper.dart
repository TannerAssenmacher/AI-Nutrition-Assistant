import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';
import 'food.dart';

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
    print('Created user ${user.id}.');
  }

  /// Update an existing user. Fails if the document does not exist.
  static Future<void> updateUser(AppUser user) async {
    final docRef = _db.collection(usersCollection).doc(user.id);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw StateError('User ${user.id} does not exist.');
    }
    await docRef.update(user.toJson());
    print('Updated user ${user.id}.');
  }

  /// Read user by ID.
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

  /// Delete user by ID.
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

  /// Check if a user document exists.
  static Future<bool> userExists(String userId) async {
    final doc = await _db.collection(usersCollection).doc(userId).get();
    return doc.exists;
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