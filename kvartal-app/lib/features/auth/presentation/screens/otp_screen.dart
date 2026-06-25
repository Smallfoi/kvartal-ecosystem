import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  int _secondsLeft = 60;
  Timer? _timer;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _localError = null);
    final success = await ref
        .read(authProvider.notifier)
        .verifyCode(_controller.text);
    if (success && mounted) {
      context.go('/map');
      return;
    }
    if (!success && mounted) {
      setState(() {
        _localError = ref.read(authProvider).error;
        _controller.clear();
      });
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    final phone = ref.read(authProvider).phone;
    await ref.read(authProvider.notifier).sendCode(phone);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth/phone'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Введи код',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SMS отправлено на ${auth.phone}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              _OtpBoxes(
                controller: _controller,
                focus: _focus,
                hasError: _localError != null,
                onComplete: _verify,
              ),
              if (_localError != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _localError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (auth.isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.electricBlue,
                  ),
                )
              else if (_secondsLeft > 0)
                Center(
                  child: Text(
                    'Отправить снова через $_secondsLeft с',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                Center(
                  child: TextButton(
                    onPressed: _resend,
                    child: const Text('Отправить снова'),
                  ),
                ),
              const Spacer(),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.bgElevated),
                  ),
                  child: const Text(
                    'Тестовый код: 1234',
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBoxes extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool hasError;
  final VoidCallback onComplete;

  const _OtpBoxes({
    required this.controller,
    required this.focus,
    required this.hasError,
    required this.onComplete,
  });

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.focus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Скрытый input
          SizedBox(
            width: 0,
            height: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focus,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              autofocus: true,
              onChanged: (v) {
                setState(() {});
                if (v.length == 4) widget.onComplete();
              },
            ),
          ),
          // Визуальные ячейки
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final char = i < widget.controller.text.length
                  ? widget.controller.text[i]
                  : null;
              final isCurrent = i == widget.controller.text.length;

              return Container(
                width: 60,
                height: 72,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.hasError
                        ? AppColors.error
                        : isCurrent
                        ? AppColors.electricBlue
                        : char != null
                        ? AppColors.electricBlue.withValues(alpha: 0.4)
                        : AppColors.bgElevated,
                    width: (isCurrent || char != null) ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: char != null
                    ? Text(
                        char,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: widget.hasError
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      )
                    : isCurrent
                    ? Container(
                        width: 2,
                        height: 28,
                        color: AppColors.electricBlue,
                      )
                    : null,
              );
            }),
          ),
        ],
      ),
    );
  }
}
