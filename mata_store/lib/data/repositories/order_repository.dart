import '../../models/order.dart';
import '../api/api_client.dart';

/// Результат запуска оплаты: куда вести покупателя и что уже известно о платеже.
class PaymentStart {
  /// none/pending/paid/canceled — как их понимает backend.
  final String status;

  /// Ссылка оплаты. Для СБП это `qr.nspk.ru/...`: на телефоне она открывает
  /// банковское приложение, на компьютере её показывают QR-кодом.
  final String confirmationUrl;
  final String paymentId;

  const PaymentStart({
    required this.status,
    required this.confirmationUrl,
    required this.paymentId,
  });

  bool get needsAction => status != 'paid' && confirmationUrl.isNotEmpty;

  factory PaymentStart.fromJson(Map<String, dynamic> j) => PaymentStart(
        status: (j['status'] ?? 'pending').toString(),
        confirmationUrl: (j['confirmationUrl'] ?? '').toString(),
        paymentId: (j['paymentId'] ?? '').toString(),
      );
}

/// Контракт работы с заказами на стороне backend.
///
/// Локальное хранение/таймеры статусов остаются в `OrderProvider` (прототип).
/// Здесь — только то, что в продакшене уходит на сервер.
abstract class OrderRepository {
  /// Отправить оформленный заказ на backend, вернуть подтверждённый заказ
  /// (с присвоенным сервером id/статусом).
  Future<Order> submitOrder(Order order);

  /// Получить заказы текущего пользователя с сервера.
  Future<List<Order>> fetchOrders();

  /// Начать оплату заказа. Возвращает ссылку, по которой покупатель платит.
  Future<PaymentStart> startPayment(String orderId);

  /// Текущий статус оплаты. Backend сам перепроверяет его у провайдера, если
  /// уведомление о платеже потерялось.
  Future<String> paymentStatus(String orderId);
}

class MockOrderRepository implements OrderRepository {
  @override
  Future<Order> submitOrder(Order order) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return order; // backend подтвердил как есть
  }

  @override
  Future<List<Order>> fetchOrders() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const []; // в прототипе заказы хранятся локально в OrderProvider
  }

  @override
  Future<PaymentStart> startPayment(String orderId) async {
    // Без backend оплата не требуется — ведём себя как dev-режим сервера.
    return const PaymentStart(status: 'paid', confirmationUrl: '', paymentId: '');
  }

  @override
  Future<String> paymentStatus(String orderId) async => 'paid';
}

class ApiOrderRepository implements OrderRepository {
  final ApiClient _client;
  ApiOrderRepository(this._client);

  @override
  Future<Order> submitOrder(Order order) async {
    final data = await _client.post('/orders', body: order.toJson());
    return Order.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<Order>> fetchOrders() async {
    final data = await _client.get('/orders') as List;
    return data.map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<PaymentStart> startPayment(String orderId) async {
    final data = await _client.post('/orders/$orderId/pay', body: const {});
    return PaymentStart.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<String> paymentStatus(String orderId) async {
    final data = await _client.get('/orders/$orderId/payment');
    return ((data as Map<String, dynamic>)['status'] ?? 'pending').toString();
  }
}
