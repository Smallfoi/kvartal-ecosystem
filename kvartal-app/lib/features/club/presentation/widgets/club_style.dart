import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Анимированная тема фона шапки клуба.
enum ClubTheme { minimal, aurora, sparks, stars, confetti }

/// Пресет оформления клуба «в один тап»: акцент-цвет + градиент шапки +
/// анимированный фон + цвет рамки логотипа. Подобраны под наш тёмный бренд.
class ClubStyle {
  final String key;
  final String label;
  final Color accent; // бейджи, цифры, кольцо логотипа, выделения
  final List<Color> headerGradient; // фон шапки
  final ClubTheme theme; // анимированный слой
  final Color frame; // кольцо вокруг логотипа

  const ClubStyle({
    required this.key,
    required this.label,
    required this.accent,
    required this.headerGradient,
    required this.theme,
    required this.frame,
  });

  static const minimal = ClubStyle(
    key: 'minimal',
    label: 'Минимал',
    accent: Color(0xFF0A84FF),
    headerGradient: [Color(0xFF0D1F3C), Color(0xFF0A1628), Color(0xFF0D0D0D)],
    theme: ClubTheme.minimal,
    frame: Color(0xFF0A84FF),
  );
  static const north = ClubStyle(
    key: 'north',
    label: 'Север',
    accent: Color(0xFF49C5FF),
    headerGradient: [Color(0xFF0A2C3E), Color(0xFF0B1E33), Color(0xFF0D0D0D)],
    theme: ClubTheme.aurora,
    frame: Color(0xFF8FE6FF),
  );
  static const fire = ClubStyle(
    key: 'fire',
    label: 'Огонь',
    accent: Color(0xFFFF6A2C),
    headerGradient: [Color(0xFF3A160C), Color(0xFF24110A), Color(0xFF0D0D0D)],
    theme: ClubTheme.sparks,
    frame: Color(0xFFFFB05A),
  );
  static const neon = ClubStyle(
    key: 'neon',
    label: 'Неон',
    accent: Color(0xFFB14CFF),
    headerGradient: [Color(0xFF1E0E33), Color(0xFF150A23), Color(0xFF0D0D0D)],
    theme: ClubTheme.stars,
    frame: Color(0xFFE08CFF),
  );
  static const festive = ClubStyle(
    key: 'festive',
    label: 'Праздник',
    accent: Color(0xFFFFC83C),
    headerGradient: [Color(0xFF26213C), Color(0xFF171229), Color(0xFF0D0D0D)],
    theme: ClubTheme.confetti,
    frame: Color(0xFFFFD86B),
  );

  static const all = [minimal, north, fire, neon, festive];

  static ClubStyle byKey(String? key) =>
      all.firstWhere((s) => s.key == key, orElse: () => minimal);
}

/// Тонкий анимированный фон шапки клуба под выбранный пресет.
/// Рисуется поверх градиента, но под контентом; полупрозрачный — текст читаем.
class ClubHeaderBackground extends StatefulWidget {
  final ClubStyle style;
  const ClubHeaderBackground({super.key, required this.style});

  @override
  State<ClubHeaderBackground> createState() => _ClubHeaderBackgroundState();
}

class _ClubHeaderBackgroundState extends State<ClubHeaderBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => CustomPaint(
      painter: _ClubHeaderPainter(style: widget.style, t: _c.value),
      size: Size.infinite,
    ),
  );
}

class _ClubHeaderPainter extends CustomPainter {
  final ClubStyle style;
  final double t; // 0..1 зациклено
  _ClubHeaderPainter({required this.style, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    switch (style.theme) {
      case ClubTheme.minimal:
        _minimal(canvas, size);
        break;
      case ClubTheme.aurora:
        _aurora(canvas, size);
        break;
      case ClubTheme.sparks:
        _sparks(canvas, size);
        break;
      case ClubTheme.stars:
        _stars(canvas, size);
        break;
      case ClubTheme.confetti:
        _confetti(canvas, size);
        break;
    }
  }

  // Минимал — два мягких «дышащих» свечения акцентом. Чисто и спокойно.
  void _minimal(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    for (final spec in [
      [0.82, 0.30, 0.10 + 0.05 * pulse],
      [0.18, 0.66, 0.08 + 0.04 * (1 - pulse)],
    ]) {
      final c = Offset(spec[0] * size.width, spec[1] * size.height);
      final r = size.width * 0.5;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              style.accent.withValues(alpha: spec[2]),
              style.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
  }

  // Север — полупрозрачные «сполохи» северного сияния, плывут по горизонтали.
  void _aurora(Canvas canvas, Size size) {
    const bands = [
      [0.30, Color(0x3349C5FF)],
      [0.46, Color(0x2A66E6B0)],
      [0.62, Color(0x2A8F6BFF)],
    ];
    for (int i = 0; i < bands.length; i++) {
      final yBase = (bands[i][0] as double) * size.height;
      final color = bands[i][1] as Color;
      final path = Path();
      final phase = t * 2 * math.pi + i;
      for (double x = 0; x <= size.width; x += 12) {
        final y = yBase +
            math.sin(x / size.width * 3 * math.pi + phase) * size.height * 0.07;
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * 0.16
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
  }

  // Огонь — искры/угольки поднимаются снизу, мерцают.
  void _sparks(Canvas canvas, Size size) {
    const n = 20;
    for (int i = 0; i < n; i++) {
      final rise = ((t * 1.4) + i / n) % 1.0;
      final x = ((i * 53) % 100) / 100 * size.width +
          math.sin((rise + i) * 2 * math.pi) * 10;
      final y = size.height * (1.0 - rise);
      final flick = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 6 * math.pi + i));
      final warm = i.isEven ? const Color(0xFFFF8A3C) : const Color(0xFFFFC83C);
      canvas.drawCircle(
        Offset(x, y),
        (i % 3 == 0 ? 2.4 : 1.5) * (0.6 + rise),
        Paint()..color = warm.withValues(alpha: flick * (1 - rise) * 0.9),
      );
    }
  }

  // Неон — мерцающие точки-звёзды в неоновом акценте.
  void _stars(Canvas canvas, Size size) {
    const pts = [
      [0.12, 0.24], [0.28, 0.40], [0.20, 0.62], [0.45, 0.27],
      [0.55, 0.55], [0.38, 0.72], [0.66, 0.34], [0.80, 0.5],
      [0.50, 0.18], [0.72, 0.66], [0.88, 0.28], [0.33, 0.5],
    ];
    final p = Paint();
    for (int i = 0; i < pts.length; i++) {
      final tw = 0.5 + 0.5 * math.sin(t * 2 * math.pi + i);
      p.color = (i.isEven ? style.accent : Colors.white)
          .withValues(alpha: 0.30 + 0.55 * tw);
      canvas.drawCircle(
        Offset(pts[i][0] * size.width, pts[i][1] * size.height),
        i.isEven ? 2.0 : 1.3,
        p,
      );
    }
  }

  // Праздник — падающее конфетти разных цветов, покачивается.
  void _confetti(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFFC83C), Color(0xFF49C5FF), Color(0xFFFF5A7A),
      Color(0xFF6BE08A), Color(0xFFB14CFF),
    ];
    const n = 22;
    for (int i = 0; i < n; i++) {
      final fall = ((t * 1.1) + i / n) % 1.0;
      final x = ((i * 67) % 100) / 100 * size.width +
          math.sin((fall + i) * 2 * math.pi) * 12;
      final y = fall * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((fall + i) * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -2, 6, 4),
          const Radius.circular(1.5),
        ),
        Paint()..color = colors[i % colors.length].withValues(alpha: 0.85),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ClubHeaderPainter old) =>
      old.t != t || old.style.key != style.key;
}
