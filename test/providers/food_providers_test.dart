/// Tests for Food providers (FoodLog, totalDailyCalories, totalDailyMacros, foodSuggestions)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrition_assistant/db/food.dart';
import 'package:nutrition_assistant/providers/food_providers.dart';

void main() {
  late ProviderContainer container;
  late DateTime today;
  late DateTime yesterday;

  setUp(() {
    container = ProviderContainer();
    today = DateTime.now();
    yesterday = today.subtract(const Duration(days: 1));
  });

  tearDown(() {
    container.dispose();
  });

  FoodItem createFood({
    required String id,
    required String name,
    double mass_g = 100,
    double calories_g = 1.0,
    double protein_g = 0.1,
    double carbs_g = 0.1,
    double fat = 0.1,
    String mealType = 'snack',
    DateTime? consumedAt,
  }) {
    return FoodItem(
      id: id,
      name: name,
      mass_g: mass_g,
      calories_g: calories_g,
      protein_g: protein_g,
      carbs_g: carbs_g,
      fat: fat,
      mealType: mealType,
      consumedAt: consumedAt ?? today,
    );
  }

  // ============================================================================
  // FOOD LOG PROVIDER TESTS
  // ============================================================================
  group('FoodLog Provider', () {
    test('should initialize with empty list', () {
      final foodLog = container.read(foodLogProvider);
      expect(foodLog, isEmpty);
    });

    test('addFoodItem should add food to log', () {
      final notifier = container.read(foodLogProvider.notifier);
      final food = createFood(id: 'food_1', name: 'Apple');

      notifier.addFoodItem(food);

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 1);
      expect(foodLog.first.name, 'Apple');
    });

    test('addFoodItem should add multiple foods', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'food_1', name: 'Apple'));
      notifier.addFoodItem(createFood(id: 'food_2', name: 'Banana'));
      notifier.addFoodItem(createFood(id: 'food_3', name: 'Chicken'));

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 3);
    });

    test('removeFoodItem should remove food by id', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'food_1', name: 'Apple'));
      notifier.addFoodItem(createFood(id: 'food_2', name: 'Banana'));

      notifier.removeFoodItem('food_1');

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 1);
      expect(foodLog.first.id, 'food_2');
    });

    test('removeFoodItem should not affect log if id not found', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'food_1', name: 'Apple'));

      notifier.removeFoodItem('non_existent');

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 1);
    });

    test('clearLog should remove all foods', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'food_1', name: 'Apple'));
      notifier.addFoodItem(createFood(id: 'food_2', name: 'Banana'));
      notifier.addFoodItem(createFood(id: 'food_3', name: 'Chicken'));

      notifier.clearLog();

      final foodLog = container.read(foodLogProvider);
      expect(foodLog, isEmpty);
    });

    test('updateFoodItem should update existing food', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'food_1', name: 'Apple', mass_g: 100));

      final updatedFood = createFood(id: 'food_1', name: 'Green Apple', mass_g: 150);
      notifier.updateFoodItem(updatedFood);

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 1);
      expect(foodLog.first.name, 'Green Apple');
      expect(foodLog.first.mass_g, 150);
    });

    test('updateFoodItem should not affect other foods', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'food_1', name: 'Apple'));
      notifier.addFoodItem(createFood(id: 'food_2', name: 'Banana'));

      final updatedFood = createFood(id: 'food_1', name: 'Green Apple');
      notifier.updateFoodItem(updatedFood);

      final foodLog = container.read(foodLogProvider);
      expect(foodLog[0].name, 'Green Apple');
      expect(foodLog[1].name, 'Banana');
    });

    test('updateFoodItem should not add food if id not found', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'food_1', name: 'Apple'));

      final updatedFood = createFood(id: 'non_existent', name: 'Ghost Food');
      notifier.updateFoodItem(updatedFood);

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 1);
      expect(foodLog.first.id, 'food_1');
    });

    test('should maintain order of added foods', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'food_1', name: 'First'));
      notifier.addFoodItem(createFood(id: 'food_2', name: 'Second'));
      notifier.addFoodItem(createFood(id: 'food_3', name: 'Third'));

      final foodLog = container.read(foodLogProvider);
      expect(foodLog[0].name, 'First');
      expect(foodLog[1].name, 'Second');
      expect(foodLog[2].name, 'Third');
    });
  });

  // ============================================================================
  // TOTAL DAILY CALORIES PROVIDER TESTS
  // ============================================================================
  group('totalDailyCalories Provider', () {
    test('should return 0 for empty food log', () {
      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 0);
    });

    test('should calculate calories for foods consumed today', () {
      final notifier = container.read(foodLogProvider.notifier);

      // 100g * 1.0 cal/g = 100 calories
      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Apple',
        mass_g: 100,
        calories_g: 1.0,
        consumedAt: today,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 100);
    });

    test('should sum calories from multiple foods today', () {
      final notifier = container.read(foodLogProvider.notifier);

      // 100g * 0.5 = 50 cal
      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Apple',
        mass_g: 100,
        calories_g: 0.5,
        consumedAt: today,
      ));

      // 150g * 1.0 = 150 cal
      notifier.addFoodItem(createFood(
        id: 'food_2',
        name: 'Chicken',
        mass_g: 150,
        calories_g: 1.0,
        consumedAt: today,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 200);
    });

    test('should exclude foods from yesterday', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Apple Today',
        mass_g: 100,
        calories_g: 1.0,
        consumedAt: today,
      ));

      notifier.addFoodItem(createFood(
        id: 'food_2',
        name: 'Apple Yesterday',
        mass_g: 100,
        calories_g: 1.0,
        consumedAt: yesterday,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 100); // Only today's food
    });

    test('should handle rounding correctly', () {
      final notifier = container.read(foodLogProvider.notifier);

      // 100g * 0.523 = 52.3 -> rounds to 52
      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Apple',
        mass_g: 100,
        calories_g: 0.523,
        consumedAt: today,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 52);
    });
  });

  // ============================================================================
  // TOTAL DAILY MACROS PROVIDER TESTS
  // ============================================================================
  group('totalDailyMacros Provider', () {
    test('should return zeros for empty food log', () {
      final macros = container.read(totalDailyMacrosProvider);

      expect(macros['protein'], 0);
      expect(macros['carbs'], 0);
      expect(macros['fat'], 0);
    });

    test('should calculate macros for foods consumed today', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Chicken',
        mass_g: 100,
        protein_g: 0.31, // 31g total
        carbs_g: 0.0,
        fat: 0.036, // 3.6g total
        consumedAt: today,
      ));

      final macros = container.read(totalDailyMacrosProvider);

      expect(macros['protein'], closeTo(31, 0.1));
      expect(macros['carbs'], 0);
      expect(macros['fat'], closeTo(3.6, 0.1));
    });

    test('should sum macros from multiple foods', () {
      final notifier = container.read(foodLogProvider.notifier);

      // Food 1: 10g protein, 20g carbs, 5g fat
      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Food1',
        mass_g: 100,
        protein_g: 0.10,
        carbs_g: 0.20,
        fat: 0.05,
        consumedAt: today,
      ));

      // Food 2: 15g protein, 30g carbs, 8g fat
      notifier.addFoodItem(createFood(
        id: 'food_2',
        name: 'Food2',
        mass_g: 100,
        protein_g: 0.15,
        carbs_g: 0.30,
        fat: 0.08,
        consumedAt: today,
      ));

      final macros = container.read(totalDailyMacrosProvider);

      expect(macros['protein'], closeTo(25, 0.1)); // 10 + 15
      expect(macros['carbs'], closeTo(50, 0.1)); // 20 + 30
      expect(macros['fat'], closeTo(13, 0.1)); // 5 + 8
    });

    test('should exclude foods from yesterday', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Today Food',
        mass_g: 100,
        protein_g: 0.20, // 20g
        consumedAt: today,
      ));

      notifier.addFoodItem(createFood(
        id: 'food_2',
        name: 'Yesterday Food',
        mass_g: 100,
        protein_g: 0.30, // 30g
        consumedAt: yesterday,
      ));

      final macros = container.read(totalDailyMacrosProvider);
      expect(macros['protein'], closeTo(20, 0.1)); // Only today
    });
  });

  // ============================================================================
  // FOOD SUGGESTIONS PROVIDER TESTS
  // ============================================================================
  group('foodSuggestions Provider', () {
    test('should return list of food suggestions', () async {
      final suggestions = await container.read(foodSuggestionsProvider.future);

      expect(suggestions, isNotEmpty);
      expect(suggestions.length, 8);
    });

    test('suggestions should contain calorie information', () async {
      final suggestions = await container.read(foodSuggestionsProvider.future);

      for (final suggestion in suggestions) {
        expect(suggestion, contains('calories'));
      }
    });

    test('suggestions should include variety of foods', () async {
      final suggestions = await container.read(foodSuggestionsProvider.future);

      expect(suggestions.any((s) => s.contains('Apple')), isTrue);
      expect(suggestions.any((s) => s.contains('Chicken')), isTrue);
      expect(suggestions.any((s) => s.contains('Banana')), isTrue);
    });
  });

  // ============================================================================
  // EDGE CASES - FOOD LOG OPERATIONS
  // ============================================================================
  group('FoodLog Edge Cases', () {
    test('should handle adding same food id multiple times', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'duplicate', name: 'First'));
      notifier.addFoodItem(createFood(id: 'duplicate', name: 'Second'));

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 2); // Both are added (no unique constraint)
    });

    test('should handle removing from empty log', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.removeFoodItem('non_existent');

      final foodLog = container.read(foodLogProvider);
      expect(foodLog, isEmpty);
    });

    test('should handle clearing already empty log', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.clearLog();

      final foodLog = container.read(foodLogProvider);
      expect(foodLog, isEmpty);
    });

    test('should handle updating non-existent food', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(id: 'existing', name: 'Existing'));
      notifier.updateFoodItem(createFood(id: 'non_existent', name: 'Ghost'));

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 1);
      expect(foodLog.first.name, 'Existing');
    });

    test('should handle very large food log', () {
      final notifier = container.read(foodLogProvider.notifier);

      for (int i = 0; i < 1000; i++) {
        notifier.addFoodItem(createFood(id: 'food_$i', name: 'Food $i'));
      }

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 1000);
    });

    test('should handle rapid add-remove cycles', () {
      final notifier = container.read(foodLogProvider.notifier);

      for (int i = 0; i < 100; i++) {
        notifier.addFoodItem(createFood(id: 'temp_$i', name: 'Temp $i'));
        notifier.removeFoodItem('temp_$i');
      }

      final foodLog = container.read(foodLogProvider);
      expect(foodLog, isEmpty);
    });

    test('should preserve food data after update', () {
      final notifier = container.read(foodLogProvider.notifier);
      
      final original = FoodItem(
        id: 'food_1',
        name: 'Original',
        mass_g: 100,
        calories_g: 1.0,
        protein_g: 0.1,
        carbs_g: 0.2,
        fat: 0.05,
        mealType: 'breakfast',
        consumedAt: today,
      );

      notifier.addFoodItem(original);

      final updated = FoodItem(
        id: 'food_1',
        name: 'Updated',
        mass_g: 200,
        calories_g: 2.0,
        protein_g: 0.2,
        carbs_g: 0.4,
        fat: 0.1,
        mealType: 'lunch',
        consumedAt: today,
      );

      notifier.updateFoodItem(updated);

      final foodLog = container.read(foodLogProvider);
      final food = foodLog.first;

      expect(food.name, 'Updated');
      expect(food.mass_g, 200);
      expect(food.calories_g, 2.0);
      expect(food.mealType, 'lunch');
    });
  });

  // ============================================================================
  // EDGE CASES - CALORIE CALCULATIONS
  // ============================================================================
  group('Calorie Calculation Edge Cases', () {
    test('should handle zero mass food', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'zero_mass',
        name: 'Zero Mass',
        mass_g: 0,
        calories_g: 10.0,
        consumedAt: today,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 0);
    });

    test('should handle zero calorie density food', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'water',
        name: 'Water',
        mass_g: 1000,
        calories_g: 0,
        consumedAt: today,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 0);
    });

    test('should handle fractional calories correctly', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Low Cal',
        mass_g: 10,
        calories_g: 0.5, // 5 calories
        consumedAt: today,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 5);
    });

    test('should round calories to nearest integer', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Precise Cal',
        mass_g: 33,
        calories_g: 0.333, // 10.989 calories
        consumedAt: today,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 11); // Rounded
    });

    test('should handle very high calorie food', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'High Cal',
        mass_g: 1000,
        calories_g: 9.0, // 9000 calories
        consumedAt: today,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 9000);
    });
  });

  // ============================================================================
  // EDGE CASES - MACRO CALCULATIONS
  // ============================================================================
  group('Macro Calculation Edge Cases', () {
    test('should handle zero macros', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Zero Macros',
        mass_g: 100,
        protein_g: 0,
        carbs_g: 0,
        fat: 0,
        consumedAt: today,
      ));

      final macros = container.read(totalDailyMacrosProvider);
      expect(macros['protein'], 0);
      expect(macros['carbs'], 0);
      expect(macros['fat'], 0);
    });

    test('should handle very high protein food', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Protein Powder',
        mass_g: 100,
        protein_g: 0.9, // 90g protein
        carbs_g: 0.05,
        fat: 0.02,
        consumedAt: today,
      ));

      final macros = container.read(totalDailyMacrosProvider);
      expect(macros['protein'], closeTo(90, 0.1));
    });

    test('should accumulate macros from many foods', () {
      final notifier = container.read(foodLogProvider.notifier);

      for (int i = 0; i < 10; i++) {
        notifier.addFoodItem(createFood(
          id: 'food_$i',
          name: 'Food $i',
          mass_g: 100,
          protein_g: 0.1, // 10g each
          carbs_g: 0.2, // 20g each
          fat: 0.05, // 5g each
          consumedAt: today,
        ));
      }

      final macros = container.read(totalDailyMacrosProvider);
      expect(macros['protein'], closeTo(100, 0.1)); // 10 * 10g
      expect(macros['carbs'], closeTo(200, 0.1)); // 10 * 20g
      expect(macros['fat'], closeTo(50, 0.1)); // 10 * 5g
    });

    test('should handle decimal precision in macros', () {
      final notifier = container.read(foodLogProvider.notifier);

      notifier.addFoodItem(createFood(
        id: 'food_1',
        name: 'Precise Food',
        mass_g: 123.456,
        protein_g: 0.123456,
        carbs_g: 0.234567,
        fat: 0.0123456,
        consumedAt: today,
      ));

      final macros = container.read(totalDailyMacrosProvider);
      expect(macros['protein'], isNotNull);
      expect(macros['carbs'], isNotNull);
      expect(macros['fat'], isNotNull);
    });
  });

  // ============================================================================
  // EDGE CASES - DATE FILTERING
  // ============================================================================
  group('Date Filtering Edge Cases', () {
    test('should handle food at midnight boundary', () {
      final notifier = container.read(foodLogProvider.notifier);
      final now = DateTime.now();
      
      // Start of today (midnight)
      final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
      
      notifier.addFoodItem(createFood(
        id: 'food_midnight',
        name: 'Midnight Snack',
        mass_g: 100,
        calories_g: 1.0,
        consumedAt: startOfToday,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 100);
    });

    test('should handle food at end of day', () {
      final notifier = container.read(foodLogProvider.notifier);
      final now = DateTime.now();
      
      // End of today (23:59:59)
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      notifier.addFoodItem(createFood(
        id: 'food_late',
        name: 'Late Night Snack',
        mass_g: 100,
        calories_g: 1.0,
        consumedAt: endOfToday,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 100);
    });

    test('should exclude food from last second of yesterday', () {
      final notifier = container.read(foodLogProvider.notifier);
      final now = DateTime.now();
      
      // Last second of yesterday
      final endOfYesterday = DateTime(now.year, now.month, now.day - 1, 23, 59, 59);
      
      notifier.addFoodItem(createFood(
        id: 'food_yesterday_late',
        name: 'Yesterday Late',
        mass_g: 100,
        calories_g: 1.0,
        consumedAt: endOfYesterday,
      ));

      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 0);
    });

    test('should handle multiple days of food', () {
      final notifier = container.read(foodLogProvider.notifier);
      final now = DateTime.now();

      // Add food for 7 days
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        notifier.addFoodItem(createFood(
          id: 'food_day_$i',
          name: 'Day $i Food',
          mass_g: 100,
          calories_g: 1.0,
          consumedAt: date,
        ));
      }

      final foodLog = container.read(foodLogProvider);
      expect(foodLog.length, 7);

      // Only today should count
      final calories = container.read(totalDailyCaloriesProvider);
      expect(calories, 100);
    });
  });
}
