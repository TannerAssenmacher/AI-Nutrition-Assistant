import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'planned_food.g.dart';

//class is meant for future meals that user wants to cook from generated recipes
@JsonSerializable()
class PlannedFood {
  final String recipeId; //db id that will be pulled for data in frontend

  @JsonKey(fromJson: AppUser.dateFromJson, toJson: AppUser.dateToJson)
  final DateTime date;

  final String mealType; // breakfast/lunch/dinner/snack

  PlannedFood({
    required this.recipeId,
    required this.date, //what day
    required this.mealType,
  });

  factory PlannedFood.fromJson(Map<String, dynamic> json) =>
      _$PlannedFoodFromJson(json);
  Map<String, dynamic> toJson() => _$PlannedFoodToJson(this);
}




