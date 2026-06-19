import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/shoes_provider.dart';

/// Спрашиваем по каждой купленной паре: «Добавить кроссовки в приложение?» (Да/Нет).
/// Вызывается при открытии приложения (из MainScaffold), а не только на экране кроссовок.
Future<void> promptPendingShoes(BuildContext context, WidgetRef ref) async {
  final pending = [...ref.read(shoesProvider).pending];
  for (final shoe in pending) {
    if (!context.mounted) break;
    final add = await showAddShoeDialog(context, shoe);
    if (add == null) break; // закрыл без ответа — спросим в следующий раз
    final ok =
        await ref.read(shoesProvider.notifier).confirm(shoeId: shoe.id, add: add);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет связи — попробуйте позже')),
      );
      break;
    }
  }
}

/// Диалог «Добавить кроссовки в приложение?» с фото товара. true=Да, false=Нет, null=закрыл.
Future<bool?> showAddShoeDialog(BuildContext context, ShoeAsset shoe) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Добавить кроссовки?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PromptImage(url: shoe.imageUrl),
          const SizedBox(height: 12),
          Text(
            shoe.model,
            textAlign: TextAlign.center,
            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавить эти кроссовки в приложение?',
            textAlign: TextAlign.center,
            style: Theme.of(ctx)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Нет',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Да'),
        ),
      ],
    ),
  );
}

class _PromptImage extends StatelessWidget {
  final String url;
  const _PromptImage({required this.url});

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.electricBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.directions_run,
          color: AppColors.electricBlue, size: 44),
    );
    if (!url.startsWith('http')) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
