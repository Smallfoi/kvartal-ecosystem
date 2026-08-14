import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/kvartal_logo.dart';
import '../../auth/data/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      final auth = ref.read(authProvider);
      context.go(
        auth.status == AuthStatus.authenticated ? '/map' : '/auth/phone',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(child: _KvartalSplashContent()),
    );
  }
}

class _KvartalSplashContent extends StatelessWidget {
  const _KvartalSplashContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const KvartalLogoMark(size: 112, glow: true)
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scaleXY(
              begin: 1.0,
              end: 1.045,
              duration: 1500.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 30),
        const Text(
              'КВАРТАЛ',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
              ),
            )
            .animate()
            .fadeIn(delay: 220.ms, duration: 420.ms)
            .slideY(
              begin: 0.18,
              end: 0,
              delay: 220.ms,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: 8),
        Text(
              'Твой город. Твой маршрут.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
                letterSpacing: 1.2,
              ),
            )
            .animate()
            .fadeIn(delay: 430.ms, duration: 420.ms)
            .slideY(
              begin: 0.16,
              end: 0,
              delay: 430.ms,
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            ),
        const SizedBox(height: 68),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .scaleXY(
                  begin: 0.45,
                  end: 1.12,
                  duration: 580.ms,
                  delay: Duration(milliseconds: i * 150),
                  curve: Curves.easeInOut,
                )
                .then()
                .scaleXY(
                  begin: 1.12,
                  end: 0.45,
                  duration: 580.ms,
                  curve: Curves.easeInOut,
                );
          }),
        ).animate().fadeIn(delay: 620.ms, duration: 300.ms),
      ],
    );
  }
}
