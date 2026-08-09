import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/remote_content_provider.dart';
import '../util/console_bridge.dart';

/// Фон экрана/блока приложения, редактируемый из «Конструктора» (как секции сайта).
///
/// Ставит на фон ФОТО (ключ `bg.<contentKey>`) с затемнением для читабельности текста;
/// если фото не задано или «убрано» (`bgoff`=1) — показывает [fallbackColor] (штатный
/// фон). В web-сборке конструктора (CONSOLE_EDIT=1) сверху-слева появляется кнопка
/// «🖼 Фон» → та же модалка фона, что на сайте (editBg → bg.*/bgvid.*/bgoff.*).
///
/// Видео-фон пока не рисуется на стороне приложения (нужен пакет video_player) —
/// при заданном видео экран покажет [fallbackColor]. Появится отдельным шагом.
class RemoteBackground extends StatelessWidget {
  final String contentKey;
  final Widget child;
  final Color? fallbackColor;

  /// Прозрачность затемняющего слоя поверх фото (0..1) — чтобы текст читался.
  final double overlayOpacity;

  /// true (по умолчанию) — фон на весь экран (StackFit.expand, нужен ограниченный
  /// по высоте родитель, напр. body Scaffold). false — фон по размеру [child]
  /// (для секции-героя внутри прокрутки, где высота не ограничена).
  final bool expand;

  const RemoteBackground(
    this.contentKey, {
    required this.child,
    this.fallbackColor,
    this.overlayOpacity = 0.4,
    this.expand = true,
    super.key,
  });

  /// "x% y%" → Alignment (50% 50% = центр).
  Alignment _align(String focal) {
    final m = RegExp(r'^(\d{1,3})% (\d{1,3})%$').firstMatch(focal);
    if (m == null) return Alignment.center;
    final x = int.parse(m.group(1)!).clamp(0, 100);
    final y = int.parse(m.group(2)!).clamp(0, 100);
    return Alignment(x / 50 - 1, y / 50 - 1);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RemoteContentProvider>();
    final rawImg = prov.imageUrl('bg.$contentKey');
    final vid = prov.value('bgvid.$contentKey');
    final off = prov.value('bgoff.$contentKey') == '1';
    // Рисуем фото только если фон не «убран» и фото задано.
    final url = (off || rawImg.isEmpty) ? '' : rawImg;
    final boxFit =
        prov.value('bgfit.$contentKey') == 'contain' ? BoxFit.contain : BoxFit.cover;
    final align = _align(prov.value('bgfocal.$contentKey'));

    Widget bg;
    if (url.isEmpty) {
      bg = Container(color: fallbackColor);
    } else {
      final img = url.startsWith('data:')
          ? Image.network(url, fit: boxFit, alignment: align)
          : CachedNetworkImage(
              imageUrl: url,
              fit: boxFit,
              alignment: align,
              placeholder: (_, __) => Container(color: fallbackColor),
              errorWidget: (_, __, ___) => Container(color: fallbackColor),
            );
      bg = Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: img),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: overlayOpacity)),
          ),
        ],
      );
    }

    return Stack(
      fit: expand ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(child: bg),
        child,
        if (consoleEditMode)
          Positioned(
            top: 8,
            left: 8,
            child: _BgEditButton(
              onTap: () => postEditBg(
                contentKey,
                img: rawImg,
                vid: vid,
                off: off ? '1' : '',
                focal: prov.value('bgfocal.$contentKey'),
                fit: prov.value('bgfit.$contentKey') == 'contain' ? 'contain' : 'cover',
              ),
            ),
          ),
      ],
    );
  }
}

class _BgEditButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BgEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6107A57),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            '🖼 Фон',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
