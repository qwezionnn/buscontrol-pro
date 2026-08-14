import 'package:flutter/material.dart';

import '../../models/expense.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/part_bookmark_repository.dart';
import '../../widgets/bus_card.dart';
import '../expenses/add_expense_screen.dart';

class BusExpensesScreen extends StatefulWidget {
  const BusExpensesScreen({super.key});

  @override
  State<BusExpensesScreen> createState() => _BusExpensesScreenState();
}

class _BusExpensesScreenState extends State<BusExpensesScreen> {
  final _repository = ExpenseRepository.instance;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Expense> _items = const [];
  bool _loading = true;

  static const _monthNames = <String>[
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    final items = await _repository.getExpensesForMonth(_month);

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  double get _total => _items.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );

  String _money(double value) => '${value.toStringAsFixed(0)} ₽';

  String _dateText(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load();
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          initialDate: DateTime.now(),
        ),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _edit(Expense expense) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(expense: expense),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete(Expense expense) async {
    final id = expense.id;
    if (id == null) return;

    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text('Удалить расход?'),
        content: Text(
          '${expense.category} • ${_money(expense.amount)}\n'
          '${_dateText(expense.date)}',
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

    if (confirmed != true) return;
    await _repository.deleteExpense(id);
    await _load();
  }

  Future<void> _addToBookmarks(Expense expense) async {
    final description = (expense.description ?? '').trim();
    final initialName = description.isNotEmpty ? description : expense.category;

    final name = TextEditingController(text: initialName);
    final brand = TextEditingController();
    final article = TextEditingController();
    final shop = TextEditingController();
    final price = TextEditingController(text: expense.amount.toStringAsFixed(
      expense.amount == expense.amount.roundToDouble() ? 0 : 2,
    ));
    final url = TextEditingController();
    final note = TextEditingController(
      text: 'Добавлено из расхода ${_dateText(expense.date)}',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Добавить в закладки'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Название *')),
              TextField(controller: brand, decoration: const InputDecoration(labelText: 'Бренд (необязательно)')),
              TextField(controller: article, decoration: const InputDecoration(labelText: 'Артикул (необязательно)')),
              TextField(controller: shop, decoration: const InputDecoration(labelText: 'Где покупал (необязательно)')),
              TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена (необязательно)')),
              TextField(controller: url, decoration: const InputDecoration(labelText: 'Ссылка (необязательно)')),
              TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Заметка (необязательно)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Сохранить')),
        ],
      ),
    );

    if (saved == true && name.text.trim().isNotEmpty) {
      await PartBookmarkRepository.instance.save(
        name: name.text,
        brand: brand.text,
        article: article.text,
        shop: shop.text,
        price: double.tryParse(price.text.replaceAll(',', '.')),
        url: url.text,
        note: note.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запчасть добавлена в закладки')),
        );
      }
    }

    for (final controller in [name, brand, article, shop, price, url, note]) {
      controller.dispose();
    }
  }

  Future<void> _showActions(Expense expense) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Редактировать'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: const Text('Добавить в закладки'),
              subtitle: Text(
                (expense.description ?? '').trim().isNotEmpty
                    ? expense.description!.trim()
                    : expense.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.pop(sheetContext, 'bookmark'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              title: const Text(
                'Удалить',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'edit') {
      await _edit(expense);
    } else if (action == 'bookmark') {
      await _addToBookmarks(expense);
    } else if (action == 'delete') {
      await _delete(expense);
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'ремонт':
        return Icons.build_outlined;
      case 'запчасти':
        return Icons.settings_outlined;
      case 'мойка':
        return Icons.local_car_wash_outlined;
      case 'страховка':
        return Icons.shield_outlined;
      case 'парковка':
        return Icons.local_parking_outlined;
      case 'штраф':
        return Icons.gavel_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расходы автобуса'),
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.add),
            tooltip: 'Добавить расход',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            BusCard(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${_monthNames[_month.month - 1]} ${_month.year}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_items.length} записей • ${_money(_total)}',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const BusCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 38),
                      SizedBox(height: 10),
                      Text('За этот месяц расходов нет.'),
                    ],
                  ),
                ),
              )
            else
              for (final expense in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BusCard(
                    onTap: () => _showActions(expense),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _categoryIcon(expense.category),
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.category,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  _dateText(expense.date),
                                  if ((expense.time ?? '').isNotEmpty)
                                    expense.time!,
                                ].join(' • '),
                              ),
                              if ((expense.description ?? '').trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(expense.description!),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _money(expense.amount),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Icon(
                              Icons.more_horiz,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
