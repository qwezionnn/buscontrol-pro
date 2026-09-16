import 'package:flutter/material.dart';

import '../../models/daily_log.dart';
import '../../repositories/daily_log_repository.dart';

class QuickEndMileageScreen extends StatefulWidget {
  const QuickEndMileageScreen({super.key});

  @override
  State<QuickEndMileageScreen> createState() => _QuickEndMileageScreenState();
}

class _QuickEndMileageScreenState extends State<QuickEndMileageScreen> {
  final _controller = TextEditingController();
  final _repository = DailyLogRepository.instance;

  DailyLog? _log;
  bool _loading = true;
  bool _saving = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final log = await _repository.getLogForDate(_today);
      if (!mounted) return;
      _controller.text = log.endMileage?.toString() ?? '';
      setState(() {
        _log = log;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Не удалось загрузить пробег: $error');
    }
  }

  Future<void> _save() async {
    final value = int.tryParse(_controller.text.trim());
    if (value == null) {
      _message('Введите конечный пробег.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _repository.completeDay(date: _today, endMileage: value);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final message = error
          .toString()
          .replaceFirst('Invalid argument(s): ', '')
          .replaceFirst('Bad state: ', '');
      _message(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Конечный пробег')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Сегодня',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _log?.startMileage == null
                        ? 'Начальный пробег не задан'
                        : 'Начальный пробег: ${_log!.startMileage} км',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saving ? null : _save(),
                    decoration: const InputDecoration(
                      labelText: 'Конечный пробег',
                      suffixText: 'км',
                      prefixIcon: Icon(Icons.route_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Сохранить пробег'),
                  ),
                ],
              ),
      ),
    );
  }
}
