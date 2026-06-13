import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class SocialSignUpScreen extends StatefulWidget {
  final OAuthPendingData pendingData;

  const SocialSignUpScreen({super.key, required this.pendingData});

  @override
  State<SocialSignUpScreen> createState() => _SocialSignUpScreenState();
}

class _SocialSignUpScreenState extends State<SocialSignUpScreen> {
  late final TextEditingController _nameCtrl;
  final _phoneCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.pendingData.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Введите имя');
      return;
    }
    final auth = context.read<AuthProvider>();
    await auth.completeSocialSignUp(
      widget.pendingData,
      _nameCtrl.text,
      _phoneCtrl.text,
    );
    if (!mounted) return;
    // pop SocialSignUpScreen + AuthScreen → return to ProfileScreen
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  String get _providerLabel => widget.pendingData.provider == LoginProvider.google
      ? 'Google'
      : 'Apple';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _Header(provider: widget.pendingData.provider),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Provider badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    color: AppColors.grey100,
                    child: Row(
                      children: [
                        _providerIcon(),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Данные из $_providerLabel',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.grey600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                widget.pendingData.email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 28),

                  const Text(
                    'Проверьте и при необходимости исправьте данные',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.grey600,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(duration: 350.ms, delay: 50.ms),

                  const SizedBox(height: 24),

                  // Name field (editable)
                  _InputField(
                    controller: _nameCtrl,
                    label: 'Имя',
                    hint: 'Иван Иванов',
                    icon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                  ).animate().fadeIn(duration: 350.ms, delay: 100.ms)
                      .slideY(begin: 0.08),

                  const SizedBox(height: 14),

                  // Email field (locked)
                  _LockedEmailField(email: widget.pendingData.email)
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 160.ms)
                      .slideY(begin: 0.08),

                  const SizedBox(height: 14),

                  // Phone field (optional)
                  _InputField(
                    controller: _phoneCtrl,
                    label: 'Телефон (необязательно)',
                    hint: '+7 (999) 000-00-00',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ).animate().fadeIn(duration: 350.ms, delay: 220.ms)
                      .slideY(begin: 0.08),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _error!),
                  ],

                  const SizedBox(height: 28),

                  _SubmitButton(
                    label: 'ПРОДОЛЖИТЬ',
                    onTap: _submit,
                  ).animate().fadeIn(duration: 350.ms, delay: 280.ms)
                      .slideY(begin: 0.08),

                  const SizedBox(height: 16),

                  const Text(
                    'Нажимая кнопку, вы соглашаетесь с условиями использования и политикой конфиденциальности',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.grey400,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 340.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerIcon() {
    if (widget.pendingData.provider == LoginProvider.google) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CustomPaint(painter: _GooglePainter()),
      );
    }
    return const Icon(Icons.apple, size: 22, color: AppColors.black);
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final LoginProvider provider;
  const _Header({required this.provider});

  @override
  Widget build(BuildContext context) {
    final label = provider == LoginProvider.google ? 'Google' : 'Apple';
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
                  onTap: () => Navigator.of(context).pop(),
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
              Text(
                'Создание аккаунта через $label',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF888888),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Locked email ─────────────────────────────────────────────────────────────

class _LockedEmailField extends StatelessWidget {
  final String email;
  const _LockedEmailField({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
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
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.grey100,
            border: Border.all(color: AppColors.grey200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 18, color: AppColors.grey400),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.grey600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Email привязан к аккаунту и не может быть изменён',
          style: TextStyle(fontSize: 11, color: AppColors.grey400),
        ),
      ],
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
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
              keyboardType: widget.keyboardType,
              textCapitalization: widget.textCapitalization,
              style: const TextStyle(fontSize: 15, color: AppColors.black),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    const TextStyle(color: AppColors.grey400, fontSize: 14),
                prefixIcon: Icon(
                  widget.icon,
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
                        color: AppColors.white, strokeWidth: 2),
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

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFFEA4335),
      const Color(0xFFFBBC05),
      const Color(0xFF34A853),
    ];
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.72),
        (i * 90 - 90) * (3.14159 / 180),
        90 * (3.14159 / 180),
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.22,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
