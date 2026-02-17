import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import '../providers/user_providers.dart';
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

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
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
            meal: item.mealType,
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

  double _percentError(double actual, double target) {
    if (target <= 0) return 0;
    return ((actual - target).abs()) / target;
  }

  _NutritionGrade _calculateNutritionGrade({
    required Map<String, double> totals,
    required Map<String, double> goals,
  }) {
    final calError = _percentError(
      totals['calories'] ?? 0,
      goals['calories'] ?? 0,
    );
    final proteinError = _percentError(
      totals['protein'] ?? 0,
      goals['protein'] ?? 0,
    );
    final carbsError = _percentError(totals['carbs'] ?? 0, goals['carbs'] ?? 0);
    final fatError = _percentError(totals['fat'] ?? 0, goals['fat'] ?? 0);

    // Weighted equally by 0.25 as specified.
    final overallError =
        0.25 * (calError + proteinError + carbsError + fatError);
    final percent = overallError * 100;
    final letter = _gradeLetterForError(overallError);
    return _NutritionGrade(
      letter: letter,
      errorPercent: percent,
      color: _gradeColor(letter),
    );
  }

  String _gradeLetterForError(double overallError) {
    if (overallError <= 0.05) return 'S';
    if (overallError <= 0.10) return 'A';
    if (overallError <= 0.15) return 'B';
    if (overallError <= 0.20) return 'C';
    if (overallError <= 0.25) return 'D';
    return 'F';
  }

  Color _gradeColor(String letter) {
    switch (letter) {
      case 'S':
        return const Color(0xFF2E7D32);
      case 'A':
        return const Color(0xFF4CAF50);
      case 'B':
        return const Color(0xFF8BC34A);
      case 'C':
        return const Color(0xFFFFB300);
      case 'D':
        return const Color(0xFFFF7043);
      case 'F':
      default:
        return const Color(0xFFE53935);
    }
  }

  void _addPlaceholderApple() {
    final authUser = ref.read(authServiceProvider);
    final userId = authUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add meals.')),
      );
      return;
    }

    final firestoreLog = ref.read(firestoreFoodLogProvider(userId).notifier);
    final day = _selectedDay ?? _focusedDay;
    final consumedAt = DateTime(day.year, day.month, day.day, 12);
    final item = FoodItem(
      id: 'apple-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Apple',
      mass_g: 150,
      calories_g: 0.52,
      protein_g: 0.0027,
      carbs_g: 0.14,
      fat: 0.0013,
      mealType: 'snack',
      consumedAt: consumedAt,
    );

    firestoreLog.addFood(userId, item);
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

                return StatefulBuilder(
                  builder: (context, setSheetState) {
                    final History = segment == 0;
                    final Scheduled = segment == 1;

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
                              children: const {
                                0: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 14,
                                  ),
                                  child: Text('History'),
                                ),
                                1: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 14,
                                  ),
                                  child: Text('Scheduled'),
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
                              future: _scheduledTotals(scheduledMeals, ref),
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
                            if (Scheduled) ...[
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
                                    onDelete: () async {
                                      if (meal.id != null) {
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
                                      }
                                    },
                                  ),
                            ] else ...[
                              Text(
                                'Logged Foods',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setSheetState(
                                    () => segment = 1,
                                  ); // ✅ switch to Scheduled tab
                                },
                                icon: const Icon(Icons.schedule),
                                label: const Text('View Scheduled Meals'),
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
                                      mealType: updatedRow.meal,
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
                                      _showAddMealDialog(day, userId),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add meal'),
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

  Future<void> _showAddMealDialog(DateTime day, String userId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddMealModal(day: day, userId: userId),
    );
  }

  void _checkAndShowNotifications(
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

  String _getMacroNotificationMessage(
    List<FoodItem> foodLog,
    Map<String, double> goals,
    String userId,
  ) {
    final now = DateTime.now();
    final dayTotals = _totalsForDay(now, foodLog);
    final remaining = NotificationService.calculateRemainingMacros(
      currentTotals: dayTotals,
      goals: goals,
    );
    return NotificationService.getMacroReminderMessage(remaining);
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = _selectedDay ?? _focusedDay;
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowNotifications(foodLog, goals, userId);
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
                      IconButton(
                        icon: const Icon(Icons.add),
                        color: Colors.redAccent,
                        tooltip: 'Add apple to selected day',
                        onPressed: _addPlaceholderApple,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: weekDays.map((day) {
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
                      final dayTotals = _totalsForDay(day, foodLog);
                      final grade = isFutureDay
                          ? null
                          : _calculateNutritionGrade(
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.selectionColor
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
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
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isToday
                                            ? const Color(
                                                0xFF6DCFF6,
                                              ).withValues(alpha: 0.2)
                                            : Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isToday
                                              ? AppColors.selectionColor
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (grade != null)
                                      Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: grade.color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: grade.color.withValues(
                                              alpha: 0.45,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          grade.letter,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 26, height: 26),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Meals summary
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      foods.isEmpty
                                          ? 'No meals logged'
                                          : '${foods.length} meal${foods.length != 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: foods.isEmpty
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                        color: foods.isEmpty
                                            ? Colors.grey.shade500
                                            : Colors.black87,
                                        fontStyle: foods.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                    if (grade != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Grade ${grade.letter}  (${grade.errorPercent.toStringAsFixed(1)}% error)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: grade.color,
                                        ),
                                      ),
                                    ],
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

class _AddMealModal extends ConsumerStatefulWidget {
  final DateTime day;
  final String userId;

  const _AddMealModal({required this.day, required this.userId});

  @override
  ConsumerState<_AddMealModal> createState() => _AddMealModalState();
}

class _AddMealModalState extends ConsumerState<_AddMealModal> {
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
        ).showSnackBar(SnackBar(content: Text('Failed to add meal: $e')));
      }
    }
  }

  Future<void> _addSearchResult(FoodSearchResult result) async {
    final rootContext = context;

    await showDialog<void>(
      context: rootContext,
      builder: (dialogContext) {
        return _AddSearchResultDialog(
          result: result,
          day: widget.day,
          userId: widget.userId,
          onSuccess: () {
            Navigator.pop(rootContext);
          },
        );
      },
    );
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
                                    ? Colors.white
                                    : AppColors.accentBrown,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Search Online',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _isSearchMode
                                      ? Colors.white
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
                                    ? Colors.white
                                    : AppColors.accentBrown,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Manual Entry',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: !_isSearchMode
                                      ? Colors.white
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) {
            setState(() {});
            _onSearchQueryChanged(value);
          },
          onSubmitted: _runSearch,
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
              style: TextStyle(color: Colors.red.shade400, fontSize: 12),
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
              foregroundColor: Colors.white,
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

class _MiniMacroChip extends StatelessWidget {
  const _MiniMacroChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
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
    if (overlay == null) return;

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
                color: isError ? Colors.red.shade700 : AppColors.navBar,
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
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
          title: const Text('Delete meal?'),
          content: Text('Remove "${widget.row.name}" from this day?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

  Widget _macroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _macroStatTile({
    required String label,
    required Color color,
    required bool isEditing,
    required TextEditingController controller,
    required String value,
    required String unit,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isEditing ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing
              ? color.withValues(alpha: 0.45)
              : Colors.brown.shade100,
        ),
        boxShadow: isEditing
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.brown.shade50.withValues(alpha: 0.65)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.brown.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                              color: Colors.brown.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.brown.shade300),
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
                                  color: Color(0xFF2E221A),
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
                                  color: Color(0xFF2E221A),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${widget.row.meal.toUpperCase()} • ${widget.row.amount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: Colors.brown.shade600,
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
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                    ),
                    tooltip: 'Remove meal',
                  ),
                  IconButton(
                    onPressed: _isEditing
                        ? _saveEdits
                        : () => setState(() => _isEditing = true),
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.edit,
                      size: 20,
                      color: Colors.brown.shade700,
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
                  color: const Color(0xFF5F9735),
                  isEditing: _isEditing,
                  controller: _calController,
                  value: widget.row.calories.toStringAsFixed(0),
                  unit: 'kcal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroStatTile(
                  label: 'Protein',
                  color: const Color(0xFFC2482B),
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
                  color: const Color(0xFFE0A100),
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
                  color: const Color(0xFF3A6FB8),
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
    final calories = (result.caloriesPerGram * result.servingGrams).round();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  '${result.servingGrams.toStringAsFixed(0)} g · $calories Cal',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      'P ${(result.proteinPerGram * result.servingGrams).toStringAsFixed(1)}g',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'C ${(result.carbsPerGram * result.servingGrams).toStringAsFixed(1)}g',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'F ${(result.fatPerGram * result.servingGrams).toStringAsFixed(1)}g',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  result.sourceLabel,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
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
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _FoodsTable extends StatelessWidget {
  const _FoodsTable({required this.date, required this.rows});

  final DateTime date;
  final List<_FoodRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          border: TableBorder.all(
            color: AppColors.accentBrown.withValues(alpha: 0.3),
          ),
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.5),
            4: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: AppColors.inputFill),
              children: const [
                _TableCellText('Food', isHeader: true),
                _TableCellText('Cal', isHeader: true),
                _TableCellText('Pro', isHeader: true),
                _TableCellText('Carb', isHeader: true),
                _TableCellText('Fat', isHeader: true),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  _TableCellText(row.name),
                  _TableCellText('${row.calories.toInt()}'),
                  _TableCellText('${row.protein.toStringAsFixed(1)}g'),
                  _TableCellText('${row.carbs.toStringAsFixed(1)}g'),
                  _TableCellText('${row.fat.toStringAsFixed(1)}g'),
                ],
              ),
          ],
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
      statusColor = Colors.red;
    } else if (percentage > 110) {
      statusColor = Colors.yellow.shade700;
    } else if (percentage >= 90) {
      statusColor = Colors.green;
    } else if (percentage >= 80) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.grey;
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
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
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
  final String meal;
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
    required this.meal,
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
      meal: meal,
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

class _NutritionGrade {
  final String letter;
  final double errorPercent;
  final Color color;

  const _NutritionGrade({
    required this.letter,
    required this.errorPercent,
    required this.color,
  });
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.suffix,
  });

  final String label;
  final double value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: ${value.toStringAsFixed(1)}$suffix'),
      backgroundColor: AppColors.inputFill,
      shape: const StadiumBorder(),
    );
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText(this.text, {this.isHeader = false});
  final String text;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
          color: AppColors.accentBrown,
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
                                  ? Colors.white
                                  : isToday
                                  ? AppColors.selectionColor
                                  : Colors.black87,
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
                  style: TextStyle(color: Colors.white),
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
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _ScheduledMealCard extends ConsumerWidget {
  final PlannedFood meal;
  final VoidCallback onDelete;

  const _ScheduledMealCard({required this.meal, required this.onDelete});

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
              color: AppColors.selectionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.selectionColor.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.selectionColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.schedule,
                    color: AppColors.selectionColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipeName, // show recipe name
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Meal Type: ${meal.mealType.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _MacroChip(
                            label: 'Calories',
                            value: calories,
                            suffix: 'kcal',
                          ),
                          _MacroChip(
                            label: 'Protein',
                            value: protein,
                            suffix: 'g',
                          ),
                          _MacroChip(label: 'Carbs', value: carbs, suffix: 'g'),
                          _MacroChip(label: 'Fat', value: fat, suffix: 'g'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to view ingredients and instructions',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.selectionColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.selectionColor),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  tooltip: 'Remove scheduled meal',
                ),
              ],
            ),
          ),
        );
      },
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
    const baseColor = Color(0xFF181818);
    const cardColor = Color.fromRGBO(255, 255, 255, 0.05);
    const accentColor = Color(0xFF5D8A73);

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        backgroundColor: baseColor,
        foregroundColor: Colors.white,
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
                      Color(0xAA2A3A33),
                      Color(0x2A2A3A33),
                      Color(0x00181818),
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
                    color: Colors.white.withValues(alpha: 0.14),
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
                        color: Color(0xFFF2F4F7),
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
                        color: accentColor,
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
                                  color: Colors.white.withValues(alpha: 0.18),
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
                              color: Colors.white.withValues(alpha: 0.18),
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
            style: TextStyle(color: Color(0xFFB8C0CC), fontSize: 18),
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
                      color: Color(0xFF5D8A73),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ingredient,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.35,
                        color: Color(0xFFE9EDF4),
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
            style: TextStyle(color: Color(0xFFB8C0CC), fontSize: 18),
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
                      color: Color(0xFF5D8A73),
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
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
                        color: Color(0xFFE9EDF4),
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
        color: Color(0xFF5D8A73),
      ),
    );
  }
}

class _AddSearchResultDialog extends ConsumerStatefulWidget {
  final FoodSearchResult result;
  final DateTime day;
  final String userId;
  final VoidCallback onSuccess;

  const _AddSearchResultDialog({
    required this.result,
    required this.day,
    required this.userId,
    required this.onSuccess,
  });

  @override
  ConsumerState<_AddSearchResultDialog> createState() =>
      _AddSearchResultDialogState();
}

class _AddSearchResultDialogState
    extends ConsumerState<_AddSearchResultDialog> {
  late final TextEditingController _gramsController;
  late final FocusNode _gramsFocusNode;
  String _mealType = 'snack';

  @override
  void initState() {
    super.initState();
    _gramsController = TextEditingController(
      text: widget.result.servingGrams.toStringAsFixed(0),
    );
    _gramsFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _gramsController.dispose();
    _gramsFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.result.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _mealType,
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
          TextField(
            controller: _gramsController,
            focusNode: _gramsFocusNode,
            decoration: InputDecoration(
              labelText: 'Grams',
              suffixIcon: IconButton(
                tooltip: 'Done',
                icon: const Icon(Icons.check),
                onPressed: () => FocusScope.of(context).unfocus(),
              ),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Source: ${widget.result.sourceLabel}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _handleAdd, child: const Text('Add')),
      ],
    );
  }

  Future<void> _handleAdd() async {
    final grams = double.tryParse(_gramsController.text.trim());
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
      calories_g: widget.result.caloriesPerGram,
      protein_g: widget.result.proteinPerGram,
      carbs_g: widget.result.carbsPerGram,
      fat: widget.result.fatPerGram,
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
      widget.onSuccess();
      messenger.showSnackBar(
        SnackBar(content: Text('Added "${widget.result.name}"')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
      }
    }
  }
}
