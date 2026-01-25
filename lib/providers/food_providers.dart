import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/food.dart';

part 'food_providers.g.dart';

@riverpod
class FoodLog extends _$FoodLog {
  @override
  List<FoodItem> build() {
    return [];
  }

  void addFoodItem(FoodItem item) {
    state = [...state, item];
  }

  void removeFoodItem(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clearLog() {
    state = [];
  }

  void updateFoodItem(FoodItem updatedItem) {
    state = state.map((item) {
      return item.id == updatedItem.id ? updatedItem : item;
    }).toList();
  }
}

@riverpod
int totalDailyCalories(Ref ref) {
  final foodLog = ref.watch(foodLogProvider);
  final today = DateTime.now();

  return foodLog
      .where((item) =>
  item.consumedAt.year == today.year &&
      item.consumedAt.month == today.month &&
      item.consumedAt.day == today.day)
      .fold(0, (total, item) =>
  total + (item.calories_g * item.mass_g).round());
}

@riverpod
Map<String, double> totalDailyMacros(Ref ref) {
  final foodLog = ref.watch(foodLogProvider);
  final today = DateTime.now();

  double protein = 0;
  double carbs = 0;
  double fat = 0;

  for (final item in foodLog.where((i) =>
  i.consumedAt.year == today.year &&
      i.consumedAt.month == today.month &&
      i.consumedAt.day == today.day))
  {
    protein += item.protein_g * item.mass_g;
    carbs   += item.carbs_g   * item.mass_g;
    fat     += item.fat       * item.mass_g;
  }

  return {
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
}

@riverpod
Future<List<String>> foodSuggestions(Ref ref) async {
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
