import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../theme/app_theme.dart';
import '../../widgets/mata_logo.dart';
import '../../widgets/remote_text.dart';

/// Сплэш запуска: фирменный ролик Higgsfield — знак МАТА собирается из
/// лаймовых лучей на тёмном фоне (сгенерирован владельцем 2026-08-21,
/// исходник в brand/higgsfield). Ролик 5 с играет с ускорением ×1.9
/// (≈2.6 с — владелец просил 1–2 с), тексты появляются после сборки знака,
/// уход в приложение — белым фейдом.
///
/// Fallback (ролик не инициализировался или включён reduced-motion):
/// статичная словомарка 0.9–1.2 с без движения.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _speed = 1.9;
  static const _textsAtMs = 1550; // сборка знака в ролике завершена (~2.9s/1.9)
  static const _fadeAtMs = 2250; // старт белого фейда
  static const _doneAtMs = 2650; // переход в приложение

  VideoPlayerController? _video;
  Timer? _textsTimer;
  Timer? _fadeTimer;
  Timer? _doneTimer;
  bool _showTexts = false;
  bool _fading = false;
  bool _fallback = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    // Reduced motion уважаем: без ролика, статичный знак и короткая пауза.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _startFallback(const Duration(milliseconds: 900));
      } else {
        _startVideo();
      }
    });
  }

  Future<void> _startVideo() async {
    final v = VideoPlayerController.asset('assets/video/splash_sign.mp4');
    _video = v;
    try {
      await v.initialize();
      await v.setVolume(0);
      await v.setPlaybackSpeed(_speed);
      if (!mounted) return;
      setState(() {}); // показать первый кадр
      await v.play();
      _textsTimer = Timer(const Duration(milliseconds: _textsAtMs), () {
        if (mounted) setState(() => _showTexts = true);
      });
      _fadeTimer = Timer(const Duration(milliseconds: _fadeAtMs), () {
        if (mounted) setState(() => _fading = true);
      });
      _doneTimer = Timer(const Duration(milliseconds: _doneAtMs), _finish);
    } catch (_) {
      // Эмулятор/старое устройство без кодека — не держим пользователя.
      _startFallback(const Duration(milliseconds: 1200));
    }
  }

  void _startFallback(Duration hold) {
    if (!mounted) return;
    setState(() {
      _fallback = true;
      _showTexts = true;
    });
    _doneTimer = Timer(hold, _finish);
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _textsTimer?.cancel();
    _fadeTimer?.cancel();
    _doneTimer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    final videoReady = !_fallback && v != null && v.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Ролик на весь экран (центр-кроп: знак в центре кадра) ──
            if (videoReady)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: v.value.size.width,
                  height: v.value.size.height,
                  child: VideoPlayer(v),
                ),
              )
            else if (_fallback)
              Center(
                child: MataLogo(
                  width: 210,
                  color: const Color(0xFFE9EAE5),
                  accent: AppColors.lime,
                ),
              ),

            // ── Тексты поверх: слоган + теглайн (после сборки знака) ──
            Align(
              alignment: const Alignment(0, 0.62),
              child: AnimatedOpacity(
                opacity: _showTexts ? 1 : 0,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RemoteText(
                      'app.splash.brand2',
                      'Комфорт, который двигает вперёд',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.robotoSerif(
                        fontSize: 17,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w200,
                        color: AppColors.lavender,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const RemoteText(
                      'app.splash.tagline',
                      'СПОРТИВНАЯ ОДЕЖДА И ЭКИПИРОВКА',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF9BA39C),
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Белый фейд-переход в приложение ──
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _fading ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeIn,
                child: Container(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
