/// Tests for MealAnalysisService models (AnalyzedFoodItem, MealAnalysis)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/services/meal_analysis_service.dart';

void main() {
  // ============================================================================
  // ANALYZED FOOD ITEM TESTS
  // ============================================================================
  group('AnalyzedFoodItem', () {
    test('should create instance with all fields', () {
      final item = AnalyzedFoodItem(
        name: 'Apple',
        mass: 150,
        calories: 78,
        protein: 0.5,
        carbs: 21,
        fat: 0.3,
      );

      expect(item.name, 'Apple');
      expect(item.mass, 150);
      expect(item.calories, 78);
      expect(item.protein, 0.5);
      expect(item.carbs, 21);
      expect(item.fat, 0.3);
    });

    test('fromJson should parse JSON correctly', () {
      final json = {
        'n': 'Banana',
        'm': 118,
        'k': 105,
        'p': 1.3,
        'c': 27,
        'a': 0.4,
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.name, 'Banana');
      expect(item.mass, 118);
      expect(item.calories, 105);
      expect(item.protein, 1.3);
      expect(item.carbs, 27);
      expect(item.fat, 0.4);
    });

    test('fromJson should handle missing name with default', () {
      final json = {
        'm': 100,
        'k': 50,
        'p': 1,
        'c': 10,
        'a': 0.5,
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.name, 'Unknown Food');
    });

    test('fromJson should handle integer values', () {
      final json = {
        'n': 'Rice',
        'm': 200,
        'k': 260,
        'p': 5,
        'c': 57,
        'a': 1,
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.mass, 200.0);
      expect(item.calories, 260.0);
      expect(item.protein, 5.0);
    });

    test('fromJson should handle string numeric values', () {
      final json = {
        'n': 'Bread',
        'm': '50',
        'k': '130',
        'p': '4',
        'c': '24',
        'a': '1.5',
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.mass, 50.0);
      expect(item.calories, 130.0);
      expect(item.protein, 4.0);
      expect(item.carbs, 24.0);
      expect(item.fat, 1.5);
    });

    test('fromJson should handle null/invalid values as 0', () {
      final json = {
        'n': 'Unknown',
        'm': null,
        'k': 'invalid',
        'p': null,
        'c': null,
        'a': null,
      };

      final item = AnalyzedFoodItem.fromJson(json);

      expect(item.mass, 0.0);
      expect(item.calories, 0.0);
      expect(item.protein, 0.0);
      expect(item.carbs, 0.0);
      expect(item.fat, 0.0);
    });

    test('toJson should produce correct JSON', () {
      final item = AnalyzedFoodItem(
        name: 'Chicken',
        mass: 100,
        calories: 165,
        protein: 31,
        carbs: 0,
        fat: 3.6,
      );

      final json = item.toJson();

      expect(json['n'], 'Chicken');
      expect(json['m'], 100);
      expect(json['k'], 165);
      expect(json['p'], 31);
      expect(json['c'], 0);
      expect(json['a'], 3.6);
    });

    test('JSON round-trip should preserve data', () {
      final original = AnalyzedFoodItem(
        name: 'Salmon',
        mass: 150,
        calories: 312,
        protein: 37.5,
        carbs: 0,
        fat: 19.5,
      );

      final json = original.toJson();
      final restored = AnalyzedFoodItem.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.mass, original.mass);
      expect(restored.calories, original.calories);
      expect(restored.protein, original.protein);
      expect(restored.carbs, original.carbs);
      expect(restored.fat, original.fat);
    });
  });

  // ============================================================================
  // MEAL ANALYSIS TESTS
  // ============================================================================
  group('MealAnalysis', () {
    test('should create instance with foods list', () {
      final analysis = MealAnalysis(
        foods: [
          AnalyzedFoodItem(
            name: 'Apple',
            mass: 150,
            calories: 78,
            protein: 0.5,
            carbs: 21,
            fat: 0.3,
          ),
        ],
      );

      expect(analysis.foods.length, 1);
      expect(analysis.foods.first.name, 'Apple');
    });

    test('fromJson should parse foods array', () {
      final json = {
        'f': [
          {'n': 'Apple', 'm': 150, 'k': 78, 'p': 0.5, 'c': 21, 'a': 0.3},
          {'n': 'Banana', 'm': 118, 'k': 105, 'p': 1.3, 'c': 27, 'a': 0.4},
        ]
      };

      final analysis = MealAnalysis.fromJson(json);

      expect(analysis.foods.length, 2);
      expect(analysis.foods[0].name, 'Apple');
      expect(analysis.foods[1].name, 'Banana');
    });

    test('fromJson should handle missing foods array', () {
      final json = <String, dynamic>{};

      final analysis = MealAnalysis.fromJson(json);

      expect(analysis.foods, isEmpty);
    });

    test('fromJson should handle null foods array', () {
      final json = {'f': null};

      final analysis = MealAnalysis.fromJson(json);

      expect(analysis.foods, isEmpty);
    });

    test('toJson should produce correct structure', () {
      final analysis = MealAnalysis(
        foods: [
          AnalyzedFoodItem(
            name: 'Chicken',
            mass: 100,
            calories: 165,
            protein: 31,
            carbs: 0,
            fat: 3.6,
          ),
        ],
      );

      final json = analysis.toJson();

      expect(json['f'], isA<List>());
      expect((json['f'] as List).length, 1);
    });

    group('Totals', () {
      late MealAnalysis analysis;

      setUp(() {
        analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Apple',
              mass: 150,
              calories: 78,
              protein: 0.5,
              carbs: 21,
              fat: 0.3,
            ),
            AnalyzedFoodItem(
              name: 'Chicken Breast',
              mass: 100,
              calories: 165,
              protein: 31,
              carbs: 0,
              fat: 3.6,
            ),
          ],
        );
      });

      test('totalMass should sum all food masses', () {
        expect(analysis.totalMass, 250); // 150 + 100
      });

      test('totalCalories should sum all calories', () {
        expect(analysis.totalCalories, 243); // 78 + 165
      });

      test('totalProtein should sum all protein', () {
        expect(analysis.totalProtein, 31.5); // 0.5 + 31
      });

      test('totalCarbs should sum all carbs', () {
        expect(analysis.totalCarbs, 21); // 21 + 0
      });

      test('totalFat should sum all fat', () {
        expect(analysis.totalFat, closeTo(3.9, 0.01)); // 0.3 + 3.6
      });
    });

    group('Percentages', () {
      test('should calculate protein percentage correctly', () {
        final analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Test',
              mass: 100,
              calories: 400,
              protein: 25, // 25g * 4 = 100 kcal -> 25%
              carbs: 50, // 50g * 4 = 200 kcal -> 50%
              fat: 11.11, // ~11g * 9 = 100 kcal -> 25%
            ),
          ],
        );

        expect(analysis.proteinPercentage, closeTo(25, 0.1));
      });

      test('should calculate carbs percentage correctly', () {
        final analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Test',
              mass: 100,
              calories: 400,
              protein: 25,
              carbs: 50, // 50g * 4 = 200 kcal -> 50%
              fat: 11.11,
            ),
          ],
        );

        expect(analysis.carbsPercentage, closeTo(50, 0.1));
      });

      test('should calculate fat percentage correctly', () {
        final analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Test',
              mass: 100,
              calories: 400,
              protein: 25,
              carbs: 50,
              fat: 11.11, // ~11g * 9 = ~100 kcal -> ~25%
            ),
          ],
        );

        expect(analysis.fatPercentage, closeTo(25, 0.1));
      });

      test('should return 0 percentages when calories are 0', () {
        final analysis = MealAnalysis(
          foods: [
            AnalyzedFoodItem(
              name: 'Water',
              mass: 250,
              calories: 0,
              protein: 0,
              carbs: 0,
              fat: 0,
            ),
          ],
        );

        expect(analysis.proteinPercentage, 0);
        expect(analysis.carbsPercentage, 0);
        expect(analysis.fatPercentage, 0);
      });

      test('should return 0 percentages for empty foods list', () {
        final analysis = MealAnalysis(foods: []);

        expect(analysis.totalCalories, 0);
        expect(analysis.proteinPercentage, 0);
        expect(analysis.carbsPercentage, 0);
        expect(analysis.fatPercentage, 0);
      });
    });

    test('JSON round-trip should preserve all data', () {
      final original = MealAnalysis(
        foods: [
          AnalyzedFoodItem(
            name: 'Salad',
            mass: 200,
            calories: 45,
            protein: 2,
            carbs: 8,
            fat: 0.5,
          ),
          AnalyzedFoodItem(
            name: 'Dressing',
            mass: 30,
            calories: 150,
            protein: 0,
            carbs: 2,
            fat: 16,
          ),
        ],
      );

      final json = original.toJson();
      final restored = MealAnalysis.fromJson(json);

      expect(restored.foods.length, original.foods.length);
      expect(restored.totalCalories, original.totalCalories);
      expect(restored.totalProtein, original.totalProtein);
    });
  });
}
