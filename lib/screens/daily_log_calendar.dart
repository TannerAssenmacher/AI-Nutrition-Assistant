import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class DailyLogCalendarScreen extends StatefulWidget {
  const DailyLogCalendarScreen({super.key});

  @override
  State<DailyLogCalendarScreen> createState() => _DailyLogCalendarScreenState();
}

class _DailyLogCalendarScreenState extends State<DailyLogCalendarScreen> {
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MacroChip(
                      label: 'Calories',
                      value: totals['calories'] ?? 0,
                      suffix: ' kcal'),
                  _MacroChip(
                      label: 'Protein',
                      value: totals['protein'] ?? 0,
                      suffix: ' g'),
                  _MacroChip(
                      label: 'Carbs',
                      value: totals['carbs'] ?? 0,
                      suffix: ' g'),
                  _MacroChip(
                      label: 'Fat', value: totals['fat'] ?? 0, suffix: ' g'),
                  _MacroChip(
                      label: 'Fiber',
                      value: totals['fiber'] ?? 0,
                      suffix: ' g'),
                ],
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No entries for this day'),
                )
              else
                _FoodsTable(date: day, rows: rows),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = _selectedDay ?? _focusedDay;
    final totals = _totalsForDay(displayDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF6E9D8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6E9D8),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true, // Ensures back button appears
        title: const Text('History', style: TextStyle(color: Colors.black87)),
        actions: [
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MacroChip(
                      label: 'Calories',
                      value: totals['calories'] ?? 0,
                      suffix: ' kcal'),
                  _MacroChip(
                      label: 'Protein',
                      value: totals['protein'] ?? 0,
                      suffix: ' g'),
                  _MacroChip(
                      label: 'Carbs',
                      value: totals['carbs'] ?? 0,
                      suffix: ' g'),
                  _MacroChip(
                      label: 'Fat', value: totals['fat'] ?? 0, suffix: ' g'),
                  _MacroChip(
                      label: 'Fiber',
                      value: totals['fiber'] ?? 0,
                      suffix: ' g'),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TableCalendar(
                  firstDay: DateTime.utc(2015, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (d) =>
                      _selectedDay != null &&
                      d.year == _selectedDay!.year &&
                      d.month == _selectedDay!.month &&
                      d.day == _selectedDay!.day,
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                    _showFoodsSheet(selected);
                  },
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                        color: Colors.transparent, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(
                        color: Color(0xFF6DCFF6), shape: BoxShape.circle),
                    outsideDaysVisible: true,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    leftChevronIcon: Icon(Icons.chevron_left),
                    rightChevronIcon: Icon(Icons.chevron_right),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final rows = _foodsForDay(day);
                      if (rows.isEmpty) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 4,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodsTable extends StatelessWidget {
  const _FoodsTable({required this.date, required this.rows});

  final DateTime date;
  final List<_FoodRow> rows;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(color: Colors.brown.shade200),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.brown.shade50),
              children: const [
                _TableCellText('Food Item', isHeader: true),
                _TableCellText('Weight', isHeader: true),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  _TableCellText(row.name),
                  _TableCellText(row.amount),
                ],
              ),
          ],
        ),
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
