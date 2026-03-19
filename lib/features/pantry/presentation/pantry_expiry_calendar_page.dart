import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../domain/kitchen_item.dart';
import '../providers/kitchen_stock_provider.dart';

class PantryExpiryCalendarPage extends StatefulWidget {
  const PantryExpiryCalendarPage({super.key});

  @override
  State<PantryExpiryCalendarPage> createState() =>
      _PantryExpiryCalendarPageState();
}

class _PantryExpiryCalendarPageState extends State<PantryExpiryCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KitchenStockProvider>();
    final expiryMap = _buildExpiryMap(provider.items);
    final today = _dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Expiry Calendar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              enabledDayPredicate: (day) =>
                  day.isAfter(DateTime.now().subtract(const Duration(days: 1))),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return _dayCell(day, expiryMap, today);
                },
                todayBuilder: (context, day, focusedDay) {
                  return _dayCell(day, expiryMap, today, isToday: true);
                },
                selectedBuilder: (context, day, focusedDay) {
                  return _dayCell(day, expiryMap, today, isSelected: true);
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _ExpiryList(
                items: _itemsForSelectedDay(expiryMap, _selectedDay),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<DateTime, List<_ExpiryEntry>> _buildExpiryMap(
    List<KitchenItem> items,
  ) {
    final map = <DateTime, List<_ExpiryEntry>>{};
    for (final item in items) {
      for (final batch in item.batches) {
        final expiry = batch.expiryDate;
        if (expiry == null) continue;
        final date = _dateOnly(expiry);
        map.putIfAbsent(date, () => []).add(
              _ExpiryEntry(item: item, batch: batch),
            );
      }
    }
    return map;
  }

  List<_ExpiryEntry> _itemsForSelectedDay(
    Map<DateTime, List<_ExpiryEntry>> expiryMap,
    DateTime? selectedDay,
  ) {
    if (selectedDay == null) return const [];
    return expiryMap[_dateOnly(selectedDay)] ?? const [];
  }

  Widget _dayCell(
    DateTime day,
    Map<DateTime, List<_ExpiryEntry>> expiryMap,
    DateTime today, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final date = _dateOnly(day);
    final hasExpiry = expiryMap.containsKey(date);
    final diff = date.difference(today).inDays;

    Color? background;
    if (date.isBefore(today)) {
      background = Colors.grey.shade300;
    } else if (hasExpiry) {
      if (diff == 0 || diff <= 3) {
        background = Colors.orange.shade300;
      } else {
        background = Colors.green.shade300;
      }
    }

    if (diff < 0 && hasExpiry) {
      background = Colors.red.shade300;
    }

    if (isSelected) {
      background = Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);
    } else if (isToday && background == null) {
      background = Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
    }

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text('${day.day}'),
    );
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}

class _ExpiryEntry {
  const _ExpiryEntry({required this.item, required this.batch});

  final KitchenItem item;
  final KitchenBatch batch;
}

class _ExpiryList extends StatelessWidget {
  const _ExpiryList({required this.items});

  final List<_ExpiryEntry> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No expiries selected'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final entry = items[index];
        final batch = entry.batch;
        final expiry = batch.expiryDate;
        final label = expiry == null
            ? 'No expiry'
            : '${expiry.day}/${expiry.month}/${expiry.year}';
        return ListTile(
          title: Text(entry.item.name),
          subtitle: Text('${formatQuantity(batch.quantity, batch.unit)} • $label'),
        );
      },
    );
  }
}
