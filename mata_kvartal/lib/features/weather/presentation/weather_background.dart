import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Время суток + фаза луны (общий источник правды) ─────────────────────────

/// Фаза суток по МЕСТНОМУ времени устройства: рассвет / день / закат / ночь.
enum WeatherPhase { dawn, day, dusk, night }

/// Реальные восход/закат (часы, местное время) по солнечному уравнению.
/// Раньше фазы были захардкожены («закат 18–21») — владелец заметил закатную
/// сцену засветло: в Якутске летом солнце садится около 20:00, зимой в 15:00.
/// Координаты по умолчанию — Якутск; точность пары минут сцене достаточна.
({double sunriseH, double sunsetH}) sunTimes({
  double lat = 62.03,
  double lon = 129.73,
  DateTime? when,
}) {
  final d = when ?? DateTime.now();
  final n = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
  final decl =
      -23.44 * math.cos(2 * math.pi / 365 * (n + 10)) * math.pi / 180;
  final phi = lat * math.pi / 180;
  final cosw = -math.tan(phi) * math.tan(decl);
  if (cosw <= -1) return (sunriseH: 0, sunsetH: 24); // полярный день
  if (cosw >= 1) return (sunriseH: 12, sunsetH: 12); // полярная ночь
  final w = math.acos(cosw) * 180 / math.pi / 15; // полудлина дня в часах
  final tz = d.timeZoneOffset.inMinutes / 60.0;
  final solarNoon = 12 - lon / 15 + tz;
  return (sunriseH: solarNoon - w, sunsetH: solarNoon + w);
}

WeatherPhase phaseNow() {
  final now = DateTime.now();
  final h = now.hour + now.minute / 60.0;
  final sun = sunTimes(when: now);
  const edge = 0.7; // ±40 минут вокруг восхода/заката — золотой час
  if ((h - sun.sunriseH).abs() <= edge) return WeatherPhase.dawn;
  if ((h - sun.sunsetH).abs() <= edge) return WeatherPhase.dusk;
  if (h > sun.sunriseH && h < sun.sunsetH) return WeatherPhase.day;
  return WeatherPhase.night;
}

/// Совместимость со старым кодом (иконки на карте): ночь = фаза night.
bool isNightNow() => phaseNow() == WeatherPhase.night;

/// Состояние Луны на дату: lit — доля освещённости (0=новолуние, 1=полнолуние),
/// waxing — растёт ли (true) или убывает (false). Приближение по синодическому месяцу.
({double lit, bool waxing}) moonState([DateTime? when]) {
  final d = (when ?? DateTime.now()).toUtc();
  final knownNew = DateTime.utc(2000, 1, 6, 18, 14); // известное новолуние
  const synodic = 29.530588853;
  var age = (d.difference(knownNew).inSeconds / 86400.0) % synodic;
  if (age < 0) age += synodic;
  final phase = age / synodic; // 0..1
  final lit = (1 - math.cos(2 * math.pi * phase)) / 2; // 0..1
  return (lit: lit, waxing: phase < 0.5);
}

// ── Тип сцены по WMO-коду ───────────────────────────────────────────────────
enum _Kind { sun, partlyCloudy, cloud, fog, rain, snow, storm }

_Kind _kindOf(int code) {
  if (code == 0 || code == 1) return _Kind.sun;
  if (code == 2) return _Kind.partlyCloudy; // переменная облачность — солнце за облаками
  if (code == 45 || code == 48) return _Kind.fog;
  if (code >= 71 && code <= 77) return _Kind.snow;
  if (code == 85 || code == 86) return _Kind.snow;
  if (code >= 95) return _Kind.storm;
  if (code >= 51 && code <= 67) return _Kind.rain;
  if (code >= 80 && code <= 82) return _Kind.rain;
  return _Kind.cloud; // 3 и прочее — пасмурно
}

// ── Общие хелперы рисования (для большого фона и мини-иконки) ───────────────

/// Луна с фазой: тёмный диск + освещённая часть (лимб + терминатор-эллипс).
/// Метод сэмплирования контура — без неоднозначных дуг, корректен для любой фазы.
void _drawMoonPhase(Canvas canvas, Offset c, double r, double lit, bool waxing) {
  canvas.drawCircle(c, r, Paint()..color = const Color(0xFF3B4358)); // тёмный диск
  if (lit < 0.03) return; // новолуние — почти невидима
  final litPaint = Paint()..color = const Color(0xFFEAF0FA);
  if (lit > 0.985) {
    canvas.drawCircle(c, r, litPaint);
    _moonCraters(canvas, c, r);
    return;
  }
  final mirror = waxing ? 1.0 : -1.0; // waxing → освещён правый край (+x)
  final k = 1 - 2 * lit; // +1 новолуние … −1 полнолуние
  final path = Path();
  const n = 28;
  for (int i = 0; i <= n; i++) {
    final y = -r + 2 * r * i / n;
    final x = math.sqrt(math.max(0.0, r * r - y * y));
    final px = c.dx + mirror * x, py = c.dy + y;
    i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
  }
  for (int i = n; i >= 0; i--) {
    final y = -r + 2 * r * i / n;
    final x = math.sqrt(math.max(0.0, r * r - y * y)) * k;
    path.lineTo(c.dx + mirror * x, c.dy + y);
  }
  path.close();
  canvas.drawPath(path, litPaint);
  if (lit > 0.9) _moonCraters(canvas, c, r);
}

void _moonCraters(Canvas canvas, Offset c, double r) {
  final p = Paint()..color = const Color(0xFFCBD5E6);
  canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.2), r * 0.18, p);
  canvas.drawCircle(c + Offset(r * 0.25, r * 0.3), r * 0.14, p);
  canvas.drawCircle(c + Offset(r * 0.4, -r * 0.35), r * 0.1, p);
}

void _drawCloud(Canvas canvas, Offset at, double s, Color color) {
  // Мягкие края (MaskFilter.blur) — облака как в системных погодных сценах,
  // а не «нарисованные» кружки с резким контуром.
  final p = Paint()
    ..color = color
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * s);
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

/// Мягкое «дышащее» солнце (дизайн погоды, утверждён 2026-08-21): диск с тёплым
/// градиентом + два слоя свечения, БЕЗ лучей-палок — владелец счёл их клипартом.
/// Центр/радиус — параметры для большого фона и мини-иконки. warm — закат/рассвет.
void _drawSun(Canvas canvas, Offset c, double r, double t, {bool warm = false}) {
  final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
  final glow = warm ? const Color(0xFFFF9E52) : const Color(0xFFFFD98F);

  // Широкий ореол — медленно «дышит».
  final haloR = r * (3.2 + 0.5 * pulse);
  canvas.drawCircle(
    c,
    haloR,
    Paint()
      ..shader = RadialGradient(
        colors: [glow.withValues(alpha: 0.30 + 0.10 * pulse), glow.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: haloR)),
  );

  // Ближнее свечение вокруг диска.
  final nearR = r * 1.8;
  canvas.drawCircle(
    c,
    nearR,
    Paint()
      ..shader = RadialGradient(
        colors: [glow.withValues(alpha: 0.52), glow.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: nearR)),
  );

  // Сам диск: светлое пятно смещено к верхнему левому краю — объём без резкости.
  final body = warm
      ? const [Color(0xFFFFEFD0), Color(0xFFFFB662), Color(0xFFF0813C)]
      : const [Color(0xFFFFF6DC), Color(0xFFFFD98F), Color(0xFFF7BE62)];
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        colors: body,
        stops: const [0.0, 0.62, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );
}

// ── Большой анимированный фон шапки погоды ──────────────────────────────────

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
    final phase = phaseNow();
    final moon = moonState();
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _WeatherPainter(
            kind: kind, t: _c.value, phase: phase,
            moonLit: moon.lit, moonWaxing: moon.waxing,
          ),
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  final _Kind kind;
  final double t;
  final WeatherPhase phase;
  final double moonLit;
  final bool moonWaxing;
  _WeatherPainter({
    required this.kind, required this.t, required this.phase,
    required this.moonLit, required this.moonWaxing,
  });

  bool get _night => phase == WeatherPhase.night;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSky(canvas, size);
    switch (kind) {
      case _Kind.sun:
        _night ? _paintNight(canvas, size) : _paintSun(canvas, size);
        _paintClouds(canvas, size, count: 1, opacity: _night ? 0.4 : 0.45);
        break;
      case _Kind.partlyCloudy:
        // Солнце светит, облака дрейфуют поверх него.
        _night ? _paintNight(canvas, size) : _paintSun(canvas, size);
        _paintClouds(canvas, size, count: 2, opacity: _night ? 0.7 : 0.8);
        break;
      case _Kind.cloud:
        if (_night) _paintNight(canvas, size);
        _paintClouds(canvas, size, count: 3, opacity: _night ? 0.8 : 0.9);
        break;
      case _Kind.fog:
        _paintFog(canvas, size);
        break;
      case _Kind.rain:
        _paintClouds(canvas, size, count: 2, opacity: 0.85);
        _paintRain(canvas, size, slant: 0);
        break;
      case _Kind.snow:
        _paintClouds(canvas, size, count: 2, opacity: 0.7);
        _paintSnow(canvas, size);
        break;
      case _Kind.storm:
        _paintClouds(canvas, size, count: 2, opacity: 0.95);
        _paintRain(canvas, size, slant: 14); // косой дождь = ветер
        _paintLightning(canvas, size);
        break;
    }
  }

  void _paintNight(Canvas canvas, Size size) {
    _paintStars(canvas, size);
    _paintMoon(canvas, size);
  }

  void _paintSky(Canvas canvas, Size size) {
    final clear = kind == _Kind.sun || kind == _Kind.partlyCloudy;
    final List<Color> colors;
    if (clear) {
      // Трёхстопные градиенты — глубина неба как в системных погодных сценах.
      colors = switch (phase) {
        WeatherPhase.dawn => [
            const Color(0xFF3D5A94),
            const Color(0xFF9B7FA8),
            const Color(0xFFF6B27A),
          ],
        WeatherPhase.day => kind == _Kind.sun
            ? [
                const Color(0xFF1D6DC4),
                const Color(0xFF5FA8E8),
                const Color(0xFFA9DCF8),
              ]
            : [
                const Color(0xFF2F7BBE),
                const Color(0xFF6FB0E0),
                const Color(0xFFB2DCF2),
              ],
        WeatherPhase.dusk => [
            const Color(0xFF2C3364),
            const Color(0xFF8A5878),
            const Color(0xFFF0885A),
          ],
        WeatherPhase.night => [
            const Color(0xFF060D1F),
            const Color(0xFF122444),
            const Color(0xFF29436B),
          ],
      };
    } else {
      colors = _night
          ? switch (kind) {
              _Kind.cloud => [const Color(0xFF161E2B), const Color(0xFF313C4D)],
              _Kind.fog => [const Color(0xFF1E242D), const Color(0xFF3C434E)],
              _Kind.rain => [const Color(0xFF111922), const Color(0xFF2A3340)],
              _Kind.snow => [const Color(0xFF18212E), const Color(0xFF384454)],
              _Kind.storm => [const Color(0xFF0A0D13), const Color(0xFF1F2632)],
              _ => [const Color(0xFF161E2B), const Color(0xFF313C4D)],
            }
          : switch (kind) {
              _Kind.cloud => [const Color(0xFF3A4452), const Color(0xFF6E7B8C)],
              _Kind.fog => [const Color(0xFF4A535F), const Color(0xFF818B97)],
              _Kind.rain => [const Color(0xFF2C3744), const Color(0xFF55657A)],
              _Kind.snow => [const Color(0xFF394656), const Color(0xFF7E90A6)],
              _Kind.storm => [const Color(0xFF1E232C), const Color(0xFF3C4654)],
              _ => [const Color(0xFF3A4452), const Color(0xFF6E7B8C)],
            };
    }
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors,
        ).createShader(rect),
    );
  }

  void _paintSun(Canvas canvas, Size size) {
    final warm = phase == WeatherPhase.dawn || phase == WeatherPhase.dusk;
    final c = switch (phase) {
      WeatherPhase.dawn => Offset(size.width * 0.30, size.height * 0.58), // восход (низко слева)
      WeatherPhase.dusk => Offset(size.width * 0.74, size.height * 0.60), // закат (низко справа)
      _ => Offset(size.width * 0.78, size.height * 0.38), // день (высоко)
    };
    if (warm) {
      // Тёплое свечение у горизонта — золотой час как в системных сценах.
      final rect = Rect.fromLTWH(
          -size.width * 0.2, size.height * 0.55, size.width * 1.4, size.height * 0.6);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFB878).withValues(alpha: 0.42),
              const Color(0x00FFB878),
            ],
          ).createShader(rect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    _drawSun(canvas, c, 30, t, warm: warm);
  }

  void _paintMoon(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.80, size.height * 0.38);
    canvas.drawCircle(
      c, 52,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x55EAF2FF), Color(0x00EAF2FF)])
            .createShader(Rect.fromCircle(center: c, radius: 52)),
    );
    _drawMoonPhase(canvas, c, 20, moonLit, moonWaxing);
  }

  void _paintStars(Canvas canvas, Size size) {
    const pts = [
      [0.12, 0.22], [0.28, 0.40], [0.20, 0.62], [0.45, 0.27],
      [0.55, 0.55], [0.38, 0.72], [0.62, 0.30], [0.08, 0.46],
      [0.50, 0.16], [0.33, 0.20], [0.15, 0.78], [0.47, 0.66],
    ];
    final p = Paint();
    for (int i = 0; i < pts.length; i++) {
      final tw = 0.5 + 0.5 * math.sin(t * 2 * math.pi + i);
      p.color = Colors.white.withValues(alpha: 0.30 + 0.50 * tw);
      canvas.drawCircle(
        Offset(pts[i][0] * size.width, pts[i][1] * size.height), i.isEven ? 1.4 : 1.0, p,
      );
    }
  }

  void _paintClouds(Canvas canvas, Size size, {required int count, double opacity = 0.9}) {
    for (int i = 0; i < count; i++) {
      final phaseX = (t + i / count) % 1.0;
      final x = phaseX * (size.width + 160) - 80;
      final y = size.height * (0.30 + 0.18 * i) % size.height;
      _drawCloud(canvas, Offset(x, y), 0.9 - i * 0.12,
          Colors.white.withValues(alpha: opacity * (0.85 - i * 0.15)));
    }
  }

  void _paintRain(Canvas canvas, Size size, {double slant = 0}) {
    final p = Paint()
      ..color = const Color(0xFFBFE0FF).withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const n = 26;
    for (int i = 0; i < n; i++) {
      final col = (i / n) * size.width + (i.isEven ? 6 : 0);
      final fall = ((t * 2) + i * 0.13) % 1.0;
      final y = fall * size.height;
      canvas.drawLine(Offset(col + slant, y), Offset(col - 4, y + 12), p);
    }
  }

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

  void _paintFog(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.16);
    for (int i = 0; i < 4; i++) {
      final ph = (t + i / 4) % 1.0;
      final x = ph * 80 - 40;
      final y = size.height * (0.25 + i * 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, size.width * 0.9, 10), const Radius.circular(8),
        ),
        p,
      );
    }
  }

  void _paintLightning(Canvas canvas, Size size) {
    final flash = math.max(0.0, math.sin(t * 4 * math.pi));
    if (flash < 0.85) return;
    final o = (flash - 0.85) / 0.15;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.25 * o));
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
      old.t != t || old.kind != kind || old.phase != phase || old.moonLit != moonLit;
}
