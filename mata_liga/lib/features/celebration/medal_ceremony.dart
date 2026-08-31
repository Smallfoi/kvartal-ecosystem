import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/kvartal_logo.dart';
import '../profile/data/badge_defs.dart';

/// Церемония получения медали — Вариант A «Duolingo»
/// (Ф1 «Праздник», утверждён владельцем 31.08.2026, 4.8 с).
///
/// Хореография: падение рубашкой вниз → squash-посадка → покачивание →
/// два нетерпеливых подпрыгивания с растущим свечением → упругий переворот
/// с перелётом → звёзды и осколки по контуру (никаких кругов и ударных волн) →
/// два радостных прыжка → блик. Тексты входят с перелётом.
Future<void> showMedalCeremony(
  BuildContext context, {
  required BadgeDef badge,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xF220252B),
    barrierLabel: 'Медаль',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => _MedalCeremony(badge: badge),
    transitionBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _MedalCeremony extends StatefulWidget {
  final BadgeDef badge;

  const _MedalCeremony({required this.badge});

  @override
  State<_MedalCeremony> createState() => _MedalCeremonyState();
}

class _MedalCeremonyState extends State<_MedalCeremony>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _haptics = <double>{};

  static const _lime = Color(0xFFDFF45F);
  static const _ink = Color(0xFF171C19);
  static const _light = Color(0xFFEDEFE8);
  static const _dim = Color(0xFF9AA59D);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    );
    _c.addListener(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  void _onTick() {
    void once(double at, VoidCallback fn) {
      if (_c.value >= at && !_haptics.contains(at)) {
        _haptics.add(at);
        fn();
      }
    }

    once(.11, HapticFeedback.heavyImpact); // посадка
    once(.30, HapticFeedback.lightImpact); // прыжок 1
    once(.44, HapticFeedback.lightImpact); // прыжок 2
    once(.58, HapticFeedback.mediumImpact); // переворот
    once(.68, HapticFeedback.heavyImpact); // взрыв звёзд
  }

  @override
  void dispose() {
    _c.removeListener(_onTick);
    _c.dispose();
    super.dispose();
  }

  double _p(double t, double a, double b, [Curve curve = Curves.easeOut]) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    return curve.transform((t - a) / (b - a));
  }

  /// Парабола прыжка: 0→1→0 с высотой h.
  double _hop(double t, double a, double b) {
    if (t <= a || t >= b) return 0;
    final x = (t - a) / (b - a);
    return 4 * x * (1 - x);
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_c.isAnimating) {
            _c.animateTo(1, duration: const Duration(milliseconds: 240));
          }
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;

            // Падение рубашкой и посадка.
            final drop = _p(t, 0, .11, Curves.easeInQuad);
            final squash = _hop(t, .11, .17);
            final wobble = t < .17 || t > .26
                ? 0.0
                : math.sin((t - .17) / .09 * math.pi * 2.4) *
                      (1 - _p(t, .17, .26, Curves.linear)) *
                      .062;

            // Нетерпеливые прыжки со свечением.
            final hop1 = _hop(t, .26, .37);
            final hop2 = _hop(t, .38, .51);
            var glow = _p(t, .26, .51) * .7;

            // Упругий переворот с перелётом: 0→96→196→174→180.
            final flipT = _p(t, .52, .68, Curves.easeInOut);
            double angle;
            if (flipT < .5) {
              angle = 96 * (flipT / .5);
            } else if (flipT < .78) {
              angle = 96 + 100 * ((flipT - .5) / .28);
            } else if (flipT < .92) {
              angle = 196 - 22 * ((flipT - .78) / .14);
            } else {
              angle = 174 + 6 * ((flipT - .92) / .08);
            }
            final rotY = angle * math.pi / 180;
            final faceUp = angle > 96;
            final flipLift = _hop(t, .52, .68) * 30;
            final flipSquash = flipT > .78 && flipT < .95
                ? math.sin((flipT - .78) / .17 * math.pi) * .05
                : 0.0;
            if (t >= .52) glow = .7 + _hop(t, .52, .72) * .3;
            if (t >= .78) glow = .7 * (1 - _p(t, .78, 1) * .5);

            // Радостные прыжки после переворота.
            final joy1 = _hop(t, .72, .81);
            final joy2 = _hop(t, .82, .9);

            // Взрыв и блик.
            final burst = _p(t, .64, .86, Curves.easeOut);
            final sheen = _p(t, .7, .84);

            // Тексты с перелётом.
            final titleIn = _p(t, .7, .8, Curves.easeOutBack);
            final reasonIn = _p(t, .76, .86, Curves.easeOutBack);
            final buttonIn = _p(t, .87, .98);

            final dy =
                -360 * (1 - drop) -
                hop1 * 24 -
                hop2 * 42 -
                flipLift -
                joy1 * 18 -
                joy2 * 10;
            final sx =
                1 + squash * .09 + hop1 * -.03 + hop2 * -.04 + flipSquash;
            final sy =
                1 - squash * .09 + hop1 * .04 + hop2 * .05 - flipSquash;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Осколки и звёзды — только формы, никаких кругов.
                if (burst > 0 && burst < 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _BurstPainter(progress: burst),
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Плита медали.
                    Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.rotate(
                        angle: wobble,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .0014)
                            ..rotateY(rotY)
                            ..scale(sx, sy),
                          child: _MedalPlate(
                            badge: badge,
                            faceUp: faceUp,
                            glow: glow,
                            sheen: sheen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    // Название.
                    Transform.translate(
                      offset: Offset(0, 14 * (1 - titleIn)),
                      child: Opacity(
                        opacity: titleIn.clamp(0, 1),
                        child: Text(
                          'Медаль «${badge.title}»',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontDisplay,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _light,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Transform.translate(
                      offset: Offset(0, 10 * (1 - reasonIn)),
                      child: Opacity(
                        opacity: reasonIn.clamp(0, 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 44),
                          child: Text(
                            badge.reason,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: _dim,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Opacity(
                      opacity: buttonIn.clamp(0, 1),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _lime,
                          foregroundColor: _ink,
                          minimumSize: const Size(190, 52),
                        ),
                        onPressed: buttonIn > .5
                            ? () => Navigator.of(context).pop()
                            : null,
                        child: const Text('Забрать'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Плита медали: рубашка — графит со знаком-контуром, лицо — лайм с эмблемой.
class _MedalPlate extends StatelessWidget {
  final BadgeDef badge;
  final bool faceUp;
  final double glow;
  final double sheen;

  const _MedalPlate({
    required this.badge,
    required this.faceUp,
    required this.glow,
    required this.sheen,
  });

  static const _lime = Color(0xFFDFF45F);
  static const _ink = Color(0xFF171C19);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(30);
    final content = faceUp
        // Лицо показывается в перевёрнутой фазе — зеркалим обратно.
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(color: _lime),
                  // Знак — гравировка-водяной знак.
                  Opacity(
                    opacity: .16,
                    child: CustomPaint(
                      size: const Size(96, 96),
                      painter: KvartalMarkPainter(
                        outline: _ink,
                        fill: _ink,
                        close: 1,
                      ),
                    ),
                  ),
                  Icon(badge.icon, size: 46, color: _ink),
                  // Блик после переворота — полоса света по лицу.
                  if (sheen > 0 && sheen < 1)
                    Positioned.fill(
                      child: FractionalTranslation(
                        translation: Offset(-1.2 + sheen * 2.4, 0),
                        child: Transform.rotate(
                          angle: -.5,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x00FFFFFF),
                                  Color(0x66FFFFFF),
                                  Color(0x00FFFFFF),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        // Рубашка: графит, знак-контур лаймом.
        : ClipRRect(
            borderRadius: radius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A302C),
                    borderRadius: radius,
                    border: Border.all(
                      color: const Color(0xFF3A423C),
                      width: 2,
                    ),
                  ),
                ),
                CustomPaint(
                  size: const Size(64, 64),
                  painter: KvartalMarkPainter(
                    outline: _lime,
                    fill: Colors.transparent,
                    close: 1,
                  ),
                ),
              ],
            ),
          );

    return Container(
      width: 138,
      height: 138,
      decoration: BoxDecoration(
        borderRadius: radius,
        // Свечение строго по контуру плиты — без кругов и волн.
        boxShadow: glow > 0.01
            ? [
                BoxShadow(
                  color: _lime.withValues(alpha: .55 * glow),
                  blurRadius: 26 * glow,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: content,
    );
  }
}

/// Звёзды-искры (4 луча) и прямоугольные осколки, разлетающиеся от контура.
class _BurstPainter extends CustomPainter {
  final double progress;

  const _BurstPainter({required this.progress});

  static const _lime = Color(0xFFDFF45F);
  static const _light = Color(0xFFEDEFE8);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 96);
    final fade = (1 - progress).clamp(0.0, 1.0);

    // 8 звёзд по направлениям от плиты.
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + .32;
      final dist = 62 + 74 * Curves.easeOut.transform(progress) + i % 3 * 9;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final r = (5.5 - i % 3 * 1.2) * (1 - progress * .4);
      _star(canvas, pos, r, angle + progress * 2.4,
          Paint()..color = _lime.withValues(alpha: .95 * fade));
    }

    // 6 осколков-прямоугольников.
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 + .9;
      final dist = 48 + 96 * Curves.easeOut.transform(progress) + i % 2 * 14;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + progress * 3.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-1.6, -4.5, 3.2, 9),
          const Radius.circular(1.2),
        ),
        Paint()
          ..color = (i.isEven ? _light : _lime).withValues(alpha: .85 * fade),
      );
      canvas.restore();
    }
  }

  void _star(Canvas canvas, Offset c, double r, double rot, Paint paint) {
    final path = Path();
    for (var k = 0; k < 8; k++) {
      final rad = k.isEven ? r : r * .38;
      final a = rot + k * math.pi / 4;
      final p = c + Offset(math.cos(a), math.sin(a)) * rad;
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
