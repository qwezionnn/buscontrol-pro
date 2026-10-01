import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../platform/file_download.dart';
import '../repositories/report_repository.dart';

class MonthlyExportOptions {
  const MonthlyExportOptions({
    this.summary = true,
    this.trips = true,
    this.orders = true,
    this.fuel = true,
    this.expenses = true,
    this.repairs = true,
    this.mileage = true,
    this.summaryRegularTrips = true,
    this.summaryRegularTripsTotal = true,
    this.summaryRegularTripsFull = true,
    this.summaryRegularTripsPartial = true,
    this.summaryRegularTripsMorning = true,
    this.summaryRegularTripsEvening = true,
    this.summaryExtraTrips = true,
    this.summaryExtraTripsTotal = true,
    this.summaryExtraTripsWait = true,
    this.summaryOrders = true,
    this.summaryOrdersRevenue = true,
    this.summaryOrderVehicle = true,
    this.summaryOrderCredit = true,
    this.summaryOrderReserve = true,
    this.summaryOrderPersonal = true,
    this.summaryTripDistribution = true,
    this.summaryTripVehicle = true,
    this.summaryTripCredit = true,
    this.summaryTripReserve = true,
    this.summaryTripPersonal = true,
    this.summaryPersonal = true,
    this.summaryPersonalTrips = true,
    this.summaryPersonalOrders = true,
    this.summaryPersonalTotal = true,
    this.summaryFuel = true,
    this.summaryFuelLiters = true,
    this.summaryFuelCost = true,
    this.summaryFuelAverage = true,
    this.summaryExpenses = true,
    this.summaryExpensesTotal = true,
    this.summaryExpenseParts = true,
    this.summaryExpenseRepairs = true,
    this.summaryExpenseOther = true,
    this.summaryMileage = true,
    this.summaryMileageDistance = true,
    this.tripsRegular = true,
    this.tripsExtra = true,
    this.fuelShowLiters = true,
    this.fuelShowCost = true,
    this.fuelShowMileage = true,
    this.fuelShowComments = true,
  });

  final bool summary;
  final bool trips;
  final bool orders;
  final bool fuel;
  final bool expenses;
  final bool repairs;
  final bool mileage;

  final bool summaryRegularTrips;
  final bool summaryRegularTripsTotal;
  final bool summaryRegularTripsFull;
  final bool summaryRegularTripsPartial;
  final bool summaryRegularTripsMorning;
  final bool summaryRegularTripsEvening;

  final bool summaryExtraTrips;
  final bool summaryExtraTripsTotal;
  final bool summaryExtraTripsWait;

  final bool summaryOrders;
  final bool summaryOrdersRevenue;
  final bool summaryOrderVehicle;
  final bool summaryOrderCredit;
  final bool summaryOrderReserve;
  final bool summaryOrderPersonal;

  final bool summaryTripDistribution;
  final bool summaryTripVehicle;
  final bool summaryTripCredit;
  final bool summaryTripReserve;
  final bool summaryTripPersonal;

  final bool summaryPersonal;
  final bool summaryPersonalTrips;
  final bool summaryPersonalOrders;
  final bool summaryPersonalTotal;

  final bool summaryFuel;
  final bool summaryFuelLiters;
  final bool summaryFuelCost;
  final bool summaryFuelAverage;

  final bool summaryExpenses;
  final bool summaryExpensesTotal;
  final bool summaryExpenseParts;
  final bool summaryExpenseRepairs;
  final bool summaryExpenseOther;

  final bool summaryMileage;
  final bool summaryMileageDistance;

  final bool tripsRegular;
  final bool tripsExtra;

  final bool fuelShowLiters;
  final bool fuelShowCost;
  final bool fuelShowMileage;
  final bool fuelShowComments;

  bool get hasAny =>
      summary || trips || orders || fuel || expenses || repairs || mileage;
}

class MonthlyReportExportService {
  MonthlyReportExportService._();

  static final MonthlyReportExportService instance =
      MonthlyReportExportService._();

  final DatabaseHelper _database = DatabaseHelper.instance;
  final ReportRepository _reports = ReportRepository.instance;

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

  String _databaseDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _monthTitle(DateTime month) =>
      '${_monthNames[month.month - 1]} ${month.year}';

  String _formatDate(Object? value) {
    final text = value?.toString() ?? '';
    final parts = text.split('-');
    if (parts.length != 3) return text;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  String _money(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return '${number.toStringAsFixed(0)} ₽';
  }

  String _number(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return number == number.roundToDouble()
        ? number.toStringAsFixed(0)
        : number.toStringAsFixed(1);
  }

  double _tripBase(Map<String, Object?> row) =>
      (row['price'] as num?)?.toDouble() ?? 0;

  double _waitHours(Map<String, Object?> row) =>
      (row['wait_hours'] as num?)?.toDouble() ?? 0;

  double _waitRate(Map<String, Object?> row) =>
      (row['wait_rate'] as num?)?.toDouble() ?? 0;

  double _waitTotal(Map<String, Object?> row) =>
      _waitHours(row) * _waitRate(row);

  double _tripTotal(Map<String, Object?> row) =>
      _tripBase(row) + _waitTotal(row);

  String _tripType(Object? value) {
    switch (value?.toString()) {
      case 'morning':
        return 'Утро';
      case 'evening':
        return 'Вечер';
      case 'extra':
        return 'Доп. рейс';
      default:
        return value?.toString() ?? '';
    }
  }

  String _orderType(Map<String, Object?> order) {
    if (order['type']?.toString() == 'intercity') return 'Межгород';
    if (order['type']?.toString() == 'fixed') return 'Фиксированный';
    return 'Почасовой';
  }

  String _orderQuantity(Map<String, Object?> order) {
    if (order['type']?.toString() == 'intercity') {
      return '${_number(order['kilometers'])} км';
    }
    if (order['hours'] != null) return '${_number(order['hours'])} ч';
    return '';
  }

  String _orderStatus(Object? value) {
    switch (value?.toString()) {
      case 'completed':
        return 'Выполнен';
      case 'cancelled':
        return 'Отменён';
      default:
        return 'Запланирован';
    }
  }

  Future<_MonthlyExportData> _loadData(DateTime month) async {
    final firstDay = DateTime(month.year, month.month);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final from = _databaseDate(firstDay);
    final to = _databaseDate(lastDay);

    final report = await _reports.getMonthReport(month);
    final allTrips = await _database.getTripsBetween(from, to);
    final orders = await _database.getOrdersBetween(from, to);
    final fuel = await _database.getFuelLogsBetween(from, to);
    final expenses = await _database.getExpensesBetween(from, to);
    final mileage = await _database.getDailyLogsBetween(from, to);
    final allRepairs = await _database.getRepairs();

    final completedTrips = allTrips
        .where((trip) => trip['completed'] == 1)
        .toList(growable: false);
    final repairs = allRepairs.where((row) {
      final date = row['date']?.toString() ?? '';
      return date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
    }).toList(growable: false);

    final db = await _database.database;
    final vehicleId = await _database.getActiveVehicleId();
    final orderPayments = await db.rawQuery(
      '''
      SELECT p.*
      FROM order_payments p
      INNER JOIN orders o ON o.id = p.order_id
      WHERE o.vehicle_id = ?
        AND o.date BETWEEN ? AND ?
        AND o.status = 'completed'
      ORDER BY p.paid_at ASC, p.id ASC
      ''',
      [vehicleId, from, to],
    );
    final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final tripPayouts = (await _database.getTripPayouts())
        .where((row) => row['month']?.toString() == monthKey)
        .toList(growable: false);

    return _MonthlyExportData(
      report: report,
      trips: completedTrips,
      orders: orders,
      fuel: fuel,
      expenses: expenses,
      repairs: repairs,
      mileage: mileage,
      orderPayments: orderPayments,
      tripPayouts: tripPayouts,
    );
  }

  _TripStats _tripStats(List<Map<String, Object?>> trips) {
    final morning = trips.where((x) => x['type'] == 'morning').toList();
    final evening = trips.where((x) => x['type'] == 'evening').toList();
    final extra = trips.where((x) => x['type'] == 'extra').toList();

    final byDate = <String, Set<String>>{};
    for (final row in [...morning, ...evening]) {
      final date = row['date']?.toString() ?? '';
      byDate.putIfAbsent(date, () => <String>{}).add(row['type'].toString());
    }
    final full = byDate.values
        .where((types) => types.contains('morning') && types.contains('evening'))
        .length;
    final partial = byDate.values.where((types) => types.length == 1).length;

    double sum(List<Map<String, Object?>> rows) => rows.fold<double>(
          0,
          (value, row) => value + _tripTotal(row),
        );

    return _TripStats(
      morningCount: morning.length,
      eveningCount: evening.length,
      fullDays: full,
      partialDays: partial,
      extraCount: extra.length,
      morningAmount: sum(morning),
      eveningAmount: sum(evening),
      extraBaseAmount: extra.fold<double>(0, (v, row) => v + _tripBase(row)),
      extraWaitHours: extra.fold<double>(0, (v, row) => v + _waitHours(row)),
      extraWaitAmount: extra.fold<double>(0, (v, row) => v + _waitTotal(row)),
    );
  }

  _FinancialStats _financialStats(_MonthlyExportData data) {
    double pct(Object? value) => (value as num?)?.toDouble() ?? 0;
    double orderVehicle = 0;
    double orderCredit = 0;
    double orderReserve = 0;
    double orderPersonal = 0;
    double orderPaid = 0;
    for (final payment in data.orderPayments) {
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
      orderPaid += amount;
      orderVehicle += amount * pct(payment['vehicle_percent']) / 100;
      orderReserve += amount * pct(payment['reserve_percent']) / 100;
      orderPersonal += amount * pct(payment['personal_percent']) / 100;
      final raw = payment['credit_distribution']?.toString();
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final creditPct = decoded.values.fold<double>(
              0,
              (sum, item) => sum + (item is num ? item.toDouble() : double.tryParse(item.toString()) ?? 0),
            );
            orderCredit += amount * creditPct / 100;
          }
        } catch (_) {}
      }
    }

    double tripGross = 0;
    double tripVehicle = 0;
    double tripCredit = 0;
    double tripReserve = 0;
    double tripPersonal = 0;
    for (final payout in data.tripPayouts) {
      final amount = (payout['gross_amount'] as num?)?.toDouble() ?? 0;
      tripGross += amount;
      tripVehicle += amount * pct(payout['vehicle_percent']) / 100;
      tripCredit += amount * pct(payout['credit_percent']) / 100;
      tripReserve += amount * pct(payout['reserve_percent']) / 100;
      tripPersonal += amount * pct(payout['personal_percent']) / 100;
    }

    final orderGross = data.orders
        .where((row) => row['status']?.toString() == 'completed')
        .fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));

    double parts = 0;
    double other = 0;
    for (final row in data.expenses) {
      if (row['category']?.toString() == 'Домашнее топливо') continue;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final category = (row['category']?.toString() ?? '').toLowerCase();
      if (category.contains('запчаст')) {
        parts += amount;
      } else {
        other += amount;
      }
    }
    final repairs = data.repairs.fold<double>(0, (sum, row) {
      final part = row['expense_id'] == null
          ? ((row['part_cost'] as num?)?.toDouble() ?? 0)
          : 0.0;
      final work = (row['work_cost'] as num?)?.toDouble() ?? 0;
      return sum + part + work;
    });

    return _FinancialStats(
      orderGross: orderGross,
      orderPaid: orderPaid,
      orderVehicle: orderVehicle,
      orderCredit: orderCredit,
      orderReserve: orderReserve,
      orderPersonal: orderPersonal,
      tripGross: tripGross,
      tripVehicle: tripVehicle,
      tripCredit: tripCredit,
      tripReserve: tripReserve,
      tripPersonal: tripPersonal,
      partsExpenses: parts,
      repairExpenses: repairs,
      otherExpenses: other,
    );
  }

  Future<Uint8List> buildPdf(
    DateTime month, {
    MonthlyExportOptions options = const MonthlyExportOptions(),
  }) async {
    final data = await _loadData(month);
    final stats = _tripStats(data.trips);
    final finances = _financialStats(data);
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    final content = <pw.Widget>[
      pw.Text(
        'Сводка — ${_monthTitle(month)}',
        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 14),
    ];

    if (options.summary) {
      content.addAll([
        _summaryCard(data.report, stats, finances, options),
        pw.SizedBox(height: 22),
      ]);
    }
    if (options.trips) {
      final regularTrips = data.trips
          .where((trip) => trip['type'] != 'extra')
          .toList(growable: false);
      final extraTrips = data.trips
          .where((trip) => trip['type'] == 'extra')
          .toList(growable: false);

      List<List<String>> tripRows(List<Map<String, Object?>> trips) =>
          trips.map((trip) {
            final wait = _waitHours(trip) > 0
                ? '${_number(_waitHours(trip))} ч × ${_money(_waitRate(trip))}'
                : '';
            return [
              _formatDate(trip['date']),
              trip['time']?.toString() ?? '',
              trip['title']?.toString() ?? 'Рейс',
              _tripType(trip['type']),
              _money(_tripBase(trip)),
              wait,
              _money(_tripTotal(trip)),
              trip['price_note']?.toString() ?? '',
            ];
          }).toList();

      if (options.tripsRegular) {
        content.addAll([
          _sectionTitle('Мои смены — утро / вечер'),
          if (regularTrips.isEmpty)
            _emptyText('Выполненных утренних и вечерних смен за месяц нет.')
          else ...[
            _pdfTable(
              const [
                'Дата',
                'Время',
                'Наименование',
                'Тип',
                'Сумма',
                'Ожидание',
                'Итого',
                'Комментарий',
              ],
              tripRows(regularTrips),
            ),
            pw.SizedBox(height: 6),
            _pdfTable(
              const ['Итоги по моим сменам', 'Значение'],
              [
                ['Полных смен', '${stats.fullDays}'],
                ['Неполных смен', '${stats.partialDays}'],
                ['Всего смен', '${stats.regularCount}'],
                ['Общая сумма', _money(stats.regularAmount)],
              ],
            ),
          ],
          pw.SizedBox(height: 16),
        ]);
      }
      if (options.tripsExtra) {
        content.addAll([
          _sectionTitle('Дополнительные смены'),
          if (extraTrips.isEmpty)
            _emptyText('Дополнительных смен за месяц нет.')
          else ...[
            _pdfTable(
              const [
                'Дата',
                'Время',
                'Назначение',
                'Сумма',
                'Ожидание',
                'Итого',
                'Комментарий',
              ],
              extraTrips.map((trip) {
                final wait = _waitHours(trip) > 0
                    ? '${_number(_waitHours(trip))} ч × ${_money(_waitRate(trip))}'
                    : '';
                return [
                  _formatDate(trip['date']),
                  trip['time']?.toString() ?? '',
                  trip['title']?.toString() ?? 'Доп. смена',
                  _money(_tripBase(trip)),
                  wait,
                  _money(_tripTotal(trip)),
                  trip['price_note']?.toString() ?? '',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 6),
            _pdfTable(
              const ['Итоги по доп. сменам', 'Значение'],
              [
                ['Всего доп. смен', '${stats.extraCount}'],
                ['Общая сумма', _money(stats.extraTotalAmount)],
              ],
            ),
          ],
          pw.SizedBox(height: 20),
        ]);
      }
    }
    if (options.orders) {
      content.addAll([
        _sectionTitle('Заказы (${data.orders.length})'),
        if (data.orders.isEmpty)
          _emptyText('Заказов за месяц нет.')
        else
          _pdfTable(
            const ['Дата', 'Время', 'Заказ', 'Тип', 'Объём', 'Статус', 'Сумма'],
            data.orders
                .map(
                  (order) => [
                    _formatDate(order['date']),
                    order['time']?.toString() ?? '',
                    order['title']?.toString() ?? 'Заказ',
                    _orderType(order),
                    _orderQuantity(order),
                    _orderStatus(order['status']),
                    _money(order['amount']),
                  ],
                )
                .toList(),
          ),
        if (data.orders.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _pdfTable(
            const ['Итоги по заказам', 'Значение'],
            [
              ['Выполнено заказов', '${data.report.completedOrders}'],
              ['Общая выручка', _money(finances.orderGross)],
              ['Получено / распределено', _money(finances.orderPaid)],
              ['На автобус', _money(finances.orderVehicle)],
              ['На кредит', _money(finances.orderCredit)],
              ['В заначку', _money(finances.orderReserve)],
              ['Себе', _money(finances.orderPersonal)],
            ],
          ),
        ],
        pw.SizedBox(height: 20),
      ]);
    }
    if (options.fuel) {
      final headers = <String>['Дата', 'Время'];
      if (options.fuelShowLiters) headers.add('Литры');
      if (options.fuelShowCost) headers.addAll(['Цена/л', 'Сумма']);
      if (options.fuelShowMileage) headers.add('Пробег');
      if (options.fuelShowComments) headers.add('Комментарий');
      final rows = data.fuel.map((item) {
        final row = <String>[
          _formatDate(item['date']),
          item['time']?.toString() ?? '',
        ];
        if (options.fuelShowLiters) row.add(_number(item['liters']));
        if (options.fuelShowCost) {
          row.add(_money(item['price_per_liter']));
          row.add(_money(item['total']));
        }
        if (options.fuelShowMileage) {
          row.add(item['mileage'] == null ? '' : '${item['mileage']} км');
        }
        if (options.fuelShowComments) row.add(item['note']?.toString() ?? '');
        return row;
      }).toList();
      content.addAll([
        _sectionTitle('Топливо (${data.fuel.length})'),
        if (data.fuel.isEmpty)
          _emptyText('Заправок за месяц нет.')
        else ...[
          _pdfTable(headers, rows),
          pw.SizedBox(height: 6),
          _pdfTable(
            const ['Итоги по топливу', 'Значение'],
            [
              if (options.fuelShowLiters)
                ['Заправлено', '${_number(data.report.fuelLiters)} л'],
              if (options.fuelShowCost)
                ['Потрачено на топливо', _money(data.report.fuelCost)],
            ],
          ),
        ],
        pw.SizedBox(height: 20),
      ]);
    }
    if (options.expenses) {
      content.addAll([
        _sectionTitle('Расходы / запчасти (${data.expenses.length})'),
        if (data.expenses.isEmpty)
          _emptyText('Расходов за месяц нет.')
        else
          _pdfTable(
            const ['Дата', 'Время', 'Категория', 'Описание', 'Сумма'],
            data.expenses
                .map(
                  (expense) => [
                    _formatDate(expense['date']),
                    expense['time']?.toString() ?? '',
                    expense['category']?.toString() ?? '',
                    expense['description']?.toString() ?? '',
                    _money(expense['amount']),
                  ],
                )
                .toList(),
          ),
        if (data.expenses.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _pdfTable(
            const ['Итоги по расходам', 'Значение'],
            [
              ['Запчасти', _money(finances.partsExpenses)],
              ['Прочие расходы', _money(finances.otherExpenses)],
              ['Всего по таблице', _money(finances.partsExpenses + finances.otherExpenses)],
            ],
          ),
        ],
        pw.SizedBox(height: 20),
      ]);
    }
    if (options.repairs) {
      content.addAll([
        _sectionTitle('Ремонты (${data.repairs.length})'),
        if (data.repairs.isEmpty)
          _emptyText('Ремонтов за месяц нет.')
        else
          _pdfTable(
            const ['Дата', 'Работа', 'Пробег', 'Запчасти', 'Работа', 'Итого'],
            data.repairs.map((repair) {
              final part = (repair['part_cost'] as num?)?.toDouble() ?? 0;
              final work = (repair['work_cost'] as num?)?.toDouble() ?? 0;
              return [
                _formatDate(repair['date']),
                repair['title']?.toString() ?? '',
                repair['mileage'] == null ? '' : '${repair['mileage']} км',
                _money(part),
                _money(work),
                _money(part + work),
              ];
            }).toList(),
          ),
        if (data.repairs.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _pdfTable(
            const ['Итоги по ремонтам', 'Значение'],
            [
              ['Работ / ремонтов', '${data.repairs.length}'],
              ['Общая сумма', _money(finances.repairExpenses)],
            ],
          ),
        ],
        pw.SizedBox(height: 20),
      ]);
    }
    if (options.mileage) {
      content.addAll([
        _sectionTitle('Пробег'),
        if (data.mileage.isEmpty)
          _emptyText('Записей пробега за месяц нет.')
        else
          _pdfTable(
            const ['Дата', 'Начало', 'Конец', 'За день'],
            data.mileage.map((log) {
              final start = (log['start_mileage'] as num?)?.toInt();
              final end = (log['end_mileage'] as num?)?.toInt();
              final distance = start == null || end == null ? null : end - start;
              return [
                _formatDate(log['date']),
                start?.toString() ?? '',
                end?.toString() ?? '',
                distance == null ? '' : '$distance км',
              ];
            }).toList(),
          ),
      ]);
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Страница ${context.pageNumber} из ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (_) => content,
      ),
    );

    return document.save();
  }

  pw.Widget _summaryCard(
    MonthReport report,
    _TripStats stats,
    _FinancialStats finances,
    MonthlyExportOptions options,
  ) {
    final groups = <MapEntry<String, List<List<String>>>>[];

    final revenueRows = <List<String>>[];
    if (options.summaryRegularTrips && options.summaryRegularTripsTotal) {
      revenueRows.add(['Мои смены — общая выручка', _money(stats.regularAmount)]);
    }
    if (options.summaryExtraTrips && options.summaryExtraTripsTotal) {
      revenueRows.add(['Доп. смены — общая выручка', _money(stats.extraTotalAmount)]);
    }
    if (options.summaryOrders && options.summaryOrdersRevenue) {
      revenueRows.add(['Заказы — общая выручка', _money(finances.orderGross)]);
    }
    if (revenueRows.isNotEmpty) groups.add(MapEntry('Доходы и выручка', revenueRows));

    final personalRows = <List<String>>[];
    if (options.summaryPersonal) {
      if (options.summaryPersonalTrips) personalRows.add(['Со смен', _money(finances.tripPersonal)]);
      if (options.summaryPersonalOrders) personalRows.add(['С заказов', _money(finances.orderPersonal)]);
      if (options.summaryPersonalTotal) personalRows.add(['Всего себе', _money(finances.personalTotal)]);
    }
    if (personalRows.isNotEmpty) groups.add(MapEntry('Заработано себе', personalRows));

    final distributionRows = <List<String>>[];
    if (options.summaryTripDistribution) {
      if (finances.tripGross > 0) distributionRows.add(['Выплата предприятия', _money(finances.tripGross)]);
      if (options.summaryTripVehicle) distributionRows.add(['Со смен → Автобус', _money(finances.tripVehicle)]);
      if (options.summaryTripCredit) distributionRows.add(['Со смен → Кредит', _money(finances.tripCredit)]);
      if (options.summaryTripReserve) distributionRows.add(['Со смен → Заначка', _money(finances.tripReserve)]);
      if (options.summaryTripPersonal) distributionRows.add(['Со смен → Себе', _money(finances.tripPersonal)]);
    }
    if (options.summaryOrders) {
      if (options.summaryOrderVehicle) distributionRows.add(['С заказов → Автобус', _money(finances.orderVehicle)]);
      if (options.summaryOrderCredit) distributionRows.add(['С заказов → Кредит', _money(finances.orderCredit)]);
      if (options.summaryOrderReserve) distributionRows.add(['С заказов → Заначка', _money(finances.orderReserve)]);
      if (options.summaryOrderPersonal) distributionRows.add(['С заказов → Себе', _money(finances.orderPersonal)]);
      if (finances.orderGross > finances.orderPaid + 0.01) {
        distributionRows.add(['Заказы — ещё не получено/не распределено', _money(finances.orderGross - finances.orderPaid)]);
      }
    }
    if (distributionRows.isNotEmpty) groups.add(MapEntry('Распределение денег', distributionRows));

    final workRows = <List<String>>[];
    if (options.summaryRegularTrips) {
      if (options.summaryRegularTripsFull) workRows.add(['Полные смены', '${stats.fullDays}']);
      if (options.summaryRegularTripsPartial) workRows.add(['Неполные смены', '${stats.partialDays}']);
      if (options.summaryRegularTripsMorning) workRows.add(['Утренние смены', '${stats.morningCount}']);
      if (options.summaryRegularTripsEvening) workRows.add(['Вечерние смены', '${stats.eveningCount}']);
    }
    if (options.summaryExtraTrips && options.summaryExtraTripsTotal) workRows.add(['Доп. смены', '${stats.extraCount}']);
    if (options.summaryExtraTrips && options.summaryExtraTripsWait) workRows.add(['Ожидание в доп. сменах', '${_number(stats.extraWaitHours)} ч']);
    if (options.summaryOrders) workRows.add(['Выполнено заказов', '${report.completedOrders}']);
    if (options.summaryMileage && options.summaryMileageDistance) workRows.add(['Пробег', '${report.distance} км']);
    if (workRows.isNotEmpty) groups.add(MapEntry('Работа и рейсы', workRows));

    final fuelRows = <List<String>>[];
    if (options.summaryFuel) {
      if (options.summaryFuelLiters) fuelRows.add(['Заправлено', '${_number(report.fuelLiters)} л']);
      if (options.summaryFuelCost) fuelRows.add(['Потрачено на топливо', _money(report.fuelCost)]);
      if (options.summaryFuelAverage && report.approximateFuelPer100Km != null) {
        fuelRows.add(['Средний расход', '≈ ${report.approximateFuelPer100Km!.toStringAsFixed(1)} л/100 км']);
      }
    }
    if (fuelRows.isNotEmpty) groups.add(MapEntry('Топливо', fuelRows));

    final expenseRows = <List<String>>[];
    if (options.summaryExpenses) {
      if (options.summaryExpenseParts) expenseRows.add(['Запчасти', _money(finances.partsExpenses)]);
      if (options.summaryExpenseRepairs) expenseRows.add(['Ремонты / ТО', _money(finances.repairExpenses)]);
      if (options.summaryExpenseOther) expenseRows.add(['Прочие расходы', _money(finances.otherExpenses)]);
      if (options.summaryExpensesTotal) expenseRows.add(['Всего расходов', _money(finances.totalExpenses(report.fuelCost))]);
    }
    if (expenseRows.isNotEmpty) groups.add(MapEntry('Расходы', expenseRows));

    if (groups.isEmpty) return _emptyText('В общей сводке не выбраны показатели.');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(groups[i].key, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                for (final row in groups[i].value)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(children: [
                      pw.Expanded(child: pw.Text(row[0], style: const pw.TextStyle(fontSize: 9))),
                      pw.Text(row[1], style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ),
              ],
            ),
          ),
          if (i != groups.length - 1) pw.SizedBox(height: 7),
        ],
      ],
    );
  }


  pw.Widget _sectionTitle(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget _emptyText(String text) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        color: PdfColors.grey100,
        child: pw.Text(text),
      );

  pw.Widget _pdfTable(List<String> headers, List<List<String>> rows) {
    final allRows = <List<String>>[headers, ...rows];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        for (var rowIndex = 0; rowIndex < allRows.length; rowIndex++)
          pw.TableRow(
            decoration: rowIndex == 0
                ? const pw.BoxDecoration(color: PdfColors.blueGrey100)
                : null,
            children: [
              for (final value in allRows[rowIndex])
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    value,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: rowIndex == 0
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> sharePdf(
    DateTime month, {
    MonthlyExportOptions options = const MonthlyExportOptions(),
  }) async {
    final bytes = await buildPdf(month, options: options);
    final fileName = 'Сводка_${_monthNames[month.month - 1]}_${month.year}.pdf';

    if (kIsWeb) {
      await downloadBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/pdf',
      );
      return;
    }

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  Future<Uint8List> buildExcel(
    DateTime month, {
    MonthlyExportOptions options = const MonthlyExportOptions(),
  }) async {
    final data = await _loadData(month);
    final stats = _tripStats(data.trips);
    final finances = _financialStats(data);
    final excel = Excel.createExcel();

    if (options.summary) {
      final summary = excel['Сводка'];
      summary.appendRow([TextCellValue('Сводка — ${_monthTitle(month)}')]);
      void title(String value) => summary.appendRow([TextCellValue(value)]);
      void moneyRow(String label, double value) => summary.appendRow([TextCellValue(label), TextCellValue(''), DoubleCellValue(value)]);
      void countRow(String label, num value) => summary.appendRow([TextCellValue(label), DoubleCellValue(value.toDouble()), TextCellValue('')]);

      title('ДОХОДЫ И ВЫРУЧКА');
      if (options.summaryRegularTrips && options.summaryRegularTripsTotal) moneyRow('Мои смены — общая выручка', stats.regularAmount);
      if (options.summaryExtraTrips && options.summaryExtraTripsTotal) moneyRow('Доп. смены — общая выручка', stats.extraTotalAmount);
      if (options.summaryOrders && options.summaryOrdersRevenue) moneyRow('Заказы — общая выручка', finances.orderGross);

      if (options.summaryPersonal) {
        title('ЗАРАБОТАНО СЕБЕ');
        if (options.summaryPersonalTrips) moneyRow('Со смен', finances.tripPersonal);
        if (options.summaryPersonalOrders) moneyRow('С заказов', finances.orderPersonal);
        if (options.summaryPersonalTotal) moneyRow('Всего себе', finances.personalTotal);
      }

      if (options.summaryTripDistribution || options.summaryOrders) {
        title('РАСПРЕДЕЛЕНИЕ ДЕНЕГ');
        if (options.summaryTripDistribution) {
          if (finances.tripGross > 0) moneyRow('Выплата предприятия', finances.tripGross);
          if (options.summaryTripVehicle) moneyRow('Со смен → Автобус', finances.tripVehicle);
          if (options.summaryTripCredit) moneyRow('Со смен → Кредит', finances.tripCredit);
          if (options.summaryTripReserve) moneyRow('Со смен → Заначка', finances.tripReserve);
          if (options.summaryTripPersonal) moneyRow('Со смен → Себе', finances.tripPersonal);
        }
        if (options.summaryOrders) {
          if (options.summaryOrderVehicle) moneyRow('С заказов → Автобус', finances.orderVehicle);
          if (options.summaryOrderCredit) moneyRow('С заказов → Кредит', finances.orderCredit);
          if (options.summaryOrderReserve) moneyRow('С заказов → Заначка', finances.orderReserve);
          if (options.summaryOrderPersonal) moneyRow('С заказов → Себе', finances.orderPersonal);
        }
      }

      title('РАБОТА И РЕЙСЫ');
      if (options.summaryRegularTrips && options.summaryRegularTripsFull) countRow('Полные смены', stats.fullDays);
      if (options.summaryRegularTrips && options.summaryRegularTripsPartial) countRow('Неполные смены', stats.partialDays);
      if (options.summaryRegularTrips && options.summaryRegularTripsMorning) countRow('Утренние смены', stats.morningCount);
      if (options.summaryRegularTrips && options.summaryRegularTripsEvening) countRow('Вечерние смены', stats.eveningCount);
      if (options.summaryExtraTrips && options.summaryExtraTripsTotal) countRow('Доп. смены', stats.extraCount);
      if (options.summaryOrders) countRow('Выполнено заказов', data.report.completedOrders);
      if (options.summaryMileage && options.summaryMileageDistance) countRow('Пробег, км', data.report.distance);

      if (options.summaryFuel) {
        title('ТОПЛИВО');
        if (options.summaryFuelLiters) countRow('Заправлено, л', data.report.fuelLiters);
        if (options.summaryFuelCost) moneyRow('Потрачено на топливо', data.report.fuelCost);
        if (options.summaryFuelAverage && data.report.approximateFuelPer100Km != null) countRow('Средний расход, л/100 км', data.report.approximateFuelPer100Km!);
      }

      if (options.summaryExpenses) {
        title('РАСХОДЫ');
        if (options.summaryExpenseParts) moneyRow('Запчасти', finances.partsExpenses);
        if (options.summaryExpenseRepairs) moneyRow('Ремонты / ТО', finances.repairExpenses);
        if (options.summaryExpenseOther) moneyRow('Прочие расходы', finances.otherExpenses);
        if (options.summaryExpensesTotal) moneyRow('Всего расходов', finances.totalExpenses(data.report.fuelCost));
      }
      excel.setDefaultSheet('Сводка');
    }

    if (options.trips) {
      void fillRegularTripSheet(
        Sheet sheet,
        Iterable<Map<String, Object?>> trips,
      ) {
        sheet.appendRow([
          TextCellValue('Дата'),
          TextCellValue('Время'),
          TextCellValue('Наименование'),
          TextCellValue('Тип'),
          TextCellValue('Стоимость смены'),
          TextCellValue('Ожидание, ч'),
          TextCellValue('Цена ожидания/ч'),
          TextCellValue('Ожидание, сумма'),
          TextCellValue('Итого'),
          TextCellValue('Комментарий'),
        ]);
        for (final trip in trips) {
          sheet.appendRow([
            TextCellValue(_formatDate(trip['date'])),
            TextCellValue(trip['time']?.toString() ?? ''),
            TextCellValue(trip['title']?.toString() ?? 'Рейс'),
            TextCellValue(_tripType(trip['type'])),
            DoubleCellValue(_tripBase(trip)),
            DoubleCellValue(_waitHours(trip)),
            DoubleCellValue(_waitRate(trip)),
            DoubleCellValue(_waitTotal(trip)),
            DoubleCellValue(_tripTotal(trip)),
            TextCellValue(trip['price_note']?.toString() ?? ''),
          ]);
        }
      }

      if (options.tripsRegular) {
        final regularSheet = excel['Мои смены'];
        fillRegularTripSheet(
          regularSheet,
          data.trips.where((trip) => trip['type'] != 'extra'),
        );
        regularSheet.appendRow([TextCellValue('')]);
        regularSheet.appendRow([
          TextCellValue('ИТОГИ ПО МОИМ СМЕНАМ'),
          TextCellValue(''),
        ]);
        regularSheet.appendRow([TextCellValue('Полных смен'), IntCellValue(stats.fullDays)]);
        regularSheet.appendRow([TextCellValue('Неполных смен'), IntCellValue(stats.partialDays)]);
        regularSheet.appendRow([TextCellValue('Всего смен'), IntCellValue(stats.regularCount)]);
        regularSheet.appendRow([TextCellValue('Общая сумма'), DoubleCellValue(stats.regularAmount)]);
      }

      if (options.tripsExtra) {
        final extraSheet = excel['Доп. смены'];
        extraSheet.appendRow([
          TextCellValue('Дата'),
          TextCellValue('Время'),
          TextCellValue('Назначение'),
          TextCellValue('Стоимость смены'),
          TextCellValue('Ожидание, ч'),
          TextCellValue('Цена ожидания/ч'),
          TextCellValue('Ожидание, сумма'),
          TextCellValue('Итого'),
          TextCellValue('Комментарий'),
        ]);
        for (final trip in data.trips.where((trip) => trip['type'] == 'extra')) {
          extraSheet.appendRow([
            TextCellValue(_formatDate(trip['date'])),
            TextCellValue(trip['time']?.toString() ?? ''),
            TextCellValue(trip['title']?.toString() ?? 'Доп. смена'),
            DoubleCellValue(_tripBase(trip)),
            DoubleCellValue(_waitHours(trip)),
            DoubleCellValue(_waitRate(trip)),
            DoubleCellValue(_waitTotal(trip)),
            DoubleCellValue(_tripTotal(trip)),
            TextCellValue(trip['price_note']?.toString() ?? ''),
          ]);
        }
        extraSheet.appendRow([TextCellValue('')]);
        extraSheet.appendRow([
          TextCellValue('ИТОГИ ПО ДОП. СМЕНАМ'),
          TextCellValue(''),
        ]);
        extraSheet.appendRow([TextCellValue('Всего доп. смен'), IntCellValue(stats.extraCount)]);
        extraSheet.appendRow([TextCellValue('Общая сумма'), DoubleCellValue(stats.extraTotalAmount)]);
      }
    }

    if (options.orders) {
      final sheet = excel['Заказы'];
      sheet.appendRow([
        TextCellValue('Дата'), TextCellValue('Время'), TextCellValue('Название'),
        TextCellValue('Тип'), TextCellValue('Часы/км'), TextCellValue('Статус'),
        TextCellValue('Сумма'), TextCellValue('Комментарий'),
      ]);
      for (final order in data.orders) {
        sheet.appendRow([
          TextCellValue(_formatDate(order['date'])),
          TextCellValue(order['time']?.toString() ?? ''),
          TextCellValue(order['title']?.toString() ?? 'Заказ'),
          TextCellValue(_orderType(order)),
          TextCellValue(_orderQuantity(order)),
          TextCellValue(_orderStatus(order['status'])),
          DoubleCellValue((order['amount'] as num?)?.toDouble() ?? 0),
          TextCellValue(order['note']?.toString() ?? ''),
        ]);
      }
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('ИТОГИ ПО ЗАКАЗАМ'), TextCellValue('')]);
      sheet.appendRow([TextCellValue('Выполнено заказов'), IntCellValue(data.report.completedOrders)]);
      sheet.appendRow([TextCellValue('Общая выручка'), DoubleCellValue(finances.orderGross)]);
      sheet.appendRow([TextCellValue('Получено / распределено'), DoubleCellValue(finances.orderPaid)]);
      sheet.appendRow([TextCellValue('На автобус'), DoubleCellValue(finances.orderVehicle)]);
      sheet.appendRow([TextCellValue('На кредит'), DoubleCellValue(finances.orderCredit)]);
      sheet.appendRow([TextCellValue('В заначку'), DoubleCellValue(finances.orderReserve)]);
      sheet.appendRow([TextCellValue('Себе'), DoubleCellValue(finances.orderPersonal)]);
    }

    if (options.fuel) {
      final sheet = excel['Топливо'];
      final headers = <CellValue?>[
        TextCellValue('Дата'),
        TextCellValue('Время'),
      ];
      if (options.fuelShowLiters) headers.add(TextCellValue('Литры'));
      if (options.fuelShowCost) {
        headers.add(TextCellValue('Цена за литр'));
        headers.add(TextCellValue('Общая сумма'));
      }
      if (options.fuelShowMileage) headers.add(TextCellValue('Пробег'));
      if (options.fuelShowComments) headers.add(TextCellValue('Комментарий'));
      sheet.appendRow(headers);

      for (final item in data.fuel) {
        final row = <CellValue?>[
          TextCellValue(_formatDate(item['date'])),
          TextCellValue(item['time']?.toString() ?? ''),
        ];
        if (options.fuelShowLiters) {
          row.add(DoubleCellValue((item['liters'] as num?)?.toDouble() ?? 0));
        }
        if (options.fuelShowCost) {
          row.add(DoubleCellValue((item['price_per_liter'] as num?)?.toDouble() ?? 0));
          row.add(DoubleCellValue((item['total'] as num?)?.toDouble() ?? 0));
        }
        if (options.fuelShowMileage) {
          row.add(item['mileage'] == null
              ? TextCellValue('')
              : IntCellValue((item['mileage'] as num).toInt()));
        }
        if (options.fuelShowComments) {
          row.add(TextCellValue(item['note']?.toString() ?? ''));
        }
        sheet.appendRow(row);
      }
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('ИТОГИ ПО ТОПЛИВУ'), TextCellValue('')]);
      if (options.fuelShowLiters) {
        sheet.appendRow([TextCellValue('Заправлено, л'), DoubleCellValue(data.report.fuelLiters)]);
      }
      if (options.fuelShowCost) {
        sheet.appendRow([TextCellValue('Потрачено на топливо'), DoubleCellValue(data.report.fuelCost)]);
      }
    }

    if (options.expenses) {
      final sheet = excel['Расходы'];
      sheet.appendRow([
        TextCellValue('Дата'), TextCellValue('Время'), TextCellValue('Категория'),
        TextCellValue('Описание'), TextCellValue('Сумма'),
      ]);
      for (final expense in data.expenses) {
        sheet.appendRow([
          TextCellValue(_formatDate(expense['date'])),
          TextCellValue(expense['time']?.toString() ?? ''),
          TextCellValue(expense['category']?.toString() ?? ''),
          TextCellValue(expense['description']?.toString() ?? ''),
          DoubleCellValue((expense['amount'] as num?)?.toDouble() ?? 0),
        ]);
      }
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('ИТОГИ ПО РАСХОДАМ'), TextCellValue('')]);
      sheet.appendRow([TextCellValue('Запчасти'), DoubleCellValue(finances.partsExpenses)]);
      sheet.appendRow([TextCellValue('Прочие расходы'), DoubleCellValue(finances.otherExpenses)]);
      sheet.appendRow([TextCellValue('Всего по таблице'), DoubleCellValue(finances.partsExpenses + finances.otherExpenses)]);
    }

    if (options.repairs) {
      final sheet = excel['Ремонты'];
      sheet.appendRow([
        TextCellValue('Дата'), TextCellValue('Работа'), TextCellValue('Пробег'),
        TextCellValue('Запчасти'), TextCellValue('Работа'), TextCellValue('Итого'),
      ]);
      for (final repair in data.repairs) {
        final part = (repair['part_cost'] as num?)?.toDouble() ?? 0;
        final work = (repair['work_cost'] as num?)?.toDouble() ?? 0;
        sheet.appendRow([
          TextCellValue(_formatDate(repair['date'])),
          TextCellValue(repair['title']?.toString() ?? ''),
          repair['mileage'] == null
              ? TextCellValue('')
              : IntCellValue((repair['mileage'] as num).toInt()),
          DoubleCellValue(part),
          DoubleCellValue(work),
          DoubleCellValue(part + work),
        ]);
      }
      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('ИТОГИ ПО РЕМОНТАМ'), TextCellValue('')]);
      sheet.appendRow([TextCellValue('Работ / ремонтов'), IntCellValue(data.repairs.length)]);
      sheet.appendRow([TextCellValue('Общая сумма'), DoubleCellValue(finances.repairExpenses)]);
    }

    if (options.mileage) {
      final sheet = excel['Пробег'];
      sheet.appendRow([
        TextCellValue('Дата'), TextCellValue('Начальный пробег'),
        TextCellValue('Конечный пробег'), TextCellValue('Пробег за день'),
      ]);
      for (final log in data.mileage) {
        final start = (log['start_mileage'] as num?)?.toInt();
        final end = (log['end_mileage'] as num?)?.toInt();
        final distance = start == null || end == null ? null : end - start;
        sheet.appendRow([
          TextCellValue(_formatDate(log['date'])),
          start == null ? TextCellValue('') : IntCellValue(start),
          end == null ? TextCellValue('') : IntCellValue(end),
          distance == null ? TextCellValue('') : IntCellValue(distance),
        ]);
      }
    }

    excel.delete('Sheet1');
    for (final sheet in excel.tables.values) {
      if (sheet.maxRows > 0) {
        for (final cell in sheet.row(0)) {
          cell?.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: ExcelColor.fromHexString('#DCE6F1'),
          );
        }
      }
      for (var column = 0; column < sheet.maxColumns; column++) {
        sheet.setColumnWidth(column, 18);
      }
    }

    final bytes = excel.save();
    if (bytes == null) throw StateError('Не удалось создать Excel-файл.');
    return Uint8List.fromList(bytes);
  }

  Future<void> shareExcel(
    DateTime month, {
    MonthlyExportOptions options = const MonthlyExportOptions(),
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await buildExcel(month, options: options);
    final fileName = 'Сводка_${_monthNames[month.month - 1]}_${month.year}.xlsx';
    const mimeType =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    if (kIsWeb) {
      await downloadBytes(bytes: bytes, fileName: fileName, mimeType: mimeType);
      return;
    }

    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}

class _MonthlyExportData {
  const _MonthlyExportData({
    required this.report,
    required this.trips,
    required this.orders,
    required this.fuel,
    required this.expenses,
    required this.repairs,
    required this.mileage,
    required this.orderPayments,
    required this.tripPayouts,
  });

  final MonthReport report;
  final List<Map<String, Object?>> trips;
  final List<Map<String, Object?>> orders;
  final List<Map<String, Object?>> fuel;
  final List<Map<String, Object?>> expenses;
  final List<Map<String, Object?>> repairs;
  final List<Map<String, Object?>> mileage;
  final List<Map<String, Object?>> orderPayments;
  final List<Map<String, Object?>> tripPayouts;
}

class _FinancialStats {
  const _FinancialStats({
    required this.orderGross, required this.orderPaid, required this.orderVehicle, required this.orderCredit, required this.orderReserve, required this.orderPersonal,
    required this.tripGross, required this.tripVehicle, required this.tripCredit, required this.tripReserve, required this.tripPersonal,
    required this.partsExpenses, required this.repairExpenses, required this.otherExpenses,
  });
  final double orderGross, orderPaid, orderVehicle, orderCredit, orderReserve, orderPersonal;
  final double tripGross, tripVehicle, tripCredit, tripReserve, tripPersonal;
  final double partsExpenses, repairExpenses, otherExpenses;
  double get personalTotal => tripPersonal + orderPersonal;
  double totalExpenses(double fuelCost) => fuelCost + partsExpenses + repairExpenses + otherExpenses;
}

class _TripStats {
  const _TripStats({
    required this.morningCount,
    required this.eveningCount,
    required this.fullDays,
    required this.partialDays,
    required this.extraCount,
    required this.morningAmount,
    required this.eveningAmount,
    required this.extraBaseAmount,
    required this.extraWaitHours,
    required this.extraWaitAmount,
  });

  final int morningCount;
  final int eveningCount;
  final int fullDays;
  final int partialDays;
  final int extraCount;
  final double morningAmount;
  final double eveningAmount;
  final double extraBaseAmount;
  final double extraWaitHours;
  final double extraWaitAmount;

  int get regularCount => fullDays + partialDays;
  double get regularAmount => morningAmount + eveningAmount;
  double get extraTotalAmount => extraBaseAmount + extraWaitAmount;
}
