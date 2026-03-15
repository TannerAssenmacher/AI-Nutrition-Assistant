import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/favorite_meal.dart';
import '../providers/firestore_providers.dart';
import '../services/food_search_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';

class AddToFavoritesSheet extends ConsumerStatefulWidget {
  final FoodSearchResult result;
  final String userId;
  final List<FavoriteMealItem>? initialItems;

  const AddToFavoritesSheet({
    super.key,
    required this.result,
    required this.userId,
    this.initialItems,
  });

  @override
  ConsumerState<AddToFavoritesSheet> createState() =>
      _AddToFavoritesSheetState();
}

class _AddToFavoritesSheetState extends ConsumerState<AddToFavoritesSheet> {
  late final TextEditingController _mealNameController;
  late final List<FoodServingOption> _availableServings;
  late FoodServingOption _selectedServing;
  late final TextEditingController _gramsController;
  FavoriteMeal? _selectedMeal;
  String _mealType = 'snack';
  int _quantity = 1;
  bool _isSaving = false;

  bool get _hasExplicitServingOptions =>
      widget.result.servingOptions.isNotEmpty;

  bool get _isBatchAdd =>
      widget.initialItems != null && widget.initialItems!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _mealNameController = TextEditingController(text: widget.result.name);
    final rawServings = _hasExplicitServingOptions
        ? widget.result.servingOptions
        : [widget.result.defaultServingOption];
    _availableServings = _normalizeServingOptions(rawServings);
    _selectedServing = _availableServings.firstWhere(
      (option) => option.isDefault,
      orElse: () => _availableServings.first,
    );
    _gramsController = TextEditingController(
      text: _selectedServing.grams.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  List<FoodServingOption> _normalizeServingOptions(
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

  String _servingLabel(FoodServingOption option) {
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

  Future<void> _handleAdd(List<FavoriteMeal> meals) async {
    if (_isSaving) return;
    final grams = _hasExplicitServingOptions
        ? _selectedServing.grams * _quantity
        : double.tryParse(_gramsController.text.trim());

    if (!_isBatchAdd && (grams == null || grams <= 0)) {
      AppSnackBar.error(context, 'Please enter a valid grams amount.');
      return;
    }

    final selectedMeal = _selectedMeal == null
        ? null
        : meals.firstWhere(
            (meal) => meal.id == _selectedMeal?.id,
            orElse: () => _selectedMeal!,
          );

    if (selectedMeal == null) {
      final mealName = _mealNameController.text.trim();
      if (mealName.isEmpty) {
        AppSnackBar.error(context, 'Please enter a meal name.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    final itemsToAdd = _isBatchAdd
        ? widget.initialItems!
        : [
            FavoriteMealItem(
              name: widget.result.name,
              grams: grams!,
              caloriesPerGram: widget.result.caloriesPerGram,
              proteinPerGram: widget.result.proteinPerGram,
              carbsPerGram: widget.result.carbsPerGram,
              fatPerGram: widget.result.fatPerGram,
              imageUrl: widget.result.imageUrl?.trim(),
              sourceId: widget.result.id,
              servingLabel: _hasExplicitServingOptions
                  ? _servingLabel(_selectedServing)
                  : '${grams.toStringAsFixed(0)} g',
              servings: _hasExplicitServingOptions
                  ? _quantity.toDouble()
                  : null,
            ),
          ];

    final now = DateTime.now();

    try {
      if (selectedMeal != null && selectedMeal.id != null) {
        final updated = selectedMeal.copyWith(
          items: [...selectedMeal.items, ...itemsToAdd],
          updatedAt: now,
        );
        await FirestoreFavoriteMealsRepository.updateFavoriteMeal(
          widget.userId,
          selectedMeal.id!,
          updated,
        );
        if (!mounted) return;
        Navigator.of(context).pop(selectedMeal.name);
        return;
      }

      final mealName = _mealNameController.text.trim();
      final newMeal = FavoriteMeal(
        name: mealName,
        mealType: _mealType,
        items: itemsToAdd,
        createdAt: now,
        updatedAt: now,
      );
      await FirestoreFavoriteMealsRepository.addFavoriteMeal(
        widget.userId,
        newMeal,
      );
      if (!mounted) return;
      Navigator.of(context).pop(mealName);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to save favorite: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final effectiveBottomInset = mediaQuery.viewInsets.bottom > 0
        ? mediaQuery.viewInsets.bottom
        : mediaQuery.viewPadding.bottom;
    final favoritesAsync = ref.watch(
      firestoreFavoriteMealsProvider(widget.userId),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: effectiveBottomInset + 16,
        top: 12,
      ),
      child: favoritesAsync.when(
        data: (meals) {
          final hasFavorites = meals.isNotEmpty;
          final selectedId = _selectedMeal?.id ?? 'new';

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to favorites',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isBatchAdd)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Adding ${widget.initialItems!.length} items from this meal.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (hasFavorites)
                  DropdownButtonFormField<String>(
                    value: selectedId,
                    decoration: const InputDecoration(
                      labelText: 'Favorite meal',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'new',
                        child: Text('Create new meal'),
                      ),
                      ...meals.map(
                        (meal) => DropdownMenuItem(
                          value: meal.id ?? meal.name,
                          child: Text(meal.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        if (value == 'new') {
                          _selectedMeal = null;
                        } else {
                          _selectedMeal = meals.firstWhere(
                            (meal) => meal.id == value || meal.name == value,
                            orElse: () => meals.first,
                          );
                          _mealType = _selectedMeal?.mealType ?? _mealType;
                        }
                      });
                    },
                  ),
                if (hasFavorites) const SizedBox(height: 12),
                if (_selectedMeal == null) ...[
                  TextField(
                    controller: _mealNameController,
                    decoration: const InputDecoration(labelText: 'Meal name'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _mealType,
                    decoration: const InputDecoration(labelText: 'Meal type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'breakfast',
                        child: Text('Breakfast'),
                      ),
                      DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                      DropdownMenuItem(value: 'snack', child: Text('Snack')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _mealType = value);
                      }
                    },
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Adding to ${_selectedMeal?.name} (${_selectedMeal?.mealType})',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (!_isBatchAdd && _hasExplicitServingOptions) ...[
                  if (_availableServings.length > 1) ...[
                    DropdownButtonFormField<FoodServingOption>(
                      initialValue: _selectedServing,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Serving size',
                      ),
                      selectedItemBuilder: (context) => _availableServings
                          .map(
                            (option) => Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                _servingLabel(option),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      items: _availableServings
                          .map(
                            (option) => DropdownMenuItem<FoodServingOption>(
                              value: option,
                              child: Text(
                                _servingLabel(option),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedServing = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<int>(
                    initialValue: _quantity,
                    decoration: const InputDecoration(labelText: 'Servings'),
                    items: List.generate(
                      10,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _quantity = value;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total: ${(_selectedServing.grams * _quantity).toStringAsFixed(0)} g',
                      style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    ),
                  ),
                ] else if (!_isBatchAdd)
                  TextField(
                    controller: _gramsController,
                    decoration: const InputDecoration(labelText: 'Weight (g)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _handleAdd(meals),
                    icon: Icon(
                      _isSaving ? Icons.hourglass_top : Icons.favorite,
                      size: 18,
                    ),
                    label: Text(_isSaving ? 'Saving...' : 'Add to favorites'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Unable to load favorites: $error',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}
