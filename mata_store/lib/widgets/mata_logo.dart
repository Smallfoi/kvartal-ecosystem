import 'package:flutter/material.dart';

/// Фирменный знак МАТА — точные пути из `brand/logo/svg` (Лого *.svg, D-34).
/// Буквы М·А·А — [color], акцентная Т (трапеция + ножка) — [accent].
/// Не рисовать знак шрифтом и не менять геометрию: источник правды — файлы бренда.
class MataLogo extends StatelessWidget {
  final double width;
  final Color color;
  final Color? accent; // null → одноцветный знак

  const MataLogo({
    super.key,
    required this.width,
    required this.color,
    this.accent,
  });

  static const double aspect = 656 / 112; // геометрия знака из brand/logo/svg

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width / aspect,
      child: CustomPaint(
        painter: _MataLogoPainter(color: color, accent: accent ?? color),
      ),
    );
  }
}

class _MataLogoPainter extends CustomPainter {
  final Color color;
  final Color accent;
  _MataLogoPainter({required this.color, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 656);
    final lp = Paint()..color = color;
    final ap = Paint()..color = accent;

    canvas.drawPath(
      Path()
      ..moveTo(16.00, 0.00)
      ..lineTo(12.86, 0.00)
      ..lineTo(0.00, 0.00)
      ..lineTo(0.00, 111.96)
      ..lineTo(16.00, 111.96)
      ..lineTo(16.00, 5.43)
      ..lineTo(77.50, 111.96)
      ..lineTo(95.96, 111.96)
      ..lineTo(31.33, 0.00)
      ..lineTo(16.00, 0.00)
      ..close(),
      lp,
    );

    canvas.drawPath(
      Path()
      ..moveTo(175.94, 0.00)
      ..lineTo(160.61, 0.00)
      ..lineTo(95.96, 111.96)
      ..lineTo(114.43, 111.96)
      ..lineTo(175.94, 5.43)
      ..lineTo(175.94, 111.96)
      ..lineTo(191.93, 111.96)
      ..lineTo(191.93, 0.00)
      ..lineTo(179.07, 0.00)
      ..lineTo(175.94, 0.00)
      ..close(),
      lp,
    );

    canvas.drawPath(
      Path()
      ..moveTo(307.03, 0.00)
      ..lineTo(300.76, 0.00)
      ..lineTo(288.56, 0.00)
      ..lineTo(223.92, 111.96)
      ..lineTo(242.39, 111.96)
      ..lineTo(251.62, 95.97)
      ..lineTo(321.45, 95.97)
      ..lineTo(330.68, 79.97)
      ..lineTo(260.86, 79.97)
      ..lineTo(303.90, 5.43)
      ..lineTo(365.40, 111.96)
      ..lineTo(383.87, 111.96)
      ..lineTo(319.23, 0.00)
      ..lineTo(307.03, 0.00)
      ..close(),
      lp,
    );

    canvas.drawPath(
      Path()
      ..moveTo(591.40, 0.00)
      ..lineTo(578.13, 0.00)
      ..lineTo(572.93, 0.00)
      ..lineTo(559.67, 0.00)
      ..lineTo(495.02, 111.96)
      ..lineTo(513.49, 111.96)
      ..lineTo(575.53, 4.50)
      ..lineTo(619.10, 79.97)
      ..lineTo(548.49, 79.97)
      ..lineTo(557.72, 95.97)
      ..lineTo(628.34, 95.97)
      ..lineTo(637.57, 111.96)
      ..lineTo(656.04, 111.96)
      ..lineTo(591.40, 0.00)
      ..close(),
      lp,
    );

    canvas.drawPath(
      Path()
      ..moveTo(502.32, 0.00)
      ..lineTo(376.84, 0.00)
      ..lineTo(367.61, 16.00)
      ..lineTo(431.58, 16.00)
      ..lineTo(447.58, 16.00)
      ..lineTo(511.56, 16.00)
      ..lineTo(502.32, 0.00)
      ..close(),
      ap,
    );

    canvas.drawPath(
      Path()
      ..moveTo(447.85, 31.99)
      ..lineTo(431.85, 31.99)
      ..lineTo(431.85, 111.96)
      ..lineTo(447.85, 111.96)
      ..lineTo(447.85, 31.99)
      ..close(),
      ap,
    );
  }

  @override
  bool shouldRepaint(_MataLogoPainter old) =>
      old.color != color || old.accent != accent;
}
