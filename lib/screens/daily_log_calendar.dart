import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import '../providers/food_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import '../db/food.dart';
import '../db/user.dart';
import '../db/planned_food.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';
import 'package:nutrition_assistant/services/food_search_service.dart';
import 'package:nutrition_assistant/services/notification_service.dart';
import '../theme/app_colors.dart';

class DailyLogCalendarScreen extends ConsumerStatefulWidget {
  final bool isInPageView;

  const DailyLogCalendarScreen({super.key, this.isInPageView = false});

  @override
  ConsumerState<DailyLogCalendarScreen> createState() =>
      _DailyLogCalendarScreenState();
}

class _DailyLogCalendarScreenState
    extends ConsumerState<DailyLogCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _notificationsChecked = false;
  bool _hasAutoScrolledToToday = false;
  final ScrollController _weekListScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
  }

  @override
  void dispose() {
    _weekListScrollController.dispose();
    super.dispose();
  }

  void _autoScrollToTodayIfNeeded(List<DateTime> weekDays) {
    if (_hasAutoScrolledToToday) return;

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    // Find the index of today in the week
    int todayIndex = -1;
    for (int i = 0; i < weekDays.length; i++) {
      final dayOnly = DateTime(
        weekDays[i].year,
        weekDays[i].month,
        weekDays[i].day,
      );
      if (dayOnly == todayOnly) {
        todayIndex = i;
        break;
      }
    }

    if (todayIndex < 0) return; // Today not in current week

    _hasAutoScrolledToToday = true;

    // Calculate the scroll offset for the item
    // Each item is roughly: margin(6+6) + padding(16+16) + content_height(~140-180) = ~180-220 per item
    final itemHeight = 180.0;
    final offset = todayIndex * itemHeight;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_weekListScrollController.hasClients) {
        _weekListScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _wrapWithScaffold(Widget body) {
    if (widget.isInPageView == true) {
      return body;
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: body,
      bottomNavigationBar: NavBar(
        currentIndex: navIndexHistory,
        onTap: (index) => handleNavTap(context, index),
      ),
    );
  }

  List<_FoodRow> _foodsForDay(DateTime day, List<FoodItem>? log) {
    final rows = <_FoodRow>[];
    if (log == null) return rows;
    for (final item in log) {
      if (item.consumedAt.year == day.year &&
          item.consumedAt.month == day.month &&
          item.consumedAt.day == day.day) {
        final calories = item.calories_g * item.mass_g;
        final protein = item.protein_g * item.mass_g;
        final carbs = item.carbs_g * item.mass_g;
        final fat = item.fat * item.mass_g;

        rows.add(
          _FoodRow(
            id: item.id,
            mealType: item.mealType,
            name: item.name,
            amount: '${item.mass_g.toStringAsFixed(0)} g',
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: 0,
            massG: item.mass_g,
            consumedAt: item.consumedAt,
          ),
        );
      }
    }
    return rows;
  }

  Future<Map<String, double>> _scheduledTotals(
    List<PlannedFood> scheduledMeals,
    WidgetRef ref,
  ) async {
    double calories = 0, protein = 0, carbs = 0, fat = 0;

    for (final meal in scheduledMeals) {
      final recipe = await ref.read(recipeByIdProvider(meal.recipeId).future);
      calories += (recipe['calories'] ?? 0).toDouble();
      protein += (recipe['protein'] ?? 0).toDouble();
      carbs += (recipe['carbs'] ?? 0).toDouble();
      fat += (recipe['fat'] ?? 0).toDouble();
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  List<PlannedFood> _scheduledMealsForDay(
    DateTime day,
    List<PlannedFood>? scheduledMeals,
  ) {
    if (scheduledMeals == null) return [];

    final dayNormalized = DateTime(day.year, day.month, day.day);

    return scheduledMeals.where((meal) {
      final mealDateNormalized = DateTime(
        meal.date.year,
        meal.date.month,
        meal.date.day,
      );
      return mealDateNormalized == dayNormalized;
    }).toList();
  }

  Map<String, double> _totalsForDay(DateTime day, List<FoodItem>? log) {
    final rows = _foodsForDay(day, log);
    double calories = 0, protein = 0, carbs = 0, fat = 0, fiber = 0;
    for (final r in rows) {
      calories += r.calories;
      protein += r.protein;
      carbs += r.carbs;
      fat += r.fat;
      fiber += r.fiber;
    }
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
    };
  }

  Map<String, double> _goalsFromProfile(AppUser? userProfile) {
    final calorieGoal =
        userProfile?.mealProfile.dailyCalorieGoal.toDouble() ?? 2000.0;

    final macroGoals = userProfile?.mealProfile.macroGoals ?? const {};
    final proteinRaw = macroGoals['protein'] ?? 0.0;
    final carbsRaw = macroGoals['carbs'] ?? 0.0;
    final fatRaw = macroGoals['fat'] ?? macroGoals['fats'] ?? 0.0;

    final values = [proteinRaw, carbsRaw, fatRaw].where((v) => v > 0).toList();
    final looksLikePercentages =
        values.isNotEmpty && values.every((v) => v <= 100.0);

    if (looksLikePercentages) {
      final proteinGoal = calorieGoal * (proteinRaw / 100) / 4;
      final carbsGoal = calorieGoal * (carbsRaw / 100) / 4;
      final fatGoal = calorieGoal * (fatRaw / 100) / 9;

      return {
        'calories': calorieGoal,
        'protein': proteinGoal,
        'carbs': carbsGoal,
        'fat': fatGoal,
      };
    }

    return {
      'calories': calorieGoal,
      'protein': proteinRaw > 0 ? proteinRaw : 150.0,
      'carbs': carbsRaw > 0 ? carbsRaw : 200.0,
      'fat': fatRaw > 0 ? fatRaw : 65.0,
    };
  }

  double _goalPointsForMacro({required double actual, required double goal}) {
    if (goal <= 0) return 0;
    final percentage = (actual / goal) * 100;
    if (percentage > 130) return 0;
    if (percentage > 110) return 0.5;
    if (percentage >= 90) return 1;
    if (percentage >= 80) return 0.5;
    return 0;
  }

  double _calculateGoalPoints({
    required Map<String, double> totals,
    required Map<String, double> goals,
  }) {
    return _goalPointsForMacro(
          actual: totals['calories'] ?? 0,
          goal: goals['calories'] ?? 0,
        ) +
        _goalPointsForMacro(
          actual: totals['protein'] ?? 0,
          goal: goals['protein'] ?? 0,
        ) +
        _goalPointsForMacro(
          actual: totals['carbs'] ?? 0,
          goal: goals['carbs'] ?? 0,
        ) +
        _goalPointsForMacro(actual: totals['fat'] ?? 0, goal: goals['fat'] ?? 0);
  }

  _ThirtyDayGoalStats _calculateThirtyDayGoalStats({
    required List<FoodItem>? log,
    required Map<String, double> goals,
  }) {
    double caloriePoints = 0;
    double proteinPoints = 0;
    double carbsPoints = 0;
    double fatPoints = 0;
    int perfectDays = 0;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (int i = 0; i < 30; i++) {
      final day = todayOnly.subtract(Duration(days: i));
      final totals = _totalsForDay(day, log);

      final cal = _goalPointsForMacro(
        actual: totals['calories'] ?? 0,
        goal: goals['calories'] ?? 0,
      );
      final pro = _goalPointsForMacro(
        actual: totals['protein'] ?? 0,
        goal: goals['protein'] ?? 0,
      );
      final carb = _goalPointsForMacro(
        actual: totals['carbs'] ?? 0,
        goal: goals['carbs'] ?? 0,
      );
      final fat = _goalPointsForMacro(
        actual: totals['fat'] ?? 0,
        goal: goals['fat'] ?? 0,
      );

      caloriePoints += cal;
      proteinPoints += pro;
      carbsPoints += carb;
      fatPoints += fat;

      if (cal == 1 && pro == 1 && carb == 1 && fat == 1) {
        perfectDays += 1;
      }
    }

    return _ThirtyDayGoalStats(
      caloriePoints: caloriePoints,
      proteinPoints: proteinPoints,
      carbsPoints: carbsPoints,
      fatPoints: fatPoints,
      perfectDays: perfectDays,
    );
  }

  Widget _buildGoalStars(double points) {
    final fullStars = points.floor();
    final hasHalfStar = (points - fullStars) >= 0.5;

    if (fullStars == 0 && !hasHalfStar) {
      return const SizedBox(width: 26, height: 26);
    }

    return SizedBox(
      width: 48,
      height: 26,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 1,
        runSpacing: 0,
        children: [
          for (int i = 0; i < fullStars; i++)
            const Icon(
              Icons.star_rounded,
              size: 11,
              color: AppColors.statusNear,
            ),
          if (hasHalfStar)
            const Icon(
              Icons.star_half_rounded,
              size: 11,
              color: AppColors.statusNear,
            ),
        ],
      ),
    );
  }

  void _showMonthlyCalendarPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return _MonthlyCalendarPicker(
          focusedDay: _focusedDay,
          onDateSelected: (selectedDate) {
            setState(() {
              _focusedDay = selectedDate;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showFoodsSheet(
    DateTime day,
    List<_FoodRow> initialRows,
    Map<String, double> initialTotals,
    String userId,
  ) {
    int segment = 0; // 0 = history, 1 = scheduled
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final dateLabel = DateFormat('MMMM d, yyyy').format(day);
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final logAsync = ref.watch(firestoreFoodLogProvider(userId));
                final scheduledAsync = ref.watch(
                  firestoreScheduledMealsProvider(userId),
                );

                final rows = logAsync.maybeWhen(
                  data: (log) => _foodsForDay(day, log),
                  orElse: () => initialRows,
                );
                final totals = logAsync.maybeWhen(
                  data: (log) => _totalsForDay(day, log),
                  orElse: () => initialTotals,
                );
                final scheduledMeals = scheduledAsync.maybeWhen(
                  data: (meals) => _scheduledMealsForDay(day, meals),
                  orElse: () => <PlannedFood>[],
                );
                final scheduledTotalsFuture = _scheduledTotals(
                  scheduledMeals,
                  ref,
                );

                return StatefulBuilder(
                  builder: (context, setSheetState) {
                    final isScheduled = segment == 1;

                    return SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 12,
                          bottom: MediaQuery.of(context).padding.bottom + 12,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateLabel,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),

                            // ✅ Segmented control
                            CupertinoSlidingSegmentedControl<int>(
                              groupValue: segment,
                              children: {
                                0: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 14,
                                  ),
                                  child: Text('History (${rows.length})'),
                                ),
                                1: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 14,
                                  ),
                                  child: Text('Scheduled (${scheduledMeals.length})'),
                                ),
                              },
                              onValueChanged: (value) {
                                if (value == null) return;
                                setSheetState(() => segment = value);
                              },
                            ),

                            const SizedBox(height: 12),

                            // Macro summary card
                            FutureBuilder<Map<String, double>>(
                              future: scheduledTotalsFuture,
                              builder: (context, snapshot) {
                                final scheduledTotals =
                                    snapshot.data ??
                                    const {
                                      'calories': 0,
                                      'protein': 0,
                                      'carbs': 0,
                                      'fat': 0,
                                    };
                                final showScheduledTotals = segment == 1;
                                final summary = {
                                  'calories': showScheduledTotals
                                      ? scheduledTotals['calories']!
                                      : (totals['calories'] ?? 0),
                                  'protein': showScheduledTotals
                                      ? scheduledTotals['protein']!
                                      : (totals['protein'] ?? 0),
                                  'carbs': showScheduledTotals
                                      ? scheduledTotals['carbs']!
                                      : (totals['carbs'] ?? 0),
                                  'fat': showScheduledTotals
                                      ? scheduledTotals['fat']!
                                      : (totals['fat'] ?? 0),
                                };

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.inputFill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.accentBrown.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _MacroSummaryItem(
                                        label: 'Cal',
                                        value:
                                            '${summary['calories']!.toInt()}',
                                      ),
                                      _MacroSummaryItem(
                                        label: 'Prot',
                                        value:
                                            '${summary['protein']!.toStringAsFixed(1)}g',
                                      ),
                                      _MacroSummaryItem(
                                        label: 'Carbs',
                                        value:
                                            '${summary['carbs']!.toStringAsFixed(1)}g',
                                      ),
                                      _MacroSummaryItem(
                                        label: 'Fat',
                                        value:
                                            '${summary['fat']!.toStringAsFixed(1)}g',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 12),

                            // ✅ CONTENT SWITCH
                            if (isScheduled) ...[
                              Text(
                                'Scheduled Meals',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.selectionColor,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              if (scheduledMeals.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'No scheduled meals for this day',
                                  ),
                                )
                              else
                                for (final meal in scheduledMeals)
                                  _ScheduledMealCard(
                                    meal: meal,
                                    onEdit: () async {
                                      await _showEditScheduledMealDialog(
                                        userId,
                                        meal,
                                      );
                                    },
                                    onDelete: () async {
                                      if (meal.id == null) return;

                                      final shouldDelete = await showDialog<bool>(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: const Text(
                                              'Delete scheduled meal?',
                                            ),
                                            content: const Text(
                                              'Remove this scheduled meal from this day?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.deleteRed,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (shouldDelete != true) return;

                                      await ref
                                          .read(
                                            firestoreScheduledMealsProvider(
                                              userId,
                                            ).notifier,
                                          )
                                          .removeScheduledMeal(
                                            userId,
                                            meal.id!,
                                          );
                                    },
                                  ),
                            ] else ...[
                              Text(
                                'Logged Foods',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),

                              if (rows.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('No entries for this day'),
                                )
                              else
                                _FoodsListWidget(
                                  rows: rows,
                                  onDelete: (foodId) async {
                                    debugPrint(
                                      'UI delete tap: user=$userId foodId=$foodId day=${day.toIso8601String()}',
                                    );
                                    await ref
                                        .read(
                                          firestoreFoodLogProvider(
                                            userId,
                                          ).notifier,
                                        )
                                        .removeFood(userId, foodId);
                                  },
                                  onSave: (updatedRow) async {
                                    final mass = updatedRow.massG > 0
                                        ? updatedRow.massG
                                        : 1.0;
                                    final updatedItem = FoodItem(
                                      id: updatedRow.id,
                                      name: updatedRow.name,
                                      mass_g: mass,
                                      calories_g: updatedRow.calories / mass,
                                      protein_g: updatedRow.protein / mass,
                                      carbs_g: updatedRow.carbs / mass,
                                      fat: updatedRow.fat / mass,
                                      mealType: updatedRow.mealType,
                                      consumedAt: updatedRow.consumedAt,
                                    );
                                    await ref
                                        .read(
                                          firestoreFoodLogProvider(
                                            userId,
                                          ).notifier,
                                        )
                                        .updateFood(
                                          userId,
                                          updatedRow.id,
                                          updatedItem,
                                        );
                                  },
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showAddFoodDialog(day, userId),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add food'),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showAddFoodDialog(DateTime day, String userId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddFoodModal(day: day, userId: userId),
    );
  }

  Future<void> _showEditScheduledMealDialog(
    String userId,
    PlannedFood meal,
  ) async {
    if (meal.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to edit this scheduled meal.')),
      );
      return;
    }

    final result = await showModalBottomSheet<_ScheduledMealEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
        var selectedDate = DateTime(
          meal.date.year,
          meal.date.month,
          meal.date.day,
        );
        var selectedMealType = meal.mealType.toLowerCase();
        if (!mealTypes.contains(selectedMealType)) {
          selectedMealType = 'snack';
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Scheduled Meal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Date', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(now.year - 1, 1, 1),
                        lastDate: DateTime(now.year + 2, 12, 31),
                      );
                      if (picked == null) return;
                      setSheetState(() {
                        selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                      });
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      DateFormat('MMMM d, yyyy').format(selectedDate),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Meal Type',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedMealType,
                    items: mealTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(_capitalizeMealType(type)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selectedMealType = value;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(
                              _ScheduledMealEditResult(
                                date: selectedDate,
                                mealType: selectedMealType,
                              ),
                            );
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    final updatedMeal = PlannedFood(
      id: meal.id,
      recipeId: meal.recipeId,
      date: result.date,
      mealType: result.mealType,
    );

    await ref
        .read(firestoreScheduledMealsProvider(userId).notifier)
        .updateScheduledMeal(userId, meal.id!, updatedMeal);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Scheduled meal updated.')));
  }

  static String _capitalizeMealType(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  Future<void> _checkAndShowNotifications(
    List<FoodItem> foodLog,
    Map<String, double> goals,
    String userId,
  ) async {
    if (_notificationsChecked) return;
    _notificationsChecked = true;

    final now = DateTime.now();

    if (!NotificationService.hasLoggedToday(foodLog)) {
      final streakAsync = ref.read(dailyStreakProvider(userId));
      streakAsync.whenData((streak) {
        NotificationService.showStreakReminder(streak);
      });
    }

    if (NotificationService.isAfter6PM()) {
      final todayLog = foodLog
          .where(
            (item) =>
                item.consumedAt.year == now.year &&
                item.consumedAt.month == now.month &&
                item.consumedAt.day == now.day,
          )
          .toList();

      final dayTotals = _totalsForDay(now, todayLog);
      final remaining = NotificationService.calculateRemainingMacros(
        currentTotals: dayTotals,
        goals: goals,
      );

      final hasRemaining = remaining.values.any((value) => value > 10);
      if (hasRemaining) {
        NotificationService.showMacroReminder(remaining);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    if (userId == null) {
      return _wrapWithScaffold(
        const SafeArea(
          child: Center(child: Text('Sign in to view your meal log.')),
        ),
      );
    }

    final foodLogAsync = ref.watch(firestoreFoodLogProvider(userId));
    final scheduledMealsAsync = ref.watch(firestoreScheduledMealsProvider(userId));
    final userProfileAsync = ref.watch(firestoreUserProfileProvider(userId));
    final goals = _goalsFromProfile(userProfileAsync.valueOrNull);
    final calorieGoal = goals['calories'] ?? 2000.0;
    final proteinGoal = goals['protein'] ?? 150.0;
    final carbsGoal = goals['carbs'] ?? 200.0;
    final fatGoal = goals['fat'] ?? 65.0;

    final weekStart = _focusedDay.subtract(
      Duration(days: _focusedDay.weekday - 1),
    );
    final weekDays = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );

    return foodLogAsync.when(
      error: (e, _) => _wrapWithScaffold(
        SafeArea(child: Center(child: Text('Failed to load meals: $e'))),
      ),
      loading: () => _wrapWithScaffold(
        const SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      data: (foodLog) {
        final thirtyDayStats = _calculateThirtyDayGoalStats(
          log: foodLog,
          goals: {
            'calories': calorieGoal,
            'protein': proteinGoal,
            'carbs': carbsGoal,
            'fat': fatGoal,
          },
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoScrollToTodayIfNeeded(weekDays);
          unawaited(_checkAndShowNotifications(foodLog, goals, userId));
        });

        return _wrapWithScaffold(
          SafeArea(
            child: Column(
              children: [
                // Week navigation controls — FIX 1: Flexible month label
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        color: AppColors.navBar,
                        tooltip: 'Previous week',
                        onPressed: () {
                          setState(() {
                            _focusedDay = _focusedDay.subtract(
                              const Duration(days: 7),
                            );
                          });
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showMonthlyCalendarPicker,
                          child: Text(
                            DateFormat('MMMM yyyy').format(_focusedDay),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navBar,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        color: AppColors.navBar,
                        tooltip: 'Next week',
                        onPressed: () {
                          setState(() {
                            _focusedDay = _focusedDay.add(
                              const Duration(days: 7),
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _weekListScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      ...weekDays.map((day) {
                      final isSelected =
                          _selectedDay != null &&
                          day.year == _selectedDay!.year &&
                          day.month == _selectedDay!.month &&
                          day.day == _selectedDay!.day;
                      final isToday =
                          day.year == DateTime.now().year &&
                          day.month == DateTime.now().month &&
                          day.day == DateTime.now().day;
                      final todayOnly = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      );
                      final dayOnly = DateTime(day.year, day.month, day.day);
                      final isFutureDay = dayOnly.isAfter(todayOnly);
                      final foods = _foodsForDay(day, foodLog);
                      final scheduledMealsForDay = scheduledMealsAsync.maybeWhen(
                        data: (meals) => _scheduledMealsForDay(day, meals),
                        orElse: () => <PlannedFood>[],
                      );
                      final summaryParts = <String>[
                        if (foods.isNotEmpty)
                          '${foods.length} Logged Food${foods.length == 1 ? '' : 's'}',
                        if (scheduledMealsForDay.isNotEmpty)
                          '${scheduledMealsForDay.length} Scheduled Meal${scheduledMealsForDay.length == 1 ? '' : 's'}',
                      ];
                      final daySummaryLabel = summaryParts.join(' - ');
                      final dayTotals = _totalsForDay(day, foodLog);
                      final goalPoints = isFutureDay
                          ? 0.0
                          : _calculateGoalPoints(
                              totals: dayTotals,
                              goals: {
                                'calories': calorieGoal,
                                'protein': proteinGoal,
                                'carbs': carbsGoal,
                                'fat': fatGoal,
                              },
                            );

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDay = day;
                          });
                          _showFoodsSheet(day, foods, dayTotals, userId);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.selectionColor
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // FIX 3: Day indicator with mainAxisSize.min
                              SizedBox(
                                width: 48,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('E').format(day),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? AppColors.selectionColor
                                                  .withValues(alpha: 0.2)
                                            : AppColors.surfaceVariant,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isToday
                                              ? AppColors.selectionColor
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _buildGoalStars(goalPoints),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Foods summary
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (daySummaryLabel.isNotEmpty)
                                      Text(
                                        daySummaryLabel,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    _MacroProgressIndicator(
                                      label: 'Cal',
                                      current: dayTotals['calories'] ?? 0,
                                      goal: calorieGoal,
                                      color: AppColors.caloriesCircle,
                                      valueLabel:
                                          '${dayTotals['calories']?.toInt() ?? 0} Cal',
                                    ),
                                    const SizedBox(height: 4),
                                    _MacroProgressIndicator(
                                      label: 'Pro',
                                      current: dayTotals['protein'] ?? 0,
                                      goal: proteinGoal,
                                      color: AppColors.protein,
                                      valueLabel:
                                          '${dayTotals['protein']?.toStringAsFixed(0) ?? 0}g',
                                    ),
                                    const SizedBox(height: 4),
                                    _MacroProgressIndicator(
                                      label: 'Carb',
                                      current: dayTotals['carbs'] ?? 0,
                                      goal: carbsGoal,
                                      color: AppColors.carbs,
                                      valueLabel:
                                          '${dayTotals['carbs']?.toStringAsFixed(0) ?? 0}g',
                                    ),
                                    const SizedBox(height: 4),
                                    _MacroProgressIndicator(
                                      label: 'Fat',
                                      current: dayTotals['fat'] ?? 0,
                                      goal: fatGoal,
                                      color: AppColors.fat,
                                      valueLabel:
                                          '${dayTotals['fat']?.toStringAsFixed(0) ?? 0}g',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                      const SizedBox(height: 10),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last 30 Days Statistics',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StatChip(
                                  label: 'Calories',
                                  points: thirtyDayStats.caloriePoints,
                                ),
                                _StatChip(
                                  label: 'Protein',
                                  points: thirtyDayStats.proteinPoints,
                                ),
                                _StatChip(
                                  label: 'Carbs',
                                  points: thirtyDayStats.carbsPoints,
                                ),
                                _StatChip(
                                  label: 'Fat',
                                  points: thirtyDayStats.fatPoints,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Perfect Days (Last 30 Days): ${thirtyDayStats.perfectDays}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddFoodModal extends ConsumerStatefulWidget {
  final DateTime day;
  final String userId;

  const _AddFoodModal({required this.day, required this.userId});

  @override
  ConsumerState<_AddFoodModal> createState() => _AddFoodModalState();
}

class _AddFoodModalState extends ConsumerState<_AddFoodModal> {
  bool _isSearchMode = true;

  final _nameController = TextEditingController();
  final _gramsController = TextEditingController(text: '100');
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _mealType = 'snack';

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
    _nameController.dispose();
    _gramsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
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

  Future<void> _addManualMeal() async {
    final name = _nameController.text.trim();
    final grams = double.tryParse(_gramsController.text.trim());
    final calories = double.tryParse(_caloriesController.text.trim());
    final protein = double.tryParse(_proteinController.text.trim());
    final carbs = double.tryParse(_carbsController.text.trim());
    final fat = double.tryParse(_fatController.text.trim());

    if (name.isEmpty || grams == null || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name and valid grams.')),
      );
      return;
    }

    final caloriesTotal = calories ?? 0;
    final proteinTotal = protein ?? 0;
    final carbsTotal = carbs ?? 0;
    final fatTotal = fat ?? 0;

    final consumedAt = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      12,
    );
    final item = FoodItem(
      id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      mass_g: grams,
      calories_g: caloriesTotal / grams,
      protein_g: proteinTotal / grams,
      carbs_g: carbsTotal / grams,
      fat: fatTotal / grams,
      mealType: _mealType,
      consumedAt: consumedAt,
    );

    try {
      await ref
          .read(firestoreFoodLogProvider(widget.userId).notifier)
          .addFood(widget.userId, item);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('Added "$name"')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add food: $e')));
      }
    }
  }

  Future<void> _addSearchResult(FoodSearchResult result) async {
    final rootContext = context;

    final added = await showDialog<bool>(
      context: rootContext,
      builder: (dialogContext) {
        return _AddSearchResultDialog(
          result: result,
          day: widget.day,
          userId: widget.userId,
        );
      },
    );

    if (added != true || !mounted || !rootContext.mounted) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted || !rootContext.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(rootContext);
    Navigator.pop(rootContext);
    messenger.showSnackBar(SnackBar(content: Text('Added "${result.name}"')));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isSearchMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isSearchMode
                                ? AppColors.accentBrown
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 20,
                                color: _isSearchMode
                                    ? AppColors.surface
                                    : AppColors.accentBrown,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Search Online',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _isSearchMode
                                      ? AppColors.surface
                                      : AppColors.accentBrown,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isSearchMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isSearchMode
                                ? AppColors.accentBrown
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit,
                                size: 20,
                                color: !_isSearchMode
                                    ? AppColors.surface
                                    : AppColors.accentBrown,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Manual Entry',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: !_isSearchMode
                                      ? AppColors.surface
                                      : AppColors.accentBrown,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: _isSearchMode
                      ? _buildSearchMode()
                      : _buildManualMode(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        if (_suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () => _applySuggestion(suggestion),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
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
    );
  }

  Widget _buildManualMode() {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Meal name'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _mealType,
          decoration: const InputDecoration(labelText: 'Meal type'),
          items: const [
            DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
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
        const SizedBox(height: 12),
        TextField(
          controller: _gramsController,
          decoration: const InputDecoration(labelText: 'Grams'),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _caloriesController,
          decoration: const InputDecoration(labelText: 'Total calories'),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _proteinController,
          decoration: const InputDecoration(labelText: 'Total protein (g)'),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _carbsController,
          decoration: const InputDecoration(labelText: 'Total carbs (g)'),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fatController,
          decoration: const InputDecoration(labelText: 'Total fat (g)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addManualMeal,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBrown,
              foregroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Add Meal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _FoodsListWidget extends StatelessWidget {
  const _FoodsListWidget({
    Key? key,
    required this.rows,
    required this.onDelete,
    required this.onSave,
  }) : super(key: key);

  final List<_FoodRow> rows;
  final Future<void> Function(String foodId) onDelete;
  final Future<void> Function(_FoodRow updatedRow) onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return _EditableFoodCard(
              key: ValueKey(row.id),
              row: row,
              onDelete: onDelete,
              onSave: onSave,
            );
          },
        ),
      ],
    );
  }
}

class _EditableFoodCard extends StatefulWidget {
  const _EditableFoodCard({
    super.key,
    required this.row,
    required this.onDelete,
    required this.onSave,
  });

  final _FoodRow row;
  final Future<void> Function(String foodId) onDelete;
  final Future<void> Function(_FoodRow updatedRow) onSave;

  @override
  State<_EditableFoodCard> createState() => _EditableFoodCardState();
}

class _EditableFoodCardState extends State<_EditableFoodCard> {
  bool _isEditing = false;
  OverlayEntry? _statusOverlay;
  Timer? _statusTimer;
  late final TextEditingController _nameController;
  late final TextEditingController _calController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbController;
  late final TextEditingController _fatController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _calController = TextEditingController();
    _proteinController = TextEditingController();
    _carbController = TextEditingController();
    _fatController = TextEditingController();
    _resetControllersFromRow();
  }

  @override
  void didUpdateWidget(covariant _EditableFoodCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.id != widget.row.id ||
        (!_isEditing && oldWidget.row != widget.row)) {
      _resetControllersFromRow();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _statusOverlay?.remove();
    _nameController.dispose();
    _calController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _resetControllersFromRow() {
    _nameController.text = widget.row.name;
    _calController.text = widget.row.calories.toStringAsFixed(1);
    _proteinController.text = widget.row.protein.toStringAsFixed(1);
    _carbController.text = widget.row.carbs.toStringAsFixed(1);
    _fatController.text = widget.row.fat.toStringAsFixed(1);
  }

  double? _parseMacro(String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null || value < 0) return null;
    return value;
  }

  void _showStatusSnack(String message, {bool isError = false}) {
    _statusTimer?.cancel();
    _statusOverlay?.remove();

    final overlay = Overlay.of(context);

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewPadding.bottom;

    _statusOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                color: isError ? AppColors.error : AppColors.navBar,
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_statusOverlay!);
    _statusTimer = Timer(const Duration(seconds: 2), () {
      _statusOverlay?.remove();
      _statusOverlay = null;
    });
  }

  Future<void> _saveEdits() async {
    final name = _nameController.text.trim();
    final calories = _parseMacro(_calController.text);
    final protein = _parseMacro(_proteinController.text);
    final carbs = _parseMacro(_carbController.text);
    final fat = _parseMacro(_fatController.text);

    if (name.isEmpty ||
        calories == null ||
        protein == null ||
        carbs == null ||
        fat == null) {
      _showStatusSnack(
        'Please enter valid name and macro values.',
        isError: true,
      );
      return;
    }

    final updatedRow = widget.row.copyWith(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

    try {
      await widget.onSave(updatedRow);
      if (!mounted) return;
      setState(() => _isEditing = false);
      _showStatusSnack('Saved "${updatedRow.name}"');
    } catch (e) {
      if (!mounted) return;
      _showStatusSnack('Failed to save: $e', isError: true);
    }
  }

  Future<void> _deleteRow() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete food?'),
          content: Text('Remove "${widget.row.name}" from this day?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deleteRed,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await widget.onDelete(widget.row.id);
      if (!mounted) return;
      _showStatusSnack('Removed "${widget.row.name}"');
    } catch (e) {
      if (!mounted) return;
      _showStatusSnack('Failed to remove: $e', isError: true);
    }
  }

  Widget _macroStatTile({
    required String label,
    required Color color,
    required bool isEditing,
    required TextEditingController controller,
    required String value,
    required String unit,
  }) {
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.35).toDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 54 * textScale,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isEditing ? color.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing
              ? color.withValues(alpha: 0.45)
              : AppColors.warmBorder,
        ),
        boxShadow: isEditing
            ? []
            : [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.03),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          if (isEditing)
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0 $unit',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: color.withValues(alpha: 0.6),
                  ),
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.95),
                ),
              ),
            )
          else
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$value $unit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.warmLight.withValues(alpha: 0.65),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: _isEditing
                          ? BoxDecoration(
                              color: AppColors.warmLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warmMid),
                            )
                          : null,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _isEditing
                            ? TextField(
                                controller: _nameController,
                                textAlignVertical: TextAlignVertical.center,
                                strutStyle: const StrutStyle(
                                  fontSize: 16,
                                  height: 1.0,
                                  forceStrutHeight: true,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Meal name',
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.mealText,
                                ),
                              )
                            : Text(
                                widget.row.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                strutStyle: const StrutStyle(
                                  fontSize: 16,
                                  height: 1.0,
                                  forceStrutHeight: true,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.mealText,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${widget.row.mealType.toUpperCase()} • ${widget.row.amount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: AppColors.warmDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _deleteRow,
                    icon: Icon(Icons.delete_outline, color: AppColors.error),
                    tooltip: 'Remove food',
                  ),
                  IconButton(
                    onPressed: _isEditing
                        ? _saveEdits
                        : () => setState(() => _isEditing = true),
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.edit,
                      size: 20,
                      color: AppColors.warmDarker,
                    ),
                    tooltip: _isEditing ? 'Save meal' : 'Edit meal',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _macroStatTile(
                  label: 'Calories',
                  color: AppColors.caloriesCircle,
                  isEditing: _isEditing,
                  controller: _calController,
                  value: widget.row.calories.toStringAsFixed(0),
                  unit: 'Cal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroStatTile(
                  label: 'Protein',
                  color: AppColors.protein,
                  isEditing: _isEditing,
                  controller: _proteinController,
                  value: widget.row.protein.toStringAsFixed(1),
                  unit: 'g',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _macroStatTile(
                  label: 'Carbs',
                  color: AppColors.carbs,
                  isEditing: _isEditing,
                  controller: _carbController,
                  value: widget.row.carbs.toStringAsFixed(1),
                  unit: 'g',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroStatTile(
                  label: 'Fat',
                  color: AppColors.fat,
                  isEditing: _isEditing,
                  controller: _fatController,
                  value: widget.row.fat.toStringAsFixed(1),
                  unit: 'g',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// FIX 4: Search result tile with wrapping macro text
class _FoodSearchResultTile extends StatelessWidget {
  const _FoodSearchResultTile({required this.result, required this.onAdd});

  final FoodSearchResult result;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final serving = result.defaultServingOption;
    final calories = (serving.caloriesPerGram * serving.grams).round();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${serving.grams.toStringAsFixed(0)} g · $calories Cal',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      'P ${(serving.proteinPerGram * serving.grams).toStringAsFixed(1)}g',
                      style: TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                    Text(
                      'C ${(serving.carbsPerGram * serving.grams).toStringAsFixed(1)}g',
                      style: TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                    Text(
                      'F ${(serving.fatPerGram * serving.grams).toStringAsFixed(1)}g',
                      style: TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onAdd, child: const Text('Add')),
        ],
      ),
    );
  }
}

class _MacroSummaryItem extends StatelessWidget {
  const _MacroSummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// FIX 2: Value chip uses Flexible instead of fixed SizedBox(width: 70)
class _MacroProgressIndicator extends StatelessWidget {
  const _MacroProgressIndicator({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
    this.valueLabel,
  });

  final String label;
  final double current;
  final double goal;
  final Color color;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final percentage = goal > 0 ? (current / goal * 100).clamp(0, 150) : 0.0;

    Color statusColor;
    if (percentage > 130) {
      statusColor = AppColors.statusOver;
    } else if (percentage > 110) {
      statusColor = AppColors.statusNear;
    } else if (percentage >= 90) {
      statusColor = AppColors.statusGood;
    } else if (percentage >= 80) {
      statusColor = AppColors.statusUnder;
    } else {
      statusColor = AppColors.statusNone;
    }

    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.progressTrack,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (percentage / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 32,
          child: Text(
            '${percentage.toInt()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
        if (valueLabel != null) ...[
          const SizedBox(width: 4),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                valueLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FoodRow {
  final String id;
  final String mealType;
  final String name;
  final String amount;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double massG;
  final DateTime consumedAt;

  const _FoodRow({
    required this.id,
    required this.mealType,
    required this.name,
    required this.amount,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.massG,
    required this.consumedAt,
  });

  _FoodRow copyWith({
    String? name,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return _FoodRow(
      id: id,
      mealType: mealType,
      name: name ?? this.name,
      amount: amount,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber,
      massG: massG,
      consumedAt: consumedAt,
    );
  }
}

class _ThirtyDayGoalStats {
  final double caloriePoints;
  final double proteinPoints;
  final double carbsPoints;
  final double fatPoints;
  final int perfectDays;

  const _ThirtyDayGoalStats({
    required this.caloriePoints,
    required this.proteinPoints,
    required this.carbsPoints,
    required this.fatPoints,
    required this.perfectDays,
  });
}

class _StatChip extends StatelessWidget {
  final String label;
  final double points;

  const _StatChip({required this.label, required this.points});

  @override
  Widget build(BuildContext context) {
    final formatted = points % 1 == 0
        ? points.toInt().toString()
        : points.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.selectionColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $formatted pts',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _MonthlyCalendarPicker extends StatefulWidget {
  final DateTime focusedDay;
  final Function(DateTime) onDateSelected;

  const _MonthlyCalendarPicker({
    required this.focusedDay,
    required this.onDateSelected,
  });

  @override
  State<_MonthlyCalendarPicker> createState() => _MonthlyCalendarPickerState();
}

class _MonthlyCalendarPickerState extends State<_MonthlyCalendarPicker> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(widget.focusedDay.year, widget.focusedDay.month);
  }

  List<List<DateTime?>> _getWeeksInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final startDate = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    final weeks = <List<DateTime?>>[];
    var currentDate = startDate;

    while (currentDate.isBefore(lastDay) ||
        currentDate.month == lastDay.month) {
      final week = <DateTime?>[];
      for (int i = 0; i < 7; i++) {
        if (currentDate.month == month.month) {
          week.add(currentDate);
        } else {
          week.add(null);
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }
      weeks.add(week);

      if (currentDate.month != month.month && currentDate.day > 7) {
        break;
      }
    }

    return weeks;
  }

  DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  bool _isInFocusedWeek(DateTime date) {
    final focusedMonday = _getMondayOfWeek(widget.focusedDay);
    final dateMonday = _getMondayOfWeek(date);
    return focusedMonday == dateMonday;
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _getWeeksInMonth(_displayMonth);
    final now = DateTime.now();

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: AppColors.navBar,
                  onPressed: () {
                    setState(() {
                      _displayMonth = DateTime(
                        _displayMonth.year,
                        _displayMonth.month - 1,
                      );
                    });
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_displayMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navBar,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: AppColors.navBar,
                  onPressed: () {
                    setState(() {
                      _displayMonth = DateTime(
                        _displayMonth.year,
                        _displayMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _DayHeader('Mon'),
                _DayHeader('Tue'),
                _DayHeader('Wed'),
                _DayHeader('Thu'),
                _DayHeader('Fri'),
                _DayHeader('Sat'),
                _DayHeader('Sun'),
              ],
            ),
            const SizedBox(height: 8),
            ...weeks.map((week) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: week.map((date) {
                    if (date == null) {
                      return const SizedBox(width: 32, height: 32);
                    }

                    final isToday =
                        date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day;
                    final isInFocusedWeek = _isInFocusedWeek(date);

                    return GestureDetector(
                      onTap: () {
                        final monday = _getMondayOfWeek(date);
                        widget.onDateSelected(monday);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isInFocusedWeek
                              ? AppColors.selectionColor
                              : isToday
                              ? AppColors.selectionColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isInFocusedWeek
                              ? Border.all(
                                  color: AppColors.selectionColor,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isInFocusedWeek
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isInFocusedWeek
                                  ? AppColors.surface
                                  : isToday
                                  ? AppColors.selectionColor
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navBar,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(color: AppColors.surface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;

  const _DayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}

class _ScheduledMealCard extends ConsumerWidget {
  final PlannedFood meal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduledMealCard({
    required this.meal,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeByIdProvider(meal.recipeId));

    return recipeAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (recipe) {
        final recipeName = (recipe['label'] ?? 'Unknown').toString();
        final calories = (recipe['calories'] ?? 0).toDouble();
        final protein = (recipe['protein'] ?? 0).toDouble();
        final carbs = (recipe['carbs'] ?? 0).toDouble();
        final fat = (recipe['fat'] ?? 0).toDouble();
        final dayLabel = DateFormat('MMMM d, yyyy').format(meal.date);

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    _ScheduledMealDetailScreen(meal: meal, recipe: recipe),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface,
                  AppColors.warmLight.withValues(alpha: 0.65),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warmBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mealText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${meal.mealType.toUpperCase()} • $dayLabel',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: AppColors.warmDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _confirmAndLogScheduledMeal(
                            context: context,
                            ref: ref,
                            recipeName: recipeName,
                            calories: calories,
                            protein: protein,
                            carbs: carbs,
                            fat: fat,
                            dayLabel: dayLabel,
                          ),
                          icon: Icon(
                            Icons.playlist_add_check_rounded,
                            color: AppColors.accentBrown,
                          ),
                          tooltip: 'Log meal',
                        ),
                        IconButton(
                          onPressed: onEdit,
                          icon: Icon(
                            Icons.edit,
                            size: 20,
                            color: AppColors.warmDarker,
                          ),
                          tooltip: 'Edit scheduled meal',
                        ),
                        IconButton(
                          onPressed: onDelete,
                          icon: Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          tooltip: 'Remove scheduled meal',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _scheduledMacroStatTile(
                        label: 'Calories',
                        value: calories.toStringAsFixed(0),
                        unit: 'Cal',
                        color: AppColors.caloriesCircle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _scheduledMacroStatTile(
                        label: 'Protein',
                        value: protein.toStringAsFixed(1),
                        unit: 'g',
                        color: AppColors.protein,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _scheduledMacroStatTile(
                        label: 'Carbs',
                        value: carbs.toStringAsFixed(1),
                        unit: 'g',
                        color: AppColors.carbs,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _scheduledMacroStatTile(
                        label: 'Fat',
                        value: fat.toStringAsFixed(1),
                        unit: 'g',
                        color: AppColors.fat,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.selectionColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to view ingredients and instructions',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.selectionColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAndLogScheduledMeal({
    required BuildContext context,
    required WidgetRef ref,
    required String recipeName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required String dayLabel,
  }) async {
    final shouldLog = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log scheduled meal?'),
          content: Text(
            'Are you sure you want to add meal "$recipeName" scheduled for day $dayLabel?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, log meal'),
            ),
          ],
        );
      },
    );

    if (shouldLog != true) return;

    final userId = ref.read(authServiceProvider)?.uid;
    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to log meals.')),
        );
      }
      return;
    }

    final item = FoodItem(
      id: 'scheduled-${DateTime.now().microsecondsSinceEpoch}',
      name: recipeName,
      mass_g: 1.0,
      calories_g: calories,
      protein_g: protein,
      carbs_g: carbs,
      fat: fat,
      mealType: meal.mealType.toLowerCase(),
      consumedAt: DateTime(meal.date.year, meal.date.month, meal.date.day, 12),
    );

    await ref
        .read(firestoreFoodLogProvider(userId).notifier)
        .addFood(userId, item);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$recipeName" logged to your food history.')),
    );
  }

  Widget _scheduledMacroStatTile({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warmBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$value $unit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduledMealDetailScreen extends StatelessWidget {
  final PlannedFood meal;
  final Map<String, dynamic> recipe;

  const _ScheduledMealDetailScreen({required this.meal, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final recipeName = (recipe['label'] ?? 'Recipe').toString();
    final ingredients = _parseIngredients(recipe['ingredients']);
    final instructions = _parseInstructions(recipe['instructions']);
    const baseColor = AppColors.recipeSurface;
    final cardColor = AppColors.surface.withValues(alpha: 0.05);

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        backgroundColor: baseColor,
        foregroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Recipe Details'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.recipeOverlayHigh,
                      AppColors.recipeOverlayMid,
                      AppColors.recipeOverlayFade,
                    ],
                    stops: [0.0, 0.34, 0.62],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.surface.withValues(alpha: 0.14),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      recipeName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 48,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.recipeText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meal.mealType.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navBar,
                      ),
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 700;
                        if (isWide) {
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _IngredientsSection(
                                    ingredients: ingredients,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  width: 1.5,
                                  color: AppColors.black.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                                Expanded(
                                  child: _InstructionsSection(
                                    instructions: instructions,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IngredientsSection(ingredients: ingredients),
                            const SizedBox(height: 16),
                            Container(
                              height: 1.5,
                              color: AppColors.surface.withValues(alpha: 0.18),
                            ),
                            const SizedBox(height: 16),
                            _InstructionsSection(instructions: instructions),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _parseIngredients(dynamic rawIngredients) {
    if (rawIngredients is List) {
      return rawIngredients
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (rawIngredients is String && rawIngredients.trim().isNotEmpty) {
      return rawIngredients
          .split('\n')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<String> _parseInstructions(dynamic rawInstructions) {
    if (rawInstructions is! String || rawInstructions.trim().isEmpty) {
      return const [];
    }

    final normalized = rawInstructions.replaceAll('\r\n', '\n').trim();
    final numberedRegex = RegExp(r'^\s*(\d+)[.)]\s+', multiLine: true);
    if (numberedRegex.hasMatch(normalized)) {
      return normalized
          .split(RegExp(r'\n(?=\s*\d+[.)]\s+)'))
          .map((line) => line.replaceFirst(RegExp(r'^\s*\d+[.)]\s+'), ''))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }

    return normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

class _IngredientsSection extends StatelessWidget {
  final List<String> ingredients;

  const _IngredientsSection({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RecipeSectionTitle('Ingredients'),
        const SizedBox(height: 12),
        if (ingredients.isEmpty)
          const Text(
            'No ingredients available.',
            style: TextStyle(color: AppColors.recipeSubtext, fontSize: 18),
          )
        else
          ...ingredients.map(
            (ingredient) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Icon(
                      Icons.circle,
                      size: 10,
                      color: AppColors.recipeAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ingredient,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.35,
                        color: AppColors.recipeBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InstructionsSection extends StatelessWidget {
  final List<String> instructions;

  const _InstructionsSection({required this.instructions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RecipeSectionTitle('Instructions'),
        const SizedBox(height: 12),
        if (instructions.isEmpty)
          const Text(
            'No instructions available.',
            style: TextStyle(color: AppColors.recipeSubtext, fontSize: 18),
          )
        else
          ...instructions.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.recipeAccent,
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: AppColors.surface,
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.35,
                        color: AppColors.recipeBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RecipeSectionTitle extends StatelessWidget {
  final String label;

  const _RecipeSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 42,
        height: 1,
        fontWeight: FontWeight.w800,
        color: AppColors.recipeAccent,
      ),
    );
  }
}

class _ScheduledMealEditResult {
  final DateTime date;
  final String mealType;

  const _ScheduledMealEditResult({required this.date, required this.mealType});
}

class _AddSearchResultDialog extends ConsumerStatefulWidget {
  final FoodSearchResult result;
  final DateTime day;
  final String userId;

  const _AddSearchResultDialog({
    required this.result,
    required this.day,
    required this.userId,
  });

  @override
  ConsumerState<_AddSearchResultDialog> createState() =>
      _AddSearchResultDialogState();
}

class _AddSearchResultDialogState
    extends ConsumerState<_AddSearchResultDialog> {
  late final bool _hasExplicitServingOptions;
  late final List<FoodServingOption> _availableServings;
  late FoodServingOption _selectedServing;
  late final TextEditingController _gramsController;
  String _mealType = 'snack';
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _hasExplicitServingOptions = widget.result.servingOptions.isNotEmpty;
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
    _gramsController.dispose();
    super.dispose();
  }

  Future<void> _closeDialog([bool? result]) async {
    // Ensure any active text input detaches before this route is removed.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).pop(result);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.result.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _mealType,
              decoration: const InputDecoration(labelText: 'Meal type'),
              items: const [
                DropdownMenuItem(value: 'breakfast', child: Text('Breakfast')),
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
            const SizedBox(height: 8),
            if (_hasExplicitServingOptions) ...[
              if (_availableServings.length > 1) ...[
                DropdownButtonFormField<FoodServingOption>(
                  value: _selectedServing,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Serving size'),
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
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<int>(
                value: _quantity,
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total: ${(_selectedServing.grams * _quantity).toStringAsFixed(0)} g',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ),
            ] else
              TextField(
                controller: _gramsController,
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
                  setState(() {});
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await _closeDialog(false);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _handleAdd, child: const Text('Add')),
      ],
    );
  }

  Future<void> _handleAdd() async {
    final grams = _hasExplicitServingOptions
        ? _selectedServing.grams * _quantity
        : double.tryParse(_gramsController.text.trim());
    if (grams == null || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid grams value.')),
      );
      return;
    }

    final consumedAt = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      12,
    );

    final item = FoodItem(
      id: 'search-${DateTime.now().microsecondsSinceEpoch}',
      name: widget.result.name,
      mass_g: grams,
      calories_g: _selectedServing.caloriesPerGram,
      protein_g: _selectedServing.proteinPerGram,
      carbs_g: _selectedServing.carbsPerGram,
      fat: _selectedServing.fatPerGram,
      mealType: _mealType,
      consumedAt: consumedAt,
    );

    try {
      await ref
          .read(firestoreFoodLogProvider(widget.userId).notifier)
          .addFood(widget.userId, item);
      if (!mounted) return;
      await _closeDialog(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
      }
    }
  }
}
