import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/kvartal_logo.dart';
import '../../auth/data/auth_provider.dart';

/// Заставка «Захват» (Вариант 2 дизайн-проекта 24d1c230, утверждён 2026-08-23).
///
/// Единая графитовая сцена с нативным сплэшем (#2A302C — тот же цвет): знак
/// стоит ровно как системная сплэш-иконка, бегун на глазах дорисовывает
/// последний метр, петля замыкается — вспышка по контуру, «КВАРТАЛ».
/// Хореография — сам смысл игры: замкни маршрут, забери квартал.
///
/// Против «склейки» (замечания владельца 2026-08-23):
/// 1) системный сплэш — ЧИСТЫЙ графит без иконки: OEM-зум плитки лаунчера
///    кроссфейдился с системной иконкой в другой позиции — был «двойник»
///    знака; теперь плитка растворяется в графит, и знак рождается уже здесь;
/// 2) анимация стартует только после первого отрисованного кадра — ничего не
///    проигрывается вслепую под системным сплэшем. Уважает reduced motion.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF2A302C); // ровно как нативный splash_background
  static const _light = Color(0xFFEDEFE8);
  static const _limeBright = Color(0xFFDFF45F);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  // Знак рождается из графита: сначала ~360мс чистого фона (OEM-зум плитки
  // лаунчера успевает раствориться — иначе видны два знака), затем рост.
  late final Animation<double> _appear = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.15, 0.29, curve: Curves.easeOutCubic),
  );

  // Бегун срывается с места и добегает последний метр — петля замыкается.
  late final Animation<double> _close = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.33, 0.55, curve: Curves.easeInOutCubic),
  );

  // Короткая вспышка свечения по контуру знака в момент захвата
  // (Вариант 2 дизайн-проекта 24d1c230: без пульса и кругов).
  late final Animation<double> _flash = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.35), weight: 70),
  ]).animate(CurvedAnimation(
    parent: _c,
    curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
  ));

  late final Animation<double> _title = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.58, 0.74, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _tagline = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.66, 0.84, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    // Старт строго после первого показанного кадра: первый видимый кадр
    // Flutter = чистый графит (как системный сплэш), всё идёт на глазах.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.forward();
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        final auth = ref.read(authProvider);
        context.go(
          auth.status == AuthStatus.authenticated ? '/map' : '/auth/phone',
        );
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final markSize = MediaQuery.of(context).size.width * 0.44;

    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final appear = reduceMotion ? 1.0 : _appear.value;
            final close = reduceMotion ? 1.0 : _close.value;
            final flash = reduceMotion ? 0.0 : _flash.value;
            final title = reduceMotion ? 1.0 : _title.value;
            final tagline = reduceMotion ? 1.0 : _tagline.value;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Знак рождается из графита и живёт: маршрут, вспышка захвата.
                SizedBox(
                  width: markSize,
                  height: markSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Вспышка строго по форме знака (рамка со скруглением),
                      // никаких кругов — Вариант 2 утверждённого дизайна.
                      if (flash > 0.01)
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.all(markSize * (9 / 48)),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  markSize * (9 / 48),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _limeBright.withValues(
                                      alpha: 0.42 * flash,
                                    ),
                                    blurRadius: markSize * 0.30,
                                    spreadRadius: markSize * 0.02,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Opacity(
                        opacity: appear,
                        child: Transform.scale(
                          scale: 0.72 + 0.28 * appear,
                          child: CustomPaint(
                            size: Size.square(markSize),
                            painter: KvartalMarkPainter(
                              outline: _light,
                              fill: _limeBright,
                              close: close,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),

                // «КВАРТАЛ» — собирается из разреженных букв в момент захвата
                // (трекинг съезжается, как в утверждённом дизайне).
                Opacity(
                  opacity: title,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - title)),
                    child: Text(
                      'КВАРТАЛ',
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: _light,
                        letterSpacing: 2 + 12 * (1 - title),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: tagline,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - tagline)),
                    child: const Text(
                      'Замкни маршрут. Забери квартал.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9AA59D),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
