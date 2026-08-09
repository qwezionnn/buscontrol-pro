
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/cloud_sync_service.dart';
import '../../models/vehicle.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/backup_service.dart';
import '../bus/bus_screen.dart';
import '../calendar/calendar_screen.dart';
import '../finance/finance_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/vehicles_screen.dart';
import '../today/today_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SettingsRepository _settingsRepository =
      SettingsRepository.instance;
  final VehicleRepository _vehicleRepository =
      VehicleRepository.instance;
  final CloudSyncService _cloudSyncService = CloudSyncService.instance;
  final BackupService _backupService = BackupService.instance;

  int _currentIndex = 0;
  int _refreshVersion = 0;
  List<Vehicle> _vehicles = const [];
  int? _activeVehicleId;

  @override
  void initState() {
    super.initState();
    _settingsRepository.addListener(_handleChanged);
    _vehicleRepository.addListener(_handleVehicleChanged);
    _cloudSyncService.addListener(_handleCloudChanged);
    _backupService.addListener(_handleBackupRestored);
    _loadVehicles();
  }

  @override
  void dispose() {
    _settingsRepository.removeListener(_handleChanged);
    _vehicleRepository.removeListener(_handleVehicleChanged);
    _cloudSyncService.removeListener(_handleCloudChanged);
    _backupService.removeListener(_handleBackupRestored);
    super.dispose();
  }


  void _handleBackupRestored() {
    if (!mounted) return;
    _loadVehicles();
    setState(() => _refreshVersion++);
  }

  void _handleCloudChanged() {
    if (!mounted) return;
    _loadVehicles();
    setState(() => _refreshVersion++);
  }

  void _handleChanged() {
    if (!mounted) return;
    _loadVehicles();
    setState(() => _refreshVersion++);
  }

  Future<void> _handleVehicleChanged() async {
    await _loadVehicles();
    if (!mounted) return;
    setState(() => _refreshVersion++);
  }

  Future<void> _loadVehicles() async {
    final vehicles = await _vehicleRepository.getVehicles();
    final active = await _vehicleRepository.getActiveVehicle();
    if (!mounted) return;
    setState(() {
      _vehicles = vehicles;
      _activeVehicleId = active.id;
    });
  }

  void _selectPage(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
      _refreshVersion++;
    });
  }

  Future<void> _selectVehicle(int? id) async {
    if (id == null || id == _activeVehicleId) return;
    HapticFeedback.selectionClick();
    await _vehicleRepository.setActiveVehicle(id);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TodayScreen(key: ValueKey('today-$_refreshVersion')),
      CalendarScreen(key: ValueKey('calendar-$_refreshVersion')),
      FinanceScreen(key: ValueKey('finance-$_refreshVersion')),
      BusScreen(key: ValueKey('bus-$_refreshVersion')),
      SettingsScreen(key: ValueKey('settings-$_refreshVersion')),
    ];

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _vehicles.any(
                            (vehicle) => vehicle.id == _activeVehicleId,
                          )
                              ? _activeVehicleId
                              : null,
                          hint: const Text('Выберите транспорт'),
                          items: _vehicles
                              .map(
                                (vehicle) => DropdownMenuItem<int>(
                                  value: vehicle.id,
                                  child: Text(
                                    vehicle.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _selectVehicle,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Управление транспортом',
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const VehiclesScreen(),
                          ),
                        );
                        await _loadVehicles();
                      },
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0.025, 0),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: slide,
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('page-$_currentIndex-$_refreshVersion'),
                child: pages[_currentIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Сегодня',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Календарь',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Финансы',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            selectedIcon: Icon(Icons.directions_bus),
            label: 'Автобус',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Ещё',
          ),
        ],
      ),
    );
  }
}
