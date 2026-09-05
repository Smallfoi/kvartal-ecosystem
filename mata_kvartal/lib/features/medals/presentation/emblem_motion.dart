import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/medals_provider.dart';
import 'medal_widgets.dart';

/// Помедальные анимации эмблем (правило эталона D-64: у КАЖДОЙ медали своя
/// анимация самой эмблемы, общий крутящийся фон запрещён как «ленивый»).
///
/// Механика — послойный экспорт: конвейер выгружает из эталона базу медали
/// (без анимируемых частей) и каждую живую часть отдельным прозрачным WebP
/// на полном холсте 768 (слои совпадают по позиции сами). Таймлайны сняты
/// с SMIL/CSS эталона и переведены в ключи ниже; координаты — в системе
/// viewBox эталона (116 единиц, начало в центре медали), масштаб эмблемы
/// (esc/ey из renderMedal) уже вмножен в значения.
///
/// Медаль без спецификации рисуется статичным ассетом — конвейер идёт
/// партиями, деградация всегда мягкая. Пульсаций и ударных волн нет (D-46).

/// Ключ таймлайна: момент [t] (0..1 периода) и поза слоя в этот момент.
class EmblemKey {
  final double t;
  final double dx, dy; // сдвиг, единицы viewBox (116 на всю медаль)
  final double rot; // градусы, по часовой (экранные координаты SVG)
  final double opacity;

  const EmblemKey(
    this.t, {
    this.dx = 0,
    this.dy = 0,
    this.rot = 0,
    this.opacity = 1,
  });
}

/// Живой слой эмблемы: ассет + цикл ключей.
class EmblemLayer {
  final String part; // суффикс файла: assets/medals/anim/<id>__<part>.webp
  final int periodMs;
  final int delayMs; // фазовый сдвиг цикла (лесенки полос, искры)
  final bool alternate; // туда-обратно (CSS animation-direction: alternate)
  final Curve curve; // кривая МЕЖДУ соседними ключами
  final List<EmblemKey> keys;
  final Offset pivot; // центр вращения, единицы viewBox от центра медали
  final Rect? clip; // окно слоя (восход за горизонтом), те же единицы

  const EmblemLayer(
    this.part, {
    required this.periodMs,
    this.delayMs = 0,
    this.alternate = false,
    this.curve = Curves.linear,
    required this.keys,
    this.pivot = Offset.zero,
    this.clip,
  });
}

/// Порядок частей медали снизу вверх — ровно документный порядок эталона:
/// статические сегменты (seg*) режутся конвейером вокруг живых слоёв, чтобы
/// z-порядок совпал (лучи ордена лежат ПОД звездой, плашка — ПОВЕРХ щита).
const Map<String, List<String>> emblemParts = {
  's_champion': ['seg0', 'rays', 'seg1'],
  'd_dawn': ['seg0', 'sun', 'seg1', 'refl', 'seg2'],
  't_defense_7': ['seg0', 'body', 'arr1', 'arr2', 'arr3', 'seg4'],
  'd_first_run': ['seg0', 'st1', 'st2', 'st3', 'runner', 'sparks', 'seg5'],
};

/// Таймлайны пилотной партии. Значения = эталон × масштаб эмблемы.
const Map<String, List<EmblemLayer>> emblemMotion = {
  // Чемпион сезона: лучи ордена делают полный оборот за 26 с (SMIL rotate).
  's_champion': [
    EmblemLayer(
      'rays',
      periodMs: 26000,
      keys: [EmblemKey(0, rot: 0), EmblemKey(1, rot: 360)],
    ),
  ],

  // Рассвет: солнце с лучами держится, садится за горизонт и всходит снова
  // (SMIL translate 10 с, сплайны ~easeInOut); дорожка света гаснет в такт.
  'd_dawn': [
    EmblemLayer(
      'sun',
      periodMs: 10000,
      curve: Curves.easeInOut,
      clip: Rect.fromLTWH(-21.84, -20.88, 43.68, 27.04),
      keys: [
        EmblemKey(0),
        EmblemKey(.5),
        EmblemKey(.62, dy: 8.32),
        EmblemKey(.7, dy: 8.32),
        EmblemKey(.88),
        EmblemKey(1),
      ],
    ),
    EmblemLayer(
      'refl',
      periodMs: 10000,
      keys: [
        EmblemKey(0),
        EmblemKey(.52),
        EmblemKey(.64, opacity: 0),
        EmblemKey(.82, opacity: 0),
        EmblemKey(.96),
        EmblemKey(1),
      ],
    ),
  ],

  // Оборона: три стрелы прилетают с разных сторон, впиваются, торчат и тают;
  // щит вздрагивает на каждый удар (CSS shieldHit: 7/23.5/40.5 % цикла 7 с).
  't_defense_7': [
    EmblemLayer(
      'body',
      periodMs: 7000,
      curve: Curves.easeOut,
      pivot: Offset(0, -8),
      keys: [
        EmblemKey(0),
        EmblemKey(.055),
        EmblemKey(.07, dx: -0.99, rot: -1.6),
        EmblemKey(.11),
        EmblemKey(.22),
        EmblemKey(.235, dx: 0.91, rot: 1.3),
        EmblemKey(.275),
        EmblemKey(.39),
        EmblemKey(.405, dx: -0.80, rot: -1.1),
        EmblemKey(.445),
        EmblemKey(1),
      ],
    ),
    EmblemLayer(
      'arr1', // translate(17,-15) rotate(-14): полёт вдоль местной оси X
      periodMs: 7000,
      keys: [
        EmblemKey(0, dx: 13.27, dy: -3.31, opacity: 0),
        EmblemKey(.028, dx: 13.27, dy: -3.31, opacity: 0),
        EmblemKey(.06, opacity: 1),
        EmblemKey(.68, opacity: 1),
        EmblemKey(.73, opacity: 0),
        EmblemKey(1, opacity: 0),
      ],
    ),
    EmblemLayer(
      'arr2', // translate(-17,-3) scale(-1,1) rotate(-9)
      periodMs: 7000,
      keys: [
        EmblemKey(0, dx: -13.51, dy: -2.14, opacity: 0),
        EmblemKey(.2, dx: -13.51, dy: -2.14, opacity: 0),
        EmblemKey(.232, opacity: 1),
        EmblemKey(.68, opacity: 1),
        EmblemKey(.73, opacity: 0),
        EmblemKey(1, opacity: 0),
      ],
    ),
    EmblemLayer(
      'arr3', // translate(14,12) rotate(9)
      periodMs: 7000,
      keys: [
        EmblemKey(0, dx: 13.51, dy: 2.14, opacity: 0),
        EmblemKey(.373, dx: 13.51, dy: 2.14, opacity: 0),
        EmblemKey(.405, opacity: 1),
        EmblemKey(.68, opacity: 1),
        EmblemKey(.73, opacity: 0),
        EmblemKey(1, opacity: 0),
      ],
    ),
  ],

  // Первый бег: бегун в ритме шага, полосы скорости пробегают, искры
  // из-под ноги (CSS runBob/streakOut + SMIL искр).
  'd_first_run': [
    EmblemLayer(
      'runner',
      periodMs: 850,
      alternate: true,
      curve: Curves.easeInOut,
      pivot: Offset(4.16, 2),
      keys: [
        EmblemKey(0, dy: -0.62, rot: -1.4),
        EmblemKey(1, dy: 0.62, rot: 1.2),
      ],
    ),
    EmblemLayer(
      'st1',
      periodMs: 1300,
      keys: [
        EmblemKey(0, dx: 3.12, opacity: 0),
        EmblemKey(.3, dx: 0.78, opacity: .75),
        EmblemKey(1, dx: -4.68, opacity: 0),
      ],
    ),
    EmblemLayer(
      'st2',
      periodMs: 1300,
      delayMs: 250,
      keys: [
        EmblemKey(0, dx: 3.12, opacity: 0),
        EmblemKey(.3, dx: 0.78, opacity: .75),
        EmblemKey(1, dx: -4.68, opacity: 0),
      ],
    ),
    EmblemLayer(
      'st3',
      periodMs: 1300,
      delayMs: 500,
      keys: [
        EmblemKey(0, dx: 3.12, opacity: 0),
        EmblemKey(.3, dx: 0.78, opacity: .75),
        EmblemKey(1, dx: -4.68, opacity: 0),
      ],
    ),
    EmblemLayer(
      'sparks',
      periodMs: 1300,
      keys: [
        EmblemKey(0, opacity: 0),
        EmblemKey(.5, dx: -2.86, dy: 0.52, opacity: .8),
        EmblemKey(1, dx: -5.72, dy: 1.04, opacity: 0),
      ],
    ),
  ],
};

/// Аверс медали, живущий своей анимацией. Для медалей без спецификации,
/// незаработанных и при выключенных анимациях системы — обычный статичный
/// [MedalImage] (тот же самый пиксель в пиксель на кадре t0).
class LiveMedalImage extends StatefulWidget {
  final MedalFull medal;
  final double size;

  const LiveMedalImage({super.key, required this.medal, required this.size});

  @override
  State<LiveMedalImage> createState() => _LiveMedalImageState();
}

class _LiveMedalImageState extends State<LiveMedalImage>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  List<EmblemLayer>? _layers;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant LiveMedalImage old) {
    super.didUpdateWidget(old);
    if (old.medal.def.id != widget.medal.def.id) _setup();
  }

  void _setup() {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();
    _layers = widget.medal.earned ? emblemMotion[widget.medal.def.id] : null;
    final layers = _layers;
    if (layers == null) return;
    for (final l in layers) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: l.periodMs),
      );
      // Фазовый сдвиг лесенок (полосы скорости): цикл запускается позже на
      // delayMs и дальше держит смещение сам — периоды у лесенки одинаковые.
      // До старта контроллер стоит на t=0 (у полос там opacity 0 — невидимы).
      void start() => l.alternate ? c.repeat(reverse: true) : c.repeat();
      if (l.delayMs == 0) {
        start();
      } else {
        Future<void>.delayed(Duration(milliseconds: l.delayMs), () {
          if (mounted && _controllers.contains(c)) start();
        });
      }
      _controllers.add(c);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  EmblemKey _sample(EmblemLayer l, double t) {
    final keys = l.keys;
    if (t <= keys.first.t) return keys.first;
    for (var i = 1; i < keys.length; i++) {
      if (t <= keys[i].t) {
        final a = keys[i - 1], b = keys[i];
        final span = b.t - a.t;
        final raw = span <= 0 ? 1.0 : (t - a.t) / span;
        final f = l.curve.transform(raw.clamp(0.0, 1.0));
        return EmblemKey(
          t,
          dx: a.dx + (b.dx - a.dx) * f,
          dy: a.dy + (b.dy - a.dy) * f,
          rot: a.rot + (b.rot - a.rot) * f,
          opacity: a.opacity + (b.opacity - a.opacity) * f,
        );
      }
    }
    return keys.last;
  }

  @override
  Widget build(BuildContext context) {
    final layers = _layers;
    final motionOff = MediaQuery.of(context).disableAnimations;
    if (layers == null || motionOff) {
      return MedalImage(
        def: widget.medal.def,
        earned: widget.medal.earned,
        size: widget.size,
      );
    }
    final s = widget.size / 116.0; // единицы viewBox → пиксели виджета
    final center = Offset(widget.size / 2, widget.size / 2);
    final parts = emblemParts[widget.medal.def.id]!;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final part in parts)
            _isStatic(layers, part)
                ? Image.asset(
                    'assets/medals/anim/${widget.medal.def.id}__$part.webp',
                    filterQuality: FilterQuality.medium,
                  )
                : _layer(
                    layers.firstWhere((l) => l.part == part),
                    layers.indexWhere((l) => l.part == part),
                    s,
                    center,
                  ),
        ],
      ),
    );
  }

  bool _isStatic(List<EmblemLayer> layers, String part) =>
      !layers.any((l) => l.part == part);

  /// Один живой слой. Окно (clip) режется СНАРУЖИ transform: горизонт стоит
  /// на месте, а солнце уходит за него — как clipPath эталона.
  Widget _layer(EmblemLayer l, int i, double s, Offset center) {
    Widget layer = AnimatedBuilder(
      animation: _controllers[i],
      builder: (context, child) {
        final k = _sample(l, _controllers[i].value);
        final pivotPx = center + l.pivot * s;
        Widget w = Transform(
          transform: Matrix4.identity()
            ..translate(k.dx * s, k.dy * s)
            ..translate(pivotPx.dx, pivotPx.dy)
            ..rotateZ(k.rot * math.pi / 180)
            ..translate(-pivotPx.dx, -pivotPx.dy),
          child: child,
        );
        if (k.opacity < 1) {
          w = Opacity(opacity: k.opacity.clamp(0.0, 1.0), child: w);
        }
        return w;
      },
      child: Image.asset(
        'assets/medals/anim/${widget.medal.def.id}__${l.part}.webp',
        width: widget.size,
        height: widget.size,
        filterQuality: FilterQuality.medium,
      ),
    );
    final clip = l.clip;
    if (clip != null) {
      layer = ClipRect(
        clipper: _WindowClipper(
          Rect.fromLTWH(
            center.dx + clip.left * s,
            center.dy + clip.top * s,
            clip.width * s,
            clip.height * s,
          ),
        ),
        child: layer,
      );
    }
    return layer;
  }
}

class _WindowClipper extends CustomClipper<Rect> {
  final Rect window;
  const _WindowClipper(this.window);

  @override
  Rect getClip(Size size) => window;

  @override
  bool shouldReclip(covariant _WindowClipper old) => old.window != window;
}
