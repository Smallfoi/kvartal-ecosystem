import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sport_store/data/mock_data.dart';
import 'package:sport_store/providers/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockData', () {
    test('searches products by Russian query', () {
      final results = MockData.search('худи');

      expect(results, isNotEmpty);
      expect(
        results.any((product) => product.name.toLowerCase().contains('худи')),
        isTrue,
      );
    });

    test('calculates product discount percent', () {
      final product = MockData.getById('1');

      expect(product, isNotNull);
      expect(product!.isOnSale, isTrue);
      expect(product.discountPercent, 34);
    });
  });

  group('CartProvider', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('merges identical product variants and updates total', () {
      final cart = CartProvider(prefs);
      final product = MockData.getById('1')!;

      cart.add(product, 'M', 'Чёрный');
      cart.add(product, 'M', 'Чёрный');

      expect(cart.items, hasLength(1));
      expect(cart.itemCount, 2);
      expect(cart.total, product.price * 2);
    });

    test('keeps different variants as separate cart items', () {
      final cart = CartProvider(prefs);
      final product = MockData.getById('1')!;

      cart.add(product, 'M', 'Чёрный');
      cart.add(product, 'L', 'Чёрный');

      expect(cart.items, hasLength(2));
      expect(cart.itemCount, 2);
    });
  });
}
