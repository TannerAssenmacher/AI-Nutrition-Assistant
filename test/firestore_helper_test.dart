import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:nutrition_assistant/db/firestore_helper.dart';
import 'package:nutrition_assistant/db/user.dart';

AppUser get mockUser {
  return AppUser(
    firstname: 'John',
    lastname: 'Doe',
    email: 'jd@gmail.com',
    password: 'hashed_pw',
    dob: DateTime(2000, 1, 1),
    sex: 'male',
    height: 180,
    weight: 75,
    activityLevel: 'lightly_active',
    mealProfile: MealProfile(
      dietaryHabits: ['vegetarian'],
      healthRestrictions: ['peanuts'],
      preferences: Preferences(likes: ['food_1'], dislikes: ['food_2']),
      macroGoals: {'protein': 150, 'carbs': 300, 'fat': 70},
      dailyCalorieGoal: 2500,
      dietaryGoal: 'muscle_gain',
    ),
    loggedFoodItems: [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

FoodItem get mockFoodItem {
  return FoodItem(
    name: 'Avocado',
    mass_g: 150,
    calories_g: 240,
    protein_g: 3,
    carbs_g: 12,
    fat: 22,
    mealType: 'Snack',
    consumedAt: DateTime.now(),
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

  group('Logged Food Items', () {
    test('addFoodToUser adds a food item to loggedFoodItems', () async {
      final user = mockUser;
      final food = mockFoodItem;
      await FirestoreHelper.createUser(user);

      await FirestoreHelper.addFoodToUser(user.id, food);

      final fetched = await FirestoreHelper.getUser(user.id);
      expect(fetched!.loggedFoodItems.length, 1);
      expect(fetched.loggedFoodItems.first.name, 'Avocado');
    });

    test('removeFoodFromUser removes the specified food item', () async {
      final user = mockUser;
      final food = mockFoodItem;
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.addFoodToUser(user.id, food);

      await FirestoreHelper.removeFoodFromUser(user.id, food);

      final fetched = await FirestoreHelper.getUser(user.id);
      expect(fetched!.loggedFoodItems.isEmpty, true);
    });

    test('getLoggedFoods returns all logged food items for a user', () async {
      final user = mockUser;
      final food1 = mockFoodItem;
      final food2 = mockFoodItem.copyWith(name: 'Banana', calories_g: 100);
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.addFoodToUser(user.id, food1);
      await FirestoreHelper.addFoodToUser(user.id, food2);

      final foods = await FirestoreHelper.getLoggedFoods(user.id);
      expect(foods.length, 2);
      expect(foods.first.name, 'Avocado');
      expect(foods.last.name, 'Banana');
    });

    test('clearLoggedFoods removes all logged food items', () async {
      final user = mockUser;
      final food = mockFoodItem;
      await FirestoreHelper.createUser(user);
      await FirestoreHelper.addFoodToUser(user.id, food);

      await FirestoreHelper.clearLoggedFoods(user.id);
      final fetched = await FirestoreHelper.getUser(user.id);
      expect(fetched!.loggedFoodItems.isEmpty, true);
    });
  });

  group('Utilities', () {
    test('printAllData completes without errors', () async {
      final user = mockUser;
      await FirestoreHelper.createUser(user);
      await expectLater(FirestoreHelper.printAllData(), completes);
    });
  });
}
