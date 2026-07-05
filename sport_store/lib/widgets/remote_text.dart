import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/remote_content_provider.dart';
import '../util/console_bridge.dart';

/// Текст приложения, редактируемый из «Конструктора» (мини-CMS, ключ `app.*`).
///
/// Показывает опубликованное значение по [contentKey] или [fallback] (текущий
/// текст). В обычной сборке — просто `Text`. В web-сборке конструктора
/// (CONSOLE_EDIT=1) — кликабелен: тап шлёт правку родителю (как клик по тексту на
/// сайте), а сам блок обводится, чтобы владелец видел, что элемент редактируемый.
class RemoteText extends StatelessWidget {
  final String contentKey;
  final String fallback;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Показывать в ВЕРХНЕМ регистре (значение хранится как есть, без учёта регистра).
  final bool upper;

  const RemoteText(
    this.contentKey,
    this.fallback, {
    this.style,
    this.maxLines,
    this.overflow,
    this.upper = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final value = context.watch<RemoteContentProvider>().text(contentKey, fallback);
    final text = Text(
      upper ? value.toUpperCase() : value,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
    if (!consoleEditMode) return text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => postEditContent(contentKey, value),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x660A84FF)),
        ),
        child: text,
      ),
    );
  }
}
