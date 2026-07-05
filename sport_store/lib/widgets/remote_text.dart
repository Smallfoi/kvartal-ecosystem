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

    final text = Text(
      upper ? value.toUpperCase() : value,
      style: effStyle,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
    if (!consoleEditMode) return text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => postEditContent(contentKey, value,
          color: colorHex, hasColor: colorHex.isNotEmpty),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x660A84FF)),
        ),
        child: text,
      ),
    );
  }
}
