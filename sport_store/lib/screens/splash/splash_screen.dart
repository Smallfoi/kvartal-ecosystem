import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  // Один контроллер — все анимации синхронизированы
  late final AnimationController _ctrl;

  // Линия: вырастает из центра
  late final Animation<double> _lineScale;

  // Слова: SPORT слева, STORE справа → летят к центру
  late final Animation<double> _wordSlide;   // 1.0 → 0.0
  late final Animation<double> _wordFade;    // 0.0 → 1.0

  // Удар: лёгкий scale-пульс после прилёта слов
  late final Animation<double> _impactScale;

  // Тэглайн
  late final Animation<double> _taglineFade;

  // Вспышка на линии (яркий всплеск перед уходом)
  late final Animation<double> _flash;

  // Белый оверлей (переход к приложению)
  late final Animation<double> _overlayFade;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // ─ Линия: 0–480ms ─────────────────────────────────────────────────────
    _lineScale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.00, 0.185, curve: Curves.easeInOut),
    );

    // ─ Слова: 80–680ms ────────────────────────────────────────────────────
    _wordSlide = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.03, 0.26, curve: Curves.easeOutCubic),
      ),
    );
    _wordFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.03, 0.20, curve: Curves.easeOut),
    );

    // ─ Удар: 680–900ms ────────────────────────────────────────────────────
    _impactScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.035), weight: 35),
      TweenSequenceItem(
        tween: Tween(begin: 1.035, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 65,
      ),
    ]).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.26, 0.40, curve: Curves.easeOut),
    ));

    // ─ Тэглайн: 780–1100ms ────────────────────────────────────────────────
    _taglineFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.30, 0.44, curve: Curves.easeOut),
    );

    // ─ Вспышка линии: 1700–2000ms ─────────────────────────────────────────
    _flash = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
    ]).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.65, 0.80, curve: Curves.easeInOut),
    ));

    // ─ Белый оверлей: 2050–2600ms ─────────────────────────────────────────
    _overlayFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.79, 1.0, curve: Curves.easeIn),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onComplete();
      }
    });

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              // ── Контент ────────────────────────────────────────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Transform.scale(
                    scale: _impactScale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // SPORT → влетает слева
                        ClipRect(
                          child: Transform.translate(
                            offset: Offset(-sw * _wordSlide.value, 0),
                            child: Opacity(
                              opacity: _wordFade.value,
                              child: Text(
                                'SPORT',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.oswald(
                                  fontSize: 88,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 12,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Линия + вспышка
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scaleX: _lineScale.value,
                              child: Container(
                                height: 1.5,
                                color: Colors.white,
                              ),
                            ),
                            if (_flash.value > 0)
                              Opacity(
                                opacity: (_flash.value * 0.9).clamp(0.0, 1.0),
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white
                                            .withValues(alpha: _flash.value * 0.8),
                                        blurRadius: 18,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // STORE → влетает справа
                        ClipRect(
                          child: Transform.translate(
                            offset: Offset(sw * _wordSlide.value, 0),
                            child: Opacity(
                              opacity: _wordFade.value,
                              child: Text(
                                'STORE',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.oswald(
                                  fontSize: 88,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 12,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Тэглайн
                        Opacity(
                          opacity: _taglineFade.value,
                          child: const Text(
                            'СПОРТИВНАЯ ОДЕЖДА И ЭКИПИРОВКА',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF777777),
                              letterSpacing: 3.0,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),

                        const SizedBox(height: 56),

                        // Прогресс-линия внизу
                        Opacity(
                          opacity: _taglineFade.value,
                          child: _ProgressLine(progress: _ctrl.value),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Белый оверлей (переход) ────────────────────────────────
              if (_overlayFade.value > 0)
                Opacity(
                  opacity: _overlayFade.value,
                  child: Container(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Тонкая прогресс-линия внизу ─────────────────────────────────────────────

class _ProgressLine extends StatelessWidget {
  final double progress;
  const _ProgressLine({required this.progress});

  @override
  Widget build(BuildContext context) {
    // Нормализуем прогресс к зоне загрузки (0.30 → 0.79)
    final p = ((progress - 0.30) / (0.79 - 0.30)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (_, constraints) {
        return Stack(
          children: [
            Container(
              height: 1,
              color: const Color(0xFF222222),
            ),
            Container(
              height: 1,
              width: constraints.maxWidth * p,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF555555), Colors.white],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
