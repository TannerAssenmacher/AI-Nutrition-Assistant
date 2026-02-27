import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/food_search_service.dart';
import '../services/food_image_service.dart';
import '../theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import '../db/food.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:nutrition_assistant/widgets/fatsecret_attribution.dart';
import '../widgets/top_bar.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  final bool isInPageView;

  const FoodSearchScreen({super.key, this.isInPageView = false});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _searchController = TextEditingController();
  final _searchService = FoodSearchService();
  Timer? _debounce;
  bool _isLoading = false;
  String? _error;
  int _searchRequestId = 0;
  List<String> _suggestions = const [];
  List<FoodSearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(
    String query, {
    bool includeSuggestions = true,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _suggestions = const [];
        _results = const [];
        _error = null;
        _isLoading = false;
      });
      return;
    }

    final requestId = ++_searchRequestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resultsFuture = _searchService.searchFoods(trimmed);
      Future<List<String>>? suggestionsFuture;
      if (includeSuggestions) {
        suggestionsFuture = _searchService.autocompleteFoods(
          trimmed,
          maxResults: 5,
        );
      }
      final results = await resultsFuture;

      List<String> suggestions = const [];
      if (suggestionsFuture != null) {
        try {
          suggestions = await suggestionsFuture;
        } catch (_) {
          suggestions = const [];
        }
      }

      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _suggestions = includeSuggestions ? suggestions : const [];
        _results = results;
        _isLoading = false;
        _error = results.isEmpty ? 'No results found from FatSecret.' : null;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoading = false;
        _error = 'Search failed: $e';
      });
    }
  }

  void _applySuggestion(String suggestion) {
    _debounce?.cancel();
    _searchController.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
    });
    _runSearch(suggestion, includeSuggestions: false);
  }

  Future<void> _addSearchResult(FoodSearchResult result) async {
    final authUser = ref.read(authServiceProvider);
    final userId = authUser?.uid;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to add foods.')),
        );
      }
      return;
    }

    final rootContext = context;
    final trimmedResultImageUrl = (result.imageUrl ?? '').trim();
    final hasExplicitServingOptions = result.servingOptions.isNotEmpty;
    List<FoodServingOption> normalizeServingOptions(
      List<FoodServingOption> options,
    ) {
      final prioritized = [
        ...options.where((option) => option.isDefault),
        ...options.where((option) => !option.isDefault),
      ];
      final seen = <String>{};
      final normalized = <FoodServingOption>[];
      for (final option in prioritized) {
        final key =
            '${option.description.trim().toLowerCase()}|${option.grams.toStringAsFixed(2)}';
        if (!seen.add(key)) continue;
        normalized.add(option);
      }
      return normalized.isEmpty ? options : normalized;
    }

    String servingLabel(FoodServingOption option) {
      final gramsText = '${option.grams.toStringAsFixed(0)} g';
      final description = option.description.trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (description.isEmpty) {
        return gramsText;
      }
      final normalized = description.toLowerCase();
      if (normalized == 'default serving') {
        return gramsText;
      }
      final duplicatePattern = RegExp(
        r'^([\d.]+\s*(?:g|gram|grams|ml|oz|ounce|ounces))\s*\(\s*\1\s*\)$',
        caseSensitive: false,
      );
      final duplicateMatch = duplicatePattern.firstMatch(description);
      if (duplicateMatch != null) {
        return duplicateMatch.group(1)!;
      }
      if (RegExp(
        r'^\s*[\d.]+\s*(g|gram|grams|ml|oz|ounce|ounces)\s*$',
      ).hasMatch(normalized)) {
        return description;
      }
      return '$description ($gramsText)';
    }

    final availableServings = normalizeServingOptions(
      hasExplicitServingOptions
          ? result.servingOptions
          : [result.defaultServingOption],
    );
    FoodServingOption selectedServing = availableServings.firstWhere(
      (option) => option.isDefault,
      orElse: () => availableServings.first,
    );
    int quantity = 1;
    final gramsController = TextEditingController(
      text: selectedServing.grams.toStringAsFixed(0),
    );
    String mealType = 'snack';
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: rootContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedGrams = double.tryParse(gramsController.text.trim());
            final currentGrams = hasExplicitServingOptions
                ? selectedServing.grams * quantity
                : ((parsedGrams != null && parsedGrams > 0)
                      ? parsedGrams
                      : selectedServing.grams);
            final calories = (selectedServing.caloriesPerGram * currentGrams)
                .round();
            final protein = (selectedServing.proteinPerGram * currentGrams)
                .toStringAsFixed(1);
            final carbs = (selectedServing.carbsPerGram * currentGrams)
                .toStringAsFixed(1);
            final fat = (selectedServing.fatPerGram * currentGrams)
                .toStringAsFixed(1);

            final dialogWidth =
                (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 420.0)
                    .toDouble();

            return AlertDialog(
              title: Text('Add ${result.name}'),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trimmedResultImageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            trimmedResultImageUrl,
                            width: dialogWidth,
                            height: 140,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: dialogWidth,
                                height: 140,
                                color: AppColors.surface,
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              width: dialogWidth,
                              height: 140,
                              color: AppColors.surface,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color: AppColors.textHint,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Image unavailable',
                                    style: TextStyle(
                                      color: AppColors.textHint,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: mealType,
                        decoration: const InputDecoration(
                          labelText: 'Meal type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'breakfast',
                            child: Text('Breakfast'),
                          ),
                          DropdownMenuItem(
                            value: 'lunch',
                            child: Text('Lunch'),
                          ),
                          DropdownMenuItem(
                            value: 'dinner',
                            child: Text('Dinner'),
                          ),
                          DropdownMenuItem(
                            value: 'snack',
                            child: Text('Snack'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              mealType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      if (hasExplicitServingOptions) ...[
                        if (availableServings.length > 1) ...[
                          DropdownButtonFormField<FoodServingOption>(
                            initialValue: selectedServing,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Serving size',
                            ),
                            selectedItemBuilder: (context) => availableServings
                                .map(
                                  (option) => Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      servingLabel(option),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                )
                                .toList(),
                            items: availableServings
                                .map(
                                  (option) =>
                                      DropdownMenuItem<FoodServingOption>(
                                        value: option,
                                        child: Text(
                                          servingLabel(option),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedServing = value;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        DropdownButtonFormField<int>(
                          initialValue: quantity,
                          decoration: const InputDecoration(
                            labelText: 'Servings',
                          ),
                          items: List.generate(
                            10,
                            (index) => DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              quantity = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Total: ${(selectedServing.grams * quantity).toStringAsFixed(0)} g',
                            style: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ] else
                        TextField(
                          controller: gramsController,
                          decoration: InputDecoration(
                            labelText: 'Weight (g)',
                            suffixIcon: IconButton(
                              tooltip: 'Done',
                              icon: const Icon(Icons.check),
                              onPressed: () =>
                                  FocusManager.instance.primaryFocus?.unfocus(),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          onChanged: (_) {
                            setDialogState(() {});
                          },
                        ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Nutrition Info',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _NutritionIndicator(
                                    label: 'Calories',
                                    value: '$calories',
                                    unit: 'Cal',
                                    color: AppColors.error,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _NutritionIndicator(
                                    label: 'Protein',
                                    value: protein,
                                    unit: 'g',
                                    color: AppColors.protein,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _NutritionIndicator(
                                    label: 'Carbs',
                                    value: carbs,
                                    unit: 'g',
                                    color: AppColors.carbs,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _NutritionIndicator(
                                    label: 'Fat',
                                    value: fat,
                                    unit: 'g',
                                    color: AppColors.fat,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                          );
                          if (pickedDate != null) {
                            setDialogState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          selectedDate.day == DateTime.now().day &&
                                  selectedDate.month == DateTime.now().month &&
                                  selectedDate.year == DateTime.now().year
                              ? 'Today'
                              : '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    await Future<void>.delayed(Duration.zero);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final grams = hasExplicitServingOptions
                        ? selectedServing.grams * quantity
                        : double.tryParse(gramsController.text.trim());
                    if (grams == null || grams <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid grams value.'),
                        ),
                      );
                      return;
                    }

                    final consumedAt = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      DateTime.now().hour,
                      DateTime.now().minute,
                    );
                    final imageUrlForLog =
                        trimmedResultImageUrl.isNotEmpty &&
                            FoodImageService.shouldShowImageForEntry(consumedAt)
                        ? trimmedResultImageUrl
                        : null;

                    final item = FoodItem(
                      id: 'search-${DateTime.now().microsecondsSinceEpoch}',
                      name: result.name,
                      mass_g: grams,
                      calories_g: selectedServing.caloriesPerGram,
                      protein_g: selectedServing.proteinPerGram,
                      carbs_g: selectedServing.carbsPerGram,
                      fat: selectedServing.fatPerGram,
                      mealType: mealType,
                      imageUrl: imageUrlForLog,
                      consumedAt: consumedAt,
                    );

                    try {
                      await ref
                          .read(firestoreFoodLogProvider(userId).notifier)
                          .addFood(userId, item);
                      FocusManager.instance.primaryFocus?.unfocus();
                      await Future<void>.delayed(Duration.zero);
                      if (!mounted ||
                          !rootContext.mounted ||
                          !dialogContext.mounted) {
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(rootContext);
                      Navigator.pop(dialogContext);
                      final dateText =
                          selectedDate.day == DateTime.now().day &&
                              selectedDate.month == DateTime.now().month &&
                              selectedDate.year == DateTime.now().year
                          ? 'today\'s log'
                          : '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}';
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Added "${result.name}" to $dateText'),
                        ),
                      );
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Failed to add: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    gramsController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    final userProfileAsync = userId != null
        ? ref.watch(firestoreUserProfileProvider(userId))
        : const AsyncValue.loading();
    final name = userProfileAsync.valueOrNull?.firstname ?? 'User';

    final bodyContent = SafeArea(
      top: false,
      child: Column(
        children: [
          // Header
          top_bar(),
          // Search bar
          Padding(
            padding: const EdgeInsets.only(
              top: 20.0,
            ), // Increase this number to push it further down
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for Foods using FatSecret ... ',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _runSearch('');
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.accentBrown.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.accentBrown.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.accentBrown,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                  _onSearchQueryChanged(value);
                },
                onSubmitted: (value) {
                  _debounce?.cancel();
                  FocusScope.of(context).unfocus();
                  _runSearch(value, includeSuggestions: false);
                },
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _suggestions
                      .map(
                        (suggestion) => ActionChip(
                          label: Text(
                            suggestion,
                            style: const TextStyle(fontSize: 12),
                          ),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onPressed: () => _applySuggestion(suggestion),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          // Error message
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppColors.warning, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          // Results
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: AppColors.divider,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'What\'s on the menu today, $name?'
                              : 'No Results Found',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textHint,
                          ),
                        ),
                        if (_searchController.text.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try: "Chobani", "Chicken", or any fast food!',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.statusNone,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return _FoodSearchResultTile(
                        result: result,
                        onAdd: () => _addSearchResult(result),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (widget.isInPageView == true) {
      return bodyContent;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: bodyContent,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.only(top: 2),
            child: const FatSecretAttribution(),
          ),
          NavBar(
            currentIndex: navIndexSearch,
            onTap: (index) => handleNavTap(context, index),
          ),
        ],
      ),
    );
  }
}

class _FoodSearchResultTile extends StatelessWidget {
  const _FoodSearchResultTile({required this.result, required this.onAdd});

  final FoodSearchResult result;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final serving = result.defaultServingOption;
    final calories = (serving.caloriesPerGram * serving.grams).round();
    final imageUrl = (result.imageUrl ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentBrown.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.restaurant,
                    color: AppColors.brand,
                    size: 24,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.restaurant, color: AppColors.brand, size: 24),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${serving.grams.toStringAsFixed(0)} g · $calories Cal',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    _MacroChip(
                      label: 'P',
                      value: (serving.proteinPerGram * serving.grams)
                          .toStringAsFixed(1),
                      color: AppColors.protein,
                    ),
                    _MacroChip(
                      label: 'C',
                      value: (serving.carbsPerGram * serving.grams)
                          .toStringAsFixed(1),
                      color: AppColors.carbs,
                    ),
                    _MacroChip(
                      label: 'F',
                      value: (serving.fatPerGram * serving.grams)
                          .toStringAsFixed(1),
                      color: AppColors.fat,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Add', semanticsLabel: 'Add ${result.name}'),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  static String _fullLabel(String abbr) {
    switch (abbr) {
      case 'P':
        return 'Protein';
      case 'C':
        return 'Carbs';
      case 'F':
        return 'Fat';
      default:
        return abbr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${_fullLabel(label)} $value grams',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$label $value g',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _NutritionIndicator extends StatelessWidget {
  const _NutritionIndicator({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$value$unit',
            style: TextStyle(
              fontSize: 15,
              color: color,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
