import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/user.dart';
import '../db/firestore_helper.dart';

part 'firestore_providers.g.dart';

@riverpod
FirebaseFirestore firestore(Ref ref) {
  return FirebaseFirestore.instance;
}

// -----------------------------------------------------------------------------
// FirestoreFoodLog Provider
// -----------------------------------------------------------------------------
@riverpod
class FirestoreFoodLog extends _$FirestoreFoodLog {
  @override
  Stream<List<FoodItem>> build(String userId) {
    // Stream the entire user document and map its loggedFoodItems list
    return FirebaseFirestore.instance
        .collection(FirestoreHelper.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return <FoodItem>[];
      final data = doc.data()!;
      final user = AppUser.fromJson(data, doc.id);
      return user.loggedFoodItems;
    });
  }

  // ---------------------------------------------------------------------------
  // Food Item Management
  // ---------------------------------------------------------------------------

  Future<void> addFood(String userId, FoodItem foodItem) async {
    await FirestoreHelper.addFoodToUser(userId, foodItem);
  }

  Future<void> removeFood(String userId, FoodItem foodItem) async {
    await FirestoreHelper.removeFoodFromUser(userId, foodItem);
  }

  Future<void> updateFood(String userId, FoodItem updatedFood) async {
    try {
      final user = await FirestoreHelper.getUser(userId);
      if (user == null) throw StateError('User not found');

      // Replace the matching food item by consumedAt + name
      final updatedList = user.loggedFoodItems.map((item) {
        final same = item.name == updatedFood.name &&
            item.consumedAt == updatedFood.consumedAt;
        return same ? updatedFood : item;
      }).toList();

      final newUser = user.copyWith(
        loggedFoodItems: updatedList,
        updatedAt: DateTime.now(),
      );

      await FirestoreHelper.updateUser(newUser);
      // ignore: avoid_print
      print('✅ Updated food item "${updatedFood.name}" for user $userId.');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error updating food: $e');
    }
  }

  Future<void> clearAll(String userId) async {
    await FirestoreHelper.clearLoggedFoods(userId);
  }
}
