import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/food_item.dart';

part 'firestore_providers.g.dart';

@riverpod
FirebaseFirestore firestore(FirestoreRef ref) {
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
          
          // Handle Firestore Timestamp conversion
          if (data['consumedAt'] is Timestamp) {
            data['consumedAt'] = (data['consumedAt'] as Timestamp).toDate().toIso8601String();
          }
          
          return FoodItem.fromJson({
            ...data,
            'id': doc.id,
          });
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

  Future<void> updateFood(String userId, FoodItem food) async {
    final data = food.toJson();
    data['consumedAt'] = Timestamp.fromDate(food.consumedAt);
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('food_log')
        .doc(food.id)
        .update(data);
  }
}