import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/order.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

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

  Future<void> scheduleOrder(Order order) async {
    if (kIsWeb || order.id == null || !order.isPlanned) return;

    await initialize();
    await cancelOrder(order.id!);

    final at = _date(order);
    if (at == null) return;

    final reminderHours = order.reminderHours <= 0 ? 2 : order.reminderHours;
    final reminders = <({int slot, DateTime when, String title, String body})>[
      (
        slot: 1,
        when: at.subtract(const Duration(days: 1)),
        title: '🚌 Завтра заказ',
        body: 'Завтра в ${order.time} — ${order.title}. Не забудь про заказ.',
      ),
      (
        slot: 2,
        when: at.subtract(Duration(hours: reminderHours)),
        title: '🚌 Скоро заказ',
        body: '${order.title} в ${order.time}. До заказа осталось $reminderHours ч.',
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
