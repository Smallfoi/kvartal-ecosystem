import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_store/data/mock_data.dart';
import 'package:sport_store/data/repositories/order_repository.dart';
import 'package:sport_store/models/order.dart';
import 'package:sport_store/providers/cart_provider.dart';
import 'package:sport_store/providers/order_provider.dart';

/// Репозиторий, у которого отправка заказа ВСЕГДА падает (сеть/сервер).
class _FailingOrderRepo implements OrderRepository {
  @override
  Future<Order> submitOrder(Order order) async =>
      throw Exception('network down');
  @override
  Future<List<Order>> fetchOrders() async => const [];
  @override
  Future<PaymentStart> startPayment(String orderId) async =>
      const PaymentStart(status: 'paid', confirmationUrl: '', paymentId: '');
  @override
  Future<String> paymentStatus(String orderId) async => 'paid';
}

/// Репозиторий, у которого отправка заказа успешна.
class _OkOrderRepo implements OrderRepository {
  @override
  Future<Order> submitOrder(Order order) async => order;
  @override
  Future<List<Order>> fetchOrders() async => const [];
  @override
  Future<PaymentStart> startPayment(String orderId) async =>
      const PaymentStart(status: 'paid', confirmationUrl: '', paymentId: '');
  @override
  Future<String> paymentStatus(String orderId) async => 'paid';
}

CheckoutData _data() => CheckoutData(
      name: 'Тест',
      phone: '+70000000000',
      email: 'test@example.com',
      deliveryType: DeliveryType.pickup,
      paymentType: PaymentType.card,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Провал отправки: заказ снимается (нет «фантома»), lastSubmit=false',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final orders =
        OrderProvider(prefs, _FailingOrderRepo(), serverBacked: true);
    final cart = CartProvider(prefs);
    cart.add(MockData.getById('1')!, 'M', 'Чёрный');

    final order = orders.placeOrder(cart.items.toList(), _data());
    final ok = await orders.lastSubmit!;

    expect(ok, isFalse, reason: 'отправка не удалась → false');
    expect(orders.orders.any((o) => o.id == order.id), isFalse,
        reason: 'фантомный заказ не должен оставаться в истории');
    orders.dispose();
  });

  test('Успех отправки: заказ остаётся, lastSubmit=true', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final orders = OrderProvider(prefs, _OkOrderRepo(), serverBacked: true);
    final cart = CartProvider(prefs);
    cart.add(MockData.getById('1')!, 'M', 'Чёрный');

    final order = orders.placeOrder(cart.items.toList(), _data());
    final ok = await orders.lastSubmit!;

    expect(ok, isTrue);
    expect(orders.orders.any((o) => o.id == order.id), isTrue);
    orders.dispose(); // гасит таймеры имитации доставки
  });
}
