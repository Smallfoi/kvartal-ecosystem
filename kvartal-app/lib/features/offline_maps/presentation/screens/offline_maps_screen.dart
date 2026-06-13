import 'dart:async' show unawaited;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/offline_maps_provider.dart';

const offlineMapOnboardingPrefsKey = 'kvartal.offline_map_onboarding_seen.v1';

class OfflineMapsScreen extends ConsumerWidget {
  final bool onboarding;

  const OfflineMapsScreen({super.key, this.onboarding = false});

  Future<void> _finish(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(offlineMapOnboardingPrefsKey, true);
    if (context.mounted) context.go('/map');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(offlineMapsProvider);
    final notifier = ref.read(offlineMapsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.bgDark,
            title: const Text(
              '\u041e\u0444\u043b\u0430\u0439\u043d-\u043a\u0430\u0440\u0442\u044b',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, onboarding ? 24 : 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IntroPanel(onboarding: onboarding),
                  if (onboarding) ...[
                    const SizedBox(height: 10),
                    _OnboardingActions(
                      status: city.status,
                      onFinish: () => _finish(context),
                      onStartDownload: () {
                        unawaited(notifier.downloadYakutsk());
                        _finish(context);
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  _CityMapCard(
                    city: city,
                    onDownload: notifier.downloadYakutsk,
                    onUpdate: notifier.updateYakutsk,
                    onDelete: notifier.deleteYakutsk,
                  ),
                  const SizedBox(height: 14),
                  const _UpcomingMapPacks(),
                  const SizedBox(height: 14),
                  _SettingsPanel(
                    allowCellular: city.allowCellularUpdates,
                    onChanged: notifier.setAllowCellularUpdates,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  final bool onboarding;

  const _IntroPanel({required this.onboarding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.cloud_download,
            color: AppColors.electricBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              onboarding
                  ? '\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0433\u043e\u0440\u043e\u0434 \u0438\u043b\u0438 \u0440\u0430\u0439\u043e\u043d \u043f\u0435\u0440\u0435\u0434 \u043f\u0435\u0440\u0432\u043e\u0439 \u043f\u0440\u043e\u0431\u0435\u0436\u043a\u043e\u0439. \u0422\u0430\u043a \u043a\u0430\u0440\u0442\u0430 \u0431\u0443\u0434\u0435\u0442 \u0433\u043e\u0442\u043e\u0432\u0430, \u0434\u0430\u0436\u0435 \u0435\u0441\u043b\u0438 \u043d\u0430 \u0443\u043b\u0438\u0446\u0435 \u043d\u0435 \u0431\u0443\u0434\u0435\u0442 \u0441\u0432\u044f\u0437\u0438.'
                  : '\u041a\u0430\u0440\u0442\u044b \u0433\u043e\u0440\u043e\u0434\u043e\u0432 \u0445\u0440\u0430\u043d\u044f\u0442\u0441\u044f \u043e\u0442\u0434\u0435\u043b\u044c\u043d\u043e \u043e\u0442 \u043f\u0440\u0438\u043b\u043e\u0436\u0435\u043d\u0438\u044f. \u0421\u043a\u0430\u0447\u0430\u0439 \u0433\u043e\u0440\u043e\u0434 \u043e\u0434\u0438\u043d \u0440\u0430\u0437, \u0438 \u043a\u0430\u0440\u0442\u0430 \u043e\u0442\u043a\u0440\u043e\u0435\u0442\u0441\u044f \u0431\u0435\u0437 \u0441\u0432\u044f\u0437\u0438.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityMapCard extends StatelessWidget {
  final OfflineCityMapState city;
  final VoidCallback onDownload;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const _CityMapCard({
    required this.city,
    required this.onDownload,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = switch (city.status) {
      OfflineMapStatus.notDownloaded =>
        '\u041d\u0435 \u0441\u043a\u0430\u0447\u0430\u043d\u0430',
      OfflineMapStatus.downloading =>
        '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 ${(city.progress * 100).clamp(0, 100).round()}%',
      OfflineMapStatus.downloaded =>
        '\u0421\u043a\u0430\u0447\u0430\u043d\u0430',
      OfflineMapStatus.failed =>
        '\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438',
    };
    final statusColor = switch (city.status) {
      OfflineMapStatus.downloaded => AppColors.success,
      OfflineMapStatus.downloading => AppColors.electricBlue,
      OfflineMapStatus.failed => AppColors.error,
      OfflineMapStatus.notDownloaded => AppColors.textTertiary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.map_pin_ellipse,
                  color: AppColors.electricBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${city.region} · ${city.estimatedSizeMb} \u041c\u0411 · z${city.minZoom}-${city.maxZoom}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (city.isDownloading) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: city.progress.clamp(0, 1),
                color: AppColors.electricBlue,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${city.downloadedTiles} / ${city.totalTiles} \u0442\u0430\u0439\u043b\u043e\u0432',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          if (city.status == OfflineMapStatus.failed &&
              city.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              city.errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: city.isDownloaded
                      ? '\u041e\u0431\u043d\u043e\u0432\u0438\u0442\u044c'
                      : '\u0421\u043a\u0430\u0447\u0430\u0442\u044c',
                  icon: city.isDownloaded
                      ? CupertinoIcons.arrow_clockwise
                      : CupertinoIcons.arrow_down_circle,
                  color: AppColors.electricBlue,
                  enabled: !city.isDownloading,
                  onTap: city.isDownloaded ? onUpdate : onDownload,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: '\u0423\u0434\u0430\u043b\u0438\u0442\u044c',
                  icon: CupertinoIcons.delete,
                  color: AppColors.bgElevated,
                  enabled: city.isDownloaded && !city.isDownloading,
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingMapPacks extends StatelessWidget {
  const _UpcomingMapPacks();

  @override
  Widget build(BuildContext context) {
    const packs = [
      (
        '\u041d\u0435\u0440\u044e\u043d\u0433\u0440\u0438',
        '\u042e\u0436\u043d\u0430\u044f \u042f\u043a\u0443\u0442\u0438\u044f',
      ),
      (
        '\u041c\u0438\u0440\u043d\u044b\u0439',
        '\u0410\u043b\u043c\u0430\u0437\u043d\u044b\u0439 \u0440\u0430\u0439\u043e\u043d',
      ),
      (
        '\u041b\u0435\u043d\u0441\u043a',
        '\u041b\u0435\u043d\u0441\u043a\u0438\u0439 \u0440\u0430\u0439\u043e\u043d',
      ),
      (
        '\u0410\u043b\u0434\u0430\u043d',
        '\u0410\u043b\u0434\u0430\u043d\u0441\u043a\u0438\u0439 \u0440\u0430\u0439\u043e\u043d',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\u0413\u043e\u0440\u043e\u0434\u0430 \u0438 \u0440\u0430\u0439\u043e\u043d\u044b',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '\u041a\u0430\u0436\u0434\u044b\u0439 \u043f\u0430\u043a\u0435\u0442 \u0441\u043a\u0430\u0447\u0438\u0432\u0430\u0435\u0442\u0441\u044f \u043e\u0442\u0434\u0435\u043b\u044c\u043d\u043e: \u0442\u043e\u043b\u044c\u043a\u043e \u0442\u0430 \u0442\u0435\u0440\u0440\u0438\u0442\u043e\u0440\u0438\u044f, \u0433\u0434\u0435 \u0447\u0435\u043b\u043e\u0432\u0435\u043a \u0431\u0435\u0433\u0430\u0435\u0442.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.25),
          ),
          const SizedBox(height: 12),
          for (final pack in packs) ...[
            _UpcomingPackTile(name: pack.$1, region: pack.$2),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _UpcomingPackTile extends StatelessWidget {
  final String name;
  final String region;

  const _UpcomingPackTile({required this.name, required this.region});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.map, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  region,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const Text(
            '\u0421\u043a\u043e\u0440\u043e',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final bool allowCellular;
  final ValueChanged<bool> onChanged;

  const _SettingsPanel({required this.allowCellular, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u041e\u0431\u043d\u043e\u0432\u043b\u044f\u0442\u044c \u043f\u043e \u0441\u043e\u0442\u043e\u0432\u043e\u0439 \u0441\u0435\u0442\u0438',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '\u041f\u043e \u0443\u043c\u043e\u043b\u0447\u0430\u043d\u0438\u044e \u043a\u0430\u0440\u0442\u044b \u043b\u0443\u0447\u0448\u0435 \u0441\u043a\u0430\u0447\u0438\u0432\u0430\u0442\u044c \u043f\u043e Wi-Fi.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: allowCellular,
            activeTrackColor: AppColors.electricBlue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _OnboardingActions extends StatelessWidget {
  final OfflineMapStatus status;
  final VoidCallback onFinish;
  final VoidCallback onStartDownload;

  const _OnboardingActions({
    required this.status,
    required this.onFinish,
    required this.onStartDownload,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloaded = status == OfflineMapStatus.downloaded;
    final isDownloading = status == OfflineMapStatus.downloading;
    final primaryLabel = isDownloaded
        ? '\u041f\u0435\u0440\u0435\u0439\u0442\u0438 \u043d\u0430 \u043a\u0430\u0440\u0442\u0443'
        : isDownloading
        ? '\u041e\u0442\u043a\u0440\u044b\u0442\u044c, \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u0432 \u0444\u043e\u043d\u0435'
        : '\u0421\u043a\u0430\u0447\u0430\u0442\u044c \u0432 \u0444\u043e\u043d\u0435 \u0438 \u043e\u0442\u043a\u0440\u044b\u0442\u044c';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActionButton(
          label: primaryLabel,
          icon: isDownloaded
              ? CupertinoIcons.check_mark_circled
              : isDownloading
              ? CupertinoIcons.arrow_right_circle
              : CupertinoIcons.cloud_download,
          color: isDownloaded ? AppColors.success : AppColors.electricBlue,
          enabled: true,
          onTap: isDownloaded || isDownloading ? onFinish : onStartDownload,
        ),
        const SizedBox(height: 8),
        _ActionButton(
          label:
              '\u041f\u043e\u0441\u043c\u043e\u0442\u0440\u0435\u0442\u044c \u0431\u0435\u0437 \u0441\u043a\u0430\u0447\u0438\u0432\u0430\u043d\u0438\u044f',
          icon: CupertinoIcons.eye,
          color: AppColors.bgElevated,
          enabled: true,
          onTap: onFinish,
        ),
        const SizedBox(height: 6),
        const Text(
          '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u043f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u0441\u044f, \u043f\u043e\u043a\u0430 \u0432\u044b \u0441\u043c\u043e\u0442\u0440\u0438\u0442\u0435 \u043f\u0440\u0438\u043b\u043e\u0436\u0435\u043d\u0438\u0435. \u041a\u0430\u0440\u0442\u0443 \u043c\u043e\u0436\u043d\u043e \u043e\u0442\u043a\u0440\u044b\u0442\u044c \u0438\u0437 \u044d\u0442\u043e\u0433\u043e \u0440\u0430\u0437\u0434\u0435\u043b\u0430 \u043f\u043e\u0437\u0436\u0435.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
