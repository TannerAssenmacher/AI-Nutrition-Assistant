import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'food.g.dart';

// -----------------------------------------------------------------------------
// FOOD ITEM
// -----------------------------------------------------------------------------

@JsonSerializable()
class FoodItem {
  final String id;
    @JsonKey(defaultValue: "none")
  final String name;
    @JsonKey(defaultValue: 0.0)
  final double mass_g;
    @JsonKey(defaultValue: 0.0)
  final double calories_g;
    @JsonKey(defaultValue: 0.0)
  final double protein_g;
    @JsonKey(defaultValue: 0.0)
  final double carbs_g;
    @JsonKey(defaultValue: 0.0)
  final double fat;
    @JsonKey(defaultValue: "NA")
  final String mealType; // breakfast/lunch/etc.
    @JsonKey(defaultValue: "")
  final String imageUrl; // URL to the meal photo

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
    this.imageUrl = "",
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
