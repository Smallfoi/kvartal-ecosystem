import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Тип анимации фона по WMO-коду (тот же код, что в WeatherData.weatherCode).
enum _Kind { sun, cloud, fog, rain, snow, storm }

_Kind _kindOf(int code) {
  if (code == 0 || code == 1) return _Kind.sun;
  if (code == 45 || code == 48) return _Kind.fog;
  if (code >= 71 && code <= 77) return _Kind.snow;
  if (code == 85 || code == 86) return _Kind.snow;
  if (code >= 95) return _Kind.storm;
  if (code >= 51 && code <= 67) return _Kind.rain;
  if (code >= 80 && code <= 82) return _Kind.rain;
  return _Kind.cloud; // 2,3 и всё прочее — облачно
}

/// Живой анимированный фон-«штрих» для шапки погоды: небо по условию + движение
/// (солнце с лучами, дрейфующие облака, дождь, снег, туман, гроза). Без пакетов —
/// CustomPainter + один AnimationController (зацикленный).
class WeatherBackground extends StatefulWidget {
  final int weatherCode;
  final double height;
  const WeatherBackground({super.key, required this.weatherCode, this.height = 150});

  @override
  State<WeatherBackground> createState() => _WeatherBackgroundState();
}

class _WeatherBackgroundState extends State<WeatherBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kindOf(widget.weatherCode);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _WeatherPainter(kind: kind, t: _c.value),
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final _Kind kind;
  final double t; // 0..1, зациклено
  _WeatherPainter({required this.kind, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    switch (kind) {
      case _Kind.sun:
        _paintSun(canvas, size);
        _paintClouds(canvas, size, count: 1, opacity: 0.6);
        break;
      case _Kind.cloud:
        _paintClouds(canvas, size, count: 3, opacity: 0.9);
        break;
      case _Kind.fog:
        _paintFog(canvas, size);
        break;
      case _Kind.rain:
        _paintClouds(canvas, size, count: 2, opacity: 0.85);
        _paintRain(canvas, size);
        break;
      case _Kind.snow:
        _paintClouds(canvas, size, count: 2, opacity: 0.7);
        _paintSnow(canvas, size);
        break;
      case _Kind.storm:
        _paintClouds(canvas, size, count: 2, opacity: 0.95);
        _paintRain(canvas, size);
        _paintLightning(canvas, size);
        break;
    }
  }

  // ── небо (градиент по условию) ──────────────────────────────────────────
  void _paintSky(Canvas canvas, Size size) {
    final colors = switch (kind) {
      _Kind.sun => [const Color(0xFF2E6DB4), const Color(0xFF6FB1E8)],
      _Kind.cloud => [const Color(0xFF3A4452), const Color(0xFF6E7B8C)],
      _Kind.fog => [const Color(0xFF4A535F), const Color(0xFF818B97)],
      _Kind.rain => [const Color(0xFF2C3744), const Color(0xFF55657A)],
      _Kind.snow => [const Color(0xFF394656), const Color(0xFF7E90A6)],
      _Kind.storm => [const Color(0xFF1E232C), const Color(0xFF3C4654)],
    };
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
  }

  // ── солнце с медленно вращающимися лучами ───────────────────────────────
  void _paintSun(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.80, size.height * 0.40);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFF3C4), const Color(0x00FFF3C4)],
      ).createShader(Rect.fromCircle(center: c, radius: 70));
    canvas.drawCircle(c, 70, glow);
    final ray = Paint()
      ..color = const Color(0xFFFFE08A).withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final a = t * 2 * math.pi + i * math.pi / 6;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * 30;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * 42;
      canvas.drawLine(p1, p2, ray);
    }
    canvas.drawCircle(c, 22, Paint()..color = const Color(0xFFFFD75E));
  }

  // ── облака, дрейфующие по горизонтали ───────────────────────────────────
  void _paintClouds(Canvas canvas, Size size, {required int count, double opacity = 0.9}) {
    for (int i = 0; i < count; i++) {
      final phase = (t + i / count) % 1.0;
      final x = phase * (size.width + 160) - 80;
      final y = size.height * (0.30 + 0.18 * i) % size.height;
      _cloud(canvas, Offset(x, y), 0.9 - i * 0.12,
          Colors.white.withValues(alpha: opacity * (0.85 - i * 0.15)));
    }
  }

  void _cloud(Canvas canvas, Offset at, double s, Color color) {
    final p = Paint()..color = color;
    canvas.drawCircle(at + Offset(-24 * s, 6 * s), 16 * s, p);
    canvas.drawCircle(at + Offset(0, -4 * s), 22 * s, p);
    canvas.drawCircle(at + Offset(26 * s, 6 * s), 17 * s, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx - 36 * s, at.dy + 6 * s, 72 * s, 16 * s),
        Radius.circular(12 * s),
      ),
      p,
    );
  }

  // ── дождь (падающие штрихи) ─────────────────────────────────────────────
  void _paintRain(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFBFE0FF).withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const n = 26;
    for (int i = 0; i < n; i++) {
      final col = (i / n) * size.width + (i.isEven ? 6 : 0);
      final fall = ((t * 2) + i * 0.13) % 1.0;
      final y = fall * size.height;
      canvas.drawLine(Offset(col, y), Offset(col - 4, y + 12), p);
    }
  }

  // ── снег (падающие снежинки с дрейфом) ──────────────────────────────────
  void _paintSnow(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
    const n = 22;
    for (int i = 0; i < n; i++) {
      final baseX = (i / n) * size.width;
      final fall = ((t * 1.2) + i * 0.16) % 1.0;
      final y = fall * size.height;
      final x = baseX + math.sin((fall + i) * 2 * math.pi) * 8;
      canvas.drawCircle(Offset(x, y), i.isEven ? 2.4 : 1.6, p);
    }
  }

  // ── туман (горизонтальные полосы) ───────────────────────────────────────
  void _paintFog(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.16);
    for (int i = 0; i < 4; i++) {
      final phase = (t + i / 4) % 1.0;
      final x = phase * 80 - 40;
      final y = size.height * (0.25 + i * 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, size.width * 0.9, 10),
          const Radius.circular(8),
        ),
        p,
      );
    }
  }

  // ── гроза (вспышка молнии) ──────────────────────────────────────────────
  void _paintLightning(Canvas canvas, Size size) {
    // короткая вспышка дважды за цикл
    final flash = math.max(0.0, math.sin(t * 4 * math.pi));
    if (flash < 0.85) return;
    final o = (flash - 0.85) / 0.15;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.25 * o),
    );
    final p = Paint()
      ..color = const Color(0xFFFFF6B0).withValues(alpha: o)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x = size.width * 0.5;
    final path = Path()
      ..moveTo(x, size.height * 0.25)
      ..lineTo(x - 10, size.height * 0.5)
      ..lineTo(x + 6, size.height * 0.5)
      ..lineTo(x - 8, size.height * 0.8);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter old) =>
      old.t != t || old.kind != kind;
}
