import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/remote_content_provider.dart';
import '../util/console_bridge.dart';
import 'remote_anim.dart';

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
    final isHidden = prov.hidden(contentKey); // скрыт в конструкторе
    final animName = prov.anim(contentKey); // пресет анимации появления

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
          // «Просмотр»/прод: скрытый элемент не показываем; иначе — со смещением + анимацией.
          if (isHidden) return const SizedBox.shrink();
          final positioned =
              off == Offset.zero ? text : Transform.translate(offset: off, child: text);
          return animatePreset(animName, positioned);
        }
        return _EditableText(
          contentKey: contentKey,
          value: value,
          colorHex: colorHex,
          baseOffset: off,
          hidden: isHidden,
          animName: animName,
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
  final bool hidden;
  final String animName;
  final Widget child;

  const _EditableText({
    required this.contentKey,
    required this.value,
    required this.colorHex,
    required this.baseOffset,
    required this.hidden,
    required this.animName,
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

  void _openSheet(BuildContext context) => showElementSheet(
        context,
        contentKey: widget.contentKey,
        animName: widget.animName,
        hidden: widget.hidden,
      );

  /// Единая кнопка «⋯» ВНУТРИ границ элемента (надёжно нажимается) → шторка действий.
  Widget _menuButton(BuildContext context, Color bg) {
    return Positioned(
      top: 0,
      right: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openSheet(context),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: const Icon(Icons.more_horiz, size: 15, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final off = widget.baseOffset + _drag;
    final built = widget.hidden ? _hiddenView(context, off) : _activeView(context, off);
    // Превью анимации появления прямо в правке (ключ по пресету → перезапуск при смене).
    return animatePreset(widget.animName, built);
  }

  // Скрытый элемент в правке — бледный «призрак»; тап/⋯ → шторка (там «Вернуть»).
  Widget _hiddenView(BuildContext context, Offset off) {
    return Transform.translate(
      offset: off,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openSheet(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: 0.35,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF9CA3AF)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: widget.child,
              ),
            ),
            _menuButton(context, const Color(0xFF16A34A)),
          ],
        ),
      ),
    );
  }

  Widget _activeView(BuildContext context, Offset off) {
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
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
            // Одна кнопка «⋯» справа-вверху ВНУТРИ границ → шторка (анимация/скрыть).
            _menuButton(context, const Color(0xFF0A84FF)),
          ],
        ),
      ),
    );
  }
}
