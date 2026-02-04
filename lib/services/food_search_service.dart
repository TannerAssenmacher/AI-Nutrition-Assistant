import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FoodSearchResult {
  final String id;
  final String name;
  final double caloriesPerGram;
  final double proteinPerGram;
  final double carbsPerGram;
  final double fatPerGram;
  final double servingGrams;
  final String source;

  const FoodSearchResult({
    required this.id,
    required this.name,
    required this.caloriesPerGram,
    required this.proteinPerGram,
    required this.carbsPerGram,
    required this.fatPerGram,
    required this.servingGrams,
    required this.source,
  });

  String get sourceLabel =>
      source == 'usda' ? 'USDA FoodData Central' : 'Spoonacular';
}

class FoodSearchService {
  FoodSearchService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<List<FoodSearchResult>> searchFoods(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    print('🔍 FoodSearchService: Starting search for: "$trimmed"');

    // Verify user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    print('🔍 FoodSearchService: Current user: ${currentUser?.uid}');

    if (currentUser == null) {
      print('❌ FoodSearchService: No user authenticated');
      throw Exception('User must be signed in to search foods');
    }

    try {
      // Force token refresh to ensure it's valid
      print('🔍 FoodSearchService: Refreshing auth token...');
      await currentUser.getIdToken(true);
      print('✅ FoodSearchService: Token refreshed successfully');

      print('🔍 FoodSearchService: Calling Cloud Function...');
      final callable = _functions.httpsCallable('searchFoods');
      final result = await callable.call({'query': trimmed});
      print('✅ FoodSearchService: Cloud Function returned successfully');

      final rawData = result.data;
      if (rawData is! Map) {
        throw StateError(
          'Unexpected Cloud Function response type: ${rawData.runtimeType}',
        );
      }

      final data = Map<String, dynamic>.from(rawData);
      final itemsRaw = data['results'];
      final items = itemsRaw is List ? itemsRaw : const <dynamic>[];
      print('✅ FoodSearchService: Found ${items.length} results');

      return items.map((item) {
        if (item is! Map) {
          throw StateError('Unexpected result item type: ${item.runtimeType}');
        }

        final map = Map<String, dynamic>.from(item);
        return FoodSearchResult(
          id: (map['id'] ?? '').toString(),
          name: (map['name'] ?? '').toString(),
          caloriesPerGram: (map['caloriesPerGram'] as num?)?.toDouble() ?? 0,
          proteinPerGram: (map['proteinPerGram'] as num?)?.toDouble() ?? 0,
          carbsPerGram: (map['carbsPerGram'] as num?)?.toDouble() ?? 0,
          fatPerGram: (map['fatPerGram'] as num?)?.toDouble() ?? 0,
          servingGrams: (map['servingGrams'] as num?)?.toDouble() ?? 100,
          source: (map['source'] ?? '').toString(),
        );
      }).toList();
    } catch (e, stackTrace) {
      print('❌ FoodSearchService: Search failed for query: "$trimmed"');
      print('❌ FoodSearchService: Error occurred: $e');
      print('❌ FoodSearchService: Stack trace: $stackTrace');
      rethrow;
    }
  }
}
