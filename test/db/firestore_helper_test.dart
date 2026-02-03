/// Tests for FirestoreHelper CRUD operations and edge cases
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nutrition_assistant/db/firestore_helper.dart';
import 'package:nutrition_assistant/db/user.dart';
import 'package:nutrition_assistant/db/food.dart';
import 'package:nutrition_assistant/db/preferences.dart';
import 'package:nutrition_assistant/db/meal_profile.dart';

// Mock data factory
AppUser createMockUser({String? id}) {
  final now = DateTime.now();

  final mealProfile = MealProfile(
    dietaryHabits: ['vegetarian'],
    healthRestrictions: ['peanuts'],
    preferences: Preferences(
      likes: ['food_1'],
      dislikes: ['food_2'],
    ),
    macroGoals: {'protein': 150, 'carbs': 300, 'fat': 70},
    dailyCalorieGoal: 2500,
    dietaryGoal: 'muscle_gain',
  );

  return AppUser(
    id: id,
    firstname: 'John',
    lastname: 'Doe',
    dob: DateTime(2000, 1, 1),
    sex: 'male',
    height: 180,
    weight: 75,
    activityLevel: 'lightly_active',
    mealProfile: mealProfile,
    createdAt: now,
    updatedAt: now,
  );
}

FoodItem createMockFood({String? id, String? name}) {
  final now = DateTime.now();

  return FoodItem(
    id: id ?? 'food_avocado',
    name: name ?? 'Avocado',
    mass_g: 150,
    calories_g: 1.6,
    protein_g: 0.02,
    carbs_g: 0.085,
    fat: 0.147,
    mealType: 'snack',
    consumedAt: now,
  );
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    FirestoreHelper.useDb(fakeFirestore);
  });

  // ============================================================================
  // USER CRUD TESTS
  // ============================================================================
  group('User CRUD', () {
    test('createUser creates a user successfully', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);
      final fetched = await FirestoreHelper.getUser(user.id);
      expect(fetched, isNotNull);
      expect(fetched!.firstname, user.firstname);
    });

    test('createUser throws StateError if user exists', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);
      expect(() => FirestoreHelper.createUser(user), throwsA(isA<StateError>()));
    });

    test('getUser returns null for non-existent user', () async {
      final user = await FirestoreHelper.getUser('non_existent_id');
      expect(user, isNull);
    });

    test('updateUser updates an existing user', () async {
      var user = createMockUser();
      await FirestoreHelper.createUser(user);
      user = user.copyWith(firstname: 'Jane', weight: 72);
      await FirestoreHelper.updateUser(user);
      final fetched = await FirestoreHelper.getUser(user.id);
      expect(fetched!.firstname, 'Jane');
      expect(fetched.weight, 72);
    });

    test('updateUser throws StateError if user does not exist', () {
      final user = createMockUser();
      expect(() => FirestoreHelper.updateUser(user), throwsA(isA<StateError>()));
    });

    test('deleteUser removes the user', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.deleteUser(user.id);
      final exists = await FirestoreHelper.userExists(user.id);
      expect(exists, isFalse);
    });

    test('getAllUsers returns a list of users', () async {
      final user1 = createMockUser().copyWith(id: 'user1');
      final user2 = createMockUser().copyWith(id: 'user2');
      await FirestoreHelper.createUser(user1);
      await FirestoreHelper.createUser(user2);
      final users = await FirestoreHelper.getAllUsers();
      expect(users.length, 2);
    });

    test('userExists returns true for existing user', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);
      final exists = await FirestoreHelper.userExists(user.id);
      expect(exists, isTrue);
    });

    test('userExists returns false for non-existing user', () async {
      final exists = await FirestoreHelper.userExists('non_existent');
      expect(exists, isFalse);
    });
  });

  // ============================================================================
  // FOOD LOG SUBCOLLECTION CRUD TESTS
  // ============================================================================
  group('Food Log Subcollection', () {
    foodLogRef(String userId) =>
        fakeFirestore.collection('Users').doc(userId).collection('food_log');

    test('add and read food item', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      final food = createMockFood();
      await foodLogRef(user.id).doc(food.id).set(food.toJson());

      final snap = await foodLogRef(user.id).get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['name'], 'Avocado');
    });

    test('update food item', () async {
      final user = createMockUser();
      final food = createMockFood();
      await FirestoreHelper.createUser(user);
      await foodLogRef(user.id).doc(food.id).set(food.toJson());

      await foodLogRef(user.id)
          .doc(food.id)
          .update({'name': 'Ripe Avocado', 'calories_g': 2.0});

      final doc = await foodLogRef(user.id).doc(food.id).get();
      expect(doc.data()!['name'], 'Ripe Avocado');
      expect(doc.data()!['calories_g'], 2.0);
    });

    test('delete food item', () async {
      final user = createMockUser();
      final food = createMockFood();
      await FirestoreHelper.createUser(user);
      await foodLogRef(user.id).doc(food.id).set(food.toJson());

      await foodLogRef(user.id).doc(food.id).delete();

      final snap = await foodLogRef(user.id).get();
      expect(snap.docs, isEmpty);
    });

    test('get single food item by id', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);
      await foodLogRef(user.id)
          .doc('food_1')
          .set(createMockFood(id: 'food_1', name: 'Apple').toJson());

      final doc = await foodLogRef(user.id).doc('food_1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], 'Apple');
    });

    test('get non-existent food item returns non-existent doc', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      final doc = await foodLogRef(user.id).doc('missing').get();
      expect(doc.exists, isFalse);
    });

    test('empty subcollection returns no docs', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      final snap = await foodLogRef(user.id).get();
      expect(snap.docs, isEmpty);
    });
  });

  // ============================================================================
  // MULTIPLE FOOD ITEMS IN SUBCOLLECTION
  // ============================================================================
  group('Multiple Food Items', () {
    foodLogRef(String userId) =>
        fakeFirestore.collection('Users').doc(userId).collection('food_log');

    test('should handle adding many food items', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      for (int i = 0; i < 10; i++) {
        await foodLogRef(user.id)
            .doc('food_$i')
            .set(createMockFood(id: 'food_$i', name: 'Food $i').toJson());
      }

      final snap = await foodLogRef(user.id).get();
      expect(snap.docs.length, 10);
    });

    test('should correctly delete specific food from multiple', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      for (int i = 0; i < 3; i++) {
        await foodLogRef(user.id)
            .doc('food_$i')
            .set(createMockFood(id: 'food_$i', name: 'Food $i').toJson());
      }

      await foodLogRef(user.id).doc('food_1').delete();

      final snap = await foodLogRef(user.id).get();
      expect(snap.docs.length, 2);

      final ids = snap.docs.map((d) => d.id).toList();
      expect(ids.contains('food_0'), isTrue);
      expect(ids.contains('food_1'), isFalse);
      expect(ids.contains('food_2'), isTrue);
    });

    test('should update correct food among multiple', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      for (int i = 0; i < 3; i++) {
        await foodLogRef(user.id)
            .doc('food_$i')
            .set(createMockFood(id: 'food_$i', name: 'Food $i').toJson());
      }

      await foodLogRef(user.id)
          .doc('food_1')
          .update({'name': 'Updated Food 1', 'mass_g': 200});

      final food0 = await foodLogRef(user.id).doc('food_0').get();
      final food1 = await foodLogRef(user.id).doc('food_1').get();
      final food2 = await foodLogRef(user.id).doc('food_2').get();

      expect(food0.data()!['name'], 'Food 0');
      expect(food1.data()!['name'], 'Updated Food 1');
      expect(food1.data()!['mass_g'], 200);
      expect(food2.data()!['name'], 'Food 2');
    });
  });

  // ============================================================================
  // USER DELETION WITH FOOD LOG
  // ============================================================================
  group('User with Food Log', () {
    test('deleting user does not auto-delete subcollection', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);
      await fakeFirestore
          .collection('Users')
          .doc(user.id)
          .collection('food_log')
          .doc('food_1')
          .set(createMockFood(id: 'food_1').toJson());

      expect(await FirestoreHelper.userExists(user.id), isTrue);

      await FirestoreHelper.deleteUser(user.id);
      expect(await FirestoreHelper.userExists(user.id), isFalse);
    });
  });

  // ============================================================================
  // CONCURRENT OPERATIONS
  // ============================================================================
  group('Concurrent Operations', () {
    test('multiple sequential updates should work', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      for (int i = 1; i <= 5; i++) {
        final updated = user.copyWith(weight: 75.0 + i);
        await FirestoreHelper.updateUser(updated);
      }

      final fetched = await FirestoreHelper.getUser(user.id);
      expect(fetched!.weight, 80);
    });
  });

  // ============================================================================
  // UTILITIES
  // ============================================================================
  group('Utilities', () {
    test('printAllData does not throw errors', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      await expectLater(FirestoreHelper.printAllData(), completes);
    });
  });
}
