import '../../models/order.dart';
import '../api/api_client.dart';

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
}
