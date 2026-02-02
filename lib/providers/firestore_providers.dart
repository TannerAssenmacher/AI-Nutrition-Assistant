import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
        .collection('Users')
        .doc(userId)
        .collection('food_log')
        .orderBy('consumedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint(
          'FirestoreFoodLog stream: user=$userId docs=${snapshot.docs.length}');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Always prefer the Firestore document id for deletes/updates to succeed
        data['id'] = doc.id;
        // Normalize consumedAt to DateTime for JSON parser
        final consumedAt = data['consumedAt'];
        if (consumedAt is Timestamp) {
          data['consumedAt'] = consumedAt.toDate();
        } else if (consumedAt is String) {
          data['consumedAt'] = DateTime.tryParse(consumedAt) ?? DateTime.now();
        }

        return FoodItem.fromJson(data);
      }).toList();
    });
  }

  Future<void> addFood(String userId, FoodItem food) async {
    final data = food.toJson();
    // Ensure DateTime is stored as Firestore Timestamp
    data['consumedAt'] = Timestamp.fromDate(food.consumedAt);

    debugPrint(
        'addFood: user=$userId name=${food.name} at=${food.consumedAt.toIso8601String()}');

    final docRef = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('food_log')
        .add(data);

    debugPrint('addFood success: docId=${docRef.id}');
  }

  Future<void> removeFood(String userId, String foodId) async {
    debugPrint('removeFood: user=$userId foodId=$foodId');
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('food_log')
          .doc(foodId)
          .delete();
      debugPrint('removeFood success: user=$userId foodId=$foodId');
    } catch (e, st) {
      debugPrint('removeFood error: user=$userId foodId=$foodId error=$e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> updateFood(String userId, String foodId, FoodItem food) async {
    final data = food.toJson();
    data['consumedAt'] = Timestamp.fromDate(food.consumedAt);

    await FirebaseFirestore.instance
        .collection('Users')
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
