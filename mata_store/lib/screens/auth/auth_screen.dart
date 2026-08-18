import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/api/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/otp_verify_boxes.dart';
import '../../widgets/remote_text.dart';
import '../profile/legal_documents_screen.dart';

/// Формат номера: пользователь вводит ТОЛЬКО 10 цифр после несъёмного «+7».
/// Ведущие «7»/«8» (набранные или вставленные: «89148278470», «+7914…»)
/// отбрасываются автоматически — мобильные номера РФ начинаются с 9.
class RuPhoneFormatter extends TextInputFormatter {
  const RuPhoneFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('7') || digits.startsWith('8')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) digits = digits.substring(0, 10);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool startWithRegister;
  const AuthScreen({super.key, this.startWithRegister = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLogin;
  String? _error;

  // Вход и регистрация — ТОЛЬКО по единому номеру телефона (директива
  // владельца 2026-08-19): email/пароль из форм убраны.
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.startWithRegister;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // Переключение табов — мягкий фейд (шторку-проезд владелец отклонил
  // для этого перехода 2026-08-19).
  void _toggle(bool isLogin) {
    setState(() {
      _isLogin = isLogin;
      _error = null;
    });
  }

  /// Проверка кода; вызывается виджетом OtpVerifyBoxes (хореография «OTP V5»
  /// играет, пока идёт запрос). При регистрации дополнительно передаём имя —
  /// verify создаёт аккаунт при первом входе.
  Future<bool> _verifyPhoneCode(String code, {bool register = false}) async {
    if (mounted) setState(() => _error = null);
    if (register && _nameCtrl.text.trim().isEmpty) {
      _phoneError = 'Введите имя';
      return false;
    }
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      _phoneError = 'Введите номер полностью';
      return false;
    }
    final auth = context.read<AuthProvider>();
    final err = await auth.loginByPhone(
      '+7$digits',
      code,
      name: register ? _nameCtrl.text.trim() : null,
    );
    if (err != null) {
      _phoneError = err;
      return false;
    }
    return true;
  }

  String? _phoneError;

  void _onPhoneFailed() {
    if (!mounted) return;
    setState(() => _error = _phoneError ?? 'Не удалось войти');
  }

  Future<void> _onPhoneVerified() async {
    if (!mounted) return;
    await _afterLogin();
  }

  /// После успешного входа: если есть непринятые обязательные документы —
  /// показываем гейт согласия вместо закрытия экрана. Иначе — закрываем вход.
  Future<void> _afterLogin() async {
    final hasPending = await hasPendingRequiredLegal(
      context.read<ApiClient?>(),
    );
    if (!mounted) return;
    if (hasPending) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConsentGateScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _BlackHeader(
            isLogin: _isLogin,
            onToggle: _toggle,
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _isLogin
                    ? _LoginForm(
                        key: const ValueKey('login'),
                        phoneCtrl: _phoneCtrl,
                        error: _error,
                        onPhoneVerify: _verifyPhoneCode,
                        onPhoneVerified: _onPhoneVerified,
                        onPhoneFailed: _onPhoneFailed,
                      )
                    : _RegisterForm(
                        key: const ValueKey('register'),
                        nameCtrl: _nameCtrl,
                        phoneCtrl: _phoneCtrl,
                        error: _error,
                        onPhoneVerify: (code) =>
                            _verifyPhoneCode(code, register: true),
                        onPhoneVerified: _onPhoneVerified,
                        onPhoneFailed: _onPhoneFailed,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Black header with tabs ───────────────────────────────────────────────────

class _BlackHeader extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onToggle;
  final VoidCallback onClose;

  const _BlackHeader({
    required this.isLogin,
    required this.onToggle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              RemoteText(
                'app.auth.brand',
                'МАТА STORE',
                style: GoogleFonts.oswald(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
              const SizedBox(height: 4),
              RemoteText(
                isLogin
                    ? 'app.auth.subtitleLogin'
                    : 'app.auth.subtitleRegister',
                isLogin
                    ? 'Войдите, чтобы управлять заказами'
                    : 'Создайте аккаунт и получите скидку 10%',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF888888),
                  height: 1.4,
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 28),
              _TabBar(isLogin: isLogin, onToggle: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onToggle;

  const _TabBar({required this.isLogin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Tab(
          labelKey: 'app.auth.tabLogin',
          label: 'ВХОД',
          isActive: isLogin,
          onTap: () => onToggle(true),
        ),
        const SizedBox(width: 28),
        _Tab(
          labelKey: 'app.auth.tabRegister',
          label: 'РЕГИСТРАЦИЯ',
          isActive: !isLogin,
          onTap: () => onToggle(false),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String labelKey;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({
    required this.labelKey,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteText(
            labelKey,
            label,
            style: GoogleFonts.oswald(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: isActive ? Colors.white : const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 2,
            width: isActive ? label.length * 9.5 : 0,
            color: Colors.white,
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}

// ─── Login form: вход только по номеру телефона (единый аккаунт) ─────────────

class _LoginForm extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final String? error;
  final Future<bool> Function(String code) onPhoneVerify;
  final VoidCallback onPhoneVerified;
  final VoidCallback onPhoneFailed;

  const _LoginForm({
    super.key,
    required this.phoneCtrl,
    required this.error,
    required this.onPhoneVerify,
    required this.onPhoneVerified,
    required this.onPhoneFailed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RemoteText(
          'app.auth.phoneHint',
          'Вход по единому номеру',
          style: GoogleFonts.oswald(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.black,
          ),
        ).animate().fadeIn(duration: 350.ms, delay: 50.ms).slideY(begin: 0.1),
        const SizedBox(height: 12),
        _InputField(
          controller: phoneCtrl,
          label: 'Телефон',
          hint: '999 000-00-00',
          prefixText: '+7 ',
          keyboardType: TextInputType.phone,
          inputFormatters: const [RuPhoneFormatter()],
          icon: Icons.phone_outlined,
        ).animate().fadeIn(duration: 350.ms, delay: 120.ms).slideY(begin: 0.1),
        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: error!),
        ],
        const SizedBox(height: 16),
        // Ввод кода — хореография «OTP V5»: при вводе 4-й цифры код уходит на
        // проверку сам, кнопка не нужна (стандарт анимаций экосистемы МАТА).
        OtpVerifyBoxes(
          hasError: error != null,
          onSubmit: onPhoneVerify,
          onSuccess: onPhoneVerified,
          onFailed: onPhoneFailed,
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Тестовый код: 1234',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.grey400,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Register form: регистрация тоже только по номеру телефона ────────────────

class _RegisterForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final String? error;
  final Future<bool> Function(String code) onPhoneVerify;
  final VoidCallback onPhoneVerified;
  final VoidCallback onPhoneFailed;

  const _RegisterForm({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.error,
    required this.onPhoneVerify,
    required this.onPhoneVerified,
    required this.onPhoneFailed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputField(
          controller: nameCtrl,
          label: 'Имя',
          hint: 'Иван Иванов',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
        ).animate().fadeIn(duration: 350.ms, delay: 50.ms).slideY(begin: 0.1),
        const SizedBox(height: 14),
        _InputField(
          controller: phoneCtrl,
          label: 'Телефон',
          hint: '999 000-00-00',
          prefixText: '+7 ',
          keyboardType: TextInputType.phone,
          inputFormatters: const [RuPhoneFormatter()],
          icon: Icons.phone_outlined,
        ).animate().fadeIn(duration: 350.ms, delay: 120.ms).slideY(begin: 0.1),
        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: error!),
        ],
        const SizedBox(height: 16),
        // Код подтверждения: verify создаёт аккаунт при первом входе (имя
        // уходит вместе с кодом) — пароль не нужен.
        OtpVerifyBoxes(
          hasError: error != null,
          onSubmit: onPhoneVerify,
          onSuccess: onPhoneVerified,
          onFailed: onPhoneFailed,
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Тестовый код: 1234',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.grey400,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const RemoteText(
          'app.auth.consent',
          'Продолжая, вы соглашаетесь с условиями использования и политикой конфиденциальности',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.grey400, height: 1.5),
        ).animate().fadeIn(duration: 300.ms, delay: 320.ms),
        const SizedBox(height: 6),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LegalDocumentsScreen()),
            ),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                'Открыть документы',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 340.ms),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Shared UI components ─────────────────────────────────────────────────────

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.prefixText,
    this.inputFormatters,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.grey600,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: _focused ? AppColors.black : AppColors.grey200,
              width: _focused ? 1.5 : 1,
            ),
          ),
          child: Focus(
            onFocusChange: (f) => setState(() => _focused = f),
            child: TextField(
              controller: widget.controller,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
              inputFormatters: widget.inputFormatters,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.black,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(
                  color: AppColors.grey400,
                  fontSize: 14,
                ),
                // Несъёмный префикс («+7 ») живёт в prefixIcon — в отличие от
                // prefixText он виден ВСЕГДА, а не только при фокусе
                // (замечание владельца). Начертание — как у вводимых цифр.
                prefixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      widget.icon,
                      size: 18,
                      color: _focused ? AppColors.black : AppColors.grey400,
                    ),
                    if (widget.prefixText != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        widget.prefixText!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ] else
                      const SizedBox(width: 12),
                  ],
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFFFF0F0),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.red),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).shakeX(hz: 3, amount: 4);
  }
}
