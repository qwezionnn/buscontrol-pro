import 'package:flutter/material.dart';

import '../../models/fuel.dart';
import '../../repositories/fuel_repository.dart';
import '../../repositories/settings_repository.dart';

class AddFuelScreen extends StatefulWidget {
  const AddFuelScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<AddFuelScreen> createState() => _AddFuelScreenState();
}

class _AddFuelScreenState extends State<AddFuelScreen> {
  final _formKey = GlobalKey<FormState>();

  final _litersController = TextEditingController();
  final _priceController = TextEditingController();
  final _mileageController = TextEditingController();
  final _noteController = TextEditingController();

  final FuelRepository _fuelRepository = FuelRepository.instance;
  final SettingsRepository _settingsRepository =
      SettingsRepository.instance;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isLoading = true;
  bool _isSaving = false;

  double get _liters {
    return double.tryParse(
      _litersController.text.trim().replaceAll(',', '.'),
    ) ??
        0;
  }

  double get _pricePerLiter {
    return double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    ) ??
        0;
  }

  double get _total => _liters * _pricePerLiter;

  @override
  void initState() {
    super.initState();
    final initialDate = widget.initialDate;
    if (initialDate != null) {
      _selectedDate = DateTime(initialDate.year, initialDate.month, initialDate.day);
    }
    _loadDefaults();
  }

  @override
  void dispose() {
    _litersController.dispose();
    _priceController.dispose();
    _mileageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    try {
      final settings = await _settingsRepository.getSettings();

      if (!mounted) {
        return;
      }

      if (settings.defaultFuelPrice > 0) {
        _priceController.text =
            _formatNumber(settings.defaultFuelPrice);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось загрузить цену топлива: $error',
          ),
        ),
      );
    }
  }

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String _databaseTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(2)} ₽';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  Future<void> _selectDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedDate = result;
    });
  }

  Future<void> _selectTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedTime = result;
    });
  }

  Future<void> _saveFuelLog() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final mileageText = _mileageController.text.trim();

    final mileage = mileageText.isEmpty
        ? null
        : int.tryParse(mileageText);

    setState(() {
      _isSaving = true;
    });

    try {
      final fuelLog = FuelLog(
        date: _databaseDate(_selectedDate),
        time: _databaseTime(_selectedTime),
        liters: _liters,
        pricePerLiter: _pricePerLiter,
        total: _total,
        mileage: mileage,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      await _fuelRepository.addFuelLog(fuelLog);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось сохранить заправку: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая заправка'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(
                        Icons.calendar_month,
                      ),
                      label: Text(
                        _formatDate(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectTime,
                      icon: const Icon(
                        Icons.access_time,
                      ),
                      label: Text(
                        _selectedTime.format(context),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _litersController,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Количество топлива',
                  hintText: 'Например: 40',
                  suffixText: 'л',
                  prefixIcon: Icon(
                    Icons.local_gas_station,
                  ),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {});
                },
                validator: (value) {
                  final number = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );

                  if (number == null || number <= 0) {
                    return 'Введите количество литров';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Цена за литр',
                  hintText: 'Например: 81.50',
                  suffixText: '₽/л',
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {});
                },
                validator: (value) {
                  final number = double.tryParse(
                    (value ?? '').replaceAll(',', '.'),
                  );

                  if (number == null || number <= 0) {
                    return 'Введите цену за литр';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _mileageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Пробег при заправке',
                  hintText: 'Необязательно',
                  suffixText: 'км',
                  prefixIcon: Icon(Icons.speed),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return null;
                  }

                  final mileage = int.tryParse(text);

                  if (mileage == null || mileage < 0) {
                    return 'Введите корректный пробег';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                maxLines: 3,
                textCapitalization:
                TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Комментарий',
                  hintText: 'Например: полный бак',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Итого',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatMoney(_total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed:
                _isSaving ? null : _saveFuelLog,
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Сохраняем...'
                      : 'Сохранить заправку',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}