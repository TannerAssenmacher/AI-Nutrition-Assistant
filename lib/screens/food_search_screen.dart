import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/food_search_service.dart';
import '../theme/app_colors.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import '../db/food.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:nutrition_assistant/widgets/fatsecret_attribution.dart';

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
      result.servingOptions.isEmpty
          ? [result.defaultServingOption]
          : result.servingOptions,
    );
    FoodServingOption selectedServing = availableServings.firstWhere(
      (option) => option.isDefault,
      orElse: () => availableServings.first,
    );
    final gramsController = TextEditingController(
      text: selectedServing.grams.toStringAsFixed(0),
    );
    final gramsFocusNode = FocusNode();
    String mealType = 'snack';
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: rootContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedGrams = double.tryParse(gramsController.text.trim());
            final currentGrams = (parsedGrams != null && parsedGrams > 0)
                ? parsedGrams
                : selectedServing.grams;
            final calories = (selectedServing.caloriesPerGram * currentGrams)
                .round();
            final protein = (selectedServing.proteinPerGram * currentGrams)
                .toStringAsFixed(1);
            final carbs = (selectedServing.carbsPerGram * currentGrams)
                .toStringAsFixed(1);
            final fat = (selectedServing.fatPerGram * currentGrams)
                .toStringAsFixed(1);

            return AlertDialog(
              title: Text('Add ${result.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: mealType,
                      decoration: const InputDecoration(labelText: 'Meal type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'breakfast',
                          child: Text('Breakfast'),
                        ),
                        DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                        DropdownMenuItem(
                          value: 'dinner',
                          child: Text('Dinner'),
                        ),
                        DropdownMenuItem(value: 'snack', child: Text('Snack')),
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
                            gramsController.text = value.grams.toStringAsFixed(
                              0,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: gramsController,
                      focusNode: gramsFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Weight (g)',
                        suffixIcon: IconButton(
                          tooltip: 'Done',
                          icon: const Icon(Icons.check),
                          onPressed: () =>
                              FocusScope.of(dialogContext).unfocus(),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          FocusScope.of(dialogContext).unfocus(),
                      onTapOutside: (_) =>
                          FocusScope.of(dialogContext).unfocus(),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final grams = double.tryParse(gramsController.text.trim());
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

                    final item = FoodItem(
                      id: 'search-${DateTime.now().microsecondsSinceEpoch}',
                      name: result.name,
                      mass_g: grams,
                      calories_g: selectedServing.caloriesPerGram,
                      protein_g: selectedServing.proteinPerGram,
                      carbs_g: selectedServing.carbsPerGram,
                      fat: selectedServing.fatPerGram,
                      mealType: mealType,
                      consumedAt: consumedAt,
                    );

                    try {
                      await ref
                          .read(firestoreFoodLogProvider(userId).notifier)
                          .addFood(userId, item);
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
    gramsFocusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = SafeArea(
      top: false,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 20,
              16,
              16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.brand,
                  AppColors.brand.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Food Search',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.surface,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search for any food and add it to your log',
                  style: TextStyle(
                    color: AppColors.surface.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search foods (FatSecret)...',
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
                              ? 'Start typing to search for foods'
                              : 'No results found',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textHint,
                          ),
                        ),
                        if (_searchController.text.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try searching for "apple", "chicken", or "rice"',
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
