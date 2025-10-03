import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/food.dart';

part 'food_providers.g.dart';

// Simple state provider for a list of consumed food items
@riverpod
class FoodLog extends _$FoodLog {
  @override
  List<Food> build() {
    return [];
  }

  void addFoodItem(Food item) {
    state = [...state, item];
  }

  void removeFoodItem(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clearLog() {
    state = [];
  }

  void updateFoodItem(Food updatedItem) {
    state = state.map((item) {
      return item.id == updatedItem.id ? updatedItem : item;
    }).toList();
  }
}

// Computed provider for total daily calories
@riverpod
int totalDailyCalories(Ref ref) {
  final foodLog = ref.watch(foodLogProvider);
  final today = DateTime.now();
  
  return foodLog
      .where((item) => 
          item.consumedAt.year == today.year &&
          item.consumedAt.month == today.month &&
          item.consumedAt.day == today.day)
      .fold(0, (total, item) => total + (item.caloriesPer100g / 100 * item.servingSize).round());
}

// Computed provider for total daily macros
@riverpod
Map<String, double> totalDailyMacros(Ref ref) {
  final foodLog = ref.watch(foodLogProvider);
  final today = DateTime.now();
  
  final todaysFoods = foodLog.where((item) => 
      item.consumedAt.year == today.year &&
      item.consumedAt.month == today.month &&
      item.consumedAt.day == today.day);

  double totalProtein = 0;
  double totalCarbs = 0;
  double totalFat = 0;

  for (final item in todaysFoods) {
    totalProtein += (item.proteinPer100g / 100 * item.servingSize);
    totalCarbs += (item.carbsPer100g / 100 * item.servingSize);
    totalFat += (item.fatPer100g / 100 * item.servingSize);
  }

  return {
    'protein': totalProtein,
    'carbs': totalCarbs,
    'fat': totalFat,
  };
}

// Example async provider for fetching food suggestions
@riverpod
Future<List<String>> foodSuggestions(Ref ref) async {
  // Simulate API call
  await Future.delayed(const Duration(seconds: 1));
  
  return [
    'Apple (80 calories)',
    'Banana (105 calories)',
    'Chicken Breast (165 calories)',
    'Brown Rice (110 calories)',
    'Greek Yogurt (100 calories)',
    'Salmon (206 calories)',
    'Broccoli (34 calories)',
    'Sweet Potato (112 calories)',
  ];
}