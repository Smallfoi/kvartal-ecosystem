import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  static const _key = 'notifications';

  final List<AppNotification> _items = [];

  NotificationsProvider(this._prefs) {
    _load();
  }

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;
  bool get hasUnread => unreadCount > 0;

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _items.addAll(
        list.map((j) => AppNotification.fromJson(j as Map<String, dynamic>)),
      );
    } catch (_) {}
  }

  void _save() {
    _prefs.setString(_key, jsonEncode(_items.map((n) => n.toJson()).toList()));
  }

  void push(AppNotification notification) {
    _items.insert(0, notification);
    _save();
    notifyListeners();
  }

  void markAllRead() {
    if (!hasUnread) return;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) _items[i] = _items[i].copyWith(read: true);
    }
    _save();
    notifyListeners();
  }

  void remove(String id) {
    _items.removeWhere((n) => n.id == id);
    _save();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _save();
    notifyListeners();
  }
}
