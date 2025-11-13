import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nutrition_assistant/db/firestore_helper.dart';
import 'package:nutrition_assistant/db/user.dart';
import 'package:nutrition_assistant/db/food.dart';

// Mock data for tests
AppUser get mockUser {
  final user = AppUser(
    firstname: 'John',
    lastname: 'Doe',
    email: 'jd@gmail.com',
    password: 'hashed_pw',
    age: 25,
    sex: 'male',
    height: 180,
    weight: 75,
    activityLevel: 'lightly_active',
    dietaryGoal: 'muscle_gain',
    dailyCalorieGoal: 2500,
    macroGoals: {'protein': 150, 'carbs': 300, 'fat': 70},
    mealProfile: MealProfile(
      dietaryHabits: ['vegetarian'],
      healthRestrictions: ['peanuts'],
      preferences: Preferences(likes: ['food_1'], dislikes: ['food_2']),
    ),
    mealPlans: {
      'plan_1': MealPlan(
        planName: 'Bulk Up Plan',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
        mealPlanItems: {
          'item_1': MealPlanItem(
            mealType: 'Breakfast',
            foodId: 'food_3',
            description: 'Oatmeal with berries',
            portionSize: '100g',
          ),
        },
      ),
    },
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  return user;
}

Food get mockFood {
  final food = Food(
    name: 'Avocado',
    category: 'fruit',
    caloriesPer100g: 160,
    proteinPer100g: 2,
    carbsPer100g: 8.5,
    fatPer100g: 14.7,
    fiberPer100g: 6.7,
    servingSize: 150,
    consumedAt: DateTime.now(),
    micronutrients: Micronutrients(
      calciumMg: 12,
      ironMg: 0.6,
      vitaminAMcg: 7,
      vitaminCMg: 10,
    ),
    source: 'USDA',
  );
  return food;
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
      expect(fetched!.email, user.email);
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
      var food = mockFood;
      await FirestoreHelper.createFood(food);
      food = food.copyWith(name: 'Ripe Avocado', caloriesPer100g: 165);
      await FirestoreHelper.updateFood(food);
      final fetched = await FirestoreHelper.getFood(food.id);
      expect(fetched!.name, 'Ripe Avocado');
      expect(fetched.caloriesPer100g, 165);
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
      final food1 = mockFood.copyWith(id: 'food1');
      final food2 = mockFood.copyWith(id: 'food2');
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
