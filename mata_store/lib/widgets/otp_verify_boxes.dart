import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Ввод кода подтверждения с хореографией «OTP V5» (стандарт экосистемы МАТА
/// для всех верификаций кодом). Светлая версия под тему Store (чёрный акцент).
///
/// Фазы одной величины прогресса prog 0..3:
///   0..1  строка ячеек разлетается в окружность (380 мс, easeOutCubic)
///   1..2  связка вращается 2 оборота ЖЁСТКО — цифры крутятся вместе с
///         ячейками (1250 мс, easeInOutCubic); пока сервер думает — связка
///         докручивает дополнительные обороты (вращение = «загрузка»)
///   2..3  схлопывание в центр с доворотом 40° (420 мс, easeInBack)
/// Успех: рамка зеленеет, кольца-ripple, искры, галочка прорисовывается.
/// Ошибка: связка возвращается в строку + горизонтальный shake.
///
/// Движение считается в AnimatedBuilder от контроллеров — без setState на кадр.
/// При MediaQuery.disableAnimations состояния меняются мгновенно, без движения.
class OtpVerifyBoxes extends StatefulWidget {
  final int length;
  final bool autofocus;

  /// Проверка кода на сервере: true — успех, false — ошибка.
  final Future<bool> Function(String code) onSubmit;

  /// После завершения анимации успеха (навигация/закрытие).
  final VoidCallback onSuccess;

  /// После возврата из анимации ошибки (показать текст ошибки).
  final VoidCallback? onFailed;

  /// Подсветить ячейки красным (текст ошибки показывает родитель).
  final bool hasError;

  const OtpVerifyBoxes({
    super.key,
    this.length = 4,
    this.autofocus = false,
    required this.onSubmit,
    required this.onSuccess,
    this.onFailed,
    this.hasError = false,
  });

  @override
  State<OtpVerifyBoxes> createState() => OtpVerifyBoxesState();
}

class OtpVerifyBoxesState extends State<OtpVerifyBoxes>
    with TickerProviderStateMixin {
  static const double _cellW = 60;
  static const double _cellH = 72;
  static const double _gap = 76;
  static const double _radius = 62;
  static const int _turns = 2;

  static const _verifiedBg = Color(0xFFEAF4EC);
  static const _spark = Color(0xFF66BB6A);

  final _text = TextEditingController();
  final _focus = FocusNode();

  late final AnimationController _phase = AnimationController(
    vsync: this,
    upperBound: 3,
  );
  late final AnimationController _extra = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  int _extraTurns = 0;

  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  bool _busy = false;
  bool _verified = false;

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _extra.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _extraTurns++;
        _extra.value = 0;
      }
    });
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _phase.dispose();
    _extra.dispose();
    _ring.dispose();
    _check.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String v) async {
    if (_busy) return;
    if (v.length == widget.length) {
      await _run(v);
    }
  }

  Future<void> _run(String code) async {
    setState(() => _busy = true);
    _focus.unfocus();

    final verifyFuture = widget.onSubmit(code);

    if (_reduceMotion) {
      final ok = await verifyFuture;
      if (!mounted) return;
      if (ok) {
        setState(() => _verified = true);
        _phase.value = 3;
        _ring.value = 1;
        _check.value = 1;
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) widget.onSuccess();
      } else {
        _resetAfterError();
      }
      return;
    }

    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    await _phase.animateTo(
      1,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    await _phase.animateTo(
      2,
      duration: const Duration(milliseconds: 1250),
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;

    bool? result;
    unawaited(
      verifyFuture.then((v) => result = v).catchError((_) => result = false),
    );
    while (result == null && mounted) {
      await _extra.animateTo(1, curve: Curves.easeInOutCubic);
      if (!mounted) return;
    }
    if (!mounted) return;
    final ok = result ?? false;

    if (ok) {
      await _phase.animateTo(
        3,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInBack,
      );
      if (!mounted) return;
      setState(() => _verified = true);
      _check.forward();
      await _ring.forward();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) widget.onSuccess();
    } else {
      await _phase.animateBack(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
      if (!mounted) return;
      _resetAfterError();
      _shake.forward(from: 0);
    }
  }

  void _resetAfterError() {
    _extraTurns = 0;
    _extra.value = 0;
    _phase.value = 0;
    _ring.value = 0;
    _check.value = 0;
    setState(() {
      _busy = false;
      _verified = false;
      _text.clear();
    });
    widget.onFailed?.call();
    _focus.requestFocus();
  }

  double _spinDeg(double prog) {
    double spin;
    if (prog <= 1) {
      spin = 0;
    } else if (prog <= 2) {
      spin = (prog - 1) * 360.0 * _turns;
    } else {
      spin = 360.0 * _turns + (prog - 2) * 40.0;
    }
    return spin + (_extraTurns + _extra.value) * 360.0;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!_busy) _focus.requestFocus();
      },
      child: SizedBox(
        height: 220,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 0,
              height: 0,
              child: TextField(
                controller: _text,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(n),
                ],
                autofocus: widget.autofocus,
                enabled: !_busy,
                onChanged: _onChanged,
              ),
            ),
            AnimatedBuilder(
              animation: _ring,
              builder: (context, _) => _verified
                  ? CustomPaint(
                      size: const Size(220, 220),
                      painter: _RipplePainter(
                        progress: _ring.value,
                        color: AppColors.success,
                        sparkColor: _spark,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([_phase, _extra, _shake]),
              builder: (context, _) {
                final prog = _phase.value;
                final p = prog.clamp(0.0, 1.0);
                final shrink = (prog - 2).clamp(0.0, 1.0);
                final spin = _spinDeg(prog);
                final shakeX = _shake.isAnimating || _shake.value > 0
                    ? math.sin(_shake.value * math.pi * 3) *
                          6 *
                          (1 - _shake.value)
                    : 0.0;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: List.generate(n, (i) {
                    // Финал: как на сайте — первая ячейка СТРОГО РОВНО по
                    // центру (translate(0,0) scale(.92), без доворота +40°,
                    // иначе галочка стоит криво), остальные скрыты.
                    if (_verified) {
                      if (i != 0) return const SizedBox.shrink();
                      return Transform.scale(scale: 0.92, child: _cell(0));
                    }
                    final rowX = (i - (n - 1) / 2) * _gap;
                    final a = (-90 + i * (360 / n) + spin) * math.pi / 180;
                    final orbX = math.cos(a) * _radius;
                    final orbY = math.sin(a) * _radius;

                    final x = (rowX + (orbX - rowX) * p) * (1 - shrink);
                    final y = orbY * p * (1 - shrink);
                    final rotRad = spin * p * math.pi / 180;
                    final sc = 1 - shrink * 0.12;
                    final fade = shrink > 0.75 && i != 0
                        ? 1 - (shrink - 0.75) / 0.25
                        : 1.0;

                    // Порядок: translate → rotate → scale (см. спеку OTP V5).
                    final m = Matrix4.identity()
                      ..translate(x + shakeX, y)
                      ..rotateZ(rotRad)
                      ..scale(sc);

                    return Transform(
                      transform: m,
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: fade.clamp(0.0, 1.0),
                        child: _cell(i),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int i) {
    final value = i < _text.text.length ? _text.text[i] : null;
    final isCurrent = !_busy && _focus.hasFocus && i == _text.text.length;
    final showCheck = _verified && i == 0;

    final Color border;
    double width = 1;
    if (showCheck) {
      border = AppColors.success;
      width = 2;
    } else if (widget.hasError) {
      border = AppColors.red;
      width = 2;
    } else if (isCurrent) {
      border = AppColors.black;
      width = 2;
    } else if (value != null) {
      border = AppColors.grey800;
      width = 2;
    } else {
      border = AppColors.grey200;
    }

    return Container(
      width: _cellW,
      height: _cellH,
      decoration: BoxDecoration(
        color: showCheck ? _verifiedBg : AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: width),
        boxShadow: showCheck
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.3),
                  blurRadius: 24,
                ),
              ]
            : isCurrent
            ? [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: showCheck
          ? AnimatedBuilder(
              animation: _check,
              builder: (context, _) => CustomPaint(
                size: const Size(30, 30),
                painter: _CheckPainter(
                  progress: Curves.easeInOut.transform(_check.value),
                  color: AppColors.success,
                ),
              ),
            )
          : value != null
          ? Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: widget.hasError ? AppColors.red : AppColors.black,
              ),
            )
          : isCurrent
          ? Container(width: 2, height: 28, color: AppColors.black)
          : null,
    );
  }
}

/// Два расходящихся кольца (сдвиг второго) + 6 искр.
class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color sparkColor;

  _RipplePainter({
    required this.progress,
    required this.color,
    required this.sparkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    void ringAt(double t) {
      if (t <= 0 || t >= 1) return;
      final eased = Curves.easeOutCubic.transform(t);
      final r = 40 + eased * 95;
      stroke.color = color.withValues(alpha: 0.9 * (1 - eased));
      canvas.drawCircle(center, r, stroke);
    }

    ringAt(progress);
    ringAt((progress - 0.17).clamp(0.0, 1.0) / 0.83);

    final dot = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final delay = i * 0.06;
      final t = ((progress - delay) / 0.7).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOut.transform(t);
      final angle = (i * 60 + 20) * math.pi / 180;
      final dist = 20 + eased * 72;
      final alpha = t < 0.35 ? t / 0.35 : 1 - (t - 0.35) / 0.65;
      dot.color = sparkColor.withValues(alpha: alpha);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * dist,
        2 * (1 - eased * 0.6),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.color != color;
}

/// Галочка, прорисовывающаяся как stroke-dashoffset 30 → 0.
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.20, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.80, size.height * 0.30);
    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
