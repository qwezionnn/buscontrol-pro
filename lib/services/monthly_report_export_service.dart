import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../platform/file_download.dart';
import '../repositories/report_repository.dart';

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

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _fileMonth(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  String _monthTitle(DateTime month) {
    return '${_monthNames[month.month - 1]} ${month.year}';
  }

  String _formatDate(Object? value) {
    final text = value?.toString() ?? '';
    final parts = text.split('-');
    if (parts.length != 3) {
      return text;
    }
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }

  String _money(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return '${number.toStringAsFixed(0)} ₽';
  }

  String _number(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    if (number == number.roundToDouble()) {
      return number.toStringAsFixed(0);
    }
    return number.toStringAsFixed(1);
  }

  String _tripType(Object? value) {
    switch (value?.toString()) {
      case 'morning':
        return 'Утренний';
      case 'evening':
        return 'Вечерний';
      case 'extra':
        return 'Дополнительный';
      default:
        return value?.toString() ?? '';
    }
  }

  String _orderType(Map<String, Object?> order) {
    if (order['type']?.toString() == 'intercity') {
      return 'Межгород';
    }
    return 'Почасовой';
  }

  String _orderQuantity(Map<String, Object?> order) {
    if (order['type']?.toString() == 'intercity') {
      return '${_number(order['kilometers'])} км';
    }
    return '${_number(order['hours'])} ч';
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

    final completedTrips = allTrips
        .where((trip) => trip['completed'] == 1)
        .toList(growable: false);

    return _MonthlyExportData(
      report: report,
      trips: completedTrips,
      orders: orders,
      fuel: fuel,
      expenses: expenses,
      mileage: mileage,
    );
  }

  Future<Uint8List> buildPdf(DateTime month) async {
    final data = await _loadData(month);
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            'BusControl PRO',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey700,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Страница ${context.pageNumber} из ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Отчёт за ${_monthTitle(month)}',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 14),
          _summaryCard(data.report),
          pw.SizedBox(height: 22),
          _sectionTitle('Рейсы (${data.trips.length})'),
          if (data.trips.isEmpty)
            _emptyText('Выполненных рейсов за месяц нет.')
          else
            _pdfTable(
              const ['Дата', 'Время', 'Рейс', 'Тип', 'Сумма'],
              data.trips
                  .map(
                    (trip) => [
                      _formatDate(trip['date']),
                      trip['time']?.toString() ?? '',
                      trip['title']?.toString() ?? 'Рейс',
                      _tripType(trip['type']),
                      _money(trip['price']),
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 20),
          _sectionTitle('Заказы (${data.orders.length})'),
          if (data.orders.isEmpty)
            _emptyText('Заказов за месяц нет.')
          else
            _pdfTable(
              const [
                'Дата',
                'Время',
                'Заказ',
                'Тип',
                'Объём',
                'Статус',
                'Сумма',
              ],
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
          _sectionTitle('Топливо (${data.fuel.length})'),
          if (data.fuel.isEmpty)
            _emptyText('Заправок за месяц нет.')
          else
            _pdfTable(
              const [
                'Дата',
                'Время',
                'Литры',
                'Цена/л',
                'Сумма',
                'Пробег',
                'Комментарий',
              ],
              data.fuel
                  .map(
                    (fuel) => [
                      _formatDate(fuel['date']),
                      fuel['time']?.toString() ?? '',
                      _number(fuel['liters']),
                      _money(fuel['price_per_liter']),
                      _money(fuel['total']),
                      fuel['mileage'] == null
                          ? ''
                          : '${fuel['mileage']} км',
                      fuel['note']?.toString() ?? '',
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 20),
          _sectionTitle('Расходы (${data.expenses.length})'),
          if (data.expenses.isEmpty)
            _emptyText('Других расходов за месяц нет.')
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
          _sectionTitle('Пробег'),
          if (data.mileage.isEmpty)
            _emptyText('Записей пробега за месяц нет.')
          else
            _pdfTable(
              const ['Дата', 'Начало', 'Конец', 'За день'],
              data.mileage
                  .map((log) {
                    final start =
                        (log['start_mileage'] as num?)?.toInt();
                    final end = (log['end_mileage'] as num?)?.toInt();
                    final distance = start == null || end == null
                        ? null
                        : end - start;
                    return [
                      _formatDate(log['date']),
                      start?.toString() ?? '',
                      end?.toString() ?? '',
                      distance == null ? '' : '$distance км',
                    ];
                  })
                  .toList(),
            ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _summaryCard(MonthReport report) {
    final rows = <List<String>>[
      ['Доход от рейсов', _money(report.tripIncome)],
      ['Доход от заказов', _money(report.orderIncome)],
      ['Заправлено топлива', '${_number(report.fuelLiters)} л'],
      ['Расходы на топливо', _money(report.fuelCost)],
      ['Другие расходы', _money(report.expenseCost)],
      ['Пробег', '${report.distance} км'],
      ['Чистая прибыль', _money(report.profit)],
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
                    pw.Text(
                      row[1],
                      style: pw.TextStyle(
                        fontWeight: row[0] == 'Чистая прибыль'
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _emptyText(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      color: PdfColors.grey100,
      child: pw.Text(text),
    );
  }

  pw.Widget _pdfTable(
    List<String> headers,
    List<List<String>> rows,
  ) {
    final allRows = <List<String>>[
      headers,
      ...rows,
    ];

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.5,
      ),
      children: [
        for (var rowIndex = 0;
            rowIndex < allRows.length;
            rowIndex++)
          pw.TableRow(
            decoration: rowIndex == 0
                ? const pw.BoxDecoration(
                    color: PdfColors.blueGrey100,
                  )
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

  Future<void> sharePdf(DateTime month) async {
    final bytes = await buildPdf(month);
    final fileName = 'bus_control_${_fileMonth(month)}.pdf';

    if (kIsWeb) {
      await downloadBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/pdf',
      );
      return;
    }

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }

  Future<void> printPdf(DateTime month) async {
    final bytes = await buildPdf(month);
    await Printing.layoutPdf(
      name: 'BusControl PRO - ${_monthTitle(month)}',
      onLayout: (_) async => bytes,
    );
  }

  Future<Uint8List> buildExcel(DateTime month) async {
    final data = await _loadData(month);
    final excel = Excel.createExcel();

    final summary = excel['Сводка'];
    excel.setDefaultSheet('Сводка');

    summary.appendRow([
      TextCellValue('BusControl PRO'),
      TextCellValue('Отчёт за ${_monthTitle(month)}'),
    ]);
    summary.appendRow([
      TextCellValue('Показатель'),
      TextCellValue('Значение'),
    ]);
    summary.appendRow([
      TextCellValue('Выполнено рейсов'),
      IntCellValue(data.report.completedTrips),
    ]);
    summary.appendRow([
      TextCellValue('Выполнено заказов'),
      IntCellValue(data.report.completedOrders),
    ]);
    summary.appendRow([
      TextCellValue('Отменено заказов'),
      IntCellValue(data.report.cancelledOrders),
    ]);
    summary.appendRow([
      TextCellValue('Доход от рейсов'),
      DoubleCellValue(data.report.tripIncome),
    ]);
    summary.appendRow([
      TextCellValue('Доход от заказов'),
      DoubleCellValue(data.report.orderIncome),
    ]);
    summary.appendRow([
      TextCellValue('Заправлено топлива, л'),
      DoubleCellValue(data.report.fuelLiters),
    ]);
    summary.appendRow([
      TextCellValue('Расходы на топливо'),
      DoubleCellValue(data.report.fuelCost),
    ]);
    summary.appendRow([
      TextCellValue('Другие расходы'),
      DoubleCellValue(data.report.expenseCost),
    ]);
    summary.appendRow([
      TextCellValue('Пробег, км'),
      IntCellValue(data.report.distance),
    ]);
    summary.appendRow([
      TextCellValue('Чистая прибыль'),
      DoubleCellValue(data.report.profit),
    ]);

    final trips = excel['Рейсы'];
    trips.appendRow([
      TextCellValue('Дата'),
      TextCellValue('Время'),
      TextCellValue('Название'),
      TextCellValue('Тип'),
      TextCellValue('Стоимость'),
    ]);
    for (final trip in data.trips) {
      trips.appendRow([
        TextCellValue(_formatDate(trip['date'])),
        TextCellValue(trip['time']?.toString() ?? ''),
        TextCellValue(trip['title']?.toString() ?? 'Рейс'),
        TextCellValue(_tripType(trip['type'])),
        DoubleCellValue(
          (trip['price'] as num?)?.toDouble() ?? 0,
        ),
      ]);
    }

    final orders = excel['Заказы'];
    orders.appendRow([
      TextCellValue('Дата'),
      TextCellValue('Время'),
      TextCellValue('Название'),
      TextCellValue('Тип'),
      TextCellValue('Часы/км'),
      TextCellValue('Статус'),
      TextCellValue('Сумма'),
      TextCellValue('Комментарий'),
    ]);
    for (final order in data.orders) {
      orders.appendRow([
        TextCellValue(_formatDate(order['date'])),
        TextCellValue(order['time']?.toString() ?? ''),
        TextCellValue(order['title']?.toString() ?? 'Заказ'),
        TextCellValue(_orderType(order)),
        TextCellValue(_orderQuantity(order)),
        TextCellValue(_orderStatus(order['status'])),
        DoubleCellValue(
          (order['amount'] as num?)?.toDouble() ?? 0,
        ),
        TextCellValue(order['note']?.toString() ?? ''),
      ]);
    }

    final fuel = excel['Топливо'];
    fuel.appendRow([
      TextCellValue('Дата'),
      TextCellValue('Время'),
      TextCellValue('Литры'),
      TextCellValue('Цена за литр'),
      TextCellValue('Общая сумма'),
      TextCellValue('Пробег'),
      TextCellValue('Комментарий'),
    ]);
    for (final item in data.fuel) {
      fuel.appendRow([
        TextCellValue(_formatDate(item['date'])),
        TextCellValue(item['time']?.toString() ?? ''),
        DoubleCellValue(
          (item['liters'] as num?)?.toDouble() ?? 0,
        ),
        DoubleCellValue(
          (item['price_per_liter'] as num?)?.toDouble() ?? 0,
        ),
        DoubleCellValue(
          (item['total'] as num?)?.toDouble() ?? 0,
        ),
        item['mileage'] == null
            ? TextCellValue('')
            : IntCellValue((item['mileage'] as num).toInt()),
        TextCellValue(item['note']?.toString() ?? ''),
      ]);
    }

    final expenses = excel['Расходы'];
    expenses.appendRow([
      TextCellValue('Дата'),
      TextCellValue('Время'),
      TextCellValue('Категория'),
      TextCellValue('Описание'),
      TextCellValue('Сумма'),
    ]);
    for (final expense in data.expenses) {
      expenses.appendRow([
        TextCellValue(_formatDate(expense['date'])),
        TextCellValue(expense['time']?.toString() ?? ''),
        TextCellValue(expense['category']?.toString() ?? ''),
        TextCellValue(expense['description']?.toString() ?? ''),
        DoubleCellValue(
          (expense['amount'] as num?)?.toDouble() ?? 0,
        ),
      ]);
    }

    final mileage = excel['Пробег'];
    mileage.appendRow([
      TextCellValue('Дата'),
      TextCellValue('Начальный пробег'),
      TextCellValue('Конечный пробег'),
      TextCellValue('Пробег за день'),
    ]);
    for (final log in data.mileage) {
      final start = (log['start_mileage'] as num?)?.toInt();
      final end = (log['end_mileage'] as num?)?.toInt();
      final distance = start == null || end == null
          ? null
          : end - start;

      mileage.appendRow([
        TextCellValue(_formatDate(log['date'])),
        start == null ? TextCellValue('') : IntCellValue(start),
        end == null ? TextCellValue('') : IntCellValue(end),
        distance == null
            ? TextCellValue('')
            : IntCellValue(distance),
      ]);
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
    if (bytes == null) {
      throw StateError('Не удалось создать Excel-файл.');
    }

    return Uint8List.fromList(bytes);
  }

  Future<void> shareExcel(DateTime month) async {
    final bytes = await buildExcel(month);
    final fileName = 'bus_control_${_fileMonth(month)}.xlsx';
    const mimeType =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

    if (kIsWeb) {
      await downloadBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      return;
    }

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          mimeType: mimeType,
        ),
      ],
      subject: 'BusControl PRO - ${_monthTitle(month)}',
      text: 'Отчёт BusControl PRO за ${_monthTitle(month)}',
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
    required this.mileage,
  });

  final MonthReport report;
  final List<Map<String, Object?>> trips;
  final List<Map<String, Object?>> orders;
  final List<Map<String, Object?>> fuel;
  final List<Map<String, Object?>> expenses;
  final List<Map<String, Object?>> mileage;
}
