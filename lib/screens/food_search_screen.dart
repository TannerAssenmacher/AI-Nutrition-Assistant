import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/food_search_service.dart';
import '../services/food_image_service.dart';
import '../theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import '../db/food.dart';
import '../db/favorite_meal.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:nutrition_assistant/widgets/fatsecret_attribution.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/add_to_favorites_sheet.dart';

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
        AppSnackBar.error(context, 'Please sign in to add foods.');
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

            final screenSize = MediaQuery.sizeOf(context);
            final dialogWidth = (screenSize.width - 24)
                .clamp(320.0, 560.0)
                .toDouble();
            final imageHeight = screenSize.height < 760 ? 86.0 : 102.0;

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: Text(
                'Add ${result.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (trimmedResultImageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          trimmedResultImageUrl,
                          width: dialogWidth,
                          height: imageHeight,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: dialogWidth,
                              height: imageHeight,
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
                            height: imageHeight,
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
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: mealType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Meal type',
                              isDense: true,
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
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                            ),
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
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              selectedDate.day == DateTime.now().day &&
                                      selectedDate.month ==
                                          DateTime.now().month &&
                                      selectedDate.year == DateTime.now().year
                                  ? 'Today'
                                  : '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hasExplicitServingOptions) ...[
                      if (availableServings.length > 1) ...[
                        DropdownButtonFormField<FoodServingOption>(
                          initialValue: selectedServing,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Serving size',
                            isDense: true,
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
                                (option) => DropdownMenuItem<FoodServingOption>(
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
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: quantity,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Servings',
                                isDense: true,
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
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Total: ${(selectedServing.grams * quantity).toStringAsFixed(0)} g',
                                style: TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      TextField(
                        controller: gramsController,
                        decoration: InputDecoration(
                          labelText: 'Weight (g)',
                          isDense: true,
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _NutritionIndicator(
                              label: 'Calories',
                              value: '$calories',
                              unit: 'Cal',
                              color: AppColors.homeBrand,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _NutritionIndicator(
                              label: 'Protein',
                              value: protein,
                              unit: 'g',
                              color: AppColors.homeProtein,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _NutritionIndicator(
                              label: 'Carbs',
                              value: carbs,
                              unit: 'g',
                              color: AppColors.homeCarbs,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _NutritionIndicator(
                              label: 'Fat',
                              value: fat,
                              unit: 'g',
                              color: AppColors.homeFat,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      AppSnackBar.error(
                        dialogContext,
                        'Please enter a valid grams value.',
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
                      FocusManager.instance.primaryFocus?.unfocus();
                      final dateText =
                          selectedDate.day == DateTime.now().day &&
                              selectedDate.month == DateTime.now().month &&
                              selectedDate.year == DateTime.now().year
                          ? 'today\'s log'
                          : '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}';
                      AppSnackBar.successFrom(
                        messenger,
                        'Added "${result.name}" to $dateText',
                      );
                    } catch (e) {
                      if (dialogContext.mounted) {
                        AppSnackBar.error(dialogContext, 'Failed to add: $e');
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

  Future<void> _addToFavorites(FoodSearchResult result) async {
    final authUser = ref.read(authServiceProvider);
    final userId = authUser?.uid;
    if (userId == null) {
      if (mounted) {
        AppSnackBar.error(context, 'Please sign in to add favorites.');
      }
      return;
    }

    final addedMealName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      showDragHandle: true,
      builder: (context) {
        return AddToFavoritesSheet(result: result, userId: userId);
      },
    );

    if (!mounted || addedMealName == null) return;
    AppSnackBar.success(context, 'Saved to favorites: $addedMealName.');
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    final favoriteMealsAsync = userId != null
        ? ref.watch(firestoreFavoriteMealsProvider(userId))
        : const AsyncValue.data(<FavoriteMeal>[]);
    final favoriteSourceIds = favoriteMealsAsync.maybeWhen(
      data: (meals) => meals
          .expand((meal) => meal.items)
          .map((item) => (item.sourceId ?? '').trim())
          .where((id) => id.isNotEmpty)
          .toSet(),
      orElse: () => <String>{},
    );
    final favoriteNames = favoriteMealsAsync.maybeWhen(
      data: (meals) => meals
          .expand((meal) => meal.items)
          .map((item) => item.name.trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet(),
      orElse: () => <String>{},
    );
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;
    final pageViewBottomNavHeight = 86.0 + bottomSafeInset;
    final pageViewKeyboardLift =
        (keyboardInset - pageViewBottomNavHeight).clamp(0.0, keyboardInset)
            as double;

    final bodyContent = AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: widget.isInPageView ? pageViewKeyboardLift : 0,
      ),
      child: SafeArea(
        top: widget.isInPageView,
        bottom: false,
        minimum: EdgeInsets.only(top: widget.isInPageView ? 8 : 0),
        child: Column(
          children: [
            if (_suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Results / Empty state
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 80,
                            color: AppColors.borderLight,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Search for foods to add to your meal log!'
                                : 'No Results Found',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textHint,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_searchController.text.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Powered by fatsecret',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.borderLight,
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
                        final normalizedResultId = result.id.trim();
                        final normalizedResultName = result.name
                            .trim()
                            .toLowerCase();
                        final isFavorited =
                            (normalizedResultId.isNotEmpty &&
                                favoriteSourceIds.contains(
                                  normalizedResultId,
                                )) ||
                            favoriteNames.contains(normalizedResultName);
                        return _FoodSearchResultTile(
                          result: result,
                          onAdd: () => _addSearchResult(result),
                          onFavorite: () => _addToFavorites(result),
                          isFavorited: isFavorited,
                        );
                      },
                    ),
            ),
            // FatSecret attribution + Search bar
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.only(top: 8),
              child: const FatSecretAttribution(),
            ),
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 4,
                bottom: keyboardInset > 0 ? 8 : 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search foods...',
                        hintStyle: TextStyle(color: AppColors.textHint),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textHint,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _runSearch('');
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.borderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: AppColors.brand,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.isInPageView == true) {
      return bodyContent;
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: bodyContent,
      bottomNavigationBar: keyboardInset > 0
          ? null
          : NavBar(
              currentIndex: navIndexSearch,
              onTap: (index) => handleNavTap(context, index),
            ),
    );
  }
}

class _FoodSearchResultTile extends StatelessWidget {
  const _FoodSearchResultTile({
    required this.result,
    required this.onAdd,
    required this.onFavorite,
    required this.isFavorited,
  });

  final FoodSearchResult result;
  final VoidCallback onAdd;
  final VoidCallback onFavorite;
  final bool isFavorited;

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
                      color: AppColors.homeProtein,
                    ),
                    _MacroChip(
                      label: 'C',
                      value: (serving.carbsPerGram * serving.grams)
                          .toStringAsFixed(1),
                      color: AppColors.homeCarbs,
                    ),
                    _MacroChip(
                      label: 'F',
                      value: (serving.fatPerGram * serving.grams)
                          .toStringAsFixed(1),
                      color: AppColors.homeFat,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onFavorite,
                tooltip: isFavorited
                    ? 'Already in favorites'
                    : 'Add to favorites',
                icon: Icon(
                  isFavorited ? Icons.favorite : Icons.favorite_border,
                ),
                color: AppColors.brand,
              ),
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Add', semanticsLabel: 'Add ${result.name}'),
              ),
            ],
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
            fontSize: 10.5,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value$unit',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
