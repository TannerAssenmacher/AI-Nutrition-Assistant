import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nutrition_assistant/db/firestore_helper.dart';
import 'package:nutrition_assistant/db/user.dart';
import 'package:nutrition_assistant/db/food.dart';
import 'package:nutrition_assistant/db/preferences.dart';
import 'package:nutrition_assistant/db/meal_profile.dart';

// Mock data for tests
AppUser get mockUser {
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

  final user = AppUser(
    firstname: 'John',
    lastname: 'Doe',
    dob: DateTime(2000, 1, 1),
    sex: 'male',
    height: 180, // inches
    weight: 75,  // pounds
    activityLevel: 'lightly_active',
    mealProfile: mealProfile,
    loggedFoodItems: const [],
    createdAt: now,
    updatedAt: now,
  );

  return user;
}


FoodItem get mockFood {
  final now = DateTime.now();

  return FoodItem(
    id: 'food_avocado',
    name: 'Avocado',
    mass_g: 150,        // serving mass
    calories_g: 1.6,    // calories per gram
    protein_g: 0.02,    // 2g protein / 100g
    carbs_g: 0.085,     // 8.5g carbs / 100g
    fat: 0.147,         // 14.7g fat / 100g
    mealType: 'snack',
    consumedAt: now,
  );
}

void main() {
  setUp(() {
    FirestoreHelper.useDb(FakeFirebaseFirestore());
  });

  group('User CRUD', () {
    test('createUser creates a user successfully', () async {
      final user = mockUser;
      await FirestoreHelper.createUser(user);
      final fetched = await FirestoreHelper.getUser(user.id);
      expect(fetched, isNotNull);
      expect(fetched!.firstname, user.firstname);
    });

    test('createUser throws StateError if user exists', () async {
      final user = mockUser;
      await FirestoreHelper.createUser(user);
      expect(() => FirestoreHelper.createUser(user), throwsA(isA<StateError>()));
    });

    test('getUser returns null for non-existent user', () async {
      final user = await FirestoreHelper.getUser('non_existent_id');
      expect(user, isNull);
    });

    test('updateUser updates an existing user', () async {
      var user = mockUser;
      await FirestoreHelper.createUser(user);
      user = user.copyWith(firstname: 'Jane', weight: 72);
      await FirestoreHelper.updateUser(user);
      final fetched = await FirestoreHelper.getUser(user.id);
      expect(fetched!.firstname, 'Jane');
      expect(fetched.weight, 72);
    });

    test('updateUser throws StateError if user does not exist', () {
      final user = mockUser;
      expect(() => FirestoreHelper.updateUser(user), throwsA(isA<StateError>()));
    });

    test('deleteUser removes the user', () async {
      final user = mockUser;
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.deleteUser(user.id);
      final exists = await FirestoreHelper.userExists(user.id);
      expect(exists, isFalse);
    });

    test('getAllUsers returns a list of users', () async {
      final user1 = mockUser.copyWith(id: 'user1');
      final user2 = mockUser.copyWith(id: 'user2');
      await FirestoreHelper.createUser(user1);
      await FirestoreHelper.createUser(user2);
      final users = await FirestoreHelper.getAllUsers();
      expect(users.length, 2);
    });
  });

  group('Food CRUD (embedded)', () {
    test('addFoodItem adds food to user', () async {
      final user = mockUser;
      await FirestoreHelper.createUser(user);

      await FirestoreHelper.addFoodItem(user.id, mockFood);

      final foods = await FirestoreHelper.getAllFoodItems(user.id);
      expect(foods.length, 1);
      expect(foods.first.name, mockFood.name);
    });

    test('updateFoodItem updates an existing food', () async {
      final user = mockUser;
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.addFoodItem(user.id, mockFood);

      final updated = FoodItem(
        id: mockFood.id,
        name: 'Ripe Avocado',
        mass_g: mockFood.mass_g,
        calories_g: 2.0, // changed
        protein_g: mockFood.protein_g,
        carbs_g: mockFood.carbs_g,
        fat: mockFood.fat,
        mealType: mockFood.mealType,
        consumedAt: mockFood.consumedAt,
      );

      await FirestoreHelper.updateFoodItem(user.id, updated);

      final fetched = await FirestoreHelper.getFoodItem(user.id, updated.id);
      expect(fetched!.name, 'Ripe Avocado');
      expect(fetched.calories_g, 2.0);
    });

    test('deleteFoodItem removes food from user', () async {
      final user = mockUser;
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.addFoodItem(user.id, mockFood);

      await FirestoreHelper.deleteFoodItem(user.id, mockFood.id);

      final foods = await FirestoreHelper.getAllFoodItems(user.id);
      expect(foods.isEmpty, true);
    });

    test('getFoodItem returns null for missing food', () async {
      final user = mockUser;
      await FirestoreHelper.createUser(user);

      final food = await FirestoreHelper.getFoodItem(user.id, 'missing');
      expect(food, isNull);
    });

    test('getAllFoodItems returns list', () async {
      final user = mockUser;
      await FirestoreHelper.createUser(user);

      await FirestoreHelper.addFoodItem(user.id, mockFood);

      final secondFood = FoodItem(
        id: 'food2',
        name: 'Apple',
        mass_g: mockFood.mass_g,
        calories_g: mockFood.calories_g,
        protein_g: mockFood.protein_g,
        carbs_g: mockFood.carbs_g,
        fat: mockFood.fat,
        mealType: mockFood.mealType,
        consumedAt: mockFood.consumedAt,
      );

      await FirestoreHelper.addFoodItem(user.id, secondFood);

      final foods = await FirestoreHelper.getAllFoodItems(user.id);
      expect(foods.length, 2);
    });
  });


  group('Utilities', () {
    test('printAllData does not throw errors', () async {
      final user = mockUser;
      final food = mockFood;
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.addFoodItem(user.id, food);

      // The function prints to console, so we just check for no exceptions.
      await expectLater(FirestoreHelper.printAllData(), completes);
    });
  });
}