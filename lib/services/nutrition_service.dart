import '../db/user.dart'; // Uses FoodItem model

class NutritionService {
  // ---------------------------------------------------------------------------
  // Simulated Food Search (mock API)
  // ---------------------------------------------------------------------------
  Future<List<FoodItem>> searchFoods(String query) async {
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock data - in a real app, this would come from an API like USDA or FatSecret
    final food1 = FoodItem(
      name: 'Apple',
      mass_g: 150,
      calories_g: 78,
      protein_g: 0.3,
      carbs_g: 20.6,
      fat: 0.2,
      mealType: 'Snack',
      consumedAt: DateTime.now(),
    );

    final food2 = FoodItem(
      name: 'Banana',
      mass_g: 118,
      calories_g: 105,
      protein_g: 1.3,
      carbs_g: 27,
      fat: 0.3,
      mealType: 'Breakfast',
      consumedAt: DateTime.now(),
    );

    final food3 = FoodItem(
      name: 'Chicken Breast',
      mass_g: 100,
      calories_g: 165,
      protein_g: 31,
      carbs_g: 0,
      fat: 3.6,
      mealType: 'Lunch',
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

  // ---------------------------------------------------------------------------
  // Calculate nutritional totals from a list of FoodItems
  // ---------------------------------------------------------------------------
  Map<String, dynamic> calculateNutrition(List<FoodItem> foods) {
    if (foods.isEmpty) {
      return _emptyNutrition();
    }

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final food in foods) {
      totalCalories += food.calories_g;
      totalProtein += food.protein_g;
      totalCarbs += food.carbs_g;
      totalFat += food.fat;
    }

    if (totalCalories == 0) {
      return _emptyNutrition();
    }

    return {
      'totalCalories': totalCalories.round(),
      'totalProtein': totalProtein.round(),
      'totalCarbs': totalCarbs.round(),
      'totalFat': totalFat.round(),
      'proteinPercentage': ((totalProtein * 4 / totalCalories) * 100).round(),
      'carbsPercentage': ((totalCarbs * 4 / totalCalories) * 100).round(),
      'fatPercentage': ((totalFat * 9 / totalCalories) * 100).round(),
    };
  }

  // ---------------------------------------------------------------------------
  // Helper: Return empty nutrition map
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _emptyNutrition() {
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
}
