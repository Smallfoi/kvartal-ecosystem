import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final err = await auth.sendPasswordReset(_emailCtrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _Header(sent: _sent, onClose: () => Navigator.of(context).pop()),
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
              child: _sent
                  ? _SuccessBody(
                      key: const ValueKey('success'),
                      email: _emailCtrl.text,
                      onBack: () => Navigator.of(context).pop(),
                      onResetPassword: () => Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, a, b) => ResetPasswordScreen(
                              email: _emailCtrl.text),
                          transitionsBuilder: (_, a, b, child) =>
                              SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                                parent: a, curve: Curves.easeOutCubic)),
                            child: child,
                          ),
                          transitionDuration:
                              const Duration(milliseconds: 350),
                        ),
                      ),
                    )
                  : _FormBody(
                      key: const ValueKey('form'),
                      emailCtrl: _emailCtrl,
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
  final bool sent;
  final VoidCallback onClose;

  const _Header({required this.sent, required this.onClose});

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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  sent ? 'Письмо отправлено' : 'Восстановление пароля',
                  key: ValueKey(sent),
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
  final TextEditingController emailCtrl;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _FormBody({
    super.key,
    required this.emailCtrl,
    required this.error,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Введите email, указанный при регистрации. Мы отправим ссылку для создания нового пароля.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.grey600,
              height: 1.6,
            ),
          ).animate().fadeIn(duration: 350.ms),

          const SizedBox(height: 28),

          // Email field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EMAIL',
                style: TextStyle(
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
                    controller: widget.emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'example@mail.ru',
                      hintStyle: const TextStyle(
                        color: AppColors.grey400,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.mail_outline,
                        size: 18,
                        color: _focused ? AppColors.black : AppColors.grey400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 350.ms, delay: 80.ms).slideY(begin: 0.1),

          if (widget.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFFFFF0F0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.error!,
                      style: const TextStyle(fontSize: 13, color: AppColors.red),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms).shakeX(hz: 3, amount: 4),
          ],

          const SizedBox(height: 24),

          // Submit button
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
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'ОТПРАВИТЬ ССЫЛКУ',
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
          ).animate().fadeIn(duration: 350.ms, delay: 160.ms).slideY(begin: 0.1),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: widget.onBack,
            child: const Text(
              'Вернуться ко входу',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.grey600,
                decoration: TextDecoration.underline,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 240.ms),
        ],
      ),
    );
  }
}

// ─── Success body ─────────────────────────────────────────────────────────────

class _SuccessBody extends StatelessWidget {
  final String email;
  final VoidCallback onBack;
  final VoidCallback onResetPassword;

  const _SuccessBody({
    super.key,
    required this.email,
    required this.onBack,
    required this.onResetPassword,
  });

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
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 40,
              color: AppColors.black,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 28),

          Text(
            'ПИСЬМО ОТПРАВЛЕНО',
            style: GoogleFonts.oswald(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.black,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 12),

          Text(
            'Мы отправили ссылку для сброса пароля на адрес\n$email',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.grey600,
              height: 1.6,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 8),

          const Text(
            'Если письмо не пришло, проверьте папку «Спам»',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.grey400,
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

          const SizedBox(height: 40),

          GestureDetector(
            onTap: onResetPassword,
            child: Container(
              height: 52,
              color: AppColors.black,
              alignment: Alignment.center,
              child: Text(
                'ЗАДАТЬ НОВЫЙ ПАРОЛЬ',
                style: GoogleFonts.oswald(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.1),

          const SizedBox(height: 16),

          GestureDetector(
            onTap: onBack,
            child: const Text(
              'Вернуться ко входу',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.grey600,
                decoration: TextDecoration.underline,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
        ],
      ),
    );
  }
}
