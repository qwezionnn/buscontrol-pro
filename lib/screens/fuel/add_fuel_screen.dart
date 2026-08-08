import 'package:flutter/material.dart';

import '../../models/fuel.dart';
import '../../repositories/fuel_repository.dart';
import '../../repositories/settings_repository.dart';

enum FuelSource { station, home }
enum StationInputMode { liters, amount }

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
  final _amountController = TextEditingController();
  final _mileageController = TextEditingController();
  final _noteController = TextEditingController();

  final FuelRepository _fuelRepository = FuelRepository.instance;
  final SettingsRepository _settingsRepository =
      SettingsRepository.instance;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  FuelSource _source = FuelSource.station;
  StationInputMode _stationMode = StationInputMode.liters;

  bool _isLoading = true;
  bool _isSaving = false;

  double _parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

  double get _enteredLiters => _parse(_litersController.text);
  double get _pricePerLiter => _parse(_priceController.text);
  double get _enteredAmount => _parse(_amountController.text);

  double get _calculatedLiters {
    if (_source == FuelSource.home) return _enteredLiters;
    if (_stationMode == StationInputMode.amount) {
      if (_pricePerLiter <= 0) return 0;
      return _enteredAmount / _pricePerLiter;
    }
    return _enteredLiters;
  }

  double get _calculatedTotal {
    if (_source == FuelSource.home) return 0;
    if (_stationMode == StationInputMode.amount) return _enteredAmount;
    return _enteredLiters * _pricePerLiter;
  }

  @override
  void initState() {
    super.initState();
    final initialDate = widget.initialDate;
    if (initialDate != null) {
      _selectedDate =
          DateTime(initialDate.year, initialDate.month, initialDate.day);
    }
    _loadDefaults();
  }

  @override
  void dispose() {
    _litersController.dispose();
    _priceController.dispose();
    _amountController.dispose();
    _mileageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    try {
      final settings = await _settingsRepository.getSettings();
      if (!mounted) return;

      if (settings.defaultFuelPrice > 0) {
        _priceController.text = _formatNumber(settings.defaultFuelPrice);
      }

      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить цену топлива: $error')),
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

  String _formatMoney(double value) => '${value.toStringAsFixed(2)} ₽';

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  Future<void> _selectDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (result == null) return;
    setState(() => _selectedDate = result);
  }

  Future<void> _selectTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (result == null) return;
    setState(() => _selectedTime = result);
  }

  Future<void> _saveFuelLog() async {
    if (!_formKey.currentState!.validate()) return;

    final mileageText = _mileageController.text.trim();
    final mileage =
        mileageText.isEmpty ? null : int.tryParse(mileageText);

    setState(() => _isSaving = true);

    try {
      final fuelLog = FuelLog(
        date: _databaseDate(_selectedDate),
        time: _databaseTime(_selectedTime),
        liters: _calculatedLiters,
        pricePerLiter:
            _source == FuelSource.home ? 0 : _pricePerLiter,
        total: _calculatedTotal,
        source: _source == FuelSource.home ? 'home' : 'station',
        mileage: mileage,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      await _fuelRepository.addFuelLog(fuelLog);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить заправку: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _sourceSelector() {
    return SegmentedButton<FuelSource>(
      segments: const [
        ButtonSegment(
          value: FuelSource.station,
          icon: Icon(Icons.local_gas_station),
          label: Text('На АЗС'),
        ),
        ButtonSegment(
          value: FuelSource.home,
          icon: Icon(Icons.home_outlined),
          label: Text('Дома'),
        ),
      ],
      selected: {_source},
      onSelectionChanged: (value) {
        setState(() => _source = value.first);
      },
    );
  }

  Widget _stationModeSelector() {
    return SegmentedButton<StationInputMode>(
      segments: const [
        ButtonSegment(
          value: StationInputMode.liters,
          label: Text('Литры + цена'),
        ),
        ButtonSegment(
          value: StationInputMode.amount,
          label: Text('Сумма + цена'),
        ),
      ],
      selected: {_stationMode},
      onSelectionChanged: (value) {
        setState(() => _stationMode = value.first);
      },
    );
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    String? suffix,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _source == FuelSource.home;

    return Scaffold(
      appBar: AppBar(title: const Text('Новая заправка')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sourceSelector(),
                    const SizedBox(height: 16),
                    if (isHome)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Домашняя заправка учитывает только литры. '
                            'Деньги сейчас не списываются. Фактическую общую '
                            'сумму за месяц можно позже списать с кошелька '
                            'автобуса через «Расчёт домашнего топлива».',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      _stationModeSelector(),
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
                    const SizedBox(height: 16),

                    if (isHome ||
                        _stationMode == StationInputMode.liters)
                      TextFormField(
                        controller: _litersController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: _decoration(
                          label: 'Количество топлива',
                          hint: 'Например: 40',
                          suffix: 'л',
                          icon: Icons.local_gas_station,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final number = _parse(value ?? '');
                          if (number <= 0) {
                            return 'Введите количество литров';
                          }
                          return null;
                        },
                      ),

                    if (!isHome &&
                        _stationMode == StationInputMode.amount)
                      TextFormField(
                        controller: _amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: _decoration(
                          label: 'Сумма заправки',
                          hint: 'Например: 3250',
                          suffix: '₽',
                          icon: Icons.payments_outlined,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final number = _parse(value ?? '');
                          if (number <= 0) return 'Введите сумму заправки';
                          return null;
                        },
                      ),

                    if (!isHome) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: _decoration(
                          label: 'Цена за литр',
                          hint: 'Например: 65',
                          suffix: '₽/л',
                          icon: Icons.sell_outlined,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final number = _parse(value ?? '');
                          if (number <= 0) return 'Введите цену за литр';
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mileageController,
                      keyboardType: TextInputType.number,
                      decoration: _decoration(
                        label: 'Пробег при заправке',
                        hint: 'Необязательно',
                        suffix: 'км',
                        icon: Icons.speed,
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
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
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoration(
                        label: 'Комментарий',
                        hint: isHome
                            ? 'Например: заправил из домашнего запаса'
                            : 'Например: полный бак',
                        icon: Icons.notes,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: isHome
                            ? Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Учтено топлива',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_formatNumber(_calculatedLiters)} л',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _stationMode ==
                                                StationInputMode.amount
                                            ? 'Рассчитано литров'
                                            : 'Итого',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _stationMode ==
                                                StationInputMode.amount
                                            ? '${_formatNumber(_calculatedLiters)} л'
                                            : _formatMoney(_calculatedTotal),
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_stationMode ==
                                      StationInputMode.amount) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'Итого: ${_formatMoney(_calculatedTotal)}',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveFuelLog,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
