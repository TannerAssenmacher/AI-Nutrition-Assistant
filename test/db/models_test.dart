/// Tests for all database models:
/// - Preferences
/// - MealProfile  
/// - AppUser
/// - FoodItem
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutrition_assistant/db/user.dart';
import 'package:nutrition_assistant/db/food.dart';
import 'package:nutrition_assistant/db/meal_profile.dart';
import 'package:nutrition_assistant/db/preferences.dart';

void main() {
  // ============================================================================
  // PREFERENCES MODEL TESTS
  // ============================================================================
  group('Preferences Model', () {
    test('should create a Preferences instance with empty lists', () {
      final preferences = Preferences(likes: [], dislikes: []);
      expect(preferences.likes, isEmpty);
      expect(preferences.dislikes, isEmpty);
    });

    test('should create a Preferences instance with values', () {
      final likes = ['pizza', 'pasta'];
      final dislikes = ['broccoli', 'spinach'];
      final preferences = Preferences(likes: likes, dislikes: dislikes);

      expect(preferences.likes, equals(likes));
      expect(preferences.dislikes, equals(dislikes));
    });

    test('should convert to and from JSON', () {
      final preferences = Preferences(
        likes: ['pizza', 'pasta'],
        dislikes: ['broccoli', 'spinach'],
      );

      final json = preferences.toJson();
      final fromJson = Preferences.fromJson(json);

      expect(fromJson.likes, equals(preferences.likes));
      expect(fromJson.dislikes, equals(preferences.dislikes));
    });

    test('JSON round-trip should preserve all data', () {
      final original = Preferences(
        likes: ['apple', 'banana', 'chicken'],
        dislikes: ['fish', 'eggs'],
      );

      final json = original.toJson();
      final restored = Preferences.fromJson(json);

      expect(restored.likes, equals(original.likes));
      expect(restored.dislikes, equals(original.dislikes));
    });
  });

  // ============================================================================
  // MEAL PROFILE MODEL TESTS
  // ============================================================================
  group('MealProfile Model', () {
    late Preferences preferences;
    late Map<String, double> macroGoals;

    setUp(() {
      preferences = Preferences(
        likes: ['pizza'],
        dislikes: ['broccoli'],
      );
      macroGoals = {
        'protein': 150.0,
        'carbs': 300.0,
        'fat': 70.0,
      };
    });

    test('should create a MealProfile instance with all fields', () {
      final mealProfile = MealProfile(
        dietaryHabits: ['vegetarian'],
        healthRestrictions: ['peanuts'],
        preferences: preferences,
        macroGoals: macroGoals,
        dailyCalorieGoal: 2500,
        dietaryGoal: 'muscle_gain',
      );

      expect(mealProfile.dietaryHabits, equals(['vegetarian']));
      expect(mealProfile.healthRestrictions, equals(['peanuts']));
      expect(mealProfile.preferences, equals(preferences));
      expect(mealProfile.macroGoals, equals(macroGoals));
      expect(mealProfile.dailyCalorieGoal, equals(2500));
      expect(mealProfile.dietaryGoal, equals('muscle_gain'));
    });

    test('should convert to and from JSON', () {
      final mealProfile = MealProfile(
        dietaryHabits: ['vegetarian'],
        healthRestrictions: ['peanuts'],
        preferences: preferences,
        macroGoals: macroGoals,
        dailyCalorieGoal: 2500,
        dietaryGoal: 'muscle_gain',
      );

      final json = mealProfile.toJson();
      final fromJson = MealProfile.fromJson(json);

      expect(fromJson.dietaryHabits, equals(mealProfile.dietaryHabits));
      expect(fromJson.healthRestrictions, equals(mealProfile.healthRestrictions));
      expect(fromJson.preferences.likes, equals(mealProfile.preferences.likes));
      expect(fromJson.preferences.dislikes, equals(mealProfile.preferences.dislikes));
      expect(fromJson.macroGoals, equals(mealProfile.macroGoals));
      expect(fromJson.dailyCalorieGoal, equals(mealProfile.dailyCalorieGoal));
      expect(fromJson.dietaryGoal, equals(mealProfile.dietaryGoal));
    });

    test('copyWith should update specified fields', () {
      final original = MealProfile(
        dietaryHabits: ['vegetarian'],
        healthRestrictions: ['peanuts'],
        preferences: preferences,
        macroGoals: macroGoals,
        dailyCalorieGoal: 2500,
        dietaryGoal: 'muscle_gain',
      );

      final updated = original.copyWith(
        dietaryHabits: ['vegan'],
        dailyCalorieGoal: 2000,
      );

      expect(updated.dietaryHabits, equals(['vegan']));
      expect(updated.dailyCalorieGoal, equals(2000));
      // Other fields should remain the same
      expect(updated.healthRestrictions, equals(original.healthRestrictions));
      expect(updated.preferences, equals(original.preferences));
      expect(updated.macroGoals, equals(original.macroGoals));
      expect(updated.dietaryGoal, equals(original.dietaryGoal));
    });

    test('copyWith with no arguments returns equivalent object', () {
      final original = MealProfile(
        dietaryHabits: ['vegetarian'],
        healthRestrictions: ['peanuts'],
        preferences: preferences,
        macroGoals: macroGoals,
        dailyCalorieGoal: 2500,
        dietaryGoal: 'muscle_gain',
      );

      final copy = original.copyWith();

      expect(copy.dietaryHabits, equals(original.dietaryHabits));
      expect(copy.healthRestrictions, equals(original.healthRestrictions));
      expect(copy.dailyCalorieGoal, equals(original.dailyCalorieGoal));
      expect(copy.dietaryGoal, equals(original.dietaryGoal));
    });

    test('should handle empty lists', () {
      final mealProfile = MealProfile(
        dietaryHabits: [],
        healthRestrictions: [],
        preferences: Preferences(likes: [], dislikes: []),
        macroGoals: {},
        dailyCalorieGoal: 2000,
        dietaryGoal: 'maintenance',
      );

      expect(mealProfile.dietaryHabits, isEmpty);
      expect(mealProfile.healthRestrictions, isEmpty);
      expect(mealProfile.macroGoals, isEmpty);
    });
  });

  // ============================================================================
  // APP USER MODEL TESTS
  // ============================================================================
  group('AppUser Model', () {
    late MealProfile mockMealProfile;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2025, 6, 15, 10, 30);
      mockMealProfile = MealProfile(
        dietaryHabits: ['vegetarian'],
        healthRestrictions: ['peanuts'],
        preferences: Preferences(likes: ['pizza'], dislikes: ['broccoli']),
        macroGoals: {'protein': 150.0, 'carbs': 300.0, 'fat': 70.0},
        dailyCalorieGoal: 2500,
        dietaryGoal: 'muscle_gain',
      );
    });

    test('should create AppUser with auto-generated ID when not provided', () {
      final user = AppUser(
        firstname: 'John',
        lastname: 'Doe',
        dob: DateTime(2000, 1, 1),
        sex: 'male',
        height: 180,
        weight: 75,
        activityLevel: 'lightly_active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(user.id, isNotEmpty);
      expect(user.firstname, 'John');
      expect(user.lastname, 'Doe');
    });

    test('should create AppUser with provided ID', () {
      final user = AppUser(
        id: 'custom_id_123',
        firstname: 'Jane',
        lastname: 'Smith',
        dob: DateTime(1995, 5, 10),
        sex: 'female',
        height: 165,
        weight: 60,
        activityLevel: 'moderately_active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(user.id, 'custom_id_123');
    });

    test('copyWith should update specified fields only', () {
      final original = AppUser(
        id: 'user_1',
        firstname: 'John',
        lastname: 'Doe',
        dob: DateTime(2000, 1, 1),
        sex: 'male',
        height: 180,
        weight: 75,
        activityLevel: 'lightly_active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      final updated = original.copyWith(
        firstname: 'Jane',
        weight: 70,
      );

      // Changed fields
      expect(updated.firstname, 'Jane');
      expect(updated.weight, 70);

      // Unchanged fields
      expect(updated.id, original.id);
      expect(updated.lastname, original.lastname);
      expect(updated.dob, original.dob);
      expect(updated.sex, original.sex);
      expect(updated.height, original.height);
      expect(updated.activityLevel, original.activityLevel);
    });

    test('copyWith with all fields should update everything', () {
      final original = AppUser(
        id: 'user_1',
        firstname: 'John',
        lastname: 'Doe',
        dob: DateTime(2000, 1, 1),
        sex: 'male',
        height: 180,
        weight: 75,
        activityLevel: 'lightly_active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      final newMealProfile = mockMealProfile.copyWith(dailyCalorieGoal: 2000);
      final newDate = DateTime(2025, 7, 1);

      final updated = original.copyWith(
        id: 'new_id',
        firstname: 'Jane',
        lastname: 'Smith',
        dob: DateTime(1995, 5, 10),
        sex: 'female',
        height: 165,
        weight: 60,
        activityLevel: 'very_active',
        mealProfile: newMealProfile,
        loggedFoodItems: [],
        createdAt: newDate,
        updatedAt: newDate,
      );

      expect(updated.id, 'new_id');
      expect(updated.firstname, 'Jane');
      expect(updated.lastname, 'Smith');
      expect(updated.sex, 'female');
      expect(updated.height, 165);
      expect(updated.weight, 60);
      expect(updated.activityLevel, 'very_active');
      expect(updated.mealProfile.dailyCalorieGoal, 2000);
    });

    test('toJson should convert AppUser to map', () {
      final user = AppUser(
        id: 'user_1',
        firstname: 'John',
        lastname: 'Doe',
        dob: DateTime(2000, 1, 1),
        sex: 'male',
        height: 180,
        weight: 75,
        activityLevel: 'lightly_active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      final json = user.toJson();

      expect(json['firstname'], 'John');
      expect(json['lastname'], 'Doe');
      expect(json['sex'], 'male');
      expect(json['height'], 180);
      expect(json['weight'], 75);
      expect(json['activityLevel'], 'lightly_active');
      expect(json['mealProfile'], isA<Map>());
      expect(json['loggedFoodItems'], isA<List>());
      // ID should be excluded from JSON
      expect(json.containsKey('id'), isFalse);
    });

    test('fromJson should create AppUser from map', () {
      final json = {
        'firstname': 'John',
        'lastname': 'Doe',
        'dob': DateTime(2000, 1, 1).toIso8601String(),
        'sex': 'male',
        'height': 180.0,
        'weight': 75.0,
        'activityLevel': 'lightly_active',
        'mealProfile': {
          'dietaryHabits': ['vegetarian'],
          'healthRestrictions': ['peanuts'],
          'preferences': {'likes': ['pizza'], 'dislikes': ['broccoli']},
          'macroGoals': {'protein': 150.0, 'carbs': 300.0, 'fat': 70.0},
          'dailyCalorieGoal': 2500,
          'dietaryGoal': 'muscle_gain',
        },
        'loggedFoodItems': [],
        'createdAt': Timestamp.fromDate(testDate),
        'updatedAt': Timestamp.fromDate(testDate),
      };

      final user = AppUser.fromJson(json, 'user_1');

      expect(user.id, 'user_1');
      expect(user.firstname, 'John');
      expect(user.lastname, 'Doe');
      expect(user.sex, 'male');
      expect(user.height, 180);
      expect(user.weight, 75);
      expect(user.mealProfile.dailyCalorieGoal, 2500);
    });

    group('Date helpers', () {
      test('dateFromJson should convert Timestamp to DateTime', () {
        final timestamp = Timestamp.fromDate(testDate);
        final result = AppUser.dateFromJson(timestamp);

        expect(result.year, testDate.year);
        expect(result.month, testDate.month);
        expect(result.day, testDate.day);
        expect(result.hour, testDate.hour);
        expect(result.minute, testDate.minute);
      });

      test('dateFromJson should pass through DateTime', () {
        final result = AppUser.dateFromJson(testDate);
        expect(result, testDate);
      });

      test('dateToJson should convert DateTime to Timestamp', () {
        final result = AppUser.dateToJson(testDate);

        expect(result, isA<Timestamp>());
        expect((result as Timestamp).toDate().year, testDate.year);
        expect(result.toDate().month, testDate.month);
        expect(result.toDate().day, testDate.day);
      });
    });
  });

  // ============================================================================
  // FOOD ITEM MODEL TESTS
  // ============================================================================
  group('FoodItem Model', () {
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2025, 6, 15, 12, 0);
    });

    test('should create FoodItem with all required fields', () {
      final food = FoodItem(
        id: 'food_1',
        name: 'Apple',
        mass_g: 150,
        calories_g: 0.52,
        protein_g: 0.003,
        carbs_g: 0.14,
        fat: 0.002,
        mealType: 'snack',
        consumedAt: testDate,
      );

      expect(food.id, 'food_1');
      expect(food.name, 'Apple');
      expect(food.mass_g, 150);
      expect(food.calories_g, 0.52);
      expect(food.protein_g, 0.003);
      expect(food.carbs_g, 0.14);
      expect(food.fat, 0.002);
      expect(food.mealType, 'snack');
      expect(food.consumedAt, testDate);
    });

    test('toJson should convert FoodItem to map', () {
      final food = FoodItem(
        id: 'food_1',
        name: 'Banana',
        mass_g: 118,
        calories_g: 0.89,
        protein_g: 0.011,
        carbs_g: 0.23,
        fat: 0.003,
        mealType: 'breakfast',
        consumedAt: testDate,
      );

      final json = food.toJson();

      expect(json['id'], 'food_1');
      expect(json['name'], 'Banana');
      expect(json['mass_g'], 118);
      expect(json['calories_g'], 0.89);
      expect(json['protein_g'], 0.011);
      expect(json['carbs_g'], 0.23);
      expect(json['fat'], 0.003);
      expect(json['mealType'], 'breakfast');
      expect(json['consumedAt'], isA<Timestamp>());
    });

    test('fromJson should create FoodItem from map', () {
      final json = {
        'id': 'food_2',
        'name': 'Chicken Breast',
        'mass_g': 100.0,
        'calories_g': 1.65,
        'protein_g': 0.31,
        'carbs_g': 0.0,
        'fat': 0.036,
        'mealType': 'lunch',
        'consumedAt': Timestamp.fromDate(testDate),
      };

      final food = FoodItem.fromJson(json);

      expect(food.id, 'food_2');
      expect(food.name, 'Chicken Breast');
      expect(food.mass_g, 100);
      expect(food.calories_g, 1.65);
      expect(food.protein_g, 0.31);
      expect(food.carbs_g, 0);
      expect(food.fat, 0.036);
      expect(food.mealType, 'lunch');
      expect(food.consumedAt.year, testDate.year);
      expect(food.consumedAt.month, testDate.month);
      expect(food.consumedAt.day, testDate.day);
    });

    test('JSON round-trip should preserve all data', () {
      final original = FoodItem(
        id: 'food_round_trip',
        name: 'Salmon',
        mass_g: 150,
        calories_g: 2.08,
        protein_g: 0.25,
        carbs_g: 0.0,
        fat: 0.13,
        mealType: 'dinner',
        consumedAt: testDate,
      );

      final json = original.toJson();
      final restored = FoodItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.mass_g, original.mass_g);
      expect(restored.calories_g, original.calories_g);
      expect(restored.protein_g, original.protein_g);
      expect(restored.carbs_g, original.carbs_g);
      expect(restored.fat, original.fat);
      expect(restored.mealType, original.mealType);
    });

    test('should handle different meal types', () {
      final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

      for (final mealType in mealTypes) {
        final food = FoodItem(
          id: 'food_$mealType',
          name: 'Test Food',
          mass_g: 100,
          calories_g: 1.0,
          protein_g: 0.1,
          carbs_g: 0.1,
          fat: 0.1,
          mealType: mealType,
          consumedAt: testDate,
        );

        expect(food.mealType, mealType);
      }
    });

    test('should handle zero nutritional values', () {
      final food = FoodItem(
        id: 'food_water',
        name: 'Water',
        mass_g: 250,
        calories_g: 0,
        protein_g: 0,
        carbs_g: 0,
        fat: 0,
        mealType: 'snack',
        consumedAt: testDate,
      );

      expect(food.calories_g, 0);
      expect(food.protein_g, 0);
      expect(food.carbs_g, 0);
      expect(food.fat, 0);
    });

    test('should calculate total calories correctly', () {
      final food = FoodItem(
        id: 'food_1',
        name: 'Apple',
        mass_g: 150,
        calories_g: 0.52,
        protein_g: 0.003,
        carbs_g: 0.14,
        fat: 0.002,
        mealType: 'snack',
        consumedAt: testDate,
      );

      final totalCalories = food.mass_g * food.calories_g;
      expect(totalCalories, closeTo(78, 0.5));
    });

    test('should calculate total macros correctly', () {
      final food = FoodItem(
        id: 'food_chicken',
        name: 'Chicken Breast',
        mass_g: 100,
        calories_g: 1.65,
        protein_g: 0.31,
        carbs_g: 0.0,
        fat: 0.036,
        mealType: 'lunch',
        consumedAt: testDate,
      );

      final totalProtein = food.mass_g * food.protein_g;
      final totalCarbs = food.mass_g * food.carbs_g;
      final totalFat = food.mass_g * food.fat;

      expect(totalProtein, closeTo(31, 0.1));
      expect(totalCarbs, 0);
      expect(totalFat, closeTo(3.6, 0.1));
    });
  });

  // ============================================================================
  // ADDITIONAL EDGE CASES - PREFERENCES
  // ============================================================================
  group('Preferences Edge Cases', () {
    test('should handle very long lists', () {
      final longLikes = List.generate(100, (i) => 'food_$i');
      final longDislikes = List.generate(50, (i) => 'dislike_$i');

      final preferences = Preferences(likes: longLikes, dislikes: longDislikes);

      expect(preferences.likes.length, 100);
      expect(preferences.dislikes.length, 50);
    });

    test('should handle unicode food names', () {
      final preferences = Preferences(
        likes: ['寿司', 'タコス', '🍕', 'Crème brûlée'],
        dislikes: ['納豆'],
      );

      expect(preferences.likes, contains('寿司'));
      expect(preferences.likes, contains('🍕'));
    });

    test('should handle special characters in names', () {
      final preferences = Preferences(
        likes: ["Mac 'n' Cheese", 'Fish & Chips', 'PB&J'],
        dislikes: [],
      );

      expect(preferences.likes[0], "Mac 'n' Cheese");
    });

    test('JSON should preserve list order', () {
      final original = Preferences(
        likes: ['first', 'second', 'third'],
        dislikes: ['a', 'b', 'c'],
      );

      final json = original.toJson();
      final restored = Preferences.fromJson(json);

      expect(restored.likes[0], 'first');
      expect(restored.likes[2], 'third');
      expect(restored.dislikes[1], 'b');
    });
  });

  // ============================================================================
  // ADDITIONAL EDGE CASES - MEAL PROFILE
  // ============================================================================
  group('MealProfile Edge Cases', () {
    test('should handle zero calorie goal', () {
      final profile = MealProfile(
        dietaryHabits: [],
        healthRestrictions: [],
        preferences: Preferences(likes: [], dislikes: []),
        macroGoals: {},
        dailyCalorieGoal: 0,
        dietaryGoal: 'fasting',
      );

      expect(profile.dailyCalorieGoal, 0);
    });

    test('should handle very high calorie goal', () {
      final profile = MealProfile(
        dietaryHabits: [],
        healthRestrictions: [],
        preferences: Preferences(likes: [], dislikes: []),
        macroGoals: {},
        dailyCalorieGoal: 10000,
        dietaryGoal: 'bulking',
      );

      expect(profile.dailyCalorieGoal, 10000);
    });

    test('should handle negative macro goals (edge case)', () {
      // While not realistic, the model should store whatever is given
      final profile = MealProfile(
        dietaryHabits: [],
        healthRestrictions: [],
        preferences: Preferences(likes: [], dislikes: []),
        macroGoals: {'protein': -10.0},
        dailyCalorieGoal: 2000,
        dietaryGoal: 'test',
      );

      expect(profile.macroGoals['protein'], -10.0);
    });

    test('should handle decimal macro goals', () {
      final profile = MealProfile(
        dietaryHabits: [],
        healthRestrictions: [],
        preferences: Preferences(likes: [], dislikes: []),
        macroGoals: {
          'protein': 123.456,
          'carbs': 200.789,
          'fat': 55.123,
        },
        dailyCalorieGoal: 2000,
        dietaryGoal: 'precision',
      );

      expect(profile.macroGoals['protein'], closeTo(123.456, 0.001));
    });

    test('should handle many dietary habits', () {
      final habits = [
        'vegetarian',
        'low-sodium',
        'high-protein',
        'low-carb',
        'gluten-free',
        'dairy-free',
        'keto',
        'paleo',
      ];

      final profile = MealProfile(
        dietaryHabits: habits,
        healthRestrictions: [],
        preferences: Preferences(likes: [], dislikes: []),
        macroGoals: {},
        dailyCalorieGoal: 2000,
        dietaryGoal: 'custom',
      );

      expect(profile.dietaryHabits.length, 8);
    });

    test('copyWith should update all fields when provided', () {
      final original = MealProfile(
        dietaryHabits: ['vegan'],
        healthRestrictions: ['nuts'],
        preferences: Preferences(likes: ['salad'], dislikes: ['meat']),
        macroGoals: {'protein': 100.0},
        dailyCalorieGoal: 2000,
        dietaryGoal: 'weight_loss',
      );

      final newPrefs = Preferences(likes: ['fruit'], dislikes: ['processed']);
      final updated = original.copyWith(
        dietaryHabits: ['vegetarian'],
        healthRestrictions: ['shellfish'],
        preferences: newPrefs,
        macroGoals: {'protein': 150.0, 'carbs': 200.0},
        dailyCalorieGoal: 2500,
        dietaryGoal: 'muscle_gain',
      );

      expect(updated.dietaryHabits, ['vegetarian']);
      expect(updated.healthRestrictions, ['shellfish']);
      expect(updated.preferences.likes, ['fruit']);
      expect(updated.macroGoals['protein'], 150.0);
      expect(updated.macroGoals['carbs'], 200.0);
      expect(updated.dailyCalorieGoal, 2500);
      expect(updated.dietaryGoal, 'muscle_gain');
    });
  });

  // ============================================================================
  // ADDITIONAL EDGE CASES - APP USER
  // ============================================================================
  group('AppUser Edge Cases', () {
    late MealProfile mockMealProfile;
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2025, 6, 15, 10, 30);
      mockMealProfile = MealProfile(
        dietaryHabits: [],
        healthRestrictions: [],
        preferences: Preferences(likes: [], dislikes: []),
        macroGoals: {},
        dailyCalorieGoal: 2000,
        dietaryGoal: 'maintenance',
      );
    });

    test('should handle very young user (edge DOB)', () {
      final youngUser = AppUser(
        firstname: 'Baby',
        lastname: 'User',
        dob: DateTime.now().subtract(const Duration(days: 30)),
        sex: 'unknown',
        height: 50,
        weight: 3.5,
        activityLevel: 'sedentary',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(youngUser.weight, 3.5);
      expect(youngUser.height, 50);
    });

    test('should handle elderly user', () {
      final elderlyUser = AppUser(
        firstname: 'Elder',
        lastname: 'User',
        dob: DateTime(1920, 1, 1),
        sex: 'male',
        height: 170,
        weight: 65,
        activityLevel: 'lightly_active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      final age = DateTime.now().year - elderlyUser.dob.year;
      expect(age, greaterThan(100));
    });

    test('should handle extreme height values', () {
      final tallUser = AppUser(
        firstname: 'Tall',
        lastname: 'Person',
        dob: DateTime(2000, 1, 1),
        sex: 'male',
        height: 96, // 8 feet in inches
        weight: 100,
        activityLevel: 'active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(tallUser.height, 96);
    });

    test('should handle extreme weight values', () {
      final heavyUser = AppUser(
        firstname: 'Heavy',
        lastname: 'Person',
        dob: DateTime(2000, 1, 1),
        sex: 'male',
        height: 72,
        weight: 500, // extreme weight
        activityLevel: 'sedentary',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(heavyUser.weight, 500);
    });

    test('should handle unicode names', () {
      final unicodeUser = AppUser(
        firstname: '田中',
        lastname: '太郎',
        dob: DateTime(1990, 5, 15),
        sex: 'male',
        height: 170,
        weight: 70,
        activityLevel: 'moderately_active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(unicodeUser.firstname, '田中');
      expect(unicodeUser.lastname, '太郎');
    });

    test('should handle names with special characters', () {
      final specialUser = AppUser(
        firstname: "Mary-Jane",
        lastname: "O'Brien",
        dob: DateTime(1985, 12, 25),
        sex: 'female',
        height: 165,
        weight: 60,
        activityLevel: 'very_active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(specialUser.firstname, "Mary-Jane");
      expect(specialUser.lastname, "O'Brien");
    });

    test('should handle different activity levels', () {
      final activityLevels = [
        'sedentary',
        'lightly_active',
        'moderately_active',
        'very_active',
        'extra_active',
      ];

      for (final level in activityLevels) {
        final user = AppUser(
          firstname: 'Test',
          lastname: 'User',
          dob: DateTime(2000, 1, 1),
          sex: 'male',
          height: 180,
          weight: 75,
          activityLevel: level,
          mealProfile: mockMealProfile,
          loggedFoodItems: const [],
          createdAt: testDate,
          updatedAt: testDate,
        );

        expect(user.activityLevel, level);
      }
    });

    test('should handle user with many logged food items', () {
      final foodItems = List.generate(
        100,
        (i) => FoodItem(
          id: 'food_$i',
          name: 'Food $i',
          mass_g: 100,
          calories_g: 1.0,
          protein_g: 0.1,
          carbs_g: 0.2,
          fat: 0.05,
          mealType: 'snack',
          consumedAt: testDate,
        ),
      );

      final user = AppUser(
        firstname: 'Test',
        lastname: 'User',
        dob: DateTime(2000, 1, 1),
        sex: 'male',
        height: 180,
        weight: 75,
        activityLevel: 'active',
        mealProfile: mockMealProfile,
        loggedFoodItems: foodItems,
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(user.loggedFoodItems.length, 100);
    });

    test('should generate unique IDs', () {
      final ids = <String>{};
      for (int i = 0; i < 10; i++) {
        final user = AppUser(
          firstname: 'Test',
          lastname: 'User',
          dob: DateTime(2000, 1, 1),
          sex: 'male',
          height: 180,
          weight: 75,
          activityLevel: 'active',
          mealProfile: mockMealProfile,
          loggedFoodItems: const [],
          createdAt: testDate,
          updatedAt: testDate,
        );
        ids.add(user.id);
      }

      expect(ids.length, 10); // All IDs should be unique
    });

    test('copyWith should preserve ID when not specified', () {
      final original = AppUser(
        id: 'preserved_id',
        firstname: 'Test',
        lastname: 'User',
        dob: DateTime(2000, 1, 1),
        sex: 'male',
        height: 180,
        weight: 75,
        activityLevel: 'active',
        mealProfile: mockMealProfile,
        loggedFoodItems: const [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      final updated = original.copyWith(firstname: 'Updated');

      expect(updated.id, 'preserved_id');
      expect(updated.firstname, 'Updated');
    });

    test('dateFromJson should handle DateTime input directly', () {
      final date = DateTime(2025, 6, 15, 10, 30);
      final result = AppUser.dateFromJson(date);

      expect(result, date);
    });

    test('dateToJson should create valid Timestamp', () {
      final date = DateTime(2025, 6, 15, 10, 30);
      final result = AppUser.dateToJson(date);

      expect(result, isA<Timestamp>());
      final timestamp = result as Timestamp;
      expect(timestamp.toDate().year, 2025);
      expect(timestamp.toDate().month, 6);
      expect(timestamp.toDate().day, 15);
    });
  });

  // ============================================================================
  // ADDITIONAL EDGE CASES - FOOD ITEM
  // ============================================================================
  group('FoodItem Edge Cases', () {
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2025, 6, 15, 12, 0);
    });

    test('should handle very small nutritional values', () {
      final food = FoodItem(
        id: 'micro_food',
        name: 'Trace Mineral',
        mass_g: 0.001,
        calories_g: 0.0001,
        protein_g: 0.00001,
        carbs_g: 0.00001,
        fat: 0.00001,
        mealType: 'supplement',
        consumedAt: testDate,
      );

      expect(food.mass_g, closeTo(0.001, 0.0001));
      expect(food.calories_g, closeTo(0.0001, 0.00001));
    });

    test('should handle very large mass values', () {
      final food = FoodItem(
        id: 'large_food',
        name: 'Feast',
        mass_g: 10000,
        calories_g: 0.5,
        protein_g: 0.1,
        carbs_g: 0.2,
        fat: 0.05,
        mealType: 'dinner',
        consumedAt: testDate,
      );

      final totalCalories = food.mass_g * food.calories_g;
      expect(totalCalories, 5000);
    });

    test('should handle unicode food names', () {
      final food = FoodItem(
        id: 'unicode_food',
        name: '寿司 (Sushi) 🍣',
        mass_g: 200,
        calories_g: 1.5,
        protein_g: 0.1,
        carbs_g: 0.25,
        fat: 0.05,
        mealType: 'lunch',
        consumedAt: testDate,
      );

      expect(food.name, contains('寿司'));
      expect(food.name, contains('🍣'));
    });

    test('should handle long food names', () {
      final longName = 'Grilled Chicken Breast with Roasted Vegetables and Quinoa Salad with Lemon Vinaigrette Dressing';
      final food = FoodItem(
        id: 'long_name_food',
        name: longName,
        mass_g: 350,
        calories_g: 1.2,
        protein_g: 0.2,
        carbs_g: 0.15,
        fat: 0.08,
        mealType: 'dinner',
        consumedAt: testDate,
      );

      expect(food.name.length, longName.length);
    });

    test('should handle custom meal types', () {
      final customMealTypes = ['second_breakfast', 'brunch', 'late_night', 'pre_workout', 'post_workout'];

      for (final mealType in customMealTypes) {
        final food = FoodItem(
          id: 'food_$mealType',
          name: 'Custom Meal',
          mass_g: 100,
          calories_g: 1.0,
          protein_g: 0.1,
          carbs_g: 0.1,
          fat: 0.1,
          mealType: mealType,
          consumedAt: testDate,
        );

        expect(food.mealType, mealType);
      }
    });

    test('should handle future consumption date', () {
      final futureDate = DateTime(2030, 12, 31);
      final food = FoodItem(
        id: 'future_food',
        name: 'Planned Meal',
        mass_g: 100,
        calories_g: 1.0,
        protein_g: 0.1,
        carbs_g: 0.1,
        fat: 0.1,
        mealType: 'dinner',
        consumedAt: futureDate,
      );

      expect(food.consumedAt.year, 2030);
    });

    test('should handle past consumption date', () {
      final pastDate = DateTime(2020, 1, 1);
      final food = FoodItem(
        id: 'past_food',
        name: 'Historical Meal',
        mass_g: 100,
        calories_g: 1.0,
        protein_g: 0.1,
        carbs_g: 0.1,
        fat: 0.1,
        mealType: 'lunch',
        consumedAt: pastDate,
      );

      expect(food.consumedAt.year, 2020);
    });

    test('should preserve precision in JSON round-trip', () {
      final original = FoodItem(
        id: 'precision_food',
        name: 'Precise Food',
        mass_g: 123.456789,
        calories_g: 0.123456789,
        protein_g: 0.0123456789,
        carbs_g: 0.123456789,
        fat: 0.0123456789,
        mealType: 'snack',
        consumedAt: testDate,
      );

      final json = original.toJson();
      final restored = FoodItem.fromJson(json);

      expect(restored.mass_g, closeTo(original.mass_g, 0.0001));
      expect(restored.calories_g, closeTo(original.calories_g, 0.0001));
    });
  });
}
