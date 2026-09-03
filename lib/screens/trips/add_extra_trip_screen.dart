import 'package:flutter/material.dart';

import '../../database/database_helper.dart';

class AddExtraTripScreen extends StatefulWidget {
  const AddExtraTripScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<AddExtraTripScreen> createState() => _AddExtraTripScreenState();
}

class _AddExtraTripScreenState extends State<AddExtraTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _waitHoursController = TextEditingController(text: '0');
  final _waitRateController = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialDate = widget.initialDate;
    if (initialDate != null) {
      _selectedDate = DateTime(initialDate.year, initialDate.month, initialDate.day);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _waitHoursController.dispose();
    _waitRateController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _databaseDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _databaseTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _selectDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (result != null) setState(() => _selectedDate = result);
  }

  Future<void> _selectTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (result != null) setState(() => _selectedTime = result);
  }

  void _changeWaitHours(double delta) {
    final next = (_parse(_waitHoursController) + delta).clamp(0, 24).toDouble();
    _waitHoursController.text = next == next.roundToDouble()
        ? next.toStringAsFixed(0)
        : next.toStringAsFixed(1);
    setState(() {});
  }

  Future<void> _saveTrip() async {
    if (!_formKey.currentState!.validate()) return;

    final price = _parse(_priceController);
    final waitHours = _parse(_waitHoursController);
    final waitRate = _parse(_waitRateController);
    if (price <= 0 || waitHours < 0 || waitRate < 0) return;

    setState(() => _isSaving = true);
    try {
      await DatabaseHelper.instance.addTrip(
        date: _databaseDate(_selectedDate),
        time: _databaseTime(_selectedTime),
        title: _titleController.text.trim(),
        type: 'extra',
        price: price,
        waitHours: waitHours,
        waitRate: waitRate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить рейс: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitHours = _parse(_waitHoursController);
    final waitRate = _parse(_waitRateController);
    final waitTotal = waitHours * waitRate;
    final total = _parse(_priceController) + waitTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Дополнительный рейс')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'За кого / куда ездил',
                  hintText: 'Например: Иванов — вокзал → аэропорт',
                  prefixIcon: Icon(Icons.add_road),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите название дополнительного рейса'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Стоимость самого рейса',
                  suffixText: '₽',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final number = double.tryParse((value ?? '').replaceAll(',', '.'));
                  return number == null || number <= 0
                      ? 'Введите стоимость больше нуля'
                      : null;
                },
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⏱ Ожидание',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      const Text('Ожидание не считается отдельным рейсом.'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton.outlined(
                            onPressed: () => _changeWaitHours(-1),
                            icon: const Icon(Icons.remove),
                          ),
                          Expanded(
                            child: TextFormField(
                              controller: _waitHoursController,
                              textAlign: TextAlign.center,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Часов ожидания',
                                suffixText: 'ч',
                              ),
                            ),
                          ),
                          IconButton.outlined(
                            onPressed: () => _changeWaitHours(1),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _waitRateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Цена одного часа ожидания',
                          suffixText: '₽/ч',
                        ),
                      ),
                      if (waitHours > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Ожидание: ${waitHours.toStringAsFixed(waitHours == waitHours.roundToDouble() ? 0 : 1)} ч × ${waitRate.toStringAsFixed(0)} ₽ = ${waitTotal.toStringAsFixed(0)} ₽',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_formatDate(_selectedDate)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(_selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  title: const Text('Итого за дополнительный рейс'),
                  subtitle: Text(
                    waitHours > 0
                        ? 'Рейс ${_parse(_priceController).toStringAsFixed(0)} ₽ + ожидание ${waitTotal.toStringAsFixed(0)} ₽'
                        : 'Без ожидания',
                  ),
                  trailing: Text(
                    '${total.toStringAsFixed(0)} ₽',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveTrip,
                icon: const Icon(Icons.save),
                label: Text(_isSaving ? 'Сохраняю…' : 'Сохранить рейс'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
