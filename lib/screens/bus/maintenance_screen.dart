import 'package:flutter/material.dart';

import '../../models/maintenance_item.dart';
import '../../models/expense.dart';
import '../../repositories/daily_log_repository.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../widgets/bus_card.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _repository = MaintenanceRepository.instance;
  final _mileageRepository = DailyLogRepository.instance;

  List<MaintenanceItem> _items = const [];
  int _currentMileage = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repository.getItems();
    final mileage = await _mileageRepository.getLastMileage() ??
        await _mileageRepository.getInitialMileage() ??
        0;
    if (!mounted) return;
    setState(() {
      _items = items;
      _currentMileage = mileage;
      _loading = false;
    });
  }

  Future<void> _addItem() async {
    final titleController = TextEditingController();
    final intervalController = TextEditingController(text: '10000');
    final lastController =
        TextEditingController(text: _currentMileage.toString());
    final noteController = TextEditingController();
    var type = 'mileage';
    var date = DateTime.now().add(const Duration(days: 365));

    final saved = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog.adaptive(
              title: const Text('Новое обслуживание'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        hintText: 'Например: Моторное масло',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'mileage',
                          label: Text('По пробегу'),
                          icon: Icon(Icons.speed),
                        ),
                        ButtonSegment(
                          value: 'date',
                          label: Text('По дате'),
                          icon: Icon(Icons.event),
                        ),
                      ],
                      selected: {type},
                      onSelectionChanged: (value) {
                        setDialogState(() => type = value.first);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (type == 'mileage') ...[
                      TextField(
                        controller: intervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Интервал',
                          suffixText: 'км',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: lastController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Пробег последнего обслуживания',
                          suffixText: 'км',
                        ),
                      ),
                    ] else
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Следующая дата'),
                        subtitle: Text(
                          '${date.day.toString().padLeft(2, '0')}.'
                          '${date.month.toString().padLeft(2, '0')}.'
                          '${date.year}',
                        ),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => date = selected);
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || titleController.text.trim().isEmpty) return;

    if (type == 'mileage') {
      final interval = int.tryParse(intervalController.text) ?? 0;
      final last = int.tryParse(lastController.text) ?? _currentMileage;
      if (interval <= 0) return;
      await _repository.addMileageItem(
        title: titleController.text.trim(),
        intervalKm: interval,
        lastMileage: last,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );
    } else {
      await _repository.addDateItem(
        title: titleController.text.trim(),
        date: date,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );
    }

    await _load();
  }

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _databaseTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _recordMaintenanceExpense(MaintenanceItem item) async {
    final controller = TextEditingController();
    final amount = await showAdaptiveDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text('Стоимость обслуживания'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Сколько списать со счёта автобуса',
            suffixText: '₽',
            helperText: 'Можно оставить пустым, если расходов не было',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 0.0),
            child: const Text('Без расходов'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Списать'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (amount == null || amount <= 0) return;
    final now = DateTime.now();
    await ExpenseRepository.instance.addExpense(
      Expense(
        date: _databaseDate(now),
        time: _databaseTime(TimeOfDay.fromDateTime(now)),
        category: 'ТО и обслуживание',
        description: item.title,
        amount: amount,
      ),
    );
  }

  Future<void> _complete(MaintenanceItem item) async {
    var completed = false;
    if (item.isMileage) {
      final controller =
          TextEditingController(text: _currentMileage.toString());
      final value = await showAdaptiveDialog<int>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text('Выполнено: ${item.title}'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Текущий пробег',
              suffixText: 'км',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(controller.text)),
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      );
      if (value != null) {
        await _repository.completeMileageItem(item, value);
        completed = true;
      }
    } else {
      final nextDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 365)),
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
      );
      if (nextDate != null) {
        await _repository.completeDateItem(item, nextDate);
        completed = true;
      }
    }
    if (completed && mounted) {
      await _recordMaintenanceExpense(item);
    }
    await _load();
  }

  Color _statusColor(MaintenanceItem item) {
    if (item.isMileage) {
      final left = (item.nextValue ?? 0) - _currentMileage;
      if (left <= 0) return Colors.red;
      if (left <= 1000) return Colors.orange;
      return Colors.green;
    }
    final next = DateTime.fromMillisecondsSinceEpoch(item.nextValue ?? 0);
    final days = next.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.red;
    if (days <= 30) return Colors.orange;
    return Colors.green;
  }

  String _statusText(MaintenanceItem item) {
    if (item.isMileage) {
      final left = (item.nextValue ?? 0) - _currentMileage;
      return left <= 0
          ? 'Просрочено на ${left.abs()} км'
          : 'Осталось $left км';
    }
    final next = DateTime.fromMillisecondsSinceEpoch(item.nextValue ?? 0);
    final days = next.difference(DateTime.now()).inDays;
    return days < 0
        ? 'Просрочено на ${days.abs()} дн.'
        : 'Через $days дн.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ТО автобуса')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  BusCard(
                    child: Row(
                      children: [
                        const Icon(Icons.speed),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Текущий пробег')),
                        Text(
                          '$_currentMileage км',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    const BusCard(
                      child: Text(
                        'Добавьте масло, фильтры, страховку, '
                        'техосмотр или другое обслуживание.',
                      ),
                    )
                  else
                    for (final item in _items) ...[
                      BusCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  item.isMileage
                                      ? Icons.build_outlined
                                      : Icons.event_available_outlined,
                                  color: _statusColor(item),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'delete' &&
                                        item.id != null) {
                                      await _repository.delete(item.id!);
                                      await _load();
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Удалить'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _statusText(item),
                              style: TextStyle(
                                color: _statusColor(item),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.note?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(item.note!),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _complete(item),
                                icon: const Icon(Icons.check),
                                label: const Text(
                                  'Отметить выполненным',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
