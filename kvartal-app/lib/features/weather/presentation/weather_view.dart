import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/weather_provider.dart';
import 'weather_background.dart';

// ── WMO weather code → иконка / подпись ──────────────────────────────────────

IconData weatherIcon(int code, {bool isNight = false}) {
  if (code == 0) {
    return isNight ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill;
  }
  if (code <= 2) {
    return isNight ? CupertinoIcons.cloud_moon_fill : CupertinoIcons.cloud_sun_fill;
  }
  if (code == 3) return CupertinoIcons.cloud_fill;
  if (code == 45 || code == 48) return CupertinoIcons.cloud_fog_fill;
  if (code >= 51 && code <= 57) return CupertinoIcons.cloud_drizzle_fill;
  if (code >= 61 && code <= 67) return CupertinoIcons.cloud_rain_fill;
  if (code >= 71 && code <= 77) return CupertinoIcons.snow;
  if (code >= 80 && code <= 82) return CupertinoIcons.cloud_heavyrain_fill;
  if (code == 85 || code == 86) return CupertinoIcons.snow;
  if (code >= 95) return CupertinoIcons.cloud_bolt_fill;
  return CupertinoIcons.cloud_fill;
}

String weatherLabel(int code) {
  if (code == 0) return 'Ясно';
  if (code == 1) return 'Малооблачно';
  if (code == 2) return 'Переменная облачность';
  if (code == 3) return 'Пасмурно';
  if (code == 45 || code == 48) return 'Туман';
  if (code >= 51 && code <= 55) return 'Морось';
  if (code == 56 || code == 57) return 'Ледяная морось';
  if (code >= 61 && code <= 65) return 'Дождь';
  if (code == 66 || code == 67) return 'Ледяной дождь';
  if (code >= 71 && code <= 77) return 'Снег';
  if (code >= 80 && code <= 82) return 'Ливень';
  if (code == 85 || code == 86) return 'Снегопад';
  if (code == 95) return 'Гроза';
  if (code >= 96) return 'Гроза с градом';
  return '—';
}

String windCompass(int deg) {
  const points = ['С', 'СВ', 'В', 'ЮВ', 'Ю', 'ЮЗ', 'З', 'СЗ'];
  return points[(((deg + 22.5) ~/ 45) % 8)];
}

String formatTemp(double t) => '${t.round()}°C';

// ── Мини-окно с подробной погодой (по тапу на чип) ───────────────────────────

Future<void> showWeatherDetailSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WeatherDetailSheet(),
  );
}

class _WeatherDetailSheet extends ConsumerWidget {
  const _WeatherDetailSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weatherProvider);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  'Погода',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    CupertinoIcons.refresh,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => ref.invalidate(weatherProvider),
                ),
              ],
            ),
            const SizedBox(height: 4),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.electricBlue,
                  ),
                ),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Не удалось загрузить погоду.\nПроверь интернет и попробуй обновить.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              data: (w) => _WeatherBody(w),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherBody extends StatelessWidget {
  final WeatherData w;
  const _WeatherBody(this.w);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Живой анимированный баннер-«штрих» по текущему условию (солнце/облака/
        // дождь/снег/туман/гроза). Текст поверх — белый с тенью для контраста.
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                WeatherBackground(weatherCode: w.weatherCode, height: 150),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatTemp(w.tempC),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 4),
                                      Shadow(color: Colors.black54, blurRadius: 16),
                                    ],
                                  ),
                                ),
                                Text(
                                  weatherLabel(w.weatherCode),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 3),
                                      Shadow(color: Colors.black54, blurRadius: 10),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            weatherIcon(w.weatherCode, isNight: isNightNow()),
                            size: 40,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      Text(
                        'Ощущается как ${formatTemp(w.feelsLikeC)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 13,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 3),
                            Shadow(color: Colors.black54, blurRadius: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _StatTile(
              icon: CupertinoIcons.wind,
              label: 'Ветер',
              value: '${w.windSpeedKmh.round()} км/ч · ${windCompass(w.windDirDeg)}',
            ),
            _StatTile(
              icon: CupertinoIcons.cloud_rain,
              label: 'Осадки',
              value: '${w.precipProbabilityPct}%',
            ),
            _StatTile(
              icon: CupertinoIcons.drop,
              label: 'Влажность',
              value: '${w.humidityPct}%',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.snow, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Морозный бонус к баллам за бег в холод — скоро',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
