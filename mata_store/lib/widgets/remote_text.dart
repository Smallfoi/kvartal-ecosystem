import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/remote_content_provider.dart';
import '../util/console_bridge.dart';

/// Текст приложения, редактируемый из «Конструктора» (мини-CMS, ключ `app.*`).
///
/// Показывает опубликованное значение по [contentKey] или [fallback], применяет
/// цвет из `color.<contentKey>` (если задан в конструкторе). В обычной сборке —
/// просто `Text`. В web-сборке конструктора (CONSOLE_EDIT=1) — кликабелен: тап
/// шлёт правку родителю (текст + текущий цвет), а блок обводится синим.
class RemoteText extends StatelessWidget {
  final String contentKey;
  final String fallback;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  /// Показывать в ВЕРХНЕМ регистре (значение хранится как есть, без учёта регистра).
  final bool upper;

  const RemoteText(
    this.contentKey,
    this.fallback, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.upper = false,
    super.key,
  });

  /// "#rrggbb"/"#rgb"/"#aarrggbb" → Color, иначе null.
  static Color? parseHex(String hex) {
    if (hex.isEmpty) return null;
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length == 6) h = 'ff$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RemoteContentProvider>();
    final value = prov.text(contentKey, fallback);
    final colorHex = prov.color(contentKey);
    final col = parseHex(colorHex);
    final effStyle = col != null ? (style ?? const TextStyle()).copyWith(color: col) : style;
    final off = prov.posOffset(contentKey); // смещение перетаскивания (прод + правка)

    final text = Text(
      upper ? value.toUpperCase() : value,
      style: effStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
    return ValueListenableBuilder<bool>(
      valueListenable: consoleEditNotifier,
      builder: (context, editing, _) {
        if (!editing) {
          // «Просмотр»/прод: применяем сохранённое смещение, тап проходит дальше.
          return off == Offset.zero ? text : Transform.translate(offset: off, child: text);
        }
        return _EditableText(
          contentKey: contentKey,
          value: value,
          colorHex: colorHex,
          baseOffset: off,
          child: text,
        );
      },
    );
  }
}

/// Режим правки одного текста: тап = правка (модалка), ПЕРЕТАСКИВАНИЕ = смещение
/// (`pos.<key>`, как drag на сайте), долгое нажатие = вернуть на место. Явная
/// подсветка, чтобы владелец видел, что элемент редактируемый и подвижный.
class _EditableText extends StatefulWidget {
  final String contentKey;
  final String value;
  final String colorHex;
  final Offset baseOffset;
  final Widget child;

  const _EditableText({
    required this.contentKey,
    required this.value,
    required this.colorHex,
    required this.baseOffset,
    required this.child,
  });

  @override
  State<_EditableText> createState() => _EditableTextState();
}

class _EditableTextState extends State<_EditableText> {
  Offset _drag = Offset.zero;
  bool _dragging = false;

  void _commit(Offset off) {
    final v = '${off.dx.round()},${off.dy.round()}';
    postDraft('pos.${widget.contentKey}', v); // в черновик конструктора → публикация
    // применяем в провайдер, чтобы baseOffset обновился и превью совпало с публикацией
    context.read<RemoteContentProvider>().applyDraft('pos.${widget.contentKey}', v);
  }

  @override
  Widget build(BuildContext context) {
    final off = widget.baseOffset + _drag;
    return Transform.translate(
      offset: off,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => postEditContent(widget.contentKey, widget.value,
            color: widget.colorHex, hasColor: widget.colorHex.isNotEmpty),
        onLongPress: () {
          _commit(Offset.zero); // вернуть на исходное место
          setState(() => _drag = Offset.zero);
        },
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (d) => setState(() => _drag += d.delta),
        onPanEnd: (_) {
          var f = widget.baseOffset + _drag;
          if (f.dx.abs() < 6 && f.dy.abs() < 6) f = Offset.zero; // магнит к исходной
          _commit(f);
          setState(() {
            _drag = Offset.zero;
            _dragging = false;
          });
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x1A0A84FF),
            border: Border.all(
              color: _dragging ? const Color(0xFFFF2D9B) : const Color(0xFF0A84FF),
              width: _dragging ? 1.8 : 1.4,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
