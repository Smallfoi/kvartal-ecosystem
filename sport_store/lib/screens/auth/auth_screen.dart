import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool startWithRegister;
  const AuthScreen({super.key, this.startWithRegister = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isLogin;
  String? _error;

  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _codeCtrl    = TextEditingController(text: '1234');

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.startWithRegister;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _toggle(bool isLogin) {
    setState(() {
      _isLogin = isLogin;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    String? err;

    if (_isLogin) {
      err = await auth.login(_emailCtrl.text, _passCtrl.text);
    } else {
      err = await auth.register(
        _nameCtrl.text,
        _emailCtrl.text,
        _passCtrl.text,
        _confirmCtrl.text,
      );
    }

    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submitPhone() async {
    final auth = context.read<AuthProvider>();
    final err = await auth.loginByPhone(_phoneCtrl.text, _codeCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, b) => const ForgotPasswordScreen(),
        transitionsBuilder: (_, a, b, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
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
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        phoneCtrl: _phoneCtrl,
                        codeCtrl: _codeCtrl,
                        error: _error,
                        onSubmit: _submit,
                        onPhoneSubmit: _submitPhone,
                        onForgotPassword: _openForgotPassword,
                      )
                    : _RegisterForm(
                        key: const ValueKey('register'),
                        nameCtrl: _nameCtrl,
                        emailCtrl: _emailCtrl,
                        passCtrl: _passCtrl,
                        confirmCtrl: _confirmCtrl,
                        error: _error,
                        onSubmit: _submit,
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
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SPORT STORE',
                style: GoogleFonts.oswald(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
              const SizedBox(height: 4),
              Text(
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
        _Tab(label: 'ВХОД', isActive: isLogin, onTap: () => onToggle(true)),
        const SizedBox(width: 28),
        _Tab(label: 'РЕГИСТРАЦИЯ', isActive: !isLogin, onTap: () => onToggle(false)),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
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

// ─── Login form ───────────────────────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController codeCtrl;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onPhoneSubmit;
  final VoidCallback onForgotPassword;

  const _LoginForm({
    super.key,
    required this.emailCtrl,
    required this.passCtrl,
    required this.phoneCtrl,
    required this.codeCtrl,
    required this.error,
    required this.onSubmit,
    required this.onPhoneSubmit,
    required this.onForgotPassword,
  });

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputField(
          controller: widget.emailCtrl,
          label: 'Email',
          hint: 'example@mail.ru',
          keyboardType: TextInputType.emailAddress,
          icon: Icons.mail_outline,
        ).animate().fadeIn(duration: 350.ms, delay: 50.ms).slideY(begin: 0.1),

        const SizedBox(height: 14),

        _InputField(
          controller: widget.passCtrl,
          label: 'Пароль',
          hint: '••••••••',
          obscure: _obscure,
          icon: Icons.lock_outline,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20,
              color: AppColors.grey400,
            ),
          ),
        ).animate().fadeIn(duration: 350.ms, delay: 120.ms).slideY(begin: 0.1),

        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: widget.onForgotPassword,
            child: const Text(
              'Забыли пароль?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.grey600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 180.ms),

        if (widget.error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: widget.error!),
        ],

        const SizedBox(height: 24),

        _SubmitButton(
          label: 'ВОЙТИ',
          onTap: widget.onSubmit,
        ).animate().fadeIn(duration: 350.ms, delay: 220.ms).slideY(begin: 0.1),

        const SizedBox(height: 22),
        _Divider(),
        const SizedBox(height: 20),
        Text(
          '\u0412\u0445\u043e\u0434 \u043f\u043e \u0435\u0434\u0438\u043d\u043e\u043c\u0443 \u043d\u043e\u043c\u0435\u0440\u0443',
          style: GoogleFonts.oswald(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 12),
        _InputField(
          controller: widget.phoneCtrl,
          label: '\u0422\u0435\u043b\u0435\u0444\u043e\u043d',
          hint: '+7 999 000-00-00',
          keyboardType: TextInputType.phone,
          icon: Icons.phone_outlined,
        ),
        const SizedBox(height: 12),
        _InputField(
          controller: widget.codeCtrl,
          label: '\u041a\u043e\u0434',
          hint: '1234',
          keyboardType: TextInputType.number,
          icon: Icons.sms_outlined,
        ),
        const SizedBox(height: 14),
        _SubmitButton(
          label: '\u0412\u041e\u0419\u0422\u0418 \u041f\u041e \u0422\u0415\u041b\u0415\u0424\u041e\u041d\u0423',
          onTap: widget.onPhoneSubmit,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Register form ────────────────────────────────────────────────────────────

class _RegisterForm extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final String? error;
  final VoidCallback onSubmit;

  const _RegisterForm({
    super.key,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.error,
    required this.onSubmit,
  });

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InputField(
          controller: widget.nameCtrl,
          label: 'Имя',
          hint: 'Иван Иванов',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
        ).animate().fadeIn(duration: 350.ms, delay: 50.ms).slideY(begin: 0.1),

        const SizedBox(height: 14),

        _InputField(
          controller: widget.emailCtrl,
          label: 'Email',
          hint: 'example@mail.ru',
          keyboardType: TextInputType.emailAddress,
          icon: Icons.mail_outline,
        ).animate().fadeIn(duration: 350.ms, delay: 110.ms).slideY(begin: 0.1),

        const SizedBox(height: 14),

        _InputField(
          controller: widget.passCtrl,
          label: 'Пароль',
          hint: 'Минимум 6 символов',
          obscure: _obscure,
          icon: Icons.lock_outline,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20,
              color: AppColors.grey400,
            ),
          ),
        ).animate().fadeIn(duration: 350.ms, delay: 170.ms).slideY(begin: 0.1),

        const SizedBox(height: 14),

        _InputField(
          controller: widget.confirmCtrl,
          label: 'Подтвердите пароль',
          hint: '••••••••',
          obscure: _obscureConfirm,
          icon: Icons.lock_outline,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
            child: Icon(
              _obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: AppColors.grey400,
            ),
          ),
        ).animate().fadeIn(duration: 350.ms, delay: 230.ms).slideY(begin: 0.1),

        if (widget.error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: widget.error!),
        ],

        const SizedBox(height: 24),

        _SubmitButton(
          label: 'СОЗДАТЬ АККАУНТ',
          onTap: widget.onSubmit,
        ).animate().fadeIn(duration: 350.ms, delay: 280.ms).slideY(begin: 0.1),

        const SizedBox(height: 14),

        const Text(
          'Нажимая кнопку, вы соглашаетесь с условиями использования и политикой конфиденциальности',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.grey400,
            height: 1.5,
          ),
        ).animate().fadeIn(duration: 300.ms, delay: 320.ms),
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
  final bool obscure;
  final IconData icon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
    required this.icon,
    this.suffix,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
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
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
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
                prefixIcon: Icon(
                  widget.icon,
                  size: 18,
                  color: _focused ? AppColors.black : AppColors.grey400,
                ),
                suffixIcon: widget.suffix != null
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: widget.suffix,
                      )
                    : null,
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

class _SubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SubmitButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return GestureDetector(
          onTap: auth.isLoading ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 52,
            color: auth.isLoading ? AppColors.grey800 : AppColors.black,
            alignment: Alignment.center,
            child: auth.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.oswald(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                      letterSpacing: 2,
                    ),
                  ),
          ),
        );
      },
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: AppColors.grey200)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'или',
            style: TextStyle(fontSize: 13, color: AppColors.grey400),
          ),
        ),
        Expanded(child: Divider(color: AppColors.grey200)),
      ],
    );
  }
}
