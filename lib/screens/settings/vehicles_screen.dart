
import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final VehicleRepository _repository = VehicleRepository.instance;
  bool _loading = true;
  List<Vehicle> _vehicles = const [];
  int? _activeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final vehicles = await _repository.getVehicles(
      includeArchived: true,
    );
    final active = await _repository.getActiveVehicle();
    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _activeId = active.id;
      _loading = false;
    });
  }

  Future<void> _edit([Vehicle? vehicle]) async {
    final name = TextEditingController(text: vehicle?.name ?? '');
    final number = TextEditingController(
      text: vehicle?.registrationNumber ?? '',
    );
    final mileage = TextEditingController(
      text: vehicle?.initialMileage?.toString() ?? '',
    );
    final note = TextEditingController(text: vehicle?.note ?? '');

    final saved = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: Text(vehicle == null ? 'Новый транспорт' : 'Редактировать'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например: ПАЗ Vector NEXT',
                ),
              ),
              TextField(
                controller: number,
                decoration: const InputDecoration(
                  labelText: 'Госномер',
                ),
              ),
              TextField(
                controller: mileage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Начальный пробег',
                  suffixText: 'км',
                ),
              ),
              TextField(
                controller: note,
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
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final value = Vehicle(
        id: vehicle?.id,
        name: name.text.trim(),
        registrationNumber:
            number.text.trim().isEmpty ? null : number.text.trim(),
        initialMileage: int.tryParse(mileage.text.trim()),
        note: note.text.trim().isEmpty ? null : note.text.trim(),
        archived: vehicle?.archived ?? false,
      );
      if (vehicle == null) {
        final id = await _repository.addVehicle(value);
        await _repository.setActiveVehicle(id);
      } else {
        await _repository.updateVehicle(value);
      }
      await _load();
    }

    name.dispose();
    number.dispose();
    mileage.dispose();
    note.dispose();
  }

  Future<void> _archive(Vehicle vehicle) async {
    try {
      await _repository.archiveVehicle(vehicle.id!);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _delete(Vehicle vehicle) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog.adaptive(
        title: const Text('Удалить автобус?'),
        content: Text(
          'Будут удалены автобус «${vehicle.displayName}» и связанные с ним '
          'рейсы, заказы, топливо, расходы, пробег, ТО и кредиты.',
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
    if (confirmed != true || !mounted) return;

    try {
      await _repository.deleteVehicle(vehicle.id!);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои автобусы и ТС'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: _vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];
                final active = vehicle.id == _activeId;
                return Card(
                  child: ListTile(
                    enabled: !vehicle.archived,
                    leading: CircleAvatar(
                      child: Icon(
                        active
                            ? Icons.directions_bus
                            : Icons.directions_bus_outlined,
                      ),
                    ),
                    title: Text(vehicle.displayName),
                    subtitle: Text(
                      vehicle.archived
                          ? 'В архиве'
                          : vehicle.initialMileage == null
                              ? 'Пробег не указан'
                              : '${vehicle.initialMileage} км',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'select') {
                          await _repository.setActiveVehicle(vehicle.id!);
                          await _load();
                        } else if (value == 'edit') {
                          await _edit(vehicle);
                        } else if (value == 'archive') {
                          await _archive(vehicle);
                        } else if (value == 'delete') {
                          await _delete(vehicle);
                        }
                      },
                      itemBuilder: (_) => [
                        if (!active && !vehicle.archived)
                          const PopupMenuItem(
                            value: 'select',
                            child: Text('Сделать активным'),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Редактировать'),
                        ),
                        if (!active && !vehicle.archived)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('Архивировать'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Удалить'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
