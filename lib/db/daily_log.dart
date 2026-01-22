import 'package:json_annotation/json_annotation.dart';
import 'food.dart';

part 'daily_log.g.dart';

@JsonSerializable(explicitToJson: true)
class DailyLog {
  final DateTime date;
  final List<FoodItem> items;

  DailyLog({required this.date, required this.items});

  factory DailyLog.fromFoods({
    required DateTime date,
    required List<FoodItem> foods,
  }) {
    final target = _normalize(date);
    final sameDay = foods.where((f) => _isSameDay(f.consumedAt, target)).toList();
    return DailyLog(date: target, items: sameDay);
  }

  double get totalCalories =>
      items.fold(0, (n, f) => n + f.calories_g);
  double get totalProtein =>
      items.fold(0, (n, f) => n + f.protein_g);
  double get totalCarbs =>
      items.fold(0, (n, f) => n + f.carbs_g);
  double get totalFat =>
      items.fold(0, (n, f) => n + f.fat);

  Map<String, List<FoodItem>> get meals {
    final map = <String, List<FoodItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.mealType, () => []).add(item);
    }
    return map;
  }

  factory DailyLog.fromJson(Map<String, dynamic> json) =>
      _$DailyLogFromJson(json);
  Map<String, dynamic> toJson() => _$DailyLogToJson(this);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Build logs for each day in an inclusive date range.
List<DailyLog> buildDailyLogsInRange({
  required List<FoodItem> foods,
  required DateTime start,
  required DateTime end,
}) {
  final startDay = DailyLog._normalize(start);
  final endDay = DailyLog._normalize(end);
  final days = endDay.difference(startDay).inDays;
  return List.generate(
    days + 1,
    (i) => DailyLog.fromFoods(
      date: startDay.add(Duration(days: i)),
      foods: foods,
    ),
  );
}
