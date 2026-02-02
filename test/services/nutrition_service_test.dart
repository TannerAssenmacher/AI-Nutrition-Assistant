/// Tests for NutritionService
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/db/food.dart';
import 'package:nutrition_assistant/services/nutrition_service.dart';

void main() {
  late NutritionService nutritionService;
  late DateTime testDate;

  setUp(() {
    nutritionService = NutritionService();
    testDate = DateTime(2025, 6, 15, 12, 0);
  });

  // ============================================================================
  // SEARCH FOODS TESTS
  // ============================================================================
  group('NutritionService.searchFoods', () {
    test('should return all foods when query is empty', () async {
      final results = await nutritionService.searchFoods('');

      expect(results, isNotEmpty);
      expect(results.length, 3); // Apple, Banana, Chicken Breast
    });

    test('should filter foods by query (case insensitive)', () async {
      final results = await nutritionService.searchFoods('apple');

      expect(results.length, 1);
      expect(results.first.name, 'Apple');
    });

    test('should filter foods with uppercase query', () async {
      final results = await nutritionService.searchFoods('BANANA');

      expect(results.length, 1);
      expect(results.first.name, 'Banana');
    });

    test('should filter foods with partial match', () async {
      final results = await nutritionService.searchFoods('chick');

      expect(results.length, 1);
      expect(results.first.name, 'Chicken Breast');
    });

    test('should return empty list for no matches', () async {
      final results = await nutritionService.searchFoods('pizza');

      expect(results, isEmpty);
    });

    test('should return foods with correct nutritional data', () async {
      final results = await nutritionService.searchFoods('Apple');

      expect(results.length, 1);
      final apple = results.first;
      expect(apple.mass_g, 150);
      expect(apple.calories_g, closeTo(0.52, 0.01));
      expect(apple.mealType, 'snack');
    });

    test('should handle mixed case queries', () async {
      final results = await nutritionService.searchFoods('BaNaNa');

      expect(results.length, 1);
      expect(results.first.name, 'Banana');
    });
  });

  // ============================================================================
  // CALCULATE NUTRITION TESTS
  // ============================================================================
  group('NutritionService.calculateNutrition', () {
    test('should return zeros for empty food list', () {
      final result = nutritionService.calculateNutrition([]);

      expect(result['totalCalories'], 0);
      expect(result['totalProtein'], 0);
      expect(result['totalCarbs'], 0);
      expect(result['totalFat'], 0);
      expect(result['proteinPercentage'], 0);
      expect(result['carbsPercentage'], 0);
      expect(result['fatPercentage'], 0);
    });

    test('should calculate totals for single food item', () {
      final foods = [
        FoodItem(
          id: '1',
          name: 'Apple',
          mass_g: 150,
          calories_g: 0.52, // 78 total calories
          protein_g: 0.003, // 0.45g total protein
          carbs_g: 0.14, // 21g total carbs
          fat: 0.002, // 0.3g total fat
          mealType: 'snack',
          consumedAt: testDate,
        ),
      ];

      final result = nutritionService.calculateNutrition(foods);

      expect(result['totalCalories'], 78); // 150 * 0.52
      expect(result['totalProtein'], 0); // 0.45 rounds to 0
      expect(result['totalCarbs'], 21); // 150 * 0.14
      expect(result['totalFat'], 0); // 0.3 rounds to 0
    });

    test('should calculate totals for multiple food items', () {
      final foods = [
        FoodItem(
          id: '1',
          name: 'Apple',
          mass_g: 100,
          calories_g: 0.52, // 52 cal
          protein_g: 0.003, // 0.3g
          carbs_g: 0.14, // 14g
          fat: 0.002, // 0.2g
          mealType: 'snack',
          consumedAt: testDate,
        ),
        FoodItem(
          id: '2',
          name: 'Chicken Breast',
          mass_g: 100,
          calories_g: 1.65, // 165 cal
          protein_g: 0.31, // 31g
          carbs_g: 0.0, // 0g
          fat: 0.036, // 3.6g
          mealType: 'lunch',
          consumedAt: testDate,
        ),
      ];

      final result = nutritionService.calculateNutrition(foods);

      // 52 + 165 = 217 calories
      expect(result['totalCalories'], 217);
      // 0.3 + 31 = 31.3 -> 31
      expect(result['totalProtein'], 31);
      // 14 + 0 = 14
      expect(result['totalCarbs'], 14);
      // 0.2 + 3.6 = 3.8 -> 4
      expect(result['totalFat'], 4);
    });

    test('should calculate macro percentages correctly', () {
      // Create food with known values for easy percentage calculation
      final foods = [
        FoodItem(
          id: '1',
          name: 'Test Food',
          mass_g: 100,
          calories_g: 4.0, // 400 total calories
          protein_g: 0.25, // 25g protein
          carbs_g: 0.50, // 50g carbs
          fat: 0.11, // 11g fat
          mealType: 'lunch',
          consumedAt: testDate,
        ),
      ];

      final result = nutritionService.calculateNutrition(foods);

      // Protein: (25 * 4 / 400) * 100 = 25%
      expect(result['proteinPercentage'], 25);
      // Carbs: (50 * 4 / 400) * 100 = 50%
      expect(result['carbsPercentage'], 50);
      // Fat: (11 * 9 / 400) * 100 = 24.75% ≈ 25%
      expect(result['fatPercentage'], 25);
    });

    test('should handle food with zero calories gracefully', () {
      final foods = [
        FoodItem(
          id: '1',
          name: 'Water',
          mass_g: 250,
          calories_g: 0,
          protein_g: 0,
          carbs_g: 0,
          fat: 0,
          mealType: 'snack',
          consumedAt: testDate,
        ),
      ];

      final result = nutritionService.calculateNutrition(foods);

      expect(result['totalCalories'], 0);
      expect(result['proteinPercentage'], 0);
      expect(result['carbsPercentage'], 0);
      expect(result['fatPercentage'], 0);
    });

    test('should handle mixed foods with some having zero values', () {
      final foods = [
        FoodItem(
          id: '1',
          name: 'Water',
          mass_g: 250,
          calories_g: 0,
          protein_g: 0,
          carbs_g: 0,
          fat: 0,
          mealType: 'snack',
          consumedAt: testDate,
        ),
        FoodItem(
          id: '2',
          name: 'Apple',
          mass_g: 100,
          calories_g: 0.52,
          protein_g: 0.003,
          carbs_g: 0.14,
          fat: 0.002,
          mealType: 'snack',
          consumedAt: testDate,
        ),
      ];

      final result = nutritionService.calculateNutrition(foods);

      // Only apple contributes
      expect(result['totalCalories'], 52);
    });

    test('should handle large food list', () {
      final foods = List.generate(
        10,
        (i) => FoodItem(
          id: 'food_$i',
          name: 'Food $i',
          mass_g: 100,
          calories_g: 1.0, // 100 cal each
          protein_g: 0.1, // 10g each
          carbs_g: 0.2, // 20g each
          fat: 0.05, // 5g each
          mealType: 'snack',
          consumedAt: testDate,
        ),
      );

      final result = nutritionService.calculateNutrition(foods);

      expect(result['totalCalories'], 1000); // 10 * 100
      expect(result['totalProtein'], 100); // 10 * 10
      expect(result['totalCarbs'], 200); // 10 * 20
      expect(result['totalFat'], 50); // 10 * 5
    });
  });
}
