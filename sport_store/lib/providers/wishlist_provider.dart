import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class WishlistProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const _key = 'wishlist_ids';

  late final Set<String> _ids;

  WishlistProvider(this._prefs) {
    _ids = _load();
  }

  Set<String> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return {};
    }
  }

  void _save() {
    _prefs.setString(_key, jsonEncode(_ids.toList()));
  }

  Set<String> get ids => Set.unmodifiable(_ids);
  bool contains(String productId) => _ids.contains(productId);
  int get count => _ids.length;

  void toggle(Product product) {
    if (_ids.contains(product.id)) {
      _ids.remove(product.id);
    } else {
      _ids.add(product.id);
    }
    _save();
    notifyListeners();
  }
}
