import '../models/food_item.dart';

class NutritionService {
  // Simulate API calls for food data
  
  Future<List<FoodItem>> searchFoods(String query) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Mock data - in a real app, this would come from an API
    final allFoods = [
      FoodItem(
        id: '1',
        name: 'Apple',
        calories: 80,
        protein: 0.4,
        carbs: 21.0,
        fat: 0.2,
        consumedAt: DateTime.now(),
      ),
      FoodItem(
        id: '2',
        name: 'Banana',
        calories: 105,
        protein: 1.3,
        carbs: 27.0,
        fat: 0.4,
        consumedAt: DateTime.now(),
      ),
      FoodItem(
        id: '3',
        name: 'Chicken Breast (100g)',
        calories: 165,
        protein: 31.0,
        carbs: 0.0,
        fat: 3.6,
        consumedAt: DateTime.now(),
      ),
      FoodItem(
        id: '4',
        name: 'Brown Rice (1 cup)',
        calories: 110,
        protein: 2.6,
        carbs: 23.0,
        fat: 0.9,
        consumedAt: DateTime.now(),
      ),
    ];
    
    // Filter based on query
    return allFoods
        .where((food) => food.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
  
  Future<FoodItem?> getFoodDetails(String foodId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock implementation
    final foods = await searchFoods('');
    return foods.firstWhere((food) => food.id == foodId);
  }
  
  Future<Map<String, dynamic>> analyzeNutrition(List<FoodItem> foods) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    int totalCalories = foods.fold(0, (sum, food) => sum + food.calories);
    double totalProtein = foods.fold(0.0, (sum, food) => sum + food.protein);
    double totalCarbs = foods.fold(0.0, (sum, food) => sum + food.carbs);
    double totalFat = foods.fold(0.0, (sum, food) => sum + food.fat);
    
    return {
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'proteinPercentage': (totalProtein * 4 / totalCalories * 100).round(),
      'carbsPercentage': (totalCarbs * 4 / totalCalories * 100).round(),
      'fatPercentage': (totalFat * 9 / totalCalories * 100).round(),
    };
  }
}