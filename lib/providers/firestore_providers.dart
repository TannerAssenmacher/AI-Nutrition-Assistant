import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/food.dart';
import '../db/user.dart';
import '../db/planned_food.dart';

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

@riverpod
class FirestoreScheduledMeals extends _$FirestoreScheduledMeals {
  @override
  Stream<List<PlannedFood>> build(String userId) {
    return FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('scheduled_meals')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      debugPrint(
          'FirestoreScheduledMeals stream: user=$userId docs=${snapshot.docs.length}');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        // Always prefer the Firestore document id for deletes/updates to succeed
        data['id'] = doc.id;
        // Normalize date to DateTime for JSON parser
        final date = data['date'];
        if (date is Timestamp) {
          data['date'] = date.toDate();
        } else if (date is String) {
          data['date'] = DateTime.tryParse(date) ?? DateTime.now();
        }

        return PlannedFood.fromJson(data);
      }).toList();
    });
  }

  Future<void> addScheduledMeal(String userId, PlannedFood meal) async {
    final data = meal.toJson();
    // Ensure DateTime is stored as Firestore Timestamp
    data['date'] = Timestamp.fromDate(meal.date);

    debugPrint(
        'addScheduledMeal: user=$userId recipeId=${meal.recipeId} at=${meal.date.toIso8601String()} mealType=${meal.mealType}');

    final docRef = await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('scheduled_meals')
        .add(data);

    debugPrint('addScheduledMeal success: docId=${docRef.id}');
  }

  Future<void> removeScheduledMeal(String userId, String mealId) async {
    debugPrint('removeScheduledMeal: user=$userId mealId=$mealId');
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .collection('scheduled_meals')
          .doc(mealId)
          .delete();
      debugPrint('removeScheduledMeal success: user=$userId mealId=$mealId');
    } catch (e, st) {
      debugPrint(
          'removeScheduledMeal error: user=$userId mealId=$mealId error=$e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> updateScheduledMeal(
      String userId, String mealId, PlannedFood meal) async {
    final data = meal.toJson();
    data['date'] = Timestamp.fromDate(meal.date);

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .collection('scheduled_meals')
        .doc(mealId)
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
