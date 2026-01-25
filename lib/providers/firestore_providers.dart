import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/food.dart';
import '../db/user.dart';

part 'firestore_providers.g.dart';

@riverpod
FirebaseFirestore firestore(Ref ref) {
  return FirebaseFirestore.instance;
}

@riverpod
class FirestoreFoodLog extends _$FirestoreFoodLog {
  @override
  Stream<List<FoodItem>> build(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('food_log')
        .orderBy('consumedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              // Normalize consumedAt to DateTime for JSON parser
              final consumedAt = data['consumedAt'];
              if (consumedAt is Timestamp) {
                data['consumedAt'] = consumedAt.toDate();
              } else if (consumedAt is String) {
                data['consumedAt'] =
                    DateTime.tryParse(consumedAt) ?? DateTime.now();
              }

              return FoodItem.fromJson(data);
            }).toList());
  }

  Future<void> addFood(String userId, FoodItem food) async {
    final data = food.toJson();
    // Ensure DateTime is stored as Firestore Timestamp
    data['consumedAt'] = Timestamp.fromDate(food.consumedAt);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('food_log')
        .add(data);
  }

  Future<void> removeFood(String userId, String foodId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('food_log')
        .doc(foodId)
        .delete();
  }

  Future<void> updateFood(String userId, String foodId, FoodItem food) async {
    final data = food.toJson();
    data['consumedAt'] = Timestamp.fromDate(food.consumedAt);

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('food_log')
        .doc(foodId)
        .update(data);
  }
}

// Manual provider (no codegen needed) to stream user profile from Firestore
final firestoreUserProfileProvider =
    StreamProvider.family<AppUser?, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('Users')
      .doc(userId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    final data = doc.data()!;
    return AppUser.fromJson(data, doc.id);
  });
});
