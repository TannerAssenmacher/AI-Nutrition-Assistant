import '../db/food.dart';

class NutritionService {
  // Simulate API calls for food data
  
  Future<List<FoodItem>> searchFoods(String query) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Mock data - in a real app, this would come from an API
    final food1 = FoodItem(
      id: '1',
      name: 'Apple',
      mass_g: 150,                  // serving mass in grams
      calories_g: 0.52,             // calories per gram (52 / 100)
      protein_g: 0.003,             // 0.3 / 100
      carbs_g: 0.14,                // 14 / 100
      fat: 0.002,                   // 0.2 / 100
      mealType: 'snack',
      consumedAt: DateTime.now(),
    );

    final food2 = FoodItem(
      id: '2',
      name: 'Banana',
      mass_g: 118,
      calories_g: 0.89,             // 89 / 100
      protein_g: 0.011,             // 1.1 / 100
      carbs_g: 0.23,                // 23 / 100
      fat: 0.003,                   // 0.3 / 100
      mealType: 'snack',
      consumedAt: DateTime.now(),
    );

    final food3 = FoodItem(
      id: '3',
      name: 'Chicken Breast',
      mass_g: 100,
      calories_g: 1.65,             // 165 / 100
      protein_g: 0.31,              // 31 / 100
      carbs_g: 0.0,
      fat: 0.036,                   // 3.6 / 100
      mealType: 'lunch',
      consumedAt: DateTime.now(),
    );

    final allFoods = [food1, food2, food3];
    
    if (query.isEmpty) {
      return allFoods;
    }
    
    return allFoods
        .where((food) => food.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
  
  // Calculate nutritional information for a list of food items
  Map<String, dynamic> calculateNutrition(List<FoodItem> foods) {
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
      // calories_g is calories per 1 gram
      totalCalories += food.calories_g * food.mass_g;
      totalProtein += food.protein_g * food.mass_g;
      totalCarbs += food.carbs_g * food.mass_g;
      totalFat += food.fat * food.mass_g;
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