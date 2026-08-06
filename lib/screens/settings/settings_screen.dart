import 'package:flutter/material.dart';

import '../../features/profile/profile_screen.dart';
import '../../models/app_settings.dart';
import '../../repositories/settings_repository.dart';
import '../../widgets/bus_card.dart';
import '../../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _repository =
      SettingsRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final BackupService _backupService = BackupService.instance;

  final _initialMileageController = TextEditingController();
  final _standardTripPriceController = TextEditingController();
  final _hourlyOrderRateController = TextEditingController();
  final _intercityOrderRateController = TextEditingController();
  final _defaultFuelPriceController = TextEditingController();
  final _summerConsumptionController = TextEditingController();
  final _winterConsumptionController = TextEditingController();
  final _tankVolumeController = TextEditingController();
  final _reminderHoursController = TextEditingController();
  final _workFundController = TextEditingController();
  final _loanFundController = TextEditingController();
  final _personalFundController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isResetting = false;
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _initialMileageController.dispose();
    _standardTripPriceController.dispose();
    _hourlyOrderRateController.dispose();
    _intercityOrderRateController.dispose();
    _defaultFuelPriceController.dispose();
    _summerConsumptionController.dispose();
    _winterConsumptionController.dispose();
    _tankVolumeController.dispose();
    _reminderHoursController.dispose();
    _workFundController.dispose();
    _loanFundController.dispose();
    _personalFundController.dispose();

    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _repository.getSettings();

      if (!mounted) {
        return;
      }

      _initialMileageController.text =
          settings.initialMileage?.toString() ?? '';

      _standardTripPriceController.text =
          _formatNumber(settings.standardTripPrice);

      _hourlyOrderRateController.text =
          _formatNumber(settings.hourlyOrderRate);

      _intercityOrderRateController.text =
          _formatNumber(settings.intercityOrderRate);

      _defaultFuelPriceController.text =
      settings.defaultFuelPrice == 0
          ? ''
          : _formatNumber(settings.defaultFuelPrice);

      _summerConsumptionController.text =
          _formatNumber(settings.summerConsumption);

      _winterConsumptionController.text =
          _formatNumber(settings.winterConsumption);

      _tankVolumeController.text =
          _formatNumber(settings.tankVolume);

      _reminderHoursController.text =
          settings.orderReminderHours.toString();

      _workFundController.text =
          _formatNumber(settings.workFundPercent);

      _loanFundController.text =
          _formatNumber(settings.loanFundPercent);

      _personalFundController.text =
          _formatNumber(settings.personalFundPercent);

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

      _showMessage(
        'Не удалось загрузить настройки: $error',
      );
    }
  }

  void _fillControllers(AppSettings settings) {
    _initialMileageController.text =
        settings.initialMileage?.toString() ?? '';
    _standardTripPriceController.text =
        _formatNumber(settings.standardTripPrice);
    _hourlyOrderRateController.text =
        _formatNumber(settings.hourlyOrderRate);
    _intercityOrderRateController.text =
        _formatNumber(settings.intercityOrderRate);
    _defaultFuelPriceController.text =
        settings.defaultFuelPrice == 0
            ? ''
            : _formatNumber(settings.defaultFuelPrice);
    _summerConsumptionController.text =
        _formatNumber(settings.summerConsumption);
    _winterConsumptionController.text =
        _formatNumber(settings.winterConsumption);
    _tankVolumeController.text =
        _formatNumber(settings.tankVolume);
    _reminderHoursController.text =
        settings.orderReminderHours.toString();
    _workFundController.text =
        _formatNumber(settings.workFundPercent);
    _loanFundController.text =
        _formatNumber(settings.loanFundPercent);
    _personalFundController.text =
        _formatNumber(settings.personalFundPercent);
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final initialMileageText =
    _initialMileageController.text.trim();

    final settings = AppSettings(
      initialMileage: initialMileageText.isEmpty
          ? null
          : int.parse(initialMileageText),
      standardTripPrice:
      _parseDouble(_standardTripPriceController.text),
      hourlyOrderRate:
      _parseDouble(_hourlyOrderRateController.text),
      intercityOrderRate:
      _parseDouble(_intercityOrderRateController.text),
      defaultFuelPrice:
      _parseOptionalDouble(_defaultFuelPriceController.text),
      summerConsumption:
      _parseDouble(_summerConsumptionController.text),
      winterConsumption:
      _parseDouble(_winterConsumptionController.text),
      tankVolume:
      _parseDouble(_tankVolumeController.text),
      orderReminderHours:
      int.parse(_reminderHoursController.text.trim()),
      workFundPercent:
      _parseDouble(_workFundController.text),
      loanFundPercent:
      _parseDouble(_loanFundController.text),
      personalFundPercent:
      _parseDouble(_personalFundController.text),
    );

    if (!settings.hasValidFundPercent) {
      _showMessage(
        'Сумма рабочего, кредитного и личного фондов '
            'должна быть равна 100%.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.saveSettings(settings);
      final savedSettings = await _repository.getSettings();

      if (!mounted) {
        return;
      }

      _fillControllers(savedSettings);
      FocusScope.of(context).unfocus();
      _showMessage('Настройки сохранены и применены.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error
          .toString()
          .replaceFirst('Invalid argument(s): ', '')
          .replaceFirst('Bad state: ', '');

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }


  Future<void> _resetAllData() async {
    final firstConfirmation = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog.adaptive(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 36,
          ),
          title: const Text('Сбросить всё?'),
          content: const Text(
            'Будут навсегда удалены рейсы, заказы, заправки, '
            'расходы, история пробега и все пользовательские настройки. '
            'Отменить это действие после сброса будет невозможно.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(dialogContext).colorScheme.error,
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Продолжить'),
            ),
          ],
        );
      },
    );

    if (firstConfirmation != true || !mounted) {
      return;
    }

    final confirmationController = TextEditingController();

    final finalConfirmation = await showAdaptiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog.adaptive(
          title: const Text('Последнее подтверждение'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Для полного удаления данных введите слово СБРОСИТЬ:',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmationController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'СБРОСИТЬ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(dialogContext).colorScheme.error,
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () {
                final matches = confirmationController.text
                        .trim()
                        .toUpperCase() ==
                    'СБРОСИТЬ';

                if (!matches) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Введите слово СБРОСИТЬ без ошибок.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, true);
              },
              child: const Text('Удалить всё'),
            ),
          ],
        );
      },
    );

    confirmationController.dispose();

    if (finalConfirmation != true || !mounted) {
      return;
    }

    setState(() {
      _isResetting = true;
    });

    try {
      await _repository.resetAllData();
      final defaults = await _repository.getSettings();

      if (!mounted) {
        return;
      }

      _fillControllers(defaults);
      FocusScope.of(context).unfocus();

      _showMessage(
        'Все данные удалены. Настройки возвращены к значениям по умолчанию.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Не удалось выполнить сброс: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  double _parseDouble(String value) {
    return double.parse(
      value.trim().replaceAll(',', '.'),
    );
  }

  double _parseOptionalDouble(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return 0;
    }

    return double.parse(
      text.replaceAll(',', '.'),
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2);
  }

  String? _validateInteger(
      String? value, {
        required String emptyMessage,
        bool allowEmpty = false,
      }) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return allowEmpty ? null : emptyMessage;
    }

    final number = int.tryParse(text);

    if (number == null || number < 0) {
      return 'Введите целое число не меньше нуля';
    }

    return null;
  }

  String? _validatePositiveDouble(
      String? value, {
        required String emptyMessage,
        bool allowZero = false,
        bool allowEmpty = false,
      }) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return allowEmpty ? null : emptyMessage;
    }

    final number = double.tryParse(
      text.replaceAll(',', '.'),
    );

    if (number == null) {
      return 'Введите корректное число';
    }

    if (allowZero) {
      if (number < 0) {
        return 'Значение не может быть отрицательным';
      }
    } else if (number <= 0) {
      return 'Значение должно быть больше нуля';
    }

    return null;
  }


  Future<void> _createBackup() async {
    setState(() => _isBackingUp = true);
    try {
      await _backupService.shareBackup();
    } catch (error) {
      if (mounted) _showMessage('Не удалось создать копию: $error');
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text('Восстановить данные?'),
        content: const Text(
          'Текущие данные будут заменены содержимым резервной копии.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBackingUp = true);
    try {
      final restored = await _backupService.restoreBackup();
      if (restored && mounted) {
        await _loadSettings();
        _showMessage('Данные восстановлены. Перейдите на вкладку «Сегодня».');
      }
    } catch (error) {
      if (mounted) _showMessage('Не удалось восстановить копию: $error');
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? suffix,
    String? hint,
    bool integer = false,
    bool allowZero = false,
    bool allowEmpty = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: integer
          ? TextInputType.number
          : const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: integer
          ? (value) {
        return _validateInteger(
          value,
          emptyMessage: 'Введите значение',
          allowEmpty: allowEmpty,
        );
      }
          : (value) {
        return _validatePositiveDouble(
          value,
          emptyMessage: 'Введите значение',
          allowZero: allowZero,
          allowEmpty: allowEmpty,
        );
      },
    );
  }

  Widget _buildSectionTitle(
      IconData icon,
      String title,
      ) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Настройки',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'Параметры автобуса и расчётов',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 24),

            BusCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.cloud_done_outlined),
                ),
                title: const Text(
                  'Облачный профиль',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Имя, аккаунт Supabase и выход',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const ProfileScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            BusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    Icons.directions_bus,
                    'Автобус',
                  ),

                  const SizedBox(height: 18),

                  _buildNumberField(
                    controller:
                    _initialMileageController,
                    label: 'Текущий пробег',
                    icon: Icons.speed,
                    suffix: 'км',
                    hint: 'Например: 358420',
                    integer: true,
                    allowEmpty: true,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Укажите текущий пробег автобуса. После завершения дня '
                    'приложение обновит его автоматически. '
                    'При необходимости значение можно исправить вручную.',
                  ),

                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller: _tankVolumeController,
                    label: 'Объём бака',
                    icon: Icons.local_gas_station,
                    suffix: 'л',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            BusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    Icons.route,
                    'Рейсы и заказы',
                  ),

                  const SizedBox(height: 18),

                  _buildNumberField(
                    controller:
                    _standardTripPriceController,
                    label: 'Стоимость стандартного рейса',
                    icon: Icons.directions_bus,
                    suffix: '₽',
                  ),

                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller:
                    _hourlyOrderRateController,
                    label: 'Почасовая ставка заказа',
                    icon: Icons.schedule,
                    suffix: '₽/ч',
                  ),

                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller:
                    _intercityOrderRateController,
                    label: 'Ставка межгорода',
                    icon: Icons.route_outlined,
                    suffix: '₽/км',
                  ),

                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller:
                    _reminderHoursController,
                    label: 'Напоминание до заказа',
                    icon: Icons.notifications_outlined,
                    suffix: 'ч',
                    integer: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            BusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    Icons.local_gas_station,
                    'Топливо',
                  ),

                  const SizedBox(height: 18),

                  _buildNumberField(
                    controller:
                    _defaultFuelPriceController,
                    label: 'Цена топлива по умолчанию',
                    icon: Icons.payments_outlined,
                    suffix: '₽/л',
                    allowZero: true,
                    allowEmpty: true,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Эта цена будет автоматически '
                        'подставляться при новой заправке. '
                        'В самой форме её можно изменить.',
                  ),

                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller:
                    _summerConsumptionController,
                    label: 'Летний расход',
                    icon: Icons.wb_sunny_outlined,
                    suffix: 'л/100 км',
                  ),

                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller:
                    _winterConsumptionController,
                    label: 'Зимний расход',
                    icon: Icons.ac_unit,
                    suffix: 'л/100 км',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            BusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    Icons.account_balance_wallet_outlined,
                    'Распределение денег',
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Сумма трёх фондов должна быть равна 100%.',
                  ),

                  const SizedBox(height: 18),

                  _buildNumberField(
                    controller: _workFundController,
                    label: 'Рабочий фонд',
                    icon: Icons.build_outlined,
                    suffix: '%',
                    allowZero: true,
                  ),

                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller: _loanFundController,
                    label: 'Кредитный фонд',
                    icon: Icons.credit_card,
                    suffix: '%',
                    allowZero: true,
                  ),

                  const SizedBox(height: 16),

                  _buildNumberField(
                    controller: _personalFundController,
                    label: 'Личные деньги',
                    icon: Icons.person_outline,
                    suffix: '%',
                    allowZero: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            BusCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    Icons.cloud_sync_outlined,
                    'Резервная копия',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Сохраните всю историю и настройки в один файл. '
                    'На iPhone его можно отправить в «Файлы», iCloud или AirDrop.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isBackingUp ? null : _createBackup,
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text('Создать резервную копию'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isBackingUp ? null : _restoreBackup,
                      icon: const Icon(Icons.restore),
                      label: const Text('Восстановить из копии'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                (_isSaving || _isResetting) ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving
                      ? 'Сохраняем...'
                      : 'Сохранить настройки',
                ),
              ),
            ),

            const SizedBox(height: 24),

            BusCard(
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Опасная зона',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Полный сброс удалит всю историю приложения: '
                    'рейсы, заказы, топливо, расходы, пробег и настройки.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onPressed: (_isSaving || _isResetting)
                          ? null
                          : _resetAllData,
                      icon: _isResetting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.delete_forever_outlined),
                      label: Text(
                        _isResetting
                            ? 'Удаляем данные...'
                            : 'Сбросить всё',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}