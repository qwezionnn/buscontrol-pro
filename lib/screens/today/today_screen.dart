import 'dart:async';

import 'package:flutter/material.dart';

import 'widgets/outstanding_orders_section.dart';
import 'widgets/today_expenses_section.dart';
import 'widgets/today_finish_day_section.dart';
import 'widgets/today_fuel_section.dart';
import 'widgets/today_month_summary_section.dart';
import 'widgets/today_orders_section.dart';
import 'widgets/today_pro_section.dart';
import 'widgets/today_trips_section.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Timer? _clockTimer;
  int _refreshVersion = 0;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() => _refreshVersion++);
        }
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _refreshOverview() {
    if (!mounted) return;
    setState(() => _refreshVersion++);
  }

  String _greetingFor(DateTime now) {
    final hour = now.hour;
    if (hour < 6) return 'Доброй ночи 🌙';
    if (hour < 12) return 'Доброе утро ☀️';
    if (hour < 18) return 'Добрый день 🌤️';
    return 'Добрый вечер 🌆';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _greetingFor(now),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Сегодня',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),

          // 1. Самое частое действие — сразу под заголовком.
          const SizedBox(height: 14),
          const TodayProSection(),

          // 2. Утро / вечер / доп. рейс + напоминание о конечном пробеге.
          const SizedBox(height: 12),
          TodayTripsSection(onChanged: _refreshOverview),

          // 3. Заказы.
          const SizedBox(height: 16),
          const TodayOrdersSection(),
          const SizedBox(height: 12),
          const OutstandingOrdersSection(),

          // 4. Заправка.
          const SizedBox(height: 12),
          TodayFuelSection(onChanged: _refreshOverview),

          // 5. Сводка за текущий месяц.
          const SizedBox(height: 16),
          TodayMonthSummarySection(
            key: ValueKey('month-summary-$_refreshVersion'),
          ),

          // 6. Затраты показываем только если сегодня они реально есть.
          const SizedBox(height: 12),
          const TodayExpensesSection(hideWhenEmpty: true),

          // 7. Ввод конечного пробега — в самом низу.
          const SizedBox(height: 16),
          TodayFinishDaySection(onChanged: _refreshOverview),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
