import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import 'mata_logo.dart';

/// Виртуальная карта лояльности МАТА с 3D-переворотом (эталон владельца
/// «Payment Card Flip», payment-card-flip-animation-recipe).
///
/// Лицо — баллы и уровень, оборот — QR для кассы. Переворот по тапу:
/// два слоя, перспектива на родителе, кривая с перелётом за 180° и
/// докруткой (Cubic(.34,1.4,.5,1) — как в эталоне), смена грани на 90°.
/// Лаймовое свечение усиливается в середине переворота.
class LoyaltyCard3D extends StatefulWidget {
  final int balance;
  final String levelLabel;
  final String holderName;
  final String qrData;

  const LoyaltyCard3D({
    super.key,
    required this.balance,
    required this.levelLabel,
    required this.holderName,
    required this.qrData,
  });

  @override
  State<LoyaltyCard3D> createState() => _LoyaltyCard3DState();
}

class _LoyaltyCard3DState extends State<LoyaltyCard3D>
    with SingleTickerProviderStateMixin {
  // Кривая эталона: перелёт за конечную точку и упругая докрутка.
  static const _flipCurve = Cubic(0.34, 1.4, 0.5, 1.0);

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  bool _showingBack = false;

  void _flip() {
    if (MediaQuery.of(context).disableAnimations) {
      // Reduced motion: мгновенная смена грани без вращения.
      setState(() {
        _showingBack = !_showingBack;
        _ctrl.value = _showingBack ? 1 : 0;
      });
      return;
    }
    if (_showingBack) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    _showingBack = !_showingBack;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.of(context).size.width - 40, 360.0);
    final height = width / 1.586; // ISO ID-1 — пропорция реальной карты

    return Semantics(
      button: true,
      label: _showingBack
          ? 'Карта лояльности, QR-код. Нажми, чтобы вернуть баллы'
          : 'Карта лояльности, ${widget.balance} баллов. Нажми — QR для кассы',
      child: GestureDetector(
        onTap: _flip,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _flipCurve.transform(_ctrl.value);
            final angle = t * math.pi;
            final showBack = angle > math.pi / 2;
            // Свечение — пик в середине переворота (эталон: пульс при действии).
            final glow = 0.35 + 0.45 * math.sin(math.pi * _ctrl.value);

            return Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: glow * 0.55),
                    blurRadius: 34,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Transform(
                alignment: Alignment.center,
                // Перспектива обязана быть в той же матрице (родителя у нас нет).
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateY(angle),
                child: showBack
                    // Оборот рисуем дозеркаленным, чтобы после rotateY(π)
                    // он читался слева направо.
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _CardBack(
                          qrData: widget.qrData,
                          holderName: widget.holderName,
                        ),
                      )
                    : _CardFace(
                        balance: widget.balance,
                        levelLabel: widget.levelLabel,
                        holderName: widget.holderName,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Лицо: словомарка, баллы, уровень, держатель ─────────────────────────────

class _CardFace extends StatelessWidget {
  final int balance;
  final String levelLabel;
  final String holderName;

  const _CardFace({
    required this.balance,
    required this.levelLabel,
    required this.holderName,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MataLogo(
                width: 74,
                color: const Color(0xFFE9EAE5),
                accent: AppColors.lime,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.lime, width: 1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  levelLabel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lime,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$balance',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'баллов',
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ДЕРЖАТЕЛЬ',
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.6,
                        color: Color(0xFF8B929B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      holderName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'ЕДИНАЯ КАРТА',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 1.6,
                  color: Color(0xFF8B929B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Оборот: QR для кассы ────────────────────────────────────────────────────

class _CardBack extends StatelessWidget {
  final String qrData;
  final String holderName;

  const _CardBack({required this.qrData, required this.holderName});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(height: 30, color: const Color(0xFF101317)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ПОКАЖИ НА КАССЕ',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.8,
                            color: AppColors.lime,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Баллы спишутся\nсо счёта $holderName',
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            color: Color(0xFF9AA0A8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 96,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Общая «болванка» карты: градиент графита + скругление ───────────────────

class _CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _CardShell({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF262C33), Color(0xFF14181D), Color(0xFF0C0F13)],
        ),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: child,
    );
  }
}
