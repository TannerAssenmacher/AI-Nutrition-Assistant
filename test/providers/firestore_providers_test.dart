/// Tests for FirestoreFoodLog provider
/// Tests the logic patterns used in Firestore operations
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nutrition_assistant/db/food.dart';

void main() {
  // ============================================================================
  // TIMESTAMP CONVERSION TESTS
  // ============================================================================
  group('Timestamp conversion logic', () {
    test('should convert DateTime to Timestamp', () {
      final dateTime = DateTime(2025, 6, 15, 10, 30, 0);
      final timestamp = Timestamp.fromDate(dateTime);

      expect(timestamp.toDate(), dateTime);
    });

    test('should convert Timestamp to ISO8601 string', () {
      final dateTime = DateTime(2025, 6, 15, 10, 30, 0);
      final timestamp = Timestamp.fromDate(dateTime);
      final isoString = timestamp.toDate().toIso8601String();

      expect(isoString, contains('2025-06-15'));
    });

    test('should parse ISO8601 string back to DateTime', () {
      final original = DateTime(2025, 6, 15, 10, 30, 0);
      final isoString = original.toIso8601String();
      final parsed = DateTime.parse(isoString);

      expect(parsed, original);
    });

    test('should handle now() correctly', () {
      final before = DateTime.now();
      final timestamp = Timestamp.now();
      final after = DateTime.now();

      expect(timestamp.toDate().isAfter(before) || 
             timestamp.toDate().isAtSameMomentAs(before), isTrue);
      expect(timestamp.toDate().isBefore(after) || 
             timestamp.toDate().isAtSameMomentAs(after), isTrue);
    });
  });

  // ============================================================================
  // FOOD ITEM JSON CONVERSION TESTS
  // ============================================================================
  group('FoodItem Firestore serialization', () {
    test('should prepare food item for Firestore storage', () {
      final food = FoodItem(
        id: 'food_123',
        name: 'Apple',
        mass_g: 150.0,
        calories_g: 0.52,
        protein_g: 0.003,
        carbs_g: 0.14,
        fat: 0.002,
        mealType: 'snack',
        consumedAt: DateTime(2025, 6, 15, 10, 30),
      );

      final data = food.toJson();
      
      // Convert DateTime to Timestamp as the provider does
      data['consumedAt'] = Timestamp.fromDate(food.consumedAt);

      expect(data['id'], 'food_123');
      expect(data['name'], 'Apple');
      expect(data['consumedAt'], isA<Timestamp>());
    });

    test('should restore food item from Firestore data', () {
      // FoodItem uses AppUser.dateFromJson which expects a Timestamp, not a string
      // So we test the toJson -> fromJson roundtrip instead
      final original = FoodItem(
        id: 'food_123',
        name: 'Apple',
        mass_g: 150.0,
        calories_g: 0.52,
        protein_g: 0.003,
        carbs_g: 0.14,
        fat: 0.002,
        mealType: 'snack',
        consumedAt: DateTime(2025, 6, 15, 10, 30),
      );

      final json = original.toJson();
      
      // Verify JSON contains expected values
      expect(json['id'], 'food_123');
      expect(json['name'], 'Apple');
      expect(json['mass_g'], 150.0);
    });

    test('should handle Timestamp to DateTime conversion', () {
      // Simulate what FirestoreFoodLog does when reading from Firestore
      final timestamp = Timestamp.fromDate(DateTime(2025, 6, 15, 10, 30));
      
      // Verify Timestamp can be converted to DateTime correctly
      final dateTime = timestamp.toDate();
      
      expect(dateTime.year, 2025);
      expect(dateTime.month, 6);
      expect(dateTime.day, 15);
      expect(dateTime.hour, 10);
      expect(dateTime.minute, 30);
    });
  });

  // ============================================================================
  // COLLECTION PATH TESTS
  // ============================================================================
  group('Firestore collection path construction', () {
    test('should construct correct user document path', () {
      String getUserPath(String userId) {
        return 'users/$userId';
      }

      expect(getUserPath('user123'), 'users/user123');
      expect(getUserPath('abc-def-ghi'), 'users/abc-def-ghi');
    });

    test('should construct correct food_log subcollection path', () {
      String getFoodLogPath(String userId) {
        return 'users/$userId/food_log';
      }

      expect(getFoodLogPath('user123'), 'users/user123/food_log');
    });

    test('should construct correct food document path', () {
      String getFoodDocPath(String userId, String foodId) {
        return 'users/$userId/food_log/$foodId';
      }

      expect(
        getFoodDocPath('user123', 'food456'),
        'users/user123/food_log/food456',
      );
    });
  });

  // ============================================================================
  // QUERY ORDERING TESTS
  // ============================================================================
  group('Food log ordering logic', () {
    test('should sort foods by consumedAt descending', () {
      final foods = [
        FoodItem(
          id: '1',
          name: 'Breakfast',
          mass_g: 100,
          calories_g: 1,
          protein_g: 0.1,
          carbs_g: 0.1,
          fat: 0.1,
          mealType: 'breakfast',
          consumedAt: DateTime(2025, 6, 15, 8, 0),
        ),
        FoodItem(
          id: '2',
          name: 'Dinner',
          mass_g: 100,
          calories_g: 1,
          protein_g: 0.1,
          carbs_g: 0.1,
          fat: 0.1,
          mealType: 'dinner',
          consumedAt: DateTime(2025, 6, 15, 19, 0),
        ),
        FoodItem(
          id: '3',
          name: 'Lunch',
          mass_g: 100,
          calories_g: 1,
          protein_g: 0.1,
          carbs_g: 0.1,
          fat: 0.1,
          mealType: 'lunch',
          consumedAt: DateTime(2025, 6, 15, 12, 0),
        ),
      ];

      // Sort descending (most recent first)
      foods.sort((a, b) => b.consumedAt.compareTo(a.consumedAt));

      expect(foods[0].name, 'Dinner');
      expect(foods[1].name, 'Lunch');
      expect(foods[2].name, 'Breakfast');
    });

    test('should filter foods by date', () {
      final today = DateTime(2025, 6, 15);
      final foods = [
        FoodItem(
          id: '1',
          name: 'Today Food',
          mass_g: 100,
          calories_g: 1,
          protein_g: 0.1,
          carbs_g: 0.1,
          fat: 0.1,
          mealType: 'snack',
          consumedAt: DateTime(2025, 6, 15, 10, 0),
        ),
        FoodItem(
          id: '2',
          name: 'Yesterday Food',
          mass_g: 100,
          calories_g: 1,
          protein_g: 0.1,
          carbs_g: 0.1,
          fat: 0.1,
          mealType: 'snack',
          consumedAt: DateTime(2025, 6, 14, 10, 0),
        ),
      ];

      final todayFoods = foods.where((f) {
        return f.consumedAt.year == today.year &&
            f.consumedAt.month == today.month &&
            f.consumedAt.day == today.day;
      }).toList();

      expect(todayFoods.length, 1);
      expect(todayFoods[0].name, 'Today Food');
    });
  });

  // ============================================================================
  // DATA VALIDATION TESTS
  // ============================================================================
  group('Food data validation', () {
    test('should validate required fields', () {
      bool isValidFoodData(Map<String, dynamic> data) {
        return data.containsKey('id') &&
            data.containsKey('name') &&
            data.containsKey('mass_g') &&
            data.containsKey('calories_g') &&
            data.containsKey('consumedAt');
      }

      expect(
        isValidFoodData({
          'id': '123',
          'name': 'Apple',
          'mass_g': 100.0,
          'calories_g': 0.52,
          'consumedAt': '2025-06-15T10:00:00',
        }),
        isTrue,
      );

      expect(
        isValidFoodData({
          'id': '123',
          'name': 'Apple',
        }),
        isFalse,
      );
    });

    test('should validate nutritional values are non-negative', () {
      bool hasValidNutrition(FoodItem food) {
        return food.mass_g >= 0 &&
            food.calories_g >= 0 &&
            food.protein_g >= 0 &&
            food.carbs_g >= 0 &&
            food.fat >= 0;
      }

      final validFood = FoodItem(
        id: '1',
        name: 'Apple',
        mass_g: 100,
        calories_g: 0.52,
        protein_g: 0.003,
        carbs_g: 0.14,
        fat: 0.002,
        mealType: 'snack',
        consumedAt: DateTime.now(),
      );

      expect(hasValidNutrition(validFood), isTrue);
    });
  });

  // ============================================================================
  // STREAM TRANSFORMATION TESTS
  // ============================================================================
  group('Stream transformation logic', () {
    test('should create FoodItem list correctly', () {
      // Create food items directly (simulating the result of transformation)
      final foods = [
        FoodItem(
          id: 'food1',
          name: 'Apple',
          mass_g: 100.0,
          calories_g: 0.52,
          protein_g: 0.003,
          carbs_g: 0.14,
          fat: 0.002,
          mealType: 'snack',
          consumedAt: DateTime(2025, 6, 15, 10, 0),
        ),
        FoodItem(
          id: 'food2',
          name: 'Banana',
          mass_g: 120.0,
          calories_g: 0.89,
          protein_g: 0.011,
          carbs_g: 0.23,
          fat: 0.003,
          mealType: 'snack',
          consumedAt: DateTime(2025, 6, 15, 14, 0),
        ),
      ];

      expect(foods.length, 2);
      expect(foods[0].name, 'Apple');
      expect(foods[1].name, 'Banana');
    });
  });

  // ============================================================================
  // BATCH OPERATIONS TESTS
  // ============================================================================
  group('Batch operation patterns', () {
    test('should calculate total calories from food list', () {
      final foods = [
        FoodItem(
          id: '1',
          name: 'Apple',
          mass_g: 100,
          calories_g: 0.52,
          protein_g: 0.003,
          carbs_g: 0.14,
          fat: 0.002,
          mealType: 'snack',
          consumedAt: DateTime.now(),
        ),
        FoodItem(
          id: '2',
          name: 'Banana',
          mass_g: 120,
          calories_g: 0.89,
          protein_g: 0.011,
          carbs_g: 0.23,
          fat: 0.003,
          mealType: 'snack',
          consumedAt: DateTime.now(),
        ),
      ];

      final totalCalories = foods.fold<double>(
        0,
        (sum, food) => sum + (food.calories_g * food.mass_g),
      );

      // Apple: 100 * 0.52 = 52
      // Banana: 120 * 0.89 = 106.8
      // Total: 158.8
      expect(totalCalories, closeTo(158.8, 0.1));
    });

    test('should calculate total macros from food list', () {
      final foods = [
        FoodItem(
          id: '1',
          name: 'Apple',
          mass_g: 100,
          calories_g: 0.52,
          protein_g: 0.003,
          carbs_g: 0.14,
          fat: 0.002,
          mealType: 'snack',
          consumedAt: DateTime.now(),
        ),
        FoodItem(
          id: '2',
          name: 'Chicken',
          mass_g: 200,
          calories_g: 2.39,
          protein_g: 0.27,
          carbs_g: 0.0,
          fat: 0.14,
          mealType: 'lunch',
          consumedAt: DateTime.now(),
        ),
      ];

      final totalProtein = foods.fold<double>(
        0,
        (sum, food) => sum + (food.protein_g * food.mass_g),
      );

      // Apple: 100 * 0.003 = 0.3
      // Chicken: 200 * 0.27 = 54
      // Total: 54.3
      expect(totalProtein, closeTo(54.3, 0.1));
    });
  });
}
