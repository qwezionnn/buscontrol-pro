import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../models/credit.dart';
import '../../repositories/credit_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../widgets/bus_card.dart';

class DistributionCalculatorScreen extends StatefulWidget {
  const DistributionCalculatorScreen({super.key});

  @override
  State<DistributionCalculatorScreen> createState() =>
      _DistributionCalculatorScreenState();
}

class _DistributionCalculatorScreenState
    extends State<DistributionCalculatorScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _personalController = TextEditingController();
  final Map<String, TextEditingController> _creditControllers = {};

  bool _loading = true;

  double _parse(TextEditingController controller) {
    return double.tryParse(
          controller.text.trim().replaceAll(',', '.'),
        ) ??
        0;
  }

  double get _amount => _parse(_amountController);
  double get _vehiclePercent => _parse(_vehicleController);
  double get _personalPercent => _parse(_personalController);

  double get _totalPercent =>
      _vehiclePercent +
      _personalPercent +
      _creditControllers.values.fold<double>(
        0,
        (sum, controller) => sum + _parse(controller),
      );

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final results = await Future.wait([
      SettingsRepository.instance.getSettings(),
      CreditRepository.instance.getCredits(),
    ]);

    final settings = results[0] as AppSettings;
    final credits = (results[1] as List<Credit>)
        .where((credit) => !credit.archived && !credit.isClosed)
        .toList();

    _vehicleController.text = _formatPercent(settings.workFundPercent);
    _personalController.text = _formatPercent(settings.personalFundPercent);

    if (credits.isEmpty) {
      _creditControllers['Кредит'] = TextEditingController(
        text: _formatPercent(settings.loanFundPercent),
      );
    } else {
      var namedPercent = 0.0;
      for (final credit in credits) {
        namedPercent += credit.incomePercent;
        _creditControllers[credit.title] = TextEditingController(
          text: _formatPercent(credit.incomePercent),
        );
      }
      final reserve = (settings.loanFundPercent - namedPercent)
          .clamp(0, double.infinity)
          .toDouble();
      if (reserve > 0.001) {
        _creditControllers['Кредитный резерв'] = TextEditingController(
          text: _formatPercent(reserve),
        );
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _vehicleController.dispose();
    _personalController.dispose();
    for (final controller in _creditControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatPercent(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  String _money(double value) => '${value.toStringAsFixed(0)} ₽';

  Widget _row(
    String title,
    TextEditingController controller,
    IconData icon,
  ) {
    final percent = _parse(controller);
    final result = _amount * percent / 100;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: title,
                  prefixIcon: Icon(icon),
                  suffixText: '%',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  _money(result),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalPercent;
    final delta = 100 - total;
    final isValid = delta.abs() <= 0.01;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Калькулятор распределения'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  BusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Сумма',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountController,
                          autofocus: true,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Введите сумму',
                            suffixText: '₽',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  BusCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Распределение',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Проценты можно менять как угодно. '
                          'Для полного распределения итог должен быть 100%.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        _row(
                          'На автобус',
                          _vehicleController,
                          Icons.directions_bus_outlined,
                        ),
                        for (final entry
                            in _creditControllers.entries)
                          _row(
                            entry.key,
                            entry.value,
                            Icons.account_balance_outlined,
                          ),
                        _row(
                          'Личные деньги',
                          _personalController,
                          Icons.person_outline,
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isValid
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isValid
                                ? 'Распределено 100% · ${_money(_amount)}'
                                : delta > 0
                                    ? 'Распределено ${_formatPercent(total)}% · '
                                        'осталось ${_formatPercent(delta)}%'
                                    : 'Распределено ${_formatPercent(total)}% · '
                                        'превышение ${_formatPercent(-delta)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
