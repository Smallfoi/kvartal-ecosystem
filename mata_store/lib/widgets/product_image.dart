import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Универсальный загрузчик фото товара.
///
/// Если путь начинается с `http` — грузит из сети через [CachedNetworkImage]
/// (так будет работать с реальным backend/CDN). Иначе берёт локальный asset
/// (используется в прототипе, работает офлайн на любой сети).
class ProductImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.iconSize = 28,
  });

  bool get _isNetwork => path.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (_isNetwork) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        placeholder: (_, __) => Container(color: AppColors.grey100),
        errorWidget: (_, __, ___) => _error(),
      );
    }
    return Image.asset(
      path,
      fit: fit,
      errorBuilder: (_, __, ___) => _error(),
    );
  }

  Widget _error() => Container(
        color: AppColors.grey100,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: AppColors.grey400,
          size: iconSize,
        ),
      );
}
