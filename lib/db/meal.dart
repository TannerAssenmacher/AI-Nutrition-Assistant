import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'meal.g.dart';

@JsonSerializable(explicitToJson: true)
class Meal {
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;
  final String userEmail;        // owner
  final DateTime date;           // day the meal belongs to
  final String name;             // e.g. Breakfast, Lunch, Snack
  final List<String> foodIds;    // references to Food docs (optional)
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final double fiber;

  Meal({
    String? id,
    required this.userEmail,
    required this.date,
    required this.name,
    required this.foodIds,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.fiber,
  }) : id = id ?? const Uuid().v4();

  factory Meal.fromJson(Map<String, dynamic> json, String id) {
    final m = _$MealFromJson(json);
    return Meal(
      id: id,
      userEmail: m.userEmail,
      date: m.date,
      name: m.name,
      foodIds: m.foodIds,
      calories: m.calories,
      protein: m.protein,
      fat: m.fat,
      carbs: m.carbs,
      fiber: m.fiber,
    );
  }

  Map<String, dynamic> toJson() => _$MealToJson(this);
}
