import '../data/mock_data.dart';
import 'product.dart';

class CartItem {
  final Product product;
  final String size;
  final String color;
  int quantity;

  CartItem({
    required this.product,
    required this.size,
    required this.color,
    this.quantity = 1,
  });

  double get total => product.price * quantity;
  String get key => '${product.id}_${size}_$color';

  Map<String, dynamic> toJson() => {
        'productId': product.id,
        'size': size,
        'color': color,
        'quantity': quantity,
      };

  static CartItem? fromJson(Map<String, dynamic> json) {
    try {
      final product = MockData.products.firstWhere(
        (p) => p.id == json['productId'],
      );
      return CartItem(
        product: product,
        size: json['size'] as String,
        color: json['color'] as String,
        quantity: json['quantity'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}
