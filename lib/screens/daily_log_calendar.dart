import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_providers.dart';
import '../providers/food_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/firestore_providers.dart';
import '../db/food.dart';
import '../db/user.dart';
import 'package:nutrition_assistant/navigation/nav_helper.dart';
import 'package:nutrition_assistant/widgets/nav_bar.dart';

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

  Widget _wrapWithScaffold(Widget body) {
    if (widget.isInPageView == true) {
      return body;
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5EDE2),
      body: body,
      bottomNavigationBar: NavBar(
        currentIndex: navIndexHistory,
        onTap: (index) => handleNavTap(context, index),
      ),
    );
  }

  List<_FoodRow> _foodsForDay(DateTime day, List<FoodItem> log) {
    final rows = <_FoodRow>[];
    for (final item in log) {
      if (item.consumedAt.year == day.year &&
          item.consumedAt.month == day.month &&
          item.consumedAt.day == day.day) {
        final calories = item.calories_g * item.mass_g;
        final protein = item.protein_g * item.mass_g;
        final carbs = item.carbs_g * item.mass_g;
        final fat = item.fat * item.mass_g;

        rows.add(_FoodRow(
          id: item.id,
          meal: item.mealType,
          name: item.name,
          amount: '${item.mass_g.toStringAsFixed(0)} g',
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: 0,
        ));
      }
    }
    return rows;
  }

  Map<String, double> _totalsForDay(DateTime day, List<FoodItem> log) {
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
                // Live-filter the latest stream so the sheet updates immediately after deletes
                final logAsync = ref.watch(firestoreFoodLogProvider(userId));
                final rows = logAsync.maybeWhen(
                  data: (log) => _foodsForDay(day, log),
                  orElse: () => initialRows,
                );
                final totals = logAsync.maybeWhen(
                  data: (log) => _totalsForDay(day, log),
                  orElse: () => initialTotals,
                );

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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.brown.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.brown.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _MacroSummaryItem(
                                label: 'Cal',
                                value: '${totals['calories']?.toInt() ?? 0}',
                              ),
                              _MacroSummaryItem(
                                label: 'Prot',
                                value:
                                    '${totals['protein']?.toStringAsFixed(1) ?? 0}g',
                              ),
                              _MacroSummaryItem(
                                label: 'Carbs',
                                value:
                                    '${totals['carbs']?.toStringAsFixed(1) ?? 0}g',
                              ),
                              _MacroSummaryItem(
                                label: 'Fat',
                                value:
                                    '${totals['fat']?.toStringAsFixed(1) ?? 0}g',
                              ),
                              /*_MacroSummaryItem(
                                label: 'Fiber',
                                value:
                                    '${totals['fiber']?.toStringAsFixed(1) ?? 0}g',
                              ),*/
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                  'UI delete tap: user=$userId foodId=$foodId day=${day.toIso8601String()}');
                              await ref
                                  .read(
                                      firestoreFoodLogProvider(userId).notifier)
                                  .removeFood(userId, foodId);
                            },
                          ),
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
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = _selectedDay ?? _focusedDay;
    final authUser = ref.watch(authServiceProvider);
    final userId = authUser?.uid;
    if (userId == null) {
      return _wrapWithScaffold(
        const SafeArea(
          child: Center(
            child: Text('Sign in to view your meal log.'),
          ),
        ),
      );
    }

    final foodLogAsync = ref.watch(firestoreFoodLogProvider(userId));
    final userProfileAsync = ref.watch(firestoreUserProfileProvider(userId));
    final goals = _goalsFromProfile(userProfileAsync.value);
    final calorieGoal = goals['calories'] ?? 2000.0;
    final proteinGoal = goals['protein'] ?? 150.0;
    final carbsGoal = goals['carbs'] ?? 200.0;
    final fatGoal = goals['fat'] ?? 65.0;

    // Get the week start (Monday) for the focused day
    final weekStart =
        _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    final weekDays =
        List.generate(7, (index) => weekStart.add(Duration(days: index)));

    return foodLogAsync.when(
      error: (e, _) => _wrapWithScaffold(
        SafeArea(
          child: Center(child: Text('Failed to load meals: $e')),
        ),
      ),
      loading: () => _wrapWithScaffold(
        const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      data: (foodLog) => _wrapWithScaffold(
        SafeArea(
          child: Column(
            children: [
              // Week navigation controls
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      color: const Color(0xFF3E2F26),
                      tooltip: 'Previous week',
                      onPressed: () {
                        setState(() {
                          _focusedDay =
                              _focusedDay.subtract(const Duration(days: 7));
                        });
                      },
                    ),
                    GestureDetector(
                      onTap: _showMonthlyCalendarPicker,
                      child: Text(
                        '${DateFormat('MMMM yyyy').format(_focusedDay)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3E2F26),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          color: const Color(0xFF3E2F26),
                          tooltip: 'Next week',
                          onPressed: () {
                            setState(() {
                              _focusedDay =
                                  _focusedDay.add(const Duration(days: 7));
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
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: weekDays.map((day) {
                    final isSelected = _selectedDay != null &&
                        day.year == _selectedDay!.year &&
                        day.month == _selectedDay!.month &&
                        day.day == _selectedDay!.day;
                    final isToday = day.year == DateTime.now().year &&
                        day.month == DateTime.now().month &&
                        day.day == DateTime.now().day;
                    final foods = _foodsForDay(day, foodLog);
                    final dayTotals = _totalsForDay(day, foodLog);

                    // Calculate average goal completion percentage
                    final calPercentage = calorieGoal > 0
                        ? ((dayTotals['calories'] ?? 0) / calorieGoal * 100)
                        : 0.0;
                    final protPercentage = proteinGoal > 0
                        ? ((dayTotals['protein'] ?? 0) / proteinGoal * 100)
                        : 0.0;
                    final carbsPercentage = carbsGoal > 0
                        ? ((dayTotals['carbs'] ?? 0) / carbsGoal * 100)
                        : 0.0;
                    final fatPercentage = fatGoal > 0
                        ? ((dayTotals['fat'] ?? 0) / fatGoal * 100)
                        : 0.0;
                    final avgPercentage = (calPercentage +
                            protPercentage +
                            carbsPercentage +
                            fatPercentage) /
                        4;

                    // Determine color based on average
                    Color goalIndicatorColor;
                    if (avgPercentage >= 100) {
                      goalIndicatorColor = Colors.green;
                    } else if (avgPercentage >= 80) {
                      goalIndicatorColor = Colors.orange;
                    } else if (avgPercentage >= 50) {
                      goalIndicatorColor = Colors.yellow.shade700;
                    } else {
                      goalIndicatorColor = Colors.grey;
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                        });
                        _showFoodsSheet(day, foods, dayTotals, userId);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6DCFF6)
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
                            // Day indicator
                            Container(
                              width: 48,
                              child: Column(
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
                                          ? const Color(0xFF6DCFF6)
                                              .withValues(alpha: 0.2)
                                          : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isToday
                                            ? const Color(0xFF6DCFF6)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Goal completion indicator circle
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: goalIndicatorColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: goalIndicatorColor.withValues(
                                            alpha: 0.5),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Meals summary
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Show meal count or "No meals"
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
                                  const SizedBox(height: 8),
                                  // Progress indicators with values (always shown)
                                  _MacroProgressIndicator(
                                    label: 'Cal',
                                    current: dayTotals['calories'] ?? 0,
                                    goal: calorieGoal,
                                    color: const Color(0xFF5F9735),
                                    valueLabel:
                                        '${dayTotals['calories']?.toInt() ?? 0} kcal',
                                  ),
                                  const SizedBox(height: 4),
                                  _MacroProgressIndicator(
                                    label: 'Pro',
                                    current: dayTotals['protein'] ?? 0,
                                    goal: proteinGoal,
                                    color: const Color(0xFFC2482B),
                                    valueLabel:
                                        '${dayTotals['protein']?.toStringAsFixed(0) ?? 0}g',
                                  ),
                                  const SizedBox(height: 4),
                                  _MacroProgressIndicator(
                                    label: 'Carb',
                                    current: dayTotals['carbs'] ?? 0,
                                    goal: carbsGoal,
                                    color: const Color(0xFFE0A100),
                                    valueLabel:
                                        '${dayTotals['carbs']?.toStringAsFixed(0) ?? 0}g',
                                  ),
                                  const SizedBox(height: 4),
                                  _MacroProgressIndicator(
                                    label: 'Fat',
                                    current: dayTotals['fat'] ?? 0,
                                    goal: fatGoal,
                                    color: const Color(0xFF3A6FB8),
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
      ),
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
  const _FoodsListWidget({Key? key, required this.rows, required this.onDelete})
      : super(key: key);

  final List<_FoodRow> rows;
  final Future<void> Function(String foodId) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Food Items',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return Material(
              key: ValueKey(row.id),
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.brown.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            row.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.white,
                          child: InkWell(
                            onTap: () async {
                              try {
                                debugPrint(
                                    'Delete button pressed for row: ${row.id}');
                                await onDelete(row.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Removed "${row.name}"'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to remove: $e'),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.close,
                                  size: 18, color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cal: ${row.calories.toInt()}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          'Prot: ${row.protein.toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          'Carbs: ${row.carbs.toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          'Fat: ${row.fat.toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
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
          border: TableBorder.all(color: Colors.brown.shade200),
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.5),
            4: FlexColumnWidth(1.5),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.brown.shade50),
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
    final isComplete = percentage >= 100;
    final isClose = percentage >= 80 && percentage < 100;

    Color statusColor;
    if (isComplete) {
      statusColor = Colors.green;
    } else if (isClose) {
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
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
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
          SizedBox(
            width: 70,
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
  });
}

class _MacroChip extends StatelessWidget {
  const _MacroChip(
      {required this.label, required this.value, required this.suffix});

  final String label;
  final double value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: ${value.toStringAsFixed(1)}$suffix'),
      backgroundColor: Colors.brown.shade50,
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
          color: Colors.brown.shade800,
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

    // Start from the Monday of the first week
    final startDate = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    final weeks = <List<DateTime?>>[];
    var currentDate = startDate;

    while (
        currentDate.isBefore(lastDay) || currentDate.month == lastDay.month) {
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

  // Get the Monday of the week containing the given date
  DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  // Check if the given date is in the focused week
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
            // Month/Year header with navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: const Color(0xFF3E2F26),
                  onPressed: () {
                    setState(() {
                      _displayMonth =
                          DateTime(_displayMonth.year, _displayMonth.month - 1);
                    });
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_displayMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E2F26),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: const Color(0xFF3E2F26),
                  onPressed: () {
                    setState(() {
                      _displayMonth =
                          DateTime(_displayMonth.year, _displayMonth.month + 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Day headers (Mon-Sun)
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
            // Calendar weeks
            ...weeks.map((week) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: week.map((date) {
                    if (date == null) {
                      return const SizedBox(width: 32, height: 32);
                    }

                    final isToday = date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day;
                    final isInFocusedWeek = _isInFocusedWeek(date);

                    return GestureDetector(
                      onTap: () {
                        // Select the Monday of the week
                        final monday = _getMondayOfWeek(date);
                        widget.onDateSelected(monday);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isInFocusedWeek
                              ? const Color(0xFF6DCFF6)
                              : isToday
                                  ? const Color(0xFF6DCFF6)
                                      .withValues(alpha: 0.2)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isInFocusedWeek
                              ? Border.all(
                                  color: const Color(0xFF6DCFF6),
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
                                      ? const Color(0xFF6DCFF6)
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
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3E2F26),
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
