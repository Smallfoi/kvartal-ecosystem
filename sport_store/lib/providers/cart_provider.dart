import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const _key = 'cart_items';

  final List<CartItem> _items = [];

  CartProvider(this._prefs) {
    _load();
  }

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get total => _items.fold(0, (sum, item) => sum + item.total);

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      for (final json in list) {
        final item = CartItem.fromJson(json as Map<String, dynamic>);
        if (item != null) _items.add(item);
      }
    } catch (_) {}
  }

  void _save() {
    _prefs.setString(_key, jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  bool contains(String productId, String size, String color) {
    final key = '${productId}_${size}_$color';
    return _items.any((item) => item.key == key);
  }

  void add(Product product, String size, String color) {
    final key = '${product.id}_${size}_$color';
    final index = _items.indexWhere((item) => item.key == key);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product, size: size, color: color));
    }
    _save();
    notifyListeners();
  }

  void remove(String key) {
    _items.removeWhere((item) => item.key == key);
    _save();
    notifyListeners();
  }

  void increment(String key) {
    final index = _items.indexWhere((item) => item.key == key);
    if (index >= 0) {
      _items[index].quantity++;
      _save();
      notifyListeners();
    }
  }

  void decrement(String key) {
    final index = _items.indexWhere((item) => item.key == key);
    if (index >= 0) {
      if (_items[index].quantity <= 1) {
        _items.removeAt(index);
      } else {
        _items[index].quantity--;
      }
      _save();
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _save();
    notifyListeners();
  }
}
