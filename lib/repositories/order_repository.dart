import '../database/database_helper.dart';
import '../models/order.dart';

class OrderRepository {
  OrderRepository._();

  static final OrderRepository instance = OrderRepository._();

  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  String _databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  /// Возвращает все заказы выбранного дня.
  Future<List<Order>> getOrdersForDate(DateTime date) async {
    final rows = await _databaseHelper.getOrdersByDate(
      _databaseDate(date),
    );

    final orders = rows.map(Order.fromMap).toList();

    orders.sort((first, second) {
      return first.time.compareTo(second.time);
    });

    return orders;
  }

  /// Добавляет новый заказ.
  Future<int> addOrder(Order order) {
    return _databaseHelper.addOrder(
      title: order.title,
      date: order.date,
      time: order.time,
      type: order.type.name,
      hours: order.hours,
      kilometers: order.kilometers,
      rate: order.rate,
      amount: order.amount,
      reminderHours: order.reminderHours,
      note: order.note,
    );
  }

  /// Устанавливает статус заказа.
  Future<void> setStatus({
    required int orderId,
    required OrderStatus status,
  }) {
    return _databaseHelper.updateOrderStatus(
      orderId,
      status.name,
    );
  }

  Future<void> markCompleted(int orderId) {
    return setStatus(
      orderId: orderId,
      status: OrderStatus.completed,
    );
  }

  Future<void> markCancelled(int orderId) {
    return setStatus(
      orderId: orderId,
      status: OrderStatus.cancelled,
    );
  }

  Future<void> restorePlanned(int orderId) {
    return setStatus(
      orderId: orderId,
      status: OrderStatus.planned,
    );
  }


  Future<int> addPayment({
    required int orderId,
    required double amount,
    String? note,
  }) {
    return _databaseHelper.addOrderPayment(
      orderId: orderId,
      amount: amount,
      note: note,
    );
  }

  Future<List<Map<String, Object?>>> getPayments(int orderId) {
    return _databaseHelper.getOrderPayments(orderId);
  }

  /// Полностью удаляет ошибочно созданную запись.
  Future<void> deleteOrder(int orderId) {
    return _databaseHelper.deleteOrder(orderId);
  }

  /// Сумма выполненных заказов за выбранный день.
  Future<double> getCompletedIncomeForDate(
      DateTime date,
      ) async {
    final orders = await getOrdersForDate(date);

    return orders
        .where((order) => order.isCompleted)
        .fold<double>(
      0,
          (total, order) => total + order.paidAmount,
    );
  }

  /// Количество заказов и доход за выбранный день.
  Future<OrderDaySummary> getDaySummary(
      DateTime date,
      ) async {
    final orders = await getOrdersForDate(date);

    final planned = orders
        .where((order) => order.isPlanned)
        .length;

    final completed = orders
        .where((order) => order.isCompleted)
        .length;

    final cancelled = orders
        .where((order) => order.isCancelled)
        .length;

    final completedIncome = orders
        .where((order) => order.isCompleted)
        .fold<double>(
      0,
          (total, order) => total + order.paidAmount,
    );

    return OrderDaySummary(
      total: orders.length,
      planned: planned,
      completed: completed,
      cancelled: cancelled,
      completedIncome: completedIncome,
    );
  }
}

class OrderDaySummary {
  const OrderDaySummary({
    required this.total,
    required this.planned,
    required this.completed,
    required this.cancelled,
    required this.completedIncome,
  });

  final int total;
  final int planned;
  final int completed;
  final int cancelled;
  final double completedIncome;
}