import 'dart:async';

import 'package:flutter/material.dart';

import 'widgets/today_attention_section.dart';
import 'widgets/today_credit_payment_section.dart';
import 'widgets/today_day_status_section.dart';
import 'widgets/today_expenses_section.dart';
import 'widgets/today_finish_day_section.dart';
import 'widgets/today_fuel_section.dart';
import 'widgets/today_month_summary_section.dart';
import 'widgets/today_orders_section.dart';
import 'widgets/outstanding_orders_section.dart';
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

    // Обновляем приветствие и компактные сводки без перезапуска приложения.
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

          // Самый часто используемый блок намеренно остаётся первым.
          const SizedBox(height: 14),
          TodayTripsSection(onChanged: _refreshOverview),

          const SizedBox(height: 12),
          TodayAttentionSection(
            key: ValueKey('attention-$_refreshVersion'),
            onChanged: _refreshOverview,
          ),

          const SizedBox(height: 12),
          TodayDayStatusSection(
            key: ValueKey('day-status-$_refreshVersion'),
          ),

          const SizedBox(height: 16),
          const TodayProSection(),

          const SizedBox(height: 16),
          TodayMonthSummarySection(
            key: ValueKey('month-summary-$_refreshVersion'),
          ),

          const SizedBox(height: 16),
          const TodayOrdersSection(),

          const SizedBox(height: 12),
          const OutstandingOrdersSection(),

          const SizedBox(height: 12),
          const TodayCreditPaymentSection(),

          const SizedBox(height: 12),
          TodayFuelSection(onChanged: _refreshOverview),

          const SizedBox(height: 12),
          const TodayExpensesSection(),

          const SizedBox(height: 20),
          TodayFinishDaySection(onChanged: _refreshOverview),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
