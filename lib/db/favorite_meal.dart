import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteMealItem {
  final String name;
  final double grams;
  final double caloriesPerGram;
  final double proteinPerGram;
  final double carbsPerGram;
  final double fatPerGram;
  final String? imageUrl;
  final String? sourceId;
  final String? servingLabel;
  final double? servings;

  const FavoriteMealItem({
    required this.name,
    required this.grams,
    required this.caloriesPerGram,
    required this.proteinPerGram,
    required this.carbsPerGram,
    required this.fatPerGram,
    this.imageUrl,
    this.sourceId,
    this.servingLabel,
    this.servings,
  });

  factory FavoriteMealItem.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return FavoriteMealItem(
      name: (json['name'] ?? '').toString(),
      grams: asDouble(json['grams']),
      caloriesPerGram: asDouble(json['caloriesPerGram']),
      proteinPerGram: asDouble(json['proteinPerGram']),
      carbsPerGram: asDouble(json['carbsPerGram']),
      fatPerGram: asDouble(json['fatPerGram']),
      imageUrl: json['imageUrl']?.toString(),
      sourceId: json['sourceId']?.toString(),
      servingLabel: json['servingLabel']?.toString(),
      servings: json['servings'] is num
          ? (json['servings'] as num).toDouble()
          : double.tryParse((json['servings'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'grams': grams,
      'caloriesPerGram': caloriesPerGram,
      'proteinPerGram': proteinPerGram,
      'carbsPerGram': carbsPerGram,
      'fatPerGram': fatPerGram,
      'imageUrl': imageUrl,
      'sourceId': sourceId,
      'servingLabel': servingLabel,
      'servings': servings,
    };
  }
}

class FavoriteMeal {
  final String? id;
  final String name;
  final String mealType;
  final List<FavoriteMealItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FavoriteMeal({
    this.id,
    required this.name,
    required this.mealType,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FavoriteMeal.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final itemsRaw = json['items'];
    final parsedItems = <FavoriteMealItem>[];
    if (itemsRaw is List) {
      for (final entry in itemsRaw) {
        if (entry is Map) {
          parsedItems.add(
            FavoriteMealItem.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }

    return FavoriteMeal(
      id: id,
      name: (json['name'] ?? '').toString(),
      mealType: (json['mealType'] ?? 'snack').toString(),
      items: parsedItems,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  FavoriteMeal copyWith({
    String? name,
    String? mealType,
    List<FavoriteMealItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FavoriteMeal(
      id: id,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mealType': mealType,
      'items': items.map((item) => item.toJson()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
