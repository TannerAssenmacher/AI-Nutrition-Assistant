class Food {
  final String id;
  final String name;
  final String category;
  final int caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final Micronutrients micronutrients;
  final String source;

  Food({
    required this.id,
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.micronutrients,
    required this.source,
  });

  factory Food.fromJson(Map<String, dynamic> json, String id) {
    return Food(
      id: id,
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      caloriesPer100g: json['calories_per_100g'] ?? 0,
      proteinPer100g: (json['protein_per_100g'] ?? 0).toDouble(),
      carbsPer100g: (json['carbs_per_100g'] ?? 0).toDouble(),
      fatPer100g: (json['fat_per_100g'] ?? 0).toDouble(),
      fiberPer100g: (json['fiber_per_100g'] ?? 0).toDouble(),
      micronutrients: Micronutrients.fromJson(json['micronutrients'] ?? {}),
      source: json['source'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'calories_per_100g': caloriesPer100g,
      'protein_per_100g': proteinPer100g,
      'carbs_per_100g': carbsPer100g,
      'fat_per_100g': fatPer100g,
      'fiber_per_100g': fiberPer100g,
      'micronutrients': micronutrients.toJson(),
      'source': source,
    };
  }
}

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

  factory Micronutrients.fromJson(Map<String, dynamic> json) {
    return Micronutrients(
      calciumMg: (json['calcium_mg'] ?? 0).toDouble(),
      ironMg: (json['iron_mg'] ?? 0).toDouble(),
      vitaminAMcg: (json['vitamin_a_mcg'] ?? 0).toDouble(),
      vitaminCMg: (json['vitamin_c_mg'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calcium_mg': calciumMg,
      'iron_mg': ironMg,
      'vitamin_a_mcg': vitaminAMcg,
      'vitamin_c_mg': vitaminCMg,
    };
  }
}
