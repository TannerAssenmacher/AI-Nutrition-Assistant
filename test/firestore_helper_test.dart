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

  group('Food CRUD', () {
    test('createFood creates a food item successfully', () async {
      final food = mockFood;
      await FirestoreHelper.createFood(food);
      final fetched = await FirestoreHelper.getFood(food.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, food.name);
    });

    test('createFood throws StateError if food exists', () async {
      final food = mockFood;
      await FirestoreHelper.createFood(food);
      expect(() => FirestoreHelper.createFood(food), throwsA(isA<StateError>()));
    });

    test('getFood returns null for non-existent food', () async {
      final food = await FirestoreHelper.getFood('non_existent_id');
      expect(food, isNull);
    });

    test('updateFood updates an existing food item', () async {
      var original = mockFood;
      await FirestoreHelper.createFood(original);

      final updated = FoodItem(
        id: original.id,
        name: 'Ripe Avocado',
        mass_g: original.mass_g,
        calories_g: 1.65, // slightly different kcal/g
        protein_g: original.protein_g,
        carbs_g: original.carbs_g,
        fat: original.fat,
        mealType: original.mealType,
        consumedAt: original.consumedAt,
      );

      await FirestoreHelper.updateFood(updated);
      final fetched = await FirestoreHelper.getFood(original.id);
      expect(fetched!.name, 'Ripe Avocado');
      expect(fetched.calories_g, 165);
    });

    test('updateFood throws StateError if food does not exist', () {
      final food = mockFood;
      expect(() => FirestoreHelper.updateFood(food), throwsA(isA<StateError>()));
    });

    test('deleteFood removes the food item', () async {
      final food = mockFood;
      await FirestoreHelper.createFood(food);
      await FirestoreHelper.deleteFood(food.id);
      final exists = await FirestoreHelper.foodExists(food.id);
      expect(exists, isFalse);
    });

    test('getAllFoods returns a list of food items', () async {
      final food1 = FoodItem(
        id: 'food1',
        name: 'Avocado 1',
        mass_g: 100,
        calories_g: 1.6,
        protein_g: 0.02,
        carbs_g: 0.085,
        fat: 0.147,
        mealType: 'snack',
        consumedAt: DateTime.now(),
      );

      final food2 = FoodItem(
        id: 'food2',
        name: 'Avocado 2',
        mass_g: 120,
        calories_g: 1.6,
        protein_g: 0.02,
        carbs_g: 0.085,
        fat: 0.147,
        mealType: 'snack',
        consumedAt: DateTime.now(),
      );

      await FirestoreHelper.createFood(food1);
      await FirestoreHelper.createFood(food2);
      final foods = await FirestoreHelper.getAllFoods();
      expect(foods.length, 2);
    });
  });

  group('Utilities', () {
    test('printAllData does not throw errors', () async {
      final user = mockUser;
      final food = mockFood;
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.createFood(food);
      
      // The function prints to console, so we just check for no exceptions.
      await expectLater(FirestoreHelper.printAllData(), completes);
    });
  });
}
