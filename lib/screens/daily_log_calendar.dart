import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_providers.dart';

class DailyLogCalendarScreen extends ConsumerStatefulWidget {
  const DailyLogCalendarScreen({super.key});

  @override
  ConsumerState<DailyLogCalendarScreen> createState() =>
      _DailyLogCalendarScreenState();
}

class _DailyLogCalendarScreenState
    extends ConsumerState<DailyLogCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Mock data: replace with your DailyLog + meals/foods from Firestore
  final Map<DateTime, List<_FoodRow>> _logs = {
    DateTime.utc(2026, 12, 6): const [
      _FoodRow(
        meal: 'Breakfast',
        name: 'Apple',
        amount: '150 g',
        calories: 78,
        protein: 0.4,
        carbs: 21,
        fat: 0.2,
        fiber: 3.6,
      ),
      _FoodRow(
        meal: 'Breakfast',
        name: 'Bread',
        amount: '28 g',
        calories: 74,
        protein: 2.6,
        carbs: 14,
        fat: 1.0,
        fiber: 0.6,
      ),
      _FoodRow(
        meal: 'Breakfast',
        name: 'Banana',
        amount: '118 g',
        calories: 105,
        protein: 1.3,
        carbs: 27,
        fat: 0.4,
        fiber: 3.1,
      ),
    ],
  };

  List<_FoodRow> _foodsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _logs[key] ?? const [];
  }

  Map<String, double> _totalsForDay(DateTime day) {
    final rows = _foodsForDay(day);
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

  void _addPlaceholderApple() {
    final day = _selectedDay ?? _focusedDay;
    final key = DateTime.utc(day.year, day.month, day.day);
    final updated = List<_FoodRow>.from(_logs[key] ?? const []);
    updated.add(const _FoodRow(
      meal: 'Snack',
      name: 'Apple',
      amount: '150 g',
      calories: 78,
      protein: 0.4,
      carbs: 21,
      fat: 0.2,
      fiber: 3.6,
    ));
    setState(() {
      _logs[key] = updated;
    });
  }

  void _showFoodsSheet(DateTime day) {
    final rows = _foodsForDay(day);
    final totals = _totalsForDay(day);
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
                            value: '${totals['fat']?.toStringAsFixed(1) ?? 0}g',
                          ),
                          _MacroSummaryItem(
                            label: 'Fiber',
                            value:
                                '${totals['fiber']?.toStringAsFixed(1) ?? 0}g',
                          ),
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
                      _FoodsList(rows: rows),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = _selectedDay ?? _focusedDay;
    final userProfile = ref.watch(userProfileNotifierProvider);

    // Mock goals if user profile not loaded - replace with actual user goals
    final calorieGoal =
        userProfile?.mealProfile.dailyCalorieGoal.toDouble() ?? 2000.0;
    final proteinGoal = userProfile?.mealProfile.macroGoals['protein'] ?? 150.0;
    final carbsGoal = userProfile?.mealProfile.macroGoals['carbs'] ?? 200.0;
    final fatGoal = userProfile?.mealProfile.macroGoals['fat'] ?? 65.0;

    // Get the week start (Monday) for the focused day
    final weekStart =
        _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    final weekDays =
        List.generate(7, (index) => weekStart.add(Duration(days: index)));

    return Scaffold(
      backgroundColor: const Color(0xFFF6E9D8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6E9D8),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true,
        title: const Text('History', style: TextStyle(color: Colors.black87)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: Colors.black87,
            tooltip: 'Previous week',
            onPressed: () {
              setState(() {
                _focusedDay = _focusedDay.subtract(const Duration(days: 7));
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: Colors.black87,
            tooltip: 'Next week',
            onPressed: () {
              setState(() {
                _focusedDay = _focusedDay.add(const Duration(days: 7));
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            color: Colors.redAccent,
            tooltip: 'Add apple to selected day',
            onPressed: _addPlaceholderApple,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.calendar_month, color: Colors.redAccent),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Week navigation header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '${DateFormat('MMMM yyyy').format(_focusedDay)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // 7-day blocks
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
                  final foods = _foodsForDay(day);
                  final dayTotals = _totalsForDay(day);

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
                      _showFoodsSheet(day);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 8),
                      padding: const EdgeInsets.all(16),
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
                          // Indicator dot
                          if (foods.isNotEmpty)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
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

class _FoodsList extends StatelessWidget {
  const _FoodsList({required this.rows});

  final List<_FoodRow> rows;

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
            return Container(
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
                  Text(
                    row.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
            width: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                valueLabel!,
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
  final String meal;
  final String name;
  final String amount;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const _FoodRow({
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
