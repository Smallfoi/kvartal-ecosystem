import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';

const kvartalLogoAsset = 'assets/brand/kvartal-logo-transparent.png';

class KvartalLogoMark extends StatelessWidget {
  final double size;
  final bool animated;
  final bool glow;

  const KvartalLogoMark({
    super.key,
    this.size = 44,
    this.animated = true,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget logo = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glow)
            Container(
              width: size * 0.78,
              height: size * 0.78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.warning.withValues(alpha: 0.22),
                    blurRadius: size * 0.32,
                    spreadRadius: size * 0.02,
                  ),
                ],
              ),
            ),
          Image.asset(
            kvartalLogoAsset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ],
      ),
    );

    if (!animated) return logo;

    return logo
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(
          begin: 0.985,
          end: 1.035,
          duration: 1800.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .custom(
          duration: 2400.ms,
          curve: Curves.easeInOut,
          builder: (context, value, child) => Transform.rotate(
            angle: math.sin(value * math.pi * 2) * 0.018,
            child: child,
          ),
        );
  }
}

class KvartalLogoBadge extends StatelessWidget {
  final double size;
  final bool showText;
  final EdgeInsetsGeometry padding;

  const KvartalLogoBadge({
    super.key,
    this.size = 34,
    this.showText = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KvartalLogoMark(size: size, glow: false),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            'КВАРТАЛ',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}
