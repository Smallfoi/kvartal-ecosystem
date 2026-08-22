import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/kvartal_logo.dart';
import '../../../../shared/widgets/phone_mask.dart';
import '../../../profile/data/legal_provider.dart';
import '../../../profile/presentation/screens/legal_documents_screen.dart';
import '../../data/auth_provider.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phoneCtrl = PhoneMaskController(hintColor: AppColors.textDisabled);
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _mode = 'login'; // login | register | reset

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _phoneOk => _phoneCtrl.text.replaceAll(RegExp(r'\D'), '').length == 10;
  String get _phone => '+7${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}';

  void _setMode(String m) => setState(() {
        _mode = m;
        _passCtrl.clear();
      });

  Future<void> _submit() async {
    final auth = ref.read(authProvider.notifier);
    if (_mode == 'login') {
      if (!_phoneOk || _passCtrl.text.isEmpty) return;
      final ok = await auth.loginByPassword(_phone, _passCtrl.text);
      if (!ok || !mounted) return;
      // Роутер намеренно не уводит с /auth (гейт согласия решается здесь),
      // поэтому навигируем сами — как OTP-экран.
      var toConsent = false;
      final token = ref.read(authProvider).token;
      if (token != null) {
        try {
          final docs = await fetchLegalDocs(token: token);
          toConsent = pendingRequired(docs).isNotEmpty;
        } catch (_) {}
      }
      if (mounted) context.go(toConsent ? '/auth/consent' : '/map');
      return;
    }
    if (!_phoneOk || _passCtrl.text.length < 4) return;
    if (_mode == 'register' && _nameCtrl.text.trim().isEmpty) return;
    auth.setPending(purpose: _mode, name: _nameCtrl.text.trim(), password: _passCtrl.text);
    await auth.sendCode(_phone);
    if (mounted) context.go('/auth/otp');
  }

  Widget _fieldBox({required Widget child}) => Container(
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgElevated),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.isLoading;
    final canSubmit = _mode == 'login'
        ? (_phoneOk && _passCtrl.text.isNotEmpty)
        : (_phoneOk &&
            _passCtrl.text.length >= 4 &&
            (_mode != 'register' || _nameCtrl.text.trim().isNotEmpty));

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const KvartalLogoMark(size: 58, outline: Color(0xFFEDEFE8)),
              const SizedBox(height: 18),
              Text(
                'КВАРТАЛ',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == 'login'
                    ? 'Вход по телефону и паролю'
                    : _mode == 'register'
                        ? 'Регистрация'
                        : 'Сброс пароля',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              if (_mode == 'register')
                _fieldBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _nameCtrl,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Имя',
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              _fieldBox(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: AppColors.bgElevated)),
                      ),
                      child: Text('+7',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: const [PhoneMaskFormatter()],
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, letterSpacing: 2),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              _fieldBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: _mode == 'reset' ? 'Новый пароль' : 'Пароль',
                      hintStyle: TextStyle(color: AppColors.textDisabled),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 13)),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: canSubmit && !isLoading ? _submit : null,
                  child: isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_mode == 'login' ? 'Войти' : 'Получить SMS-код',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              if (_mode == 'login') ...[
                Center(child: TextButton(onPressed: () => _setMode('register'), child: const Text('Нет аккаунта? Регистрация', style: TextStyle(color: AppColors.accentBlue)))),
                Center(child: TextButton(onPressed: () => _setMode('reset'), child: const Text('Забыл пароль?', style: TextStyle(color: AppColors.textSecondary)))),
              ] else
                Center(child: TextButton(onPressed: () => _setMode('login'), child: const Text('Уже есть аккаунт? Войти', style: TextStyle(color: AppColors.accentBlue)))),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LegalDocumentsScreen()),
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Условия использования и документы',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textDisabled,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
