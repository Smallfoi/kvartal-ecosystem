import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/auth_repository.dart';
import '../models/auth_user.dart';

// Re-export, чтобы существующие `import '.../auth_provider.dart'` по-прежнему
// видели AuthUser/SavedAddress/LoginProvider.
export '../models/auth_user.dart';

class AuthProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final AuthRepository _repo;
  final VoidCallback? onSessionEnd; // очистка JWT при выходе (для API)
  static const _key = 'auth_user';

  AuthUser? _user;
  bool _isLoading = false;

  AuthProvider(this._prefs, this._repo, {this.onSessionEnd}) {
    _load();
    // Если есть кэш юзера (и валидный JWT) — обновить профиль с backend.
    if (_user != null) refreshFromServer();
  }

  /// backend пока не хранит адреса/локальный аватар — сохраняем их при синке.
  AuthUser _mergeKeepingLocal(AuthUser fresh) => AuthUser(
    id: fresh.id,
    name: fresh.name,
    email: fresh.email,
    phone: fresh.phone,
    city: fresh.city,
    provider: fresh.provider,
    addresses: fresh.addresses.isNotEmpty ? fresh.addresses : _user!.addresses,
    avatarPath: fresh.avatarPath ?? _user!.avatarPath,
  );

  /// Обновить профиль из backend (GET /auth/me). Тихо игнорирует офлайн/mock.
  Future<void> refreshFromServer() async {
    if (_user == null) return;
    try {
      _user = _mergeKeepingLocal(await _repo.fetchMe());
      _save();
      notifyListeners();
    } catch (_) {
      // backend недоступен или mock — оставляем локальный кэш
    }
  }

  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      _user = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  void _save() {
    if (_user == null) {
      _prefs.remove(_key);
    } else {
      _prefs.setString(_key, jsonEncode(_user!.toJson()));
    }
  }

  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return 'Заполните все поля';
    if (!email.contains('@')) return 'Некорректный email';
    if (password.length < 6) return 'Минимум 6 символов';
    _setLoading(true);
    _user = await _repo.login(email, password);
    _save();
    _setLoading(false);
    return null;
  }

  Future<String?> loginByPhone(String phone, String code) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Введите корректный номер';
    if (code.trim().length != 4) return 'Введите код из SMS';
    _setLoading(true);
    try {
      _user = await _repo.loginByPhone(phone, code);
      _save();
      return null;
    } catch (e) {
      return 'Не удалось войти по телефону';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> register(
    String name,
    String email,
    String password,
    String confirm,
  ) async {
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      return 'Заполните все поля';
    }
    if (!email.contains('@')) return 'Некорректный email';
    if (password.length < 6) return 'Минимум 6 символов';
    if (password != confirm) return 'Пароли не совпадают';
    _setLoading(true);
    _user = await _repo.register(name, email, password);
    _save();
    _setLoading(false);
    return null;
  }

  Future<String?> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) return 'Введите email';
    if (!email.contains('@')) return 'Некорректный email';
    _setLoading(true);
    await _repo.sendPasswordReset(email);
    _setLoading(false);
    return null;
  }

  Future<String?> resetPassword(String newPass, String confirm) async {
    if (newPass.isEmpty || confirm.isEmpty) return 'Заполните все поля';
    if (newPass.length < 6) return 'Минимум 6 символов';
    if (newPass != confirm) return 'Пароли не совпадают';
    _setLoading(true);
    await _repo.resetPassword(newPass);
    _setLoading(false);
    return null;
  }

  Future<String?> updateProfile({
    required String name,
    String? phone,
    String? city,
    String? email,
  }) async {
    if (_user == null) return 'Не авторизован';
    if (name.trim().isEmpty) return 'Введите имя';
    if (email != null && email.trim().isNotEmpty && !email.contains('@')) {
      return 'Введите корректный email';
    }
    _setLoading(true);
    try {
      _user = _mergeKeepingLocal(
        await _repo.updateProfile(_user!,
            name: name, phone: phone, city: city, email: email),
      );
      _save();
      return null;
    } catch (_) {
      return 'Не удалось сохранить профиль';
    } finally {
      _setLoading(false);
    }
  }

  /// Загрузить серверный аватар (единый для экосистемы). null — успех.
  Future<String?> uploadAvatar(String filePath) async {
    if (_user == null) return 'Не авторизован';
    _setLoading(true);
    try {
      _user = _withServerAvatar(await _repo.uploadAvatar(filePath));
      _save();
      return null;
    } catch (_) {
      return 'Не удалось загрузить фото';
    } finally {
      _setLoading(false);
    }
  }

  /// Снять серверный аватар (вернуться к инициалам).
  Future<String?> removeAvatar() async {
    if (_user == null) return 'Не авторизован';
    _setLoading(true);
    try {
      _user = _withServerAvatar(await _repo.removeAvatar());
      _save();
      return null;
    } catch (_) {
      return 'Не удалось убрать фото';
    } finally {
      _setLoading(false);
    }
  }

  /// Свежий юзер с сервера, но локальные адреса сохраняем; аватар — серверный
  /// (включая null при удалении — в отличие от _mergeKeepingLocal).
  AuthUser _withServerAvatar(AuthUser fresh) => AuthUser(
    id: fresh.id,
    name: fresh.name,
    email: fresh.email,
    phone: fresh.phone,
    city: fresh.city,
    provider: fresh.provider,
    addresses: fresh.addresses.isNotEmpty ? fresh.addresses : _user!.addresses,
    avatarPath: fresh.avatarPath,
  );

  void addAddress(SavedAddress address) {
    if (_user == null) return;
    final list = List<SavedAddress>.from(_user!.addresses);
    final exists = list.any((a) => a.displayLine == address.displayLine);
    if (!exists) list.insert(0, address);
    _user = AuthUser(
      id: _user!.id,
      name: _user!.name,
      email: _user!.email,
      phone: _user!.phone,
      provider: _user!.provider,
      city: _user!.city,
      addresses: list,
      avatarPath: _user!.avatarPath,
    );
    _save();
    notifyListeners();
  }

  void removeAddress(int index) {
    if (_user == null) return;
    final list = List<SavedAddress>.from(_user!.addresses)..removeAt(index);
    _user = AuthUser(
      id: _user!.id,
      name: _user!.name,
      email: _user!.email,
      phone: _user!.phone,
      provider: _user!.provider,
      city: _user!.city,
      addresses: list,
      avatarPath: _user!.avatarPath,
    );
    _save();
    notifyListeners();
  }

  Future<String?> changePassword(
    String oldPass,
    String newPass,
    String confirm,
  ) async {
    if (oldPass.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      return 'Заполните все поля';
    }
    if (oldPass.length < 6) return 'Неверный текущий пароль';
    if (newPass.length < 6) return 'Минимум 6 символов';
    if (newPass != confirm) return 'Пароли не совпадают';
    _setLoading(true);
    await _repo.changePassword(oldPass, newPass);
    _setLoading(false);
    return null;
  }

  void logout() {
    _user = null;
    _save();
    onSessionEnd?.call();
    notifyListeners();
  }

  /// Видимость профиля (общая настройка приватности аккаунта).
  Future<bool> getProfilePublic() async {
    try {
      return await _repo.getProfilePublic();
    } catch (_) {
      return false;
    }
  }

  Future<bool> setProfilePublic(bool value) async {
    try {
      return await _repo.setProfilePublic(value);
    } catch (_) {
      return value;
    }
  }

  /// Необратимо удалить аккаунт; при успехе разлогинивает. true — успех.
  Future<bool> deleteAccount() async {
    if (_user == null) return false;
    try {
      await _repo.deleteAccount();
      logout();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
