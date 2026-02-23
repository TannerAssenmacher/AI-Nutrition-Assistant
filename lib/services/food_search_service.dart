import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FoodServingOption {
  final String id;
  final String description;
  final double grams;
  final double caloriesPerGram;
  final double proteinPerGram;
  final double carbsPerGram;
  final double fatPerGram;
  final bool isDefault;

  const FoodServingOption({
    required this.id,
    required this.description,
    required this.grams,
    required this.caloriesPerGram,
    required this.proteinPerGram,
    required this.carbsPerGram,
    required this.fatPerGram,
    required this.isDefault,
  });
}

class FoodSearchResult {
  final String id;
  final String name;
  final double caloriesPerGram;
  final double proteinPerGram;
  final double carbsPerGram;
  final double fatPerGram;
  final double servingGrams;
  final String source;
  final String? barcode;
  final String? brand;
  final String? imageUrl;
  final List<FoodServingOption> servingOptions;

  const FoodSearchResult({
    required this.id,
    required this.name,
    required this.caloriesPerGram,
    required this.proteinPerGram,
    required this.carbsPerGram,
    required this.fatPerGram,
    required this.servingGrams,
    required this.source,
    this.barcode,
    this.brand,
    this.imageUrl,
    this.servingOptions = const [],
  });

  String get sourceLabel => switch (source) {
    'fatsecret' => 'FatSecret',
    _ => 'FatSecret',
  };

  FoodServingOption get defaultServingOption {
    if (servingOptions.isEmpty) {
      return FoodServingOption(
        id: 'default',
        description: 'Default serving',
        grams: servingGrams,
        caloriesPerGram: caloriesPerGram,
        proteinPerGram: proteinPerGram,
        carbsPerGram: carbsPerGram,
        fatPerGram: fatPerGram,
        isDefault: true,
      );
    }

    return servingOptions.firstWhere(
      (option) => option.isDefault,
      orElse: () => servingOptions.first,
    );
  }
}

class FoodSearchService {
  FoodSearchService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;
  static final RegExp _nonDigitsRegex = RegExp(r'\D');

  static String normalizeBarcodeInput(String barcode) {
    return barcode.replaceAll(_nonDigitsRegex, '');
  }

  static String canonicalBarcode(String barcode) {
    final normalized = normalizeBarcodeInput(barcode);
    if (normalized.length == 13 && normalized.startsWith('0')) {
      return normalized.substring(1);
    }
    return normalized;
  }

  Future<List<String>> autocompleteFoods(
    String expression, {
    int maxResults = 5,
  }) async {
    final trimmed = expression.trim();
    if (trimmed.length < 2) return const [];

    await _ensureAuthenticatedUser();
    final callable = _functions.httpsCallable('autocompleteFoods');
    final result = await callable.call({
      'expression': trimmed,
      'maxResults': maxResults,
    });

    final rawData = result.data;
    if (rawData is! Map) {
      throw StateError(
        'Unexpected Cloud Function response type: ${rawData.runtimeType}',
      );
    }

    final data = Map<String, dynamic>.from(rawData);
    final suggestionsRaw = data['suggestions'];
    final suggestions = suggestionsRaw is List ? suggestionsRaw : const [];
    final seen = <String>{};
    final parsed = <String>[];

    for (final item in suggestions) {
      final suggestion = item.toString().trim();
      if (suggestion.isEmpty) continue;
      final key = suggestion.toLowerCase();
      if (!seen.add(key)) continue;
      parsed.add(suggestion);
      if (parsed.length >= maxResults) {
        break;
      }
    }
    return parsed;
  }

  Future<List<FoodSearchResult>> searchFoods(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      await _ensureAuthenticatedUser();
      final callable = _functions.httpsCallable('searchFoods');
      final result = await callable.call({'query': trimmed});

      final rawData = result.data;
      if (rawData is! Map) {
        throw StateError(
          'Unexpected Cloud Function response type: ${rawData.runtimeType}',
        );
      }

      final data = Map<String, dynamic>.from(rawData);
      final itemsRaw = data['results'];
      final items = itemsRaw is List ? itemsRaw : const <dynamic>[];

      return items.map((item) {
        if (item is! Map) {
          throw StateError('Unexpected result item type: ${item.runtimeType}');
        }

        final map = Map<String, dynamic>.from(item);
        return _parseResult(map);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<FoodSearchResult?> lookupFoodByBarcode(String barcode) async {
    final normalized = normalizeBarcodeInput(barcode);
    if (normalized.length < 8) {
      throw Exception('Please scan a valid barcode.');
    }

    await _ensureAuthenticatedUser();

    final callable = _functions.httpsCallable('lookupFoodByBarcode');
    final response = await callable.call({'barcode': normalized});
    final rawData = response.data;
    if (rawData is! Map) {
      throw StateError(
        'Unexpected Cloud Function response type: ${rawData.runtimeType}',
      );
    }

    final data = Map<String, dynamic>.from(rawData);
    final resultRaw = data['result'];
    if (resultRaw == null) {
      return null;
    }
    if (resultRaw is! Map) {
      throw StateError(
        'Unexpected barcode result type: ${resultRaw.runtimeType}',
      );
    }

    final result = _parseResult(Map<String, dynamic>.from(resultRaw));
    return result;
  }

  Future<void> _ensureAuthenticatedUser() async {
    final auth = FirebaseAuth.instance;
    var currentUser = auth.currentUser;
    if (currentUser == null) {
      try {
        final credential = await auth.signInAnonymously();
        currentUser = credential.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'admin-restricted-operation') {
          throw StateError('Please sign in. Anonymous auth is disabled.');
        }
        rethrow;
      }
    }
    if (currentUser == null) {
      throw Exception('User must be signed in to search foods');
    }
    await currentUser.getIdToken(true);
  }

  FoodSearchResult _parseResult(Map<String, dynamic> map) {
    final parsedBarcode = canonicalBarcode((map['barcode'] ?? '').toString());
    final imageUrl = _toNullableHttpUrl((map['imageUrl'] ?? '').toString());

    return FoodSearchResult(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      caloriesPerGram: (map['caloriesPerGram'] as num?)?.toDouble() ?? 0,
      proteinPerGram: (map['proteinPerGram'] as num?)?.toDouble() ?? 0,
      carbsPerGram: (map['carbsPerGram'] as num?)?.toDouble() ?? 0,
      fatPerGram: (map['fatPerGram'] as num?)?.toDouble() ?? 0,
      servingGrams: (map['servingGrams'] as num?)?.toDouble() ?? 100,
      source: (map['source'] ?? '').toString(),
      barcode: parsedBarcode.isEmpty ? null : parsedBarcode,
      brand: (map['brand'] ?? '').toString().isEmpty
          ? null
          : (map['brand'] ?? '').toString(),
      imageUrl: imageUrl,
      servingOptions: _parseServingOptions(map),
    );
  }

  List<FoodServingOption> _parseServingOptions(Map<String, dynamic> map) {
    final raw = map['servingOptions'];
    final items = raw is List ? raw : const [];
    final parsed = <FoodServingOption>[];

    for (final item in items) {
      if (item is! Map) continue;
      final option = _parseServingOption(Map<String, dynamic>.from(item));
      if (option == null) continue;
      parsed.add(option);
    }

    if (parsed.isNotEmpty) {
      final prioritized = [
        ...parsed.where((option) => option.isDefault),
        ...parsed.where((option) => !option.isDefault),
      ];
      final seen = <String>{};
      final deduped = <FoodServingOption>[];
      for (final option in prioritized) {
        final key =
            '${option.description.trim().toLowerCase()}|${option.grams.toStringAsFixed(2)}';
        if (!seen.add(key)) continue;
        deduped.add(option);
      }
      if (deduped.isEmpty) {
        return [];
      }
      final hasDefault = deduped.any((option) => option.isDefault);
      if (hasDefault) return deduped;
      return [deduped.first.copyWith(isDefault: true), ...deduped.skip(1)];
    }

    final fallbackGrams = (map['servingGrams'] as num?)?.toDouble() ?? 100;
    return [
      FoodServingOption(
        id: 'default',
        description: 'Default serving',
        grams: fallbackGrams > 0 ? fallbackGrams : 100,
        caloriesPerGram: (map['caloriesPerGram'] as num?)?.toDouble() ?? 0,
        proteinPerGram: (map['proteinPerGram'] as num?)?.toDouble() ?? 0,
        carbsPerGram: (map['carbsPerGram'] as num?)?.toDouble() ?? 0,
        fatPerGram: (map['fatPerGram'] as num?)?.toDouble() ?? 0,
        isDefault: true,
      ),
    ];
  }

  FoodServingOption? _parseServingOption(Map<String, dynamic> map) {
    final grams = (map['grams'] as num?)?.toDouble();
    if (grams == null || grams <= 0) {
      return null;
    }

    final id = (map['id'] ?? '').toString().trim();
    final description = (map['description'] ?? '').toString().trim();
    return FoodServingOption(
      id: id.isEmpty ? description : id,
      description: description.isEmpty ? 'Serving' : description,
      grams: grams,
      caloriesPerGram: (map['caloriesPerGram'] as num?)?.toDouble() ?? 0,
      proteinPerGram: (map['proteinPerGram'] as num?)?.toDouble() ?? 0,
      carbsPerGram: (map['carbsPerGram'] as num?)?.toDouble() ?? 0,
      fatPerGram: (map['fatPerGram'] as num?)?.toDouble() ?? 0,
      isDefault: map['isDefault'] == true,
    );
  }

  String? _toNullableHttpUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return trimmed;
  }
}

extension on FoodServingOption {
  FoodServingOption copyWith({
    String? id,
    String? description,
    double? grams,
    double? caloriesPerGram,
    double? proteinPerGram,
    double? carbsPerGram,
    double? fatPerGram,
    bool? isDefault,
  }) {
    return FoodServingOption(
      id: id ?? this.id,
      description: description ?? this.description,
      grams: grams ?? this.grams,
      caloriesPerGram: caloriesPerGram ?? this.caloriesPerGram,
      proteinPerGram: proteinPerGram ?? this.proteinPerGram,
      carbsPerGram: carbsPerGram ?? this.carbsPerGram,
      fatPerGram: fatPerGram ?? this.fatPerGram,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
