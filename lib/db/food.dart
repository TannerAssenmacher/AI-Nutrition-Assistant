
import 'package:json_annotation/json_annotation.dart';

part 'food.g.dart';

@JsonSerializable(explicitToJson: true)
class Food {
  @JsonKey(includeFromJson: false, includeToJson: false)
  late String id; // unique identifier
  final String name;
  final String category; // Fruit,Vegi,Protein,Dairy,Grain,Other
  final int caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final Micronutrients micronutrients;
  final String source; // source of data
  final DateTime consumedAt; // time eaten by user
  final double servingSize;
  final int servingCount;

  Food({
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.micronutrients,
    required this.source,
    required this.consumedAt,
    this.servingSize = 1.0,
    this.servingCount = 1,
  });

  factory Food.fromJson(Map<String, dynamic> json, String id) {
    final food = _$FoodFromJson(json);
    food.id = id;
    return food;
  }

  Map<String, dynamic> toJson() => _$FoodToJson(this);

  Food copyWith({
    String? id,
    String? name,
    String? category,
    int? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? fiberPer100g,
    Micronutrients? micronutrients,
    String? source,
    DateTime? consumedAt,
    double? servingSize,
    int? servingCount,
  }) {
    final food = Food(
      name: name ?? this.name,
      category: category ?? this.category,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      fiberPer100g: fiberPer100g ?? this.fiberPer100g,
      micronutrients: micronutrients ?? this.micronutrients,
      source: source ?? this.source,
      consumedAt: consumedAt ?? this.consumedAt,
      servingSize: servingSize ?? this.servingSize,
      servingCount: servingCount ?? this.servingCount,
    );
    food.id = id ?? this.id;
    return food;
  }
}

@JsonSerializable()
class Micronutrients {
  final double calciumMg;
  final double ironMg;
  final double vitaminAMcg;
  final double vitaminCMg;

  Micronutrients({
    required this.calciumMg,
    required this.ironMg,
    required this.vitaminAMcg,
    required this.vitaminCMg,
  });

  factory Micronutrients.fromJson(Map<String, dynamic> json) =>
      _$MicronutrientsFromJson(json);

  Map<String, dynamic> toJson() => _$MicronutrientsToJson(this);
}
