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
  String? _pendingNavigationAction;

  static const String _endMileageEnabledKey = 'end_mileage_reminder_enabled';
  static const String _endMileageHourKey = 'end_mileage_reminder_hour';
  static const String _endMileageMinuteKey = 'end_mileage_reminder_minute';

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
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        launchDetails?.notificationResponse != null) {
      _handleNotificationResponse(launchDetails!.notificationResponse!);
    }

    _ready = true;
  }


  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload ?? '';
    if (payload == 'quick_end_mileage') {
      _pendingNavigationAction = 'mileage';
      return;
    }
    if (payload.startsWith('maintenance:')) {
      _pendingNavigationAction = 'maintenance';
    }
  }

  /// Returns a one-shot navigation action created by tapping a notification.
  String? consumeNavigationAction() {
    final action = _pendingNavigationAction;
    _pendingNavigationAction = null;
    return action;
  }

  Future<({bool enabled, int hour, int minute})>
      getEndMileageReminderSettings() async {
    final enabled =
        (await DatabaseHelper.instance.getSetting(_endMileageEnabledKey)) == '1';
    final hour = int.tryParse(
          await DatabaseHelper.instance.getSetting(_endMileageHourKey) ?? '',
        ) ??
        18;
    final minute = int.tryParse(
          await DatabaseHelper.instance.getSetting(_endMileageMinuteKey) ?? '',
        ) ??
        5;
    return (
      enabled: enabled,
      hour: hour.clamp(0, 23).toInt(),
      minute: minute.clamp(0, 59).toInt(),
    );
  }

  Future<void> saveEndMileageReminderSettings({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await DatabaseHelper.instance.setSettings({
      _endMileageEnabledKey: enabled ? '1' : '0',
      _endMileageHourKey: hour.clamp(0, 23).toString(),
      _endMileageMinuteKey: minute.clamp(0, 59).toString(),
    });
    await refreshEndMileageReminderSchedule();
  }

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  int _endMileageReminderId(DateTime date) {
    // Stable positive id below Android's signed 32-bit limit.
    return 920000000 +
        (date.year % 100) * 10000 +
        date.month * 100 +
        date.day;
  }

  bool _isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  Future<void> cancelEndMileageReminderForDate(DateTime date) async {
    if (kIsWeb) return;
    await initialize();
    final normalized = DateTime(date.year, date.month, date.day);
    await _plugin.cancel(_endMileageReminderId(normalized));
  }

  /// Rebuilds a rolling set of weekday reminders. Weekends are intentionally
  /// skipped. Today's reminder is skipped when the end mileage is already saved.
  Future<void> refreshEndMileageReminderSchedule() async {
    if (kIsWeb) return;
    await initialize();

    final settings = await getEndMileageReminderSettings();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Remove the previous rolling schedule first so changing the time doesn't
    // leave old notifications behind.
    for (var offset = -1; offset <= 16; offset++) {
      final date = today.add(Duration(days: offset));
      await _plugin.cancel(_endMileageReminderId(date));
    }

    if (!settings.enabled) return;

    // Keep two weeks scheduled to stay well below iOS' pending-notification limit.
    // Each app launch refreshes this rolling window.
    for (var offset = 0; offset <= 14; offset++) {
      final date = today.add(Duration(days: offset));
      if (_isWeekend(date)) continue;

      final when = DateTime(
        date.year,
        date.month,
        date.day,
        settings.hour,
        settings.minute,
      );
      if (!when.isAfter(now)) continue;

      final existing = await DatabaseHelper.instance.getDailyLog(
        _databaseDate(date),
      );
      if (existing?['end_mileage'] != null) continue;

      await _plugin.zonedSchedule(
        _endMileageReminderId(date),
        '🛣️ Конечный пробег',
        'Не забудь внести конечный пробег за сегодня.',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
          android: AndroidNotificationDetails(
            'end_mileage',
            'Конечный пробег',
            channelDescription: 'Напоминание внести конечный пробег автобуса',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'quick_end_mileage',
      );
    }
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

  Future<void> _scheduleLiveActivity({
    required int activityId,
    required String kind,
    required String title,
    required String time,
    required String note,
    required DateTime eventAt,
    required int leadMinutes,
    bool replaceExisting = true,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!eventAt.isAfter(DateTime.now())) return;

    final minutes = leadMinutes <= 0 ? 60 : leadMinutes;
    final startAt = eventAt.subtract(Duration(minutes: minutes));
    final now = DateTime.now();

    try {
      await _liveChannel.invokeMethod(
        startAt.isAfter(now) ? 'schedule' : 'start',
        {
          // Keep orderId for backwards compatibility with older native builds,
          // while eventId is the generic identifier used by the new bridge.
          'eventId': activityId,
          'orderId': activityId,
          'kind': kind,
          'title': title,
          'time': time,
          'note': note,
          'orderTimestampMs': eventAt.millisecondsSinceEpoch,
          'startTimestampMs': startAt.millisecondsSinceEpoch,
          'replaceExisting': replaceExisting,
        },
      );
      debugPrint(
        'Live Activity registered: kind=$kind id=$activityId '
        'start=$startAt event=$eventAt',
      );
    } on PlatformException catch (error) {
      // Keep the ordinary local notification as a fallback, but don't hide the
      // reason anymore. This makes GitHub/Xcode/device logs useful if iOS
      // rejects a pending Live Activity because of permissions or system limits.
      debugPrint(
        'Live Activity registration failed: kind=$kind id=$activityId '
        'code=${error.code} message=${error.message}',
      );
    }
  }

  Future<void> startLiveActivityIfEligible(
    Order order, {
    bool replaceExisting = true,
  }) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        order.id == null ||
        !order.isPlanned) {
      return;
    }
    final at = _date(order);
    if (at == null) return;

    await _scheduleLiveActivity(
      activityId: order.id!,
      kind: 'order',
      title: order.title,
      time: order.time,
      note: order.note ?? '',
      eventAt: at,
      leadMinutes: order.liveActivityMinutes,
      replaceExisting: replaceExisting,
    );
  }

  /// Recovery helper for orders created before the current build. Newly saved
  /// orders are registered immediately by scheduleOrder().
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
    for (final row in rows) {
      final order = Order.fromMap(row);
      final at = _date(order);
      if (at == null || !at.isAfter(now)) continue;
      await startLiveActivityIfEligible(order, replaceExisting: false);
      break;
    }
  }

  Future<void> endLiveActivity(int eventId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _liveChannel.invokeMethod('end', {
        'eventId': eventId,
        'orderId': eventId,
      });
    } on PlatformException catch (error) {
      debugPrint(
        'Live Activity end failed: id=$eventId '
        'code=${error.code} message=${error.message}',
      );
    }
  }

  Future<void> scheduleOrder(Order order) async {
    if (kIsWeb || order.id == null || !order.isPlanned) return;

    await initialize();
    await cancelOrder(order.id!);

    final at = _date(order);
    if (at == null) return;

    await startLiveActivityIfEligible(order);

    final firstMinutes =
        order.firstReminderMinutes <= 0 ? 720 : order.firstReminderMinutes;
    final liveMinutes =
        order.liveActivityMinutes <= 0 ? 60 : order.liveActivityMinutes;
    final reminders = <({int slot, DateTime when, String title, String body})>[
      (
        slot: 1,
        when: at.subtract(Duration(minutes: firstMinutes)),
        title: '🚌 Напоминание о заказе',
        body:
            '${order.title} • ${order.time}${order.note == null || order.note!.trim().isEmpty ? '' : '\n${order.note}'}',
      ),
      (
        slot: 2,
        when: at.subtract(Duration(minutes: liveMinutes)),
        title: '🚌 Скоро заказ',
        body:
            '${order.title} • ${order.time} • осталось ${_durationLabel(liveMinutes)}${order.note == null || order.note!.trim().isEmpty ? '' : '\n${order.note}'}',
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

  // Use a positive namespace for calendar events. Older builds used negative
  // ids; keeping a legacy id helper lets us clean those pending activities up.
  int _calendarLiveId(int id) => 1000000000 + id;
  int _legacyCalendarLiveId(int id) => -1000000 - id;

  DateTime? _calendarEventDate(String date, String? time) {
    if (time == null || time.isEmpty) return null;
    final dp = date.split('-');
    final tp = time.split(':');
    if (dp.length != 3 || tp.length < 2) return null;
    final year = int.tryParse(dp[0]);
    final month = int.tryParse(dp[1]);
    final day = int.tryParse(dp[2]);
    final hour = int.tryParse(tp[0]);
    final minute = int.tryParse(tp[1]);
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }
    return DateTime(year, month, day, hour, minute);
  }

  Future<void> startCalendarNoteLiveActivityIfEligible({
    required int id,
    required String date,
    required String? time,
    required String title,
    String? body,
    required bool enabled,
    required int reminderMinutes,
    bool replaceExisting = true,
  }) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        !enabled) {
      return;
    }

    final at = _calendarEventDate(date, time);
    if (at == null || !at.isAfter(DateTime.now())) return;

    // Remove the identifier used by older builds so it can never compete with
    // the new generic calendar-event activity.
    await endLiveActivity(_legacyCalendarLiveId(id));

    await _scheduleLiveActivity(
      activityId: _calendarLiveId(id),
      kind: 'note',
      title: title,
      time: time!,
      note: body ?? '',
      eventAt: at,
      leadMinutes: reminderMinutes <= 0 ? 60 : reminderMinutes,
      replaceExisting: replaceExisting,
    );
  }

  /// Recovery helper for calendar notes created before this build.
  Future<void> startNearestCalendarNoteLiveActivityIfEligible() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final db = await DatabaseHelper.instance.database;
    final vehicleId = await DatabaseHelper.instance.getActiveVehicleId();
    final rows = await db.query(
      'calendar_notes',
      where:
          'vehicle_id = ? AND reminder_enabled = 1 AND time IS NOT NULL',
      whereArgs: [vehicleId],
      orderBy: 'date ASC, time ASC',
    );
    final now = DateTime.now();
    for (final row in rows) {
      final at = _calendarEventDate(
        row['date']?.toString() ?? '',
        row['time']?.toString(),
      );
      if (at == null || !at.isAfter(now)) continue;
      await startCalendarNoteLiveActivityIfEligible(
        id: (row['id'] as num).toInt(),
        date: row['date'].toString(),
        time: row['time']?.toString(),
        title: row['title']?.toString() ?? 'Заметка',
        body: row['body']?.toString(),
        enabled: true,
        reminderMinutes:
            (row['reminder_minutes'] as num?)?.toInt() ?? 60,
        replaceExisting: false,
      );
      break;
    }
  }

  /// Re-registers a small chronological recovery window for both orders and
  /// calendar notes. New/edited events are scheduled immediately when saved;
  /// this mainly restores Live Activities after upgrading the app or reinstalling
  /// it. Scheduled Live Activities count toward the iOS system limit, so the
  /// recovery pass intentionally prioritizes only the nearest events.
  Future<void> refreshUpcomingLiveActivities({int maxEvents = 6}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    final db = await DatabaseHelper.instance.database;
    final vehicleId = await DatabaseHelper.instance.getActiveVehicleId();
    final now = DateTime.now();

    final candidates = <({
      DateTime at,
      int activityId,
      String kind,
      String title,
      String time,
      String note,
      int leadMinutes,
      int? legacyId,
    })>[];

    final orderRows = await db.query(
      'orders',
      where: 'vehicle_id = ? AND status = ?',
      whereArgs: [vehicleId, 'planned'],
      orderBy: 'date ASC, time ASC',
    );
    for (final row in orderRows) {
      final order = Order.fromMap(row);
      final at = _date(order);
      if (order.id == null || at == null || !at.isAfter(now)) continue;
      candidates.add((
        at: at,
        activityId: order.id!,
        kind: 'order',
        title: order.title,
        time: order.time,
        note: order.note ?? '',
        leadMinutes:
            order.liveActivityMinutes <= 0 ? 60 : order.liveActivityMinutes,
        legacyId: null,
      ));
    }

    final noteRows = await db.query(
      'calendar_notes',
      where:
          'vehicle_id = ? AND reminder_enabled = 1 AND time IS NOT NULL',
      whereArgs: [vehicleId],
      orderBy: 'date ASC, time ASC',
    );
    for (final row in noteRows) {
      final id = (row['id'] as num?)?.toInt();
      final date = row['date']?.toString() ?? '';
      final time = row['time']?.toString();
      final at = _calendarEventDate(date, time);
      if (id == null || at == null || !at.isAfter(now) || time == null) continue;
      candidates.add((
        at: at,
        activityId: _calendarLiveId(id),
        kind: 'note',
        title: row['title']?.toString() ?? 'Заметка',
        time: time,
        note: row['body']?.toString() ?? '',
        leadMinutes:
            ((row['reminder_minutes'] as num?)?.toInt() ?? 60) <= 0
                ? 60
                : (row['reminder_minutes'] as num?)?.toInt() ?? 60,
        legacyId: _legacyCalendarLiveId(id),
      ));
    }

    candidates.sort((a, b) => a.at.compareTo(b.at));

    for (final event in candidates.take(maxEvents)) {
      if (event.legacyId != null) {
        await endLiveActivity(event.legacyId!);
      }
      await _scheduleLiveActivity(
        activityId: event.activityId,
        kind: event.kind,
        title: event.title,
        time: event.time,
        note: event.note,
        eventAt: event.at,
        leadMinutes: event.leadMinutes,
        replaceExisting: false,
      );
    }
  }

  int _calendarNoteId(int id) => 850000 + id;

  Future<void> cancelCalendarNote(int id) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(_calendarNoteId(id));
    await endLiveActivity(_calendarLiveId(id));
    await endLiveActivity(_legacyCalendarLiveId(id));
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
    await endLiveActivity(_calendarLiveId(id));
    await endLiveActivity(_legacyCalendarLiveId(id));
    if (!enabled || time == null || time.isEmpty) return;

    final effectiveReminderMinutes = reminderMinutes <= 0 ? 60 : reminderMinutes;
    await startCalendarNoteLiveActivityIfEligible(
      id: id,
      date: date,
      time: time,
      title: title,
      body: body,
      enabled: enabled,
      reminderMinutes: effectiveReminderMinutes,
    );

    final eventAt = _calendarEventDate(date, time);
    if (eventAt == null) return;
    final when = eventAt.subtract(Duration(minutes: effectiveReminderMinutes));
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

  int _maintenanceReminderId(int itemId, int slot) {
    return 780000000 + (itemId % 1000000) * 10 + slot;
  }

  Future<void> cancelMaintenanceReminders(int itemId) async {
    if (kIsWeb) return;
    await initialize();
    for (var slot = 1; slot <= 3; slot++) {
      await _plugin.cancel(_maintenanceReminderId(itemId, slot));
    }
  }

  /// Schedules document / date-based maintenance warnings for 30, 7 and 1 day
  /// before the due date. Mileage-based maintenance is surfaced in-app because
  /// its trigger depends on the odometer rather than wall-clock time.
  Future<void> scheduleMaintenanceReminders({
    required int itemId,
    required String title,
    required DateTime dueDate,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await cancelMaintenanceReminders(itemId);

    final due = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      10,
    );
    const leads = <int>[30, 7, 1];
    final now = DateTime.now();

    for (var index = 0; index < leads.length; index++) {
      final days = leads[index];
      final when = due.subtract(Duration(days: days));
      if (!when.isAfter(now)) continue;

      final dateLabel =
          '${due.day.toString().padLeft(2, '0')}.'
          '${due.month.toString().padLeft(2, '0')}.${due.year}';
      await _plugin.zonedSchedule(
        _maintenanceReminderId(itemId, index + 1),
        '🔧 ТО / документы',
        '$title — срок $dateLabel. Осталось $days дн.',
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
          android: AndroidNotificationDetails(
            'maintenance_dates',
            'ТО и документы',
            channelDescription: 'Сроки страховки, карт, тахографа и ТО',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'maintenance:$itemId',
      );
    }
  }

  /// Restores all date-based maintenance reminders after an app update,
  /// restart or database restore.
  Future<void> refreshMaintenanceReminders() async {
    if (kIsWeb) return;
    await initialize();
    final db = await DatabaseHelper.instance.database;
    final vehicleId = await DatabaseHelper.instance.getActiveVehicleId();
    final rows = await db.query(
      'maintenance_items',
      where: 'vehicle_id = ? AND kind = ?',
      whereArgs: [vehicleId, 'date'],
    );

    for (final row in rows) {
      final id = (row['id'] as num?)?.toInt();
      final nextValue = (row['next_value'] as num?)?.toInt();
      if (id == null || nextValue == null || nextValue <= 0) continue;
      await scheduleMaintenanceReminders(
        itemId: id,
        title: row['title']?.toString() ?? 'ТО / документ',
        dueDate: DateTime.fromMillisecondsSinceEpoch(nextValue),
      );
    }
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
