import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final err = await auth.resetPassword(_passCtrl.text, _confirmCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() => _done = true);
    }
  }

  void _goToLogin() {
    // pop ResetPasswordScreen + ForgotPasswordScreen → back to AuthScreen
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _Header(done: _done, onClose: () => Navigator.of(context).pop()),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _done
                  ? _SuccessBody(
                      key: const ValueKey('success'),
                      onLogin: _goToLogin,
                    )
                  : _FormBody(
                      key: const ValueKey('form'),
                      email: widget.email,
                      passCtrl: _passCtrl,
                      confirmCtrl: _confirmCtrl,
                      error: _error,
                      onSubmit: _submit,
                      onBack: () => Navigator.of(context).pop(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool done;
  final VoidCallback onClose;
  const _Header({required this.done, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 22),
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  done ? 'Пароль обновлён' : 'Новый пароль',
                  key: ValueKey(done),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Form body ────────────────────────────────────────────────────────────────

class _FormBody extends StatefulWidget {
  final String email;
  final TextEditingController passCtrl;
  final TextEditingController confirmCtrl;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _FormBody({
    super.key,
    required this.email,
    required this.passCtrl,
    required this.confirmCtrl,
    required this.error,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: AppColors.grey100,
            child: Row(
              children: [
                const Icon(Icons.mail_outline,
                    size: 16, color: AppColors.grey600),
                const SizedBox(width: 8),
                Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.grey600,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 8),

          const Text(
            'Придумайте надёжный пароль — минимум 6 символов.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.grey600,
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 350.ms, delay: 60.ms),

          const SizedBox(height: 24),

          // New password
          _PasswordField(
            controller: widget.passCtrl,
            label: 'Новый пароль',
            hint: 'Минимум 6 символов',
            obscure: _obscure,
            onToggle: () => setState(() => _obscure = !_obscure),
          ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.08),

          const SizedBox(height: 14),

          // Confirm password
          _PasswordField(
            controller: widget.confirmCtrl,
            label: 'Подтвердите пароль',
            hint: '••••••••',
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ).animate().fadeIn(duration: 350.ms, delay: 170.ms).slideY(begin: 0.08),

          if (widget.error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: widget.error!)
                .animate()
                .fadeIn(duration: 250.ms)
                .shakeX(hz: 3, amount: 4),
          ],

          const SizedBox(height: 28),

          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return GestureDetector(
                onTap: auth.isLoading ? null : widget.onSubmit,
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
                              color: AppColors.white, strokeWidth: 2),
                        )
                      : Text(
                          'СОХРАНИТЬ ПАРОЛЬ',
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
          ).animate().fadeIn(duration: 350.ms, delay: 230.ms).slideY(begin: 0.08),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: widget.onBack,
            child: const Text(
              'Вернуться назад',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.grey600,
                decoration: TextDecoration.underline,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 300.ms),
        ],
      ),
    );
  }
}

// ─── Success body ─────────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  final VoidCallback onLogin;
  const _SuccessBody({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            color: AppColors.grey100,
            child: const Icon(Icons.check, size: 40, color: AppColors.black),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 28),

          Text(
            'ПАРОЛЬ ОБНОВЛЁН',
            style: GoogleFonts.oswald(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.black,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 12),

          const Text(
            'Теперь вы можете войти\nс новым паролем',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.grey600,
              height: 1.6,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 40),

          GestureDetector(
            onTap: onLogin,
            child: Container(
              height: 52,
              color: AppColors.black,
              alignment: Alignment.center,
              child: Text(
                'ВОЙТИ',
                style: GoogleFonts.oswald(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _FocusableField(
      controller: controller,
      label: label,
      hint: hint,
      obscure: obscure,
      suffix: GestureDetector(
        onTap: onToggle,
        child: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: AppColors.grey400,
        ),
      ),
    );
  }
}

class _FocusableField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final Widget? suffix;

  const _FocusableField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.suffix,
  });

  @override
  State<_FocusableField> createState() => _FocusableFieldState();
}

class _FocusableFieldState extends State<_FocusableField> {
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
              style: const TextStyle(fontSize: 15, color: AppColors.black),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    const TextStyle(color: AppColors.grey400, fontSize: 14),
                prefixIcon: Icon(Icons.lock_outline,
                    size: 18,
                    color: _focused ? AppColors.black : AppColors.grey400),
                suffixIcon: widget.suffix != null
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: widget.suffix,
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}
