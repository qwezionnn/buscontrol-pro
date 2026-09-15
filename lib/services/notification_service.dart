import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/order.dart';
import '../database/database_helper.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  static const MethodChannel _liveChannel = MethodChannel('buscontrol/live_activity');

  Future<void> initialize() async {
    if (kIsWeb || _ready) return;

    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {}

    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      const InitializationSettings(iOS: ios, android: android),
    );
    _ready = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await initialize();

    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final mac = await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return ios ?? mac ?? true;
  }

  int _id(int orderId, int slot) => orderId * 10 + slot;

  DateTime? _date(Order order) {
    final dateParts = order.date.split('-');
    final timeParts = order.time.split(':');
    if (dateParts.length != 3 || timeParts.length < 2) return null;

    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes % 60 == 0) return '${minutes ~/ 60} ч';
    if (minutes > 60) return '${minutes ~/ 60} ч ${minutes % 60} мин';
    return '$minutes мин';
  }

  Future<void> startLiveActivityIfEligible(Order order) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS || order.id == null || !order.isPlanned) return;
    final at = _date(order);
    if (at == null) return;

    final minutes = order.liveActivityMinutes <= 0 ? 60 : order.liveActivityMinutes;
    final startAt = at.subtract(Duration(minutes: minutes));
    final now = DateTime.now();
    if (now.isBefore(startAt) || !now.isBefore(at)) return;

    try {
      await _liveChannel.invokeMethod('start', {
        'orderId': order.id,
        'title': order.title,
        'time': order.time,
        'note': order.note ?? '',
        'orderTimestampMs': at.millisecondsSinceEpoch,
      });
    } on PlatformException {
      // Live Activities may be disabled by the user or unavailable on this iOS version.
    }
  }

  Future<void> startNearestLiveActivityIfEligible() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final db = await DatabaseHelper.instance.database;
    final vehicleId = await DatabaseHelper.instance.getActiveVehicleId();
    final rows = await db.query(
      'orders',
      where: 'vehicle_id = ? AND status = ?',
      whereArgs: [vehicleId, 'planned'],
      orderBy: 'date ASC, time ASC',
    );

    final now = DateTime.now();
    Order? nearest;
    DateTime? nearestAt;
    for (final row in rows) {
      final order = Order.fromMap(row);
      final at = _date(order);
      if (at == null || !at.isAfter(now)) continue;
      if (nearestAt == null || at.isBefore(nearestAt)) {
        nearest = order;
        nearestAt = at;
      }
    }
    if (nearest != null) {
      await startLiveActivityIfEligible(nearest);
    }
  }

  Future<void> endLiveActivity(int orderId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _liveChannel.invokeMethod('end', {'orderId': orderId});
    } on PlatformException {
      // Ignore unsupported/disabled Live Activities.
    }
  }

  Future<void> scheduleOrder(Order order) async {
    if (kIsWeb || order.id == null || !order.isPlanned) return;

    await initialize();
    await cancelOrder(order.id!);

    final at = _date(order);
    if (at == null) return;

    await startLiveActivityIfEligible(order);

    final firstMinutes = order.firstReminderMinutes <= 0 ? 720 : order.firstReminderMinutes;
    final liveMinutes = order.liveActivityMinutes <= 0 ? 60 : order.liveActivityMinutes;
    final reminders = <({int slot, DateTime when, String title, String body})>[
      (
        slot: 1,
        when: at.subtract(Duration(minutes: firstMinutes)),
        title: '🚌 Напоминание о заказе',
        body: '${order.title} • ${order.time}${order.note == null || order.note!.trim().isEmpty ? '' : '\n${order.note}'}',
      ),
      (
        slot: 2,
        when: at.subtract(Duration(minutes: liveMinutes)),
        title: '🚌 Скоро заказ',
        body: '${order.title} • ${order.time} • осталось ${_durationLabel(liveMinutes)}${order.note == null || order.note!.trim().isEmpty ? '' : '\n${order.note}'}',
      ),
    ];

    for (final reminder in reminders) {
      if (reminder.when.isBefore(DateTime.now())) continue;

      await _plugin.zonedSchedule(
        _id(order.id!, reminder.slot),
        reminder.title,
        reminder.body,
        tz.TZDateTime.from(reminder.when, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
          android: AndroidNotificationDetails(
            'orders',
            'Заказы',
            channelDescription: 'Напоминания о предстоящих заказах',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'order:${order.id}',
      );
    }
  }

  Future<void> cancelOrder(int id) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(_id(id, 1));
    await _plugin.cancel(_id(id, 2));
    await endLiveActivity(id);
  }

  int _calendarNoteId(int id) => 850000 + id;

  Future<void> cancelCalendarNote(int id) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(_calendarNoteId(id));
  }

  Future<void> scheduleCalendarNote({
    required int id,
    required String date,
    required String? time,
    required String title,
    String? body,
    required bool enabled,
    required int reminderMinutes,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(_calendarNoteId(id));
    if (!enabled || time == null || time.isEmpty) return;

    final dp = date.split('-');
    final tp = time.split(':');
    if (dp.length != 3 || tp.length < 2) return;
    final eventAt = DateTime(
      int.parse(dp[0]), int.parse(dp[1]), int.parse(dp[2]),
      int.parse(tp[0]), int.parse(tp[1]),
    );
    final when = eventAt.subtract(Duration(minutes: reminderMinutes));
    if (!when.isAfter(DateTime.now())) return;

    final note = body?.trim();
    await _plugin.zonedSchedule(
      _calendarNoteId(id),
      '📌 $title',
      '${time.trim()}${note == null || note.isEmpty ? '' : '\n$note'}',
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
        android: AndroidNotificationDetails(
          'calendar_notes',
          'Заметки календаря',
          channelDescription: 'Напоминания о заметках и личных событиях',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'calendar_note:$id',
    );
  }

  Future<void> scheduleService({
    required int id,
    required String title,
    required String date,
    int firstDays = 7,
    int secondDays = 1,
  }) async {
    if (kIsWeb) return;

    await initialize();
    final parts = date.split('-');
    if (parts.length != 3) return;

    final due = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      10,
    );

    for (final slot in [(number: 1, days: firstDays), (number: 2, days: secondDays)]) {
      final when = due.subtract(Duration(days: slot.days));
      if (when.isBefore(DateTime.now())) continue;

      await _plugin.zonedSchedule(
        700000 + id * 10 + slot.number,
        '🔧 Скоро обслуживание',
        '$title — осталось ${slot.days} дн. Подготовьте запчасти и расходники.',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
          android: AndroidNotificationDetails(
            'service',
            'ТО и обслуживание',
            channelDescription: 'Напоминания о ТО и обслуживании',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
