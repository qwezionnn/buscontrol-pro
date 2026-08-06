import 'dart:async';

import 'package:flutter/material.dart';

import 'widgets/today_expenses_section.dart';
import 'widgets/today_finish_day_section.dart';
import 'widgets/today_fuel_section.dart';
import 'widgets/today_orders_section.dart';
import 'widgets/today_trips_section.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();

    // Обновляем приветствие без перезапуска приложения,
    // если оно осталось открытым при переходе в другой период суток.
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _greetingFor(DateTime now) {
    final hour = now.hour;

    if (hour < 6) {
      return 'Доброй ночи 🌙';
    }

    if (hour < 12) {
      return 'Доброе утро ☀️';
    }

    if (hour < 18) {
      return 'Добрый день 🌤️';
    }

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

          const SizedBox(height: 24),

          const TodayTripsSection(),

          const SizedBox(height: 16),

          const TodayOrdersSection(),

          const SizedBox(height: 12),

          const TodayFuelSection(),

          const SizedBox(height: 12),

          const TodayExpensesSection(),

          const SizedBox(height: 20),

          const TodayFinishDaySection(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
