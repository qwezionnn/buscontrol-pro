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
  });

  final bool summary;
  final bool trips;
  final bool orders;
  final bool fuel;
  final bool expenses;
  final bool repairs;
  final bool mileage;

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

    return _MonthlyExportData(
      report: report,
      trips: completedTrips,
      orders: orders,
      fuel: fuel,
      expenses: expenses,
      repairs: repairs,
      mileage: mileage,
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

  Future<Uint8List> buildPdf(
    DateTime month, {
    MonthlyExportOptions options = const MonthlyExportOptions(),
  }) async {
    final data = await _loadData(month);
    final stats = _tripStats(data.trips);
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
        _summaryCard(data.report, stats),
        pw.SizedBox(height: 22),
      ]);
    }
    if (options.trips) {
      content.addAll([
        _sectionTitle('Рейсы'),
        _tripSummaryPdf(stats),
        pw.SizedBox(height: 10),
        if (data.trips.isEmpty)
          _emptyText('Выполненных рейсов за месяц нет.')
        else
          _pdfTable(
            const [
              'Дата',
              'Время',
              'Наименование',
              'Тип',
              'Рейс',
              'Ожидание',
              'Итого',
            ],
            data.trips.map((trip) {
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
              ];
            }).toList(),
          ),
        pw.SizedBox(height: 20),
      ]);
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
        pw.SizedBox(height: 20),
      ]);
    }
    if (options.fuel) {
      content.addAll([
        _sectionTitle('Топливо (${data.fuel.length})'),
        if (data.fuel.isEmpty)
          _emptyText('Заправок за месяц нет.')
        else
          _pdfTable(
            const ['Дата', 'Время', 'Литры', 'Цена/л', 'Сумма', 'Пробег', 'Комментарий'],
            data.fuel
                .map(
                  (fuel) => [
                    _formatDate(fuel['date']),
                    fuel['time']?.toString() ?? '',
                    _number(fuel['liters']),
                    _money(fuel['price_per_liter']),
                    _money(fuel['total']),
                    fuel['mileage'] == null ? '' : '${fuel['mileage']} км',
                    fuel['note']?.toString() ?? '',
                  ],
                )
                .toList(),
          ),
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

  pw.Widget _summaryCard(MonthReport report, _TripStats stats) {
    final rows = <List<String>>[
      ['Полных рейсов (утро + вечер)', '${stats.fullDays}'],
      ['Неполных дней', '${stats.partialDays}'],
      ['Утренних поездок', '${stats.morningCount} • ${_money(stats.morningAmount)}'],
      ['Вечерних поездок', '${stats.eveningCount} • ${_money(stats.eveningAmount)}'],
      ['Доп. рейсов', '${stats.extraCount} • ${_money(stats.extraTotalAmount)}'],
      ['Ожидание в доп. рейсах', '${_number(stats.extraWaitHours)} ч • ${_money(stats.extraWaitAmount)}'],
      ['Доход от заказов', _money(report.orderIncome)],
      ['Заправлено топлива', '${_number(report.fuelLiters)} л'],
      ['Расходы на топливо', _money(report.fuelCost)],
      ['Другие расходы', _money(report.expenseCost)],
      ['Пробег', '${report.distance} км'],
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blueGrey200),
      ),
      child: pw.Column(
        children: rows
            .map(
              (row) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text(row[0])),
                    pw.Text(row[1], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  pw.Widget _tripSummaryPdf(_TripStats stats) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        color: PdfColors.grey100,
        child: pw.Wrap(
          spacing: 18,
          runSpacing: 6,
          children: [
            pw.Text('Полных: ${stats.fullDays}'),
            pw.Text('Неполных: ${stats.partialDays}'),
            pw.Text('Утро: ${stats.morningCount} / ${_money(stats.morningAmount)}'),
            pw.Text('Вечер: ${stats.eveningCount} / ${_money(stats.eveningAmount)}'),
            pw.Text('Доп.: ${stats.extraCount} / ${_money(stats.extraTotalAmount)}'),
            pw.Text('Ожидание: ${_number(stats.extraWaitHours)} ч / ${_money(stats.extraWaitAmount)}'),
          ],
        ),
      );

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
    final excel = Excel.createExcel();

    if (options.summary) {
      final summary = excel['Сводка'];
      summary.appendRow([TextCellValue('Сводка — ${_monthTitle(month)}')]);
      summary.appendRow([TextCellValue('Показатель'), TextCellValue('Количество'), TextCellValue('Сумма')]);
      summary.appendRow([TextCellValue('Полный рейс (утро + вечер)'), IntCellValue(stats.fullDays), DoubleCellValue(stats.regularAmount)]);
      summary.appendRow([TextCellValue('Неполный день'), IntCellValue(stats.partialDays), TextCellValue('')]);
      summary.appendRow([TextCellValue('Утренние поездки'), IntCellValue(stats.morningCount), DoubleCellValue(stats.morningAmount)]);
      summary.appendRow([TextCellValue('Вечерние поездки'), IntCellValue(stats.eveningCount), DoubleCellValue(stats.eveningAmount)]);
      summary.appendRow([TextCellValue('Дополнительные рейсы'), IntCellValue(stats.extraCount), DoubleCellValue(stats.extraTotalAmount)]);
      summary.appendRow([TextCellValue('Ожидание в доп. рейсах, часов'), DoubleCellValue(stats.extraWaitHours), DoubleCellValue(stats.extraWaitAmount)]);
      summary.appendRow([TextCellValue('Заказы'), IntCellValue(data.report.completedOrders), DoubleCellValue(data.report.orderIncome)]);
      summary.appendRow([TextCellValue('Топливо, л'), DoubleCellValue(data.report.fuelLiters), DoubleCellValue(data.report.fuelCost)]);
      summary.appendRow([TextCellValue('Другие расходы'), TextCellValue(''), DoubleCellValue(data.report.expenseCost)]);
      summary.appendRow([TextCellValue('Пробег, км'), IntCellValue(data.report.distance), TextCellValue('')]);
      excel.setDefaultSheet('Сводка');
    }

    if (options.trips) {
      final sheet = excel['Рейсы'];
      sheet.appendRow([
        TextCellValue('Дата'),
        TextCellValue('Время'),
        TextCellValue('Наименование'),
        TextCellValue('Тип'),
        TextCellValue('Стоимость рейса'),
        TextCellValue('Ожидание, ч'),
        TextCellValue('Цена ожидания/ч'),
        TextCellValue('Ожидание, сумма'),
        TextCellValue('Итого'),
      ]);
      for (final trip in data.trips) {
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
        ]);
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
    }

    if (options.fuel) {
      final sheet = excel['Топливо'];
      sheet.appendRow([
        TextCellValue('Дата'), TextCellValue('Время'), TextCellValue('Литры'),
        TextCellValue('Цена за литр'), TextCellValue('Общая сумма'),
        TextCellValue('Пробег'), TextCellValue('Комментарий'),
      ]);
      for (final item in data.fuel) {
        sheet.appendRow([
          TextCellValue(_formatDate(item['date'])),
          TextCellValue(item['time']?.toString() ?? ''),
          DoubleCellValue((item['liters'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((item['price_per_liter'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((item['total'] as num?)?.toDouble() ?? 0),
          item['mileage'] == null
              ? TextCellValue('')
              : IntCellValue((item['mileage'] as num).toInt()),
          TextCellValue(item['note']?.toString() ?? ''),
        ]);
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
      [XFile.fromData(bytes, mimeType: mimeType)],
      fileNameOverrides: [fileName],
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
  });

  final MonthReport report;
  final List<Map<String, Object?>> trips;
  final List<Map<String, Object?>> orders;
  final List<Map<String, Object?>> fuel;
  final List<Map<String, Object?>> expenses;
  final List<Map<String, Object?>> repairs;
  final List<Map<String, Object?>> mileage;
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

  double get regularAmount => morningAmount + eveningAmount;
  double get extraTotalAmount => extraBaseAmount + extraWaitAmount;
}
