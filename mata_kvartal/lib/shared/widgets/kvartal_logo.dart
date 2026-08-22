import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Знак Квартала «Последний метр» (вариант А3, утверждён владельцем 2026-08-21,
/// дизайн-проект 37ed0b07): контур-маршрут почти обвёл квартал — внутри уже
/// лаймовая захваченная территория, впереди пунктир незавершённых метров,
/// «бегун»-точка несётся замкнуть петлю.
///
/// Векторный (CustomPainter) — чёткий в любом размере; цвета параметризованы:
/// [outline] по умолчанию графит (светлые фоны), на тёмных передать светлый.
/// [animated] — живое замыкание петли (уважает отключение анимаций в системе).
class KvartalLogoMark extends StatefulWidget {
  final double size;
  final bool animated;
  final bool glow;
  final Color? outline;
  final Color? fill;

  const KvartalLogoMark({
    super.key,
    this.size = 44,
    this.animated = true,
    this.glow = true,
    this.outline,
    this.fill,
  });

  @override
  State<KvartalLogoMark> createState() => _KvartalLogoMarkState();
}

class _KvartalLogoMarkState extends State<KvartalLogoMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant KvartalLogoMark old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.animated && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final outline = widget.outline ?? AppColors.ink;
    final fill = widget.fill ?? AppColors.lime;

    Widget mark = AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        size: Size.square(widget.size),
        painter: KvartalMarkPainter(
          outline: outline,
          fill: fill,
          close: (widget.animated && !reduceMotion)
              ? Curves.easeInOutCubic.transform(_c.value)
              : 0,
        ),
      ),
    );

    if (!widget.glow) return mark;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size * 0.72,
            height: widget.size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: 0.30),
                  blurRadius: widget.size * 0.30,
                  spreadRadius: widget.size * 0.02,
                ),
              ],
            ),
          ),
          mark,
        ],
      ),
    );
  }
}

/// Painter знака: обычный режим ([draw] = 1) — статика/дыхание петли через
/// [close]; режим заставки ([draw] < 1) — маршрут рисуется с нуля по
/// пунктирному «плану», а территория появляется через [fillScale].
class KvartalMarkPainter extends CustomPainter {
  final Color outline;
  final Color fill;
  final double close; // 0 — разрыв полный, 1 — петля замкнута
  final double draw; // 0..1 — сколько маршрута уже нарисовано (сплэш)
  final double fillScale; // 0..1 — масштаб заливки территории (сплэш)

  KvartalMarkPainter({
    required this.outline,
    required this.fill,
    this.close = 0,
    this.draw = 1,
    this.fillScale = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 48;
    canvas.scale(k);

    // Захваченная территория (в сплэше «врывается» масштабом).
    if (fillScale > 0.01) {
      canvas.save();
      canvas.translate(24, 24);
      canvas.scale(fillScale);
      canvas.translate(-24, -24);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(15.5, 15.5, 17, 17),
          const Radius.circular(4.5),
        ),
        Paint()..color = fill,
      );
      canvas.restore();
    }

    if (draw < 1) {
      _paintDrawing(canvas);
      return;
    }

    // Контур-маршрут с разрывом «последнего метра».
    final ring = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 9, 30, 30),
        const Radius.circular(9),
      ));
    final metric = ring.computeMetrics().first;
    final len = metric.length;

    final gapFull = len * 0.14;
    final gap = gapFull * (1 - close);
    final dotT = 5 + gapFull * close; // бегун закрывает петлю
    final solidLen = len - gap;
    final start = dotT - solidLen;

    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.6
      ..strokeCap = StrokeCap.round;

    if (start < 0) {
      canvas.drawPath(metric.extractPath(start + len, len), stroke);
      canvas.drawPath(metric.extractPath(0, dotT), stroke);
    } else {
      canvas.drawPath(metric.extractPath(start, dotT), stroke);
    }

    // Пунктир впереди бегуна — незавершённые метры.
    if (gap > 4.5) {
      final dashPaint = Paint()
        ..color = outline.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round;
      var t = dotT + 3.4;
      final end = dotT + gap - 2.2;
      while (t + 2.4 < end) {
        canvas.drawPath(metric.extractPath(t % len, (t + 2.4) % len == 0 ? len : t + 2.4), dashPaint);
        t += 5.2;
      }
    }

    // «Бегун» на конце сплошной линии.
    final pos = metric.getTangentForOffset(dotT % len)!.position;
    canvas.drawCircle(pos, 5, Paint()..color = outline);
    canvas.drawCircle(pos, 2.2, Paint()..color = fill);
  }

  /// Режим заставки: сплошная линия растёт от старта, впереди — слабый
  /// пунктирный «план маршрута» на весь остаток, бегун ведёт линию.
  void _paintDrawing(Canvas canvas) {
    final ring = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 9, 30, 30),
        const Radius.circular(9),
      ));
    final metric = ring.computeMetrics().first;
    final len = metric.length;
    const t0 = 5.0;
    final solid = len * draw;
    final dotT = t0 + solid;

    // План-пунктир впереди — тонкий, чтобы не спорил с маршрутом.
    final plan = Paint()
      ..color = outline.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    var t = dotT + 4.0;
    while (t + 1.8 < t0 + len - 2.0) {
      canvas.drawPath(
        metric.extractPath(t % len, (t + 1.8) % len), plan);
      t += 4.8;
    }

    // Нарисованный маршрут.
    if (solid > 0.5) {
      final stroke = Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.6
        ..strokeCap = StrokeCap.round;
      if (dotT <= len) {
        canvas.drawPath(metric.extractPath(t0, dotT), stroke);
      } else {
        canvas.drawPath(metric.extractPath(t0, len), stroke);
        canvas.drawPath(metric.extractPath(0, dotT - len), stroke);
      }
    }

    // Бегун.
    final pos = metric.getTangentForOffset(dotT % len)!.position;
    canvas.drawCircle(pos, 5, Paint()..color = outline);
    canvas.drawCircle(pos, 2.2, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(KvartalMarkPainter old) =>
      old.outline != outline ||
      old.fill != fill ||
      old.close != close ||
      old.draw != draw ||
      old.fillScale != fillScale;
}

class KvartalLogoBadge extends StatelessWidget {
  final double size;
  final bool showText;
  final EdgeInsetsGeometry padding;

  const KvartalLogoBadge({
    super.key,
    this.size = 34,
    this.showText = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KvartalLogoMark(size: size, glow: false, animated: false),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            'КВАРТАЛ',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              // Слово живёт на светлой панели — дисплейным шрифтом, как заголовки сайта.
              fontFamily: AppTheme.fontDisplay,
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}
