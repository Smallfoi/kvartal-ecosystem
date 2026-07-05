import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/remote_content_provider.dart';
import '../theme/app_theme.dart';
import '../util/console_bridge.dart';

/// Фото приложения, редактируемое из «Конструктора» (мини-CMS, ключ `app.*`).
///
/// Показывает опубликованное фото по [contentKey] (или [fallbackAsset], пока фото
/// не задано), с учётом фокус-области (`focal.<key>`) и подгона (`fit.<key>`).
/// В web-сборке конструктора (CONSOLE_EDIT=1) — кликабельно: тап открывает ту же
/// модалку фото, что и на сайте (editImage → /site-image). Публикуется под тем же
/// ключом → приложение показывает.
class RemoteImage extends StatelessWidget {
  final String contentKey;
  final String? fallbackAsset;
  final BoxFit fit;
  final double? width;
  final double? height;

  const RemoteImage(
    this.contentKey, {
    this.fallbackAsset,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  /// "x% y%" → Alignment (50% 50% = центр, 0% 0% = верх-лево).
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
    final url = prov.imageUrl(contentKey);
    final boxFit = prov.fit(contentKey) == 'contain' ? BoxFit.contain : fit;
    final align = _align(prov.focal(contentKey));

    Widget img;
    if (url.isEmpty) {
      img = (fallbackAsset != null)
          ? Image.asset(fallbackAsset!,
              fit: boxFit,
              alignment: align,
              width: width,
              height: height,
              errorBuilder: (_, __, ___) => _ph())
          : _ph();
    } else if (url.startsWith('data:')) {
      // свежая незагруженная картинка из конструктора (dataURL) — на web играет.
      img = Image.network(url,
          fit: boxFit,
          alignment: align,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _ph());
    } else {
      img = CachedNetworkImage(
        imageUrl: url,
        fit: boxFit,
        alignment: align,
        width: width,
        height: height,
        placeholder: (_, __) => Container(color: AppColors.grey100),
        errorWidget: (_, __, ___) => _ph(),
      );
    }

    if (!consoleEditMode) return img;
    final aspect = (width != null && height != null && height! > 0)
        ? width! / height!
        : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => postEditImage(
        contentKey,
        url,
        focal: prov.focal(contentKey),
        fit: prov.fit(contentKey) == 'contain' ? 'contain' : 'cover',
        aspect: aspect,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x660A84FF), width: 2),
        ),
        child: img,
      ),
    );
  }

  Widget _ph() => Container(
        width: width,
        height: height,
        color: AppColors.grey100,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, color: AppColors.grey400, size: 28),
      );
}
