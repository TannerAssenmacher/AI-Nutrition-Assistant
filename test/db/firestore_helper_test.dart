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
    loggedFoodItems: const [],
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
  setUp(() {
    FirestoreHelper.useDb(FakeFirebaseFirestore());
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
  // FOOD CRUD TESTS (EMBEDDED)
  // ============================================================================
  group('Food CRUD (embedded)', () {
    test('addFoodItem adds food to user', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      await FirestoreHelper.addFoodItem(user.id, createMockFood());

      final foods = await FirestoreHelper.getAllFoodItems(user.id);
      expect(foods.length, 1);
      expect(foods.first.name, 'Avocado');
    });

    test('updateFoodItem updates an existing food', () async {
      final user = createMockUser();
      final food = createMockFood();
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.addFoodItem(user.id, food);

      final updated = FoodItem(
        id: food.id,
        name: 'Ripe Avocado',
        mass_g: food.mass_g,
        calories_g: 2.0,
        protein_g: food.protein_g,
        carbs_g: food.carbs_g,
        fat: food.fat,
        mealType: food.mealType,
        consumedAt: food.consumedAt,
      );

      await FirestoreHelper.updateFoodItem(user.id, updated);

      final fetched = await FirestoreHelper.getFoodItem(user.id, updated.id);
      expect(fetched!.name, 'Ripe Avocado');
      expect(fetched.calories_g, 2.0);
    });

    test('deleteFoodItem removes food from user', () async {
      final user = createMockUser();
      final food = createMockFood();
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.addFoodItem(user.id, food);

      await FirestoreHelper.deleteFoodItem(user.id, food.id);

      final foods = await FirestoreHelper.getAllFoodItems(user.id);
      expect(foods.isEmpty, true);
    });

    test('getFoodItem returns null for missing food', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      final food = await FirestoreHelper.getFoodItem(user.id, 'missing');
      expect(food, isNull);
    });

    test('getAllFoodItems returns list', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      await FirestoreHelper.addFoodItem(user.id, createMockFood(id: 'food1', name: 'Avocado'));
      await FirestoreHelper.addFoodItem(user.id, createMockFood(id: 'food2', name: 'Apple'));

      final foods = await FirestoreHelper.getAllFoodItems(user.id);
      expect(foods.length, 2);
    });
  });

  // ============================================================================
  // FOOD CRUD ERROR CASES
  // ============================================================================
  group('Food CRUD Error Cases', () {
    test('addFoodItem throws StateError for non-existent user', () async {
      expect(
        () => FirestoreHelper.addFoodItem('non_existent_user', createMockFood()),
        throwsA(isA<StateError>()),
      );
    });

    test('updateFoodItem throws StateError for non-existent user', () async {
      expect(
        () => FirestoreHelper.updateFoodItem('non_existent_user', createMockFood()),
        throwsA(isA<StateError>()),
      );
    });

    test('updateFoodItem throws StateError for non-existent food', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      expect(
        () => FirestoreHelper.updateFoodItem(user.id, createMockFood()),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteFoodItem throws StateError for non-existent user', () async {
      expect(
        () => FirestoreHelper.deleteFoodItem('non_existent_user', 'food_id'),
        throwsA(isA<StateError>()),
      );
    });

    test('getAllFoodItems returns empty for non-existent user', () async {
      final foods = await FirestoreHelper.getAllFoodItems('non_existent');
      expect(foods, isEmpty);
    });

    test('getFoodItem returns null for non-existent user', () async {
      final food = await FirestoreHelper.getFoodItem('non_existent', 'food_id');
      expect(food, isNull);
    });
  });

  // ============================================================================
  // MULTIPLE FOOD ITEMS
  // ============================================================================
  group('Multiple Food Items', () {
    test('should handle adding many food items', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      for (int i = 0; i < 10; i++) {
        await FirestoreHelper.addFoodItem(
          user.id, 
          createMockFood(id: 'food_$i', name: 'Food $i'),
        );
      }

      final foods = await FirestoreHelper.getAllFoodItems(user.id);
      expect(foods.length, 10);
    });

    test('should correctly delete specific food from multiple', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      for (int i = 0; i < 3; i++) {
        await FirestoreHelper.addFoodItem(
          user.id, 
          createMockFood(id: 'food_$i', name: 'Food $i'),
        );
      }

      await FirestoreHelper.deleteFoodItem(user.id, 'food_1');

      final foods = await FirestoreHelper.getAllFoodItems(user.id);
      expect(foods.length, 2);

      final foodIds = foods.map((f) => f.id).toList();
      expect(foodIds.contains('food_0'), isTrue);
      expect(foodIds.contains('food_1'), isFalse);
      expect(foodIds.contains('food_2'), isTrue);
    });

    test('should update correct food among multiple', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);

      for (int i = 0; i < 3; i++) {
        await FirestoreHelper.addFoodItem(
          user.id, 
          createMockFood(id: 'food_$i', name: 'Food $i'),
        );
      }

      final updatedFood = FoodItem(
        id: 'food_1',
        name: 'Updated Food 1',
        mass_g: 200,
        calories_g: 2.0,
        protein_g: 0.2,
        carbs_g: 0.4,
        fat: 0.1,
        mealType: 'dinner',
        consumedAt: DateTime.now(),
      );

      await FirestoreHelper.updateFoodItem(user.id, updatedFood);

      final food0 = await FirestoreHelper.getFoodItem(user.id, 'food_0');
      final food1 = await FirestoreHelper.getFoodItem(user.id, 'food_1');
      final food2 = await FirestoreHelper.getFoodItem(user.id, 'food_2');

      expect(food0!.name, 'Food 0');
      expect(food1!.name, 'Updated Food 1');
      expect(food1.mass_g, 200);
      expect(food2!.name, 'Food 2');
    });
  });

  // ============================================================================
  // USER WITH LOGGED FOODS
  // ============================================================================
  group('User with Logged Foods', () {
    test('deleting user cleans up all data', () async {
      final user = createMockUser();
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.addFoodItem(user.id, createMockFood());

      expect(await FirestoreHelper.userExists(user.id), isTrue);
      final foods = await FirestoreHelper.getAllFoodItems(user.id);
      expect(foods.length, 1);

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
      await FirestoreHelper.addFoodItem(user.id, createMockFood());

      await expectLater(FirestoreHelper.printAllData(), completes);
    });
  });
}
