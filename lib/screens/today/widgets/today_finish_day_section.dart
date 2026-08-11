import 'package:flutter/material.dart';

import '../../../models/daily_log.dart';
import '../../../repositories/daily_log_repository.dart';
import '../../../widgets/bus_card.dart';

class TodayFinishDaySection extends StatefulWidget {
  const TodayFinishDaySection({super.key});

  @override
  State<TodayFinishDaySection> createState() =>
      _TodayFinishDaySectionState();
}

class _TodayFinishDaySectionState
    extends State<TodayFinishDaySection> {
  final DailyLogRepository _repository =
      DailyLogRepository.instance;

  final TextEditingController _endMileageController =
  TextEditingController();

  DailyLog? _dailyLog;
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDailyLog();
  }

  @override
  void dispose() {
    _endMileageController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyLog() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final dailyLog = await _repository.getLogForDate(
        _selectedDate,
      );

      if (!mounted) {
        return;
      }

      _endMileageController.text =
          dailyLog.endMileage?.toString() ?? '';

      setState(() {
        _dailyLog = dailyLog;
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
        'Не удалось загрузить пробег: $error',
      );
    }
  }

  Future<void> _completeDay() async {
    final endMileage = int.tryParse(
      _endMileageController.text.trim(),
    );

    if (endMileage == null) {
      _showMessage('Введите конечный пробег.');
      return;
    }

    if (_dailyLog?.startMileage == null) {
      _showMessage(
        'Сначала укажите начальный пробег в настройках.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final savedLog = await _repository.completeDay(
        date: _selectedDate,
        endMileage: endMileage,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _dailyLog = savedLog;
      });

      _showMessage('Конечный пробег сохранён.');
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: today,
      helpText: 'Дата конечного пробега',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
      _endMileageController.clear();
    });

    await _loadDailyLog();
  }

  void _editCompletedMileage() {
    final current = _dailyLog;
    if (current == null) return;

    final endMileage = current.endMileage;
    if (endMileage != null) {
      _endMileageController.text = endMileage.toString();
    }

    setState(() {
      _dailyLog = DailyLog(
        id: current.id,
        date: current.date,
        startMileage: current.startMileage,
        endMileage: null,
        completedAt: current.completedAt,
      );
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _buildMileageRow({
    required String title,
    required String value,
    bool isStrong = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(
          value,
          style: TextStyle(
            fontSize: isStrong ? 18 : 15,
            fontWeight: isStrong
                ? FontWeight.w700
                : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return BusCard(
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Дата пробега',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _isSaving ? null : _selectDate,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Изменить'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedView(DailyLog dailyLog) {
    return BusCard(
      backgroundColor: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              SizedBox(width: 10),
              Text(
                'Пробег сохранён',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _buildMileageRow(
            title: 'Дата',
            value: _formatDate(_selectedDate),
          ),

          const SizedBox(height: 10),

          _buildMileageRow(
            title: 'Конечный пробег',
            value: dailyLog.endMileageText,
          ),

          const Divider(height: 28),

          _buildMileageRow(
            title: 'Пробег за день',
            value: dailyLog.distanceText,
            isStrong: true,
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _editCompletedMileage,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Исправить конечный пробег'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingInitialMileageView() {
    return BusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Начальный пробег ещё не указан',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          const Text(
            'Укажите его один раз во вкладке «Ещё» → '
                '«Настройки». После этого приложение будет '
                'считать пробег автоматически.',
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadDailyLog,
              icon: const Icon(Icons.refresh),
              label: const Text('Проверить снова'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnfinishedView(DailyLog dailyLog) {
    return BusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed),
              SizedBox(width: 10),
              Text(
                'Конечный пробег',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Text(
            'Введите показание одометра в любое время, как только '
            'работа за выбранный день закончилась.',
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _endMileageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Например: 358612',
              suffixText: 'км',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              if (!_isSaving) {
                _completeDay();
              }
            },
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : _completeDay,
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
                    : 'Сохранить конечный пробег',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const BusCard(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final dailyLog = _dailyLog;

    if (dailyLog == null) {
      return BusCard(
        child: Column(
          children: [
            const Text(
              'Не удалось загрузить данные пробега.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadDailyLog,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    Widget content;
    if (dailyLog.startMileage == null) {
      content = _buildMissingInitialMileageView();
    } else if (dailyLog.isCompleted) {
      content = _buildCompletedView(dailyLog);
    } else {
      content = _buildUnfinishedView(dailyLog);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDateSelector(),
        const SizedBox(height: 12),
        content,
      ],
    );
  }
}