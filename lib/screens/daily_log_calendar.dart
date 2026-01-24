import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

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
      _FoodRow(meal: 'Breakfast', name: 'Apple', amount: '150 g'),
      _FoodRow(meal: 'Breakfast', name: 'Bread', amount: '28 g'),
      _FoodRow(meal: 'Breakfast', name: 'Banana', amount: '118 g'),
    ],
  };

  List<_FoodRow> _foodsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return _logs[key] ?? const [];
  }

  @override
  Widget build(BuildContext context) {
    final displayDate = _selectedDay ?? _focusedDay;
    final dateLabel = DateFormat('MMMM d, yyyy').format(displayDate);
    final selectedFoods = _foodsForDay(displayDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF6E9D8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6E9D8),
        elevation: 0,
        centerTitle: false,
        title: const Text('History', style: TextStyle(color: Colors.black87)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.calendar_month, color: Colors.redAccent),
          ),
        ],
      ),
      body: Column(
        children: [
          _CalendarCard(
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: selectedFoods.isEmpty
                        ? const Center(child: Text('No entries for this day'))
                        : _FoodsTable(date: displayDate, rows: selectedFoods),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Add your BottomNavigationBar here to match the mockup
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime, DateTime) onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          firstDay: DateTime.utc(2015, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: focusedDay,
          selectedDayPredicate: (d) =>
              selectedDay != null &&
              d.year == selectedDay!.year &&
              d.month == selectedDay!.month &&
              d.day == selectedDay!.day,
          onDaySelected: onDaySelected,
          calendarStyle: const CalendarStyle(
            todayDecoration:
                BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
            selectedDecoration:
                BoxDecoration(color: Color(0xFF6DCFF6), shape: BoxShape.circle),
            outsideDaysVisible: true,
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronIcon: Icon(Icons.chevron_left),
            rightChevronIcon: Icon(Icons.chevron_right),
          ),
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
  const _FoodRow({required this.meal, required this.name, required this.amount});
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
