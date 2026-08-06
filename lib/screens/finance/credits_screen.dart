import 'package:flutter/material.dart';

import '../../models/credit.dart';
import '../../models/vehicle.dart';
import '../../repositories/credit_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/vehicle_repository.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  final CreditRepository _repository = CreditRepository.instance;

  bool _loading = true;
  List<Credit> _credits = const [];
  List<Vehicle> _vehicles = const [];
  double _creditFundLimit = 35;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final credits = await _repository.getCredits(
        includeArchived: true,
      );
      final vehicles = await VehicleRepository.instance.getVehicles(
        includeArchived: true,
      );
      final settings = await SettingsRepository.instance.getSettings();
      if (!mounted) return;
      setState(() {
        _credits = credits;
        _vehicles = vehicles;
        _creditFundLimit = settings.loanFundPercent;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Не удалось загрузить кредиты: $error');
    }
  }

  String _money(double value) => '${value.toStringAsFixed(0)} ₽';

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _edit([Credit? credit]) async {
    final draft = await showAdaptiveDialog<_CreditDraft>(
      context: context,
      builder: (_) => _CreditEditDialog(
        credit: credit,
        vehicles: _vehicles,
      ),
    );
    if (draft == null || !mounted) return;

    final otherPercent = _credits
        .where(
          (item) =>
              !item.archived &&
              !item.isClosed &&
              item.id != credit?.id,
        )
        .fold<double>(0, (sum, item) => sum + item.incomePercent);

    if (otherPercent + draft.incomePercent >
        _creditFundLimit + 0.001) {
      _showError(
        'Сумма процентов кредитов не может превышать '
        '${_creditFundLimit.toStringAsFixed(1)}%. '
        'Изменить общий кредитный фонд можно в настройках.',
      );
      return;
    }

    try {
      final value = Credit(
        id: credit?.id,
        title: draft.title,
        initialAmount: draft.initialAmount,
        remainingAmount: draft.remainingAmount,
        incomePercent: draft.incomePercent,
        monthlyPayment: draft.monthlyPayment,
        paymentDay: draft.paymentDay,
        vehicleId: draft.vehicleId,
        note: draft.note,
        archived: credit?.archived ?? false,
      );
      if (credit == null) {
        await _repository.addCredit(value);
      } else {
        await _repository.updateCredit(value);
      }
      await _load();
    } catch (error) {
      _showError('Не удалось сохранить кредит: $error');
    }
  }

  Future<void> _payment(Credit credit) async {
    final payment = await showAdaptiveDialog<_PaymentDraft>(
      context: context,
      builder: (_) => _CreditPaymentDialog(credit: credit),
    );
    if (payment == null || !mounted) return;

    try {
      await _repository.addPayment(
        creditId: credit.id!,
        amount: payment.amount,
        note: payment.note,
      );
      await _load();
    } catch (error) {
      _showError('Не удалось записать платёж: $error');
    }
  }

  Future<void> _archive(Credit credit) async {
    try {
      await _repository.updateCredit(
        Credit(
          id: credit.id,
          title: credit.title,
          initialAmount: credit.initialAmount,
          remainingAmount: credit.remainingAmount,
          incomePercent: credit.incomePercent,
          monthlyPayment: credit.monthlyPayment,
          paymentDay: credit.paymentDay,
          vehicleId: credit.vehicleId,
          note: credit.note,
          archived: true,
        ),
      );
      await _load();
    } catch (error) {
      _showError('Не удалось архивировать кредит: $error');
    }
  }

  Future<void> _delete(Credit credit) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text('Удалить кредит?'),
        content: Text(
          'Кредит «${credit.title}» и вся история его платежей будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository.deleteCredit(credit.id!);
      await _load();
    } catch (error) {
      _showError('Не удалось удалить кредит: $error');
    }
  }

  String _vehicleName(int? vehicleId) {
    if (vehicleId == null) return 'Общий кредит';
    for (final vehicle in _vehicles) {
      if (vehicle.id == vehicleId) return vehicle.displayName;
    }
    return 'Транспорт не найден';
  }

  @override
  Widget build(BuildContext context) {
    final active = _credits.where((credit) => !credit.archived).toList();
    final percentTotal = active
        .where((credit) => !credit.isClosed)
        .fold<double>(0, (sum, credit) => sum + credit.incomePercent);

    return Scaffold(
      appBar: AppBar(title: const Text('Кредиты')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.percent),
                      title: const Text('Всего направляется на кредиты'),
                      trailing: Text(
                        '${percentTotal.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Лимит кредитного фонда: '
                        '${_creditFundLimit.toStringAsFixed(1)}%. '
                        'Проценты считаются только с фактически '
                        'полученных денег.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_credits.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('Кредиты ещё не добавлены.'),
                        ),
                      ),
                    ),
                  for (final credit in _credits)
                    Card(
                      child: ListTile(
                        enabled: !credit.archived,
                        title: Text(credit.title),
                        subtitle: Text(
                          '${credit.incomePercent.toStringAsFixed(1)}% с дохода\n'
                          '${_vehicleName(credit.vehicleId)}\n'
                          'Остаток: ${_money(credit.remainingAmount)}'
                          '${credit.archived ? '\nВ архиве' : ''}',
                        ),
                        isThreeLine: false,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'pay':
                                await _payment(credit);
                                break;
                              case 'edit':
                                await _edit(credit);
                                break;
                              case 'archive':
                                await _archive(credit);
                                break;
                              case 'delete':
                                await _delete(credit);
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            if (!credit.isClosed && !credit.archived)
                              const PopupMenuItem(
                                value: 'pay',
                                child: Text('Добавить платёж'),
                              ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Редактировать'),
                            ),
                            if (!credit.archived)
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text('Архивировать'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Удалить'),
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
}

class _CreditDraft {
  const _CreditDraft({
    required this.title,
    required this.initialAmount,
    required this.remainingAmount,
    required this.incomePercent,
    this.monthlyPayment,
    this.paymentDay,
    this.vehicleId,
    this.note,
  });

  final String title;
  final double initialAmount;
  final double remainingAmount;
  final double incomePercent;
  final double? monthlyPayment;
  final int? paymentDay;
  final int? vehicleId;
  final String? note;
}

class _CreditEditDialog extends StatefulWidget {
  const _CreditEditDialog({
    required this.credit,
    required this.vehicles,
  });

  final Credit? credit;
  final List<Vehicle> vehicles;

  @override
  State<_CreditEditDialog> createState() => _CreditEditDialogState();
}

class _CreditEditDialogState extends State<_CreditEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _initial;
  late final TextEditingController _remaining;
  late final TextEditingController _percent;
  late final TextEditingController _monthly;
  late final TextEditingController _day;
  late final TextEditingController _note;
  int? _vehicleId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final credit = widget.credit;
    _title = TextEditingController(text: credit?.title ?? '');
    _initial = TextEditingController(
      text: credit?.initialAmount.toStringAsFixed(0) ?? '',
    );
    _remaining = TextEditingController(
      text: credit?.remainingAmount.toStringAsFixed(0) ?? '',
    );
    _percent = TextEditingController(
      text: credit?.incomePercent.toStringAsFixed(1) ?? '',
    );
    _monthly = TextEditingController(
      text: credit?.monthlyPayment?.toStringAsFixed(0) ?? '',
    );
    _day = TextEditingController(
      text: credit?.paymentDay?.toString() ?? '',
    );
    _note = TextEditingController(text: credit?.note ?? '');
    _vehicleId = credit?.vehicleId;
  }

  @override
  void dispose() {
    _title.dispose();
    _initial.dispose();
    _remaining.dispose();
    _percent.dispose();
    _monthly.dispose();
    _day.dispose();
    _note.dispose();
    super.dispose();
  }

  double? _parseDouble(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  void _save() {
    final title = _title.text.trim();
    final initial = _parseDouble(_initial.text);
    final percent = _parseDouble(_percent.text);
    final remainingText = _remaining.text.trim();
    final remaining = remainingText.isEmpty
        ? initial
        : _parseDouble(remainingText);
    final monthly = _monthly.text.trim().isEmpty
        ? null
        : _parseDouble(_monthly.text);
    final day = _day.text.trim().isEmpty
        ? null
        : int.tryParse(_day.text.trim());

    if (title.isEmpty) {
      setState(() => _error = 'Введите название кредита.');
      return;
    }
    if (initial == null || initial < 0) {
      setState(() => _error = 'Проверьте первоначальную сумму.');
      return;
    }
    if (remaining == null || remaining < 0) {
      setState(() => _error = 'Проверьте остаток кредита.');
      return;
    }
    if (percent == null || percent < 0 || percent > 100) {
      setState(() => _error = 'Процент должен быть от 0 до 100.');
      return;
    }
    if (day != null && (day < 1 || day > 31)) {
      setState(() => _error = 'День платежа должен быть от 1 до 31.');
      return;
    }
    if (monthly != null && monthly < 0) {
      setState(() => _error = 'Проверьте плановый платёж.');
      return;
    }

    Navigator.of(context).pop(
      _CreditDraft(
        title: title,
        initialAmount: initial,
        remainingAmount: remaining,
        incomePercent: percent,
        monthlyPayment: monthly,
        paymentDay: day,
        vehicleId: _vehicleId,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text(
        widget.credit == null ? 'Новый кредит' : 'Редактировать кредит',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: _initial,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Первоначальная сумма',
                  suffixText: '₽',
                ),
              ),
              TextField(
                controller: _remaining,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Остаток',
                  suffixText: '₽',
                ),
              ),
              TextField(
                controller: _percent,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Процент с каждого дохода',
                  suffixText: '%',
                  helperText: 'Каждый кредит может иметь свой процент',
                ),
              ),
              TextField(
                controller: _monthly,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Плановый платёж',
                  suffixText: '₽',
                ),
              ),
              TextField(
                controller: _day,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'День платежа',
                ),
              ),
              DropdownButtonFormField<int?>(
                initialValue: _vehicleId,
                decoration: const InputDecoration(labelText: 'Привязка'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Общий кредит'),
                  ),
                  ...widget.vehicles.map(
                    (vehicle) => DropdownMenuItem<int?>(
                      value: vehicle.id,
                      child: Text(vehicle.displayName),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _vehicleId = value),
              ),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _PaymentDraft {
  const _PaymentDraft({
    required this.amount,
    this.note,
  });

  final double amount;
  final String? note;
}

class _CreditPaymentDialog extends StatefulWidget {
  const _CreditPaymentDialog({required this.credit});

  final Credit credit;

  @override
  State<_CreditPaymentDialog> createState() =>
      _CreditPaymentDialogState();
}

class _CreditPaymentDialogState extends State<_CreditPaymentDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(
      _amount.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Введите сумму больше нуля.');
      return;
    }
    Navigator.of(context).pop(
      _PaymentDraft(
        amount: amount,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text('Платёж: ${widget.credit.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Сумма',
              suffixText: '₽',
              helperText:
                  'Остаток: ${widget.credit.remainingAmount.toStringAsFixed(0)} ₽',
            ),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Записать'),
        ),
      ],
    );
  }
}
