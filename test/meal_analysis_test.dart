import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_assistant/services/meal_analysis_service.dart';

void main() {
  group('MealAnalysis', () {
    test('computes totals and macronutrient percentages', () {
      final analysis = MealAnalysis(foods: [
        AnalyzedFoodItem(
          name: 'Chicken breast',
          mass: 150,
          calories: 226.5,
          protein: 46.5,
          carbs: 0,
          fat: 4.5,
        ),
        AnalyzedFoodItem(
          name: 'Rice',
          mass: 180,
          calories: 232.0,
          protein: 4.5,
          carbs: 50.5,
          fat: 2.0,
        ),
      ]);

      expect(analysis.totalMass, closeTo(330, 0.001));
      expect(analysis.totalCalories, closeTo(458.5, 0.001));
      expect(analysis.totalProtein, closeTo(51.0, 0.001));
      expect(analysis.totalCarbs, closeTo(50.5, 0.001));
      expect(analysis.totalFat, closeTo(6.5, 0.001));

      // Percentages should align with 4/4/9 calorie math.
      expect(
          analysis.proteinPercentage, closeTo((51 * 4 / 458.5) * 100, 0.001));
      expect(
          analysis.carbsPercentage, closeTo((50.5 * 4 / 458.5) * 100, 0.001));
      expect(analysis.fatPercentage, closeTo((6.5 * 9 / 458.5) * 100, 0.001));
    });

    test('serializes and deserializes compact JSON shape', () {
      final item = AnalyzedFoodItem(
        name: 'Apple',
        mass: 150.5,
        calories: 78.2,
        protein: 0.3,
        carbs: 20.6,
        fat: 0.2,
      );
      final analysis = MealAnalysis(foods: [item]);

      final encoded = analysis.toJson();
      expect(encoded, {
        'f': [
          {
            'n': 'Apple',
            'm': 150.5,
            'k': 78.2,
            'p': 0.3,
            'c': 20.6,
            'a': 0.2,
          }
        ]
      });

      final decoded = MealAnalysis.fromJson(encoded);
      expect(decoded.foods.single.name, 'Apple');
      expect(decoded.foods.single.mass, closeTo(150.5, 0.001));
      expect(decoded.foods.single.calories, closeTo(78.2, 0.001));
      expect(decoded.foods.single.protein, closeTo(0.3, 0.001));
      expect(decoded.foods.single.carbs, closeTo(20.6, 0.001));
      expect(decoded.foods.single.fat, closeTo(0.2, 0.001));
    });
  });
}
