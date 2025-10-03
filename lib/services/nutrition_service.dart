import '../db/food.dart';

class NutritionService {
  // Simulate API calls for food data
  
  Future<List<Food>> searchFoods(String query) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Mock data - in a real app, this would come from an API
    final food1 = Food(
        name: 'Apple',
        category: 'Fruit',
        caloriesPer100g: 52,
        proteinPer100g: 0.3,
        carbsPer100g: 14,
        fatPer100g: 0.2,
        fiberPer100g: 2.4,
        micronutrients: Micronutrients(
          calciumMg: 6,
          ironMg: 0.1,
          vitaminAMcg: 3,
          vitaminCMg: 4.6,
        ),
        source: 'USDA',
        consumedAt: DateTime.now(),
        servingSize: 150
      );
    food1.id = '1';

    final food2 = Food(
        name: 'Banana',
        category: 'Fruit',
        caloriesPer100g: 89,
        proteinPer100g: 1.1,
        carbsPer100g: 23,
        fatPer100g: 0.3,
        fiberPer100g: 2.6,
        micronutrients: Micronutrients(
          calciumMg: 5,
          ironMg: 0.3,
          vitaminAMcg: 3,
          vitaminCMg: 8.7,
        ),
        source: 'USDA',
        consumedAt: DateTime.now(),
        servingSize: 118
      );
    food2.id = '2';

    final food3 = Food(
        name: 'Chicken Breast',
        category: 'Meat',
        caloriesPer100g: 165,
        proteinPer100g: 31,
        carbsPer100g: 0,
        fatPer100g: 3.6,
        fiberPer100g: 0,
        micronutrients: Micronutrients(
          calciumMg: 13,
          ironMg: 1,
          vitaminAMcg: 0,
          vitaminCMg: 0,
        ),
        source: 'USDA',
        consumedAt: DateTime.now(),
        servingSize: 100
      );
    food3.id = '3';

    final allFoods = [food1, food2, food3];
    
    if (query.isEmpty) {
      return allFoods;
    }
    
    return allFoods
        .where((food) => food.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
  
  // Calculate nutritional information for a list of food items
  Map<String, dynamic> calculateNutrition(List<Food> foods) {
    if (foods.isEmpty) {
      return {
        'totalCalories': 0,
        'totalProtein': 0,
        'totalCarbs': 0,
        'totalFat': 0,
        'proteinPercentage': 0,
        'carbsPercentage': 0,
        'fatPercentage': 0,
      };
    }

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final food in foods) {
      final servingRatio = food.servingSize / 100;
      totalCalories += food.caloriesPer100g * servingRatio;
      totalProtein += food.proteinPer100g * servingRatio;
      totalCarbs += food.carbsPer100g * servingRatio;
      totalFat += food.fatPer100g * servingRatio;
    }

    if (totalCalories == 0) {
      return {
        'totalCalories': 0,
        'totalProtein': 0,
        'totalCarbs': 0,
        'totalFat': 0,
        'proteinPercentage': 0,
        'carbsPercentage': 0,
        'fatPercentage': 0,
      };
    }
    
    return {
      'totalCalories': totalCalories.round(),
      'totalProtein': totalProtein.round(),
      'totalCarbs': totalCarbs.round(),
      'totalFat': totalFat.round(),
      'proteinPercentage': (totalProtein * 4 / totalCalories * 100).round(),
      'carbsPercentage': (totalCarbs * 4 / totalCalories * 100).round(),
      'fatPercentage': (totalFat * 9 / totalCalories * 100).round(),
    };
  }
}
