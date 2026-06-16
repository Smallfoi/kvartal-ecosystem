import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/location_access.dart';
import '../data/location_access_provider.dart';

/// Показать экран настройки доступа к геолокации (онбординг/исправление).
Future<void> showLocationSetupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _LocationSetupSheet(),
  );
}

class _LocationSetupSheet extends ConsumerWidget {
  const _LocationSetupSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(locationAccessProvider);
    final notifier = ref.read(locationAccessProvider.notifier);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final foregroundDone = st.canRun;
    final alwaysDone = st.backgroundReady;
    final batteryDone = st.batteryUnrestricted;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.location_fill,
                  color: AppColors.electricBlue,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Доступ к геолокации',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'КВАРТАЛ записывает маршрут пробежки, в том числе когда экран выключен '
              'или приложение свёрнуто. Для этого нужен доступ к геолокации '
              '«Разрешить всё время». Без него трек прервётся, как только вы '
              'заблокируете экран, и территория не засчитается.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),

            _Step(
              index: 1,
              title: 'Доступ к геолокации',
              subtitle: 'Базовое разрешение, чтобы вести маршрут.',
              done: foregroundDone,
              actionLabel: 'Разрешить',
              onTap: foregroundDone ? null : notifier.requestWhenInUse,
            ),
            const SizedBox(height: 10),
            _Step(
              index: 2,
              title: 'Фон: «Разрешить всё время»',
              subtitle: alwaysDone
                  ? 'Фоновый трекинг включён.'
                  : 'Чтобы трек шёл с заблокированным экраном. На некоторых '
                        'телефонах нужно выбрать вручную в настройках.',
              done: alwaysDone,
              actionLabel: foregroundDone ? 'Включить' : 'Сначала шаг 1',
              onTap: (!foregroundDone || alwaysDone)
                  ? null
                  : () async {
                      await notifier.requestAlways();
                      if (!context.mounted) return;
                      if (!ref.read(locationAccessProvider).backgroundReady) {
                        await notifier.openSettings();
                      }
                    },
            ),
            const SizedBox(height: 10),
            _Step(
              index: 3,
              title: 'Не экономить батарею',
              subtitle: batteryDone
                  ? 'Система не будет «усыплять» трекинг.'
                  : 'Иначе система может остановить запись в фоне.',
              done: batteryDone,
              actionLabel: 'Отключить экономию',
              onTap: batteryDone ? null : notifier.requestBattery,
            ),

            if (st.aggressiveOem) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Этот телефон агрессивно ограничивает фон',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      oemBackgroundHint(st.manufacturer),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: notifier.openSettings,
                      child: Text(
                        'Открыть настройки приложения →',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.electricBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(st.fullyReady ? 'Готово' : 'Позже'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int index;
  final String title, subtitle, actionLabel;
  final bool done;
  final VoidCallback? onTap;

  const _Step({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.separator,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.electricBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: done
                ? const Icon(
                    CupertinoIcons.check_mark,
                    color: AppColors.success,
                    size: 16,
                  )
                : Text(
                    '$index',
                    style: const TextStyle(
                      color: AppColors.electricBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (!done && onTap != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onTap,
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Предупреждение на экране бега, если фон не готов (постоянное, по требованию владельца).
class LocationWarningBanner extends ConsumerWidget {
  const LocationWarningBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(locationAccessProvider);
    if (!st.loaded || st.fullyReady) return const SizedBox.shrink();

    final denied = !st.canRun;
    final title = denied
        ? 'Нет доступа к геолокации'
        : !st.backgroundReady
        ? 'Фоновый трекинг выключен'
        : 'Возможна остановка в фоне';
    final subtitle = denied
        ? 'Без геолокации маршрут не записать.'
        : !st.backgroundReady
        ? 'Включите «Разрешить всё время», иначе трек прервётся при блокировке экрана.'
        : 'Отключите экономию батареи, чтобы запись не останавливалась.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => showLocationSetupSheet(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.location_slash_fill,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.chevron_right,
                color: AppColors.warning,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
