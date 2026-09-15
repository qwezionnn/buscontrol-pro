import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<TimeOfDay?> showBusTimeWheelPicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String title = 'Выберите время',
}) async {
  var selected = DateTime(2020, 1, 1, initialTime.hour, initialTime.minute);
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: false,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: 330,
        child: Column(
          children: [
            _PickerHeader(
              title: title,
              onCancel: () => Navigator.pop(sheetContext),
              onDone: () => Navigator.pop(
                sheetContext,
                TimeOfDay(hour: selected.hour, minute: selected.minute),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                minuteInterval: 1,
                initialDateTime: selected,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<int?> showBusDurationWheelPicker(
  BuildContext context, {
  required int initialMinutes,
  String title = 'Выберите длительность',
  int maxHours = 24,
  bool allowZero = false,
}) async {
  var hours = (initialMinutes ~/ 60).clamp(0, maxHours);
  var minutes = (initialMinutes % 60).clamp(0, 59);

  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: false,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: 330,
        child: Column(
          children: [
            _PickerHeader(
              title: title,
              onCancel: () => Navigator.pop(sheetContext),
              onDone: () {
                final total = hours * 60 + minutes;
                if (!allowZero && total == 0) return;
                Navigator.pop(sheetContext, total);
              },
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: hours),
                      itemExtent: 42,
                      onSelectedItemChanged: (value) => hours = value,
                      children: [
                        for (var i = 0; i <= maxHours; i++)
                          Center(child: Text('$i ч')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: minutes),
                      itemExtent: 42,
                      onSelectedItemChanged: (value) => minutes = value,
                      children: [
                        for (var i = 0; i < 60; i++)
                          Center(child: Text('${i.toString().padLeft(2, '0')} мин')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String formatBusDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest мин';
  if (rest == 0) return '$hours ч';
  return '$hours ч ${rest.toString().padLeft(2, '0')} мин';
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({
    required this.title,
    required this.onCancel,
    required this.onDone,
  });

  final String title;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          TextButton(onPressed: onCancel, child: const Text('Отмена')),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onDone, child: const Text('Готово')),
        ],
      ),
    );
  }
}
