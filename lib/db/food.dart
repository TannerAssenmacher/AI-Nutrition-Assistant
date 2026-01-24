import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'food.g.dart';

// -----------------------------------------------------------------------------
// FOOD ITEM
// -----------------------------------------------------------------------------

@JsonSerializable()
class FoodItem {
  final String id;
  final String name;
  final double mass_g;
  final double calories_g;
  final double protein_g;
  final double carbs_g;
  final double fat;
  final String mealType; // breakfast/lunch/etc.

  @JsonKey(fromJson: AppUser.dateFromJson, toJson: AppUser.dateToJson)
  final DateTime consumedAt;

  FoodItem({
    required this.id,
    required this.name,
    required this.mass_g,
    required this.calories_g,
    required this.protein_g,
    required this.carbs_g,
    required this.fat,
    required this.mealType,
    required this.consumedAt,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) =>
      _$FoodItemFromJson(json);
  Map<String, dynamic> toJson() => _$FoodItemToJson(this);
}

// For later implementation of micronutrients:

// @JsonSerializable()
// class Micronutrients {
//   final double calciumMg;
//   final double ironMg;
//   final double vitaminAMcg;
//   final double vitaminCMg;
//
//   Micronutrients({
//     required this.calciumMg,
//     required this.ironMg,
//     required this.vitaminAMcg,
//     required this.vitaminCMg,
//   });
//
//   factory Micronutrients.fromJson(Map<String, dynamic> json) =>
//       _$MicronutrientsFromJson(json);
//
//   Map<String, dynamic> toJson() => _$MicronutrientsToJson(this);
// }
