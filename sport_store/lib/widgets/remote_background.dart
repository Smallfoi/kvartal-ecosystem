import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../data/api/api_config.dart';
import '../providers/remote_content_provider.dart';
import '../util/console_bridge.dart';

/// Фон экрана/блока приложения, редактируемый из «Конструктора» (как секции сайта).
///
/// Приоритет: ВИДЕО (`bgvid.<k>`) → ФОТО (`bg.<k>`) → [fallbackColor] (штатный фон),
/// с затемнением для читабельности текста. «Убрать» (`bgoff`=1) → штатный фон.
/// Видео проигрывается зациклённо, без звука, «cover». В web-сборке конструктора
/// (CONSOLE_EDIT=1) сверху-слева — кнопка «🖼 Фон» → та же модалка фона, что на сайте
/// (editBg → bg.*/bgvid.*/bgoff.*).
class RemoteBackground extends StatelessWidget {
  final String contentKey;
  final Widget child;
  final Color? fallbackColor;

  /// Прозрачность затемняющего слоя поверх фото/видео (0..1) — чтобы текст читался.
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
    final rawVid = prov.value('bgvid.$contentKey');
    final off = prov.value('bgoff.$contentKey') == '1';
    // Приоритет видео > фото; «убрано» гасит всё.
    final vidUrl = (off || rawVid.isEmpty) ? '' : ApiConfig.resolveMedia(rawVid);
    final imgUrl = (off || vidUrl.isNotEmpty || rawImg.isEmpty) ? '' : rawImg;
    final boxFit =
        prov.value('bgfit.$contentKey') == 'contain' ? BoxFit.contain : BoxFit.cover;
    final align = _align(prov.value('bgfocal.$contentKey'));

    Widget bg;
    if (vidUrl.isNotEmpty) {
      bg = Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _BgVideo(url: vidUrl, fit: boxFit)),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: overlayOpacity)),
          ),
        ],
      );
    } else if (imgUrl.isNotEmpty) {
      final img = imgUrl.startsWith('data:')
          ? Image.network(imgUrl, fit: boxFit, alignment: align)
          : CachedNetworkImage(
              imageUrl: imgUrl,
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
    } else {
      bg = Container(color: fallbackColor);
    }

    return ValueListenableBuilder<bool>(
      valueListenable: consoleEditNotifier,
      builder: (context, editing, _) => Stack(
        fit: expand ? StackFit.expand : StackFit.loose,
        children: [
          Positioned.fill(child: bg),
          child,
          if (editing)  // кнопка «Фон» только в режиме правки
            Positioned(
              top: 8,
              left: 8,
              child: _BgEditButton(
                onTap: () => postEditBg(
                  contentKey,
                  img: rawImg,
                  vid: rawVid,
                  off: off ? '1' : '',
                  focal: prov.value('bgfocal.$contentKey'),
                  fit: prov.value('bgfit.$contentKey') == 'contain' ? 'contain' : 'cover',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Фоновое видео: зациклённо, без звука, автоплей, «cover» через FittedBox.
class _BgVideo extends StatefulWidget {
  final String url;
  final BoxFit fit;
  const _BgVideo({required this.url, this.fit = BoxFit.cover});

  @override
  State<_BgVideo> createState() => _BgVideoState();
}

class _BgVideoState extends State<_BgVideo> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_BgVideo old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _stop();
      _start();
    }
  }

  void _start() {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    c
      ..setLooping(true)
      ..setVolume(0);
    c.initialize().then((_) {
      if (!mounted || _c != c) return;
      c.play();
      setState(() {});
    }).catchError((_) {
      // битый URL/формат — остаётся прозрачный слой (снизу fallbackColor)
    });
  }

  void _stop() {
    _c?.dispose();
    _c = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return const SizedBox.expand();
    return ClipRect(
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: c.value.size.width,
          height: c.value.size.height,
          child: VideoPlayer(c),
        ),
      ),
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
