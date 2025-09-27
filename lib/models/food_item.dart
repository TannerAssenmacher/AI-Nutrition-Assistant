class FoodItem {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime consumedAt;

  const FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.consumedAt,
  });

  FoodItem copyWith({
    String? id,
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    DateTime? consumedAt,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      consumedAt: consumedAt ?? this.consumedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoodItem &&
        other.id == id &&
        other.name == name &&
        other.calories == calories &&
        other.protein == protein &&
        other.carbs == carbs &&
        other.fat == fat &&
        other.consumedAt == consumedAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, calories, protein, carbs, fat, consumedAt);
  }

  @override
  String toString() {
    return 'FoodItem(id: $id, name: $name, calories: $calories, protein: $protein, carbs: $carbs, fat: $fat, consumedAt: $consumedAt)';
  }
}