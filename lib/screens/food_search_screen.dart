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

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _searchService.searchFoods(trimmed);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
        _error = results.isEmpty
            ? 'No results found from USDA or Spoonacular.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Search failed: $e';
      });
    }
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
    final gramsController =
        TextEditingController(text: result.servingGrams.toStringAsFixed(0));
    final gramsFocusNode = FocusNode();
    String mealType = 'snack';
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: rootContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentGrams =
                double.tryParse(gramsController.text) ?? result.servingGrams;
            final calories = (result.caloriesPerGram * currentGrams).round();
            final protein =
                (result.proteinPerGram * currentGrams).toStringAsFixed(1);
            final carbs =
                (result.carbsPerGram * currentGrams).toStringAsFixed(1);
            final fat = (result.fatPerGram * currentGrams).toStringAsFixed(1);

            return AlertDialog(
              title: Text('Add ${result.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: mealType,
                      decoration: const InputDecoration(labelText: 'Meal type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'breakfast', child: Text('Breakfast')),
                        DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                        DropdownMenuItem(
                            value: 'dinner', child: Text('Dinner')),
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
                    TextField(
                      controller: gramsController,
                      focusNode: gramsFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Grams',
                        suffixIcon: IconButton(
                          tooltip: 'Done',
                          icon: const Icon(Icons.check),
                          onPressed: () =>
                              FocusScope.of(dialogContext).unfocus(),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          FocusScope.of(dialogContext).unfocus(),
                      onTapOutside: (_) =>
                          FocusScope.of(dialogContext).unfocus(),
                      onChanged: (value) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Nutrition Info',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
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
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NutritionIndicator(
                                  label: 'Protein',
                                  value: protein,
                                  unit: 'g',
                                  color: Colors.blue,
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
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _NutritionIndicator(
                                  label: 'Fat',
                                  value: fat,
                                  unit: 'g',
                                  color: Colors.purple,
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
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 30)),
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
                            content: Text('Please enter a valid grams value.')),
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
                      calories_g: result.caloriesPerGram,
                      protein_g: result.proteinPerGram,
                      carbs_g: result.carbsPerGram,
                      fat: result.fatPerGram,
                      mealType: mealType,
                      consumedAt: consumedAt,
                    );

                    try {
                      await ref
                          .read(firestoreFoodLogProvider(userId).notifier)
                          .addFood(userId, item);
                      if (!mounted) return;
                      final messenger = ScaffoldMessenger.of(rootContext);
                      Navigator.pop(dialogContext);
                      final dateText = selectedDate.day == DateTime.now().day &&
                              selectedDate.month == DateTime.now().month &&
                              selectedDate.year == DateTime.now().year
                          ? 'today\'s log'
                          : '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}';
                      messenger.showSnackBar(
                        SnackBar(
                            content:
                                Text('Added "${result.name}" to $dateText')),
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
                colors: [AppColors.brand, AppColors.brand.withValues(alpha: 0.85)],
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
                          color: Colors.white,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search for any food and add it to your log',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
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
                hintText: 'Search USDA foods (Spoonacular fallback)...',
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
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accentBrown.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accentBrown.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.accentBrown, width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {});
                _onSearchQueryChanged(value);
              },
              onSubmitted: _runSearch,
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
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                          color: Colors.orange.shade700, fontSize: 13),
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
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Start typing to search for foods'
                              : 'No results found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchController.text.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try searching for "apple", "chicken", or "rice"',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
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
      backgroundColor: AppColors.background,
      body: bodyContent,
      bottomNavigationBar: NavBar(
        currentIndex: navIndexSearch,
        onTap: (index) => handleNavTap(context, index),
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
    final calories = (result.caloriesPerGram * result.servingGrams).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
            child: Icon(
              Icons.restaurant,
              color: AppColors.brand,
              size: 24,
            ),
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
                  '${result.servingGrams.toStringAsFixed(0)} g · $calories Cal',
                  style: TextStyle(
                    color: Colors.grey.shade700,
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
                      value: (result.proteinPerGram * result.servingGrams)
                          .toStringAsFixed(1),
                      color: AppColors.protein,
                    ),
                    _MacroChip(
                      label: 'C',
                      value: (result.carbsPerGram * result.servingGrams)
                          .toStringAsFixed(1),
                      color: AppColors.carbs,
                    ),
                    _MacroChip(
                      label: 'F',
                      value: (result.fatPerGram * result.servingGrams)
                          .toStringAsFixed(1),
                      color: AppColors.fat,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result.sourceLabel,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
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
      case 'P': return 'Protein';
      case 'C': return 'Carbs';
      case 'F': return 'Fat';
      default: return abbr;
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
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
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
                color: color.shade700,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
