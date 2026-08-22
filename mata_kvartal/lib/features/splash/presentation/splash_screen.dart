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
/// Против «склейки» (замечание владельца 2026-08-23): анимация стартует ТОЛЬКО
/// после первого отрисованного кадра (иначе под системным сплэшем вслепую
/// проигрывается начало, и первый видимый кадр Flutter ловится с бегуном уже
/// в пути — виден обрыв). Масштабных скачков нет: знак сразу в размере,
/// совпадающем с системной иконкой. Уважает reduced motion.
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
    duration: const Duration(milliseconds: 2200),
  );

  // Бегун срывается с места и добегает последний метр — петля замыкается.
  late final Animation<double> _close = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.14, 0.40, curve: Curves.easeInOutCubic),
  );

  // Короткая вспышка свечения по контуру знака в момент захвата
  // (Вариант 2 дизайн-проекта 24d1c230: без пульса и кругов).
  late final Animation<double> _flash = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.35), weight: 70),
  ]).animate(CurvedAnimation(
    parent: _c,
    curve: const Interval(0.40, 0.70, curve: Curves.easeOut),
  ));

  late final Animation<double> _title = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.48, 0.66, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _tagline = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.56, 0.76, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    // Старт строго после первого показанного кадра: первый видимый кадр
    // Flutter = системная сплэш-иконка (close 0), анимация идёт на глазах.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _c.forward();
      Future.delayed(const Duration(milliseconds: 2300), () {
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
            final close = reduceMotion ? 1.0 : _close.value;
            final flash = reduceMotion ? 0.0 : _flash.value;
            final title = reduceMotion ? 1.0 : _title.value;
            final tagline = reduceMotion ? 1.0 : _tagline.value;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Знак: свечение захвата + рисующийся маршрут.
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
                      CustomPaint(
                        size: Size.square(markSize),
                        painter: KvartalMarkPainter(
                          outline: _light,
                          fill: _limeBright,
                          close: close,
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
