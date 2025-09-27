// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$totalDailyCaloriesHash() =>
    r'a62c94e9ad1b427772f7e83d55442a8d75eb6d77';

/// See also [totalDailyCalories].
@ProviderFor(totalDailyCalories)
final totalDailyCaloriesProvider = AutoDisposeProvider<int>.internal(
  totalDailyCalories,
  name: r'totalDailyCaloriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalDailyCaloriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalDailyCaloriesRef = AutoDisposeProviderRef<int>;
String _$totalDailyMacrosHash() => r'8c3ae2317c199d65a965ca064b0ee44e5f7b7ef8';

/// See also [totalDailyMacros].
@ProviderFor(totalDailyMacros)
final totalDailyMacrosProvider =
    AutoDisposeProvider<Map<String, double>>.internal(
  totalDailyMacros,
  name: r'totalDailyMacrosProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalDailyMacrosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalDailyMacrosRef = AutoDisposeProviderRef<Map<String, double>>;
String _$foodSuggestionsHash() => r'bbcbbd66fdfcae4aa73880ccdd0ad6a426c53509';

/// See also [foodSuggestions].
@ProviderFor(foodSuggestions)
final foodSuggestionsProvider =
    AutoDisposeFutureProvider<List<String>>.internal(
  foodSuggestions,
  name: r'foodSuggestionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$foodSuggestionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FoodSuggestionsRef = AutoDisposeFutureProviderRef<List<String>>;
String _$foodLogHash() => r'9cfa3c586ad24795d6235dcfd23ac03215302406';

/// See also [FoodLog].
@ProviderFor(FoodLog)
final foodLogProvider =
    AutoDisposeNotifierProvider<FoodLog, List<FoodItem>>.internal(
  FoodLog.new,
  name: r'foodLogProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$foodLogHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FoodLog = AutoDisposeNotifier<List<FoodItem>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
