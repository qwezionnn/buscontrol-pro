import 'package:flutter/material.dart';

import '../../bus/pro_tools_screen.dart';
import '../../expenses/add_expense_screen.dart';
import '../../finance/notes_screen.dart';
import '../../fuel/add_fuel_screen.dart';
import '../../orders/add_order_screen.dart';
import '../../trips/add_extra_trip_screen.dart';

class TodayProSection extends StatefulWidget {
  const TodayProSection({super.key});

  @override
  State<TodayProSection> createState() => _TodayProSectionState();
}

class _TodayProSectionState extends State<TodayProSection> {
  Future<void> _showQuickActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'Быстро добавить',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _item(
              sheetContext,
              Icons.local_taxi,
              'Заказ',
              const AddOrderScreen(),
            ),
            _item(
              sheetContext,
              Icons.add_road,
              'Доп. рейс',
              const AddExtraTripScreen(),
            ),
            _item(
              sheetContext,
              Icons.local_gas_station,
              'Заправку',
              const AddFuelScreen(),
            ),
            _item(
              sheetContext,
              Icons.receipt_long,
              'Расход',
              const AddExpenseScreen(),
            ),
            _item(
              sheetContext,
              Icons.note_alt_outlined,
              'Заметку',
              const NotesScreen(),
            ),
            _item(
              sheetContext,
              Icons.dashboard_customize_outlined,
              'Центр 5.0',
              const ProToolsScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext sheetContext,
    IconData icon,
    String title,
    Widget page,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(sheetContext);
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _showQuickActions,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Быстрые действия'),
      ),
    );
  }
}
