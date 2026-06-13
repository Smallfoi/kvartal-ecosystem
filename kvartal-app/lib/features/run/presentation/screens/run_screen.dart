import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../map/data/zone_provider.dart';
import '../../data/run_provider.dart';
import '../../data/completed_runs_provider.dart';
import '../../../../shared/widgets/kvartal_logo.dart';

class RunScreen extends ConsumerWidget {
  const RunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(runProvider);
    return runState.status == RunStatus.idle
        ? _IdleView(runState: runState)
        : _ActiveRunView(runState: runState);
  }
}

// ── Экран до начала тренировки ─────────────────────────────────────────────

class _IdleView extends ConsumerWidget {
  final RunState runState;
  const _IdleView({required this.runState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentRuns = ref.watch(completedRunsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RunHeader(),
              const SizedBox(height: 20),
              _QuickStatsRow(),
              const SizedBox(height: 20),
              _StartCard(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Цели на неделю',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '42%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _WeeklyGoalCard(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Последние пробежки',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Все',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (recentRuns.isEmpty)
                const _EmptyRunsHint()
              else
                ...recentRuns.take(3).map((r) => _RunTile(run: r)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'КВАРТАЛ',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Якутск · территория ждёт',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.separator),
          ),
          child: const Center(child: KvartalLogoMark(size: 34)),
        ),
      ],
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _QuickStat(
          icon: CupertinoIcons.flame_fill,
          value: '5.4',
          label: 'км сегодня',
          color: AppColors.error,
        ),
        SizedBox(width: 10),
        _QuickStat(
          icon: CupertinoIcons.bolt_fill,
          value: '7',
          label: 'дней подряд',
          color: AppColors.warning,
        ),
        SizedBox(width: 10),
        _QuickStat(
          icon: CupertinoIcons.location_fill,
          value: '12',
          label: 'зон моих',
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
          onTap: () => ref.read(runProvider.notifier).start(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A2722), Color(0xFF121210)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Готов бежать?',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Замкни маршрут. Забери квартал.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.play_fill,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'НАЧАТЬ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.28),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.warning.withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(child: KvartalLogoMark(size: 58)),
                ),
              ],
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.015,
          duration: 2200.ms,
          curve: Curves.easeInOut,
        );
  }
}

// ── Экран активной тренировки ──────────────────────────────────────────────

class _ActiveRunView extends ConsumerWidget {
  final RunState runState;
  const _ActiveRunView({required this.runState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(runProvider.notifier);
    final isActive = runState.status == RunStatus.active;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  _StatusBadge(isActive: isActive),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showStopDialog(context, ref),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.separator),
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              Text(
                runState.distanceKm.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 84,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1,
                  letterSpacing: -4,
                ),
              ),
              const Text(
                'КМ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.separator),
                ),
                child: Row(
                  children: [
                    _MetricTile(
                      label: 'ВРЕМЯ',
                      value: runState.elapsedFormatted,
                    ),
                    _MetricDivider(),
                    _MetricTile(
                      label: 'ТЕМП',
                      value: '${runState.paceFormatted}/км',
                    ),
                    _MetricDivider(),
                    const _MetricTile(label: 'ЗОНЫ', value: '+0'),
                  ],
                ),
              ),
              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RunControlButton(
                    icon: isActive
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    color: isActive ? AppColors.warning : AppColors.success,
                    onTap: () =>
                        isActive ? notifier.pause() : notifier.resume(),
                  ),
                  const SizedBox(width: 24),
                  _RunControlButton(
                    icon: CupertinoIcons.stop_fill,
                    color: AppColors.error,
                    onTap: () => _showStopDialog(context, ref),
                    size: 72,
                  ),
                  const SizedBox(width: 24),
                  _RunControlButton(
                    icon: CupertinoIcons.map,
                    color: AppColors.warning,
                    onTap: () => context.go('/map'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showStopDialog(BuildContext context, WidgetRef ref) {
    final run = ref.read(runProvider);
    final zoneNotifier = ref.read(zoneProvider.notifier);
    final closure = zoneNotifier.inspectLoopClosure(run.route);
    final canCapture = closure.canCapture;
    final gap = closure.gapMeters.round();
    final distance = run.distanceKm.toStringAsFixed(2);
    final captureHint = canCapture
        ? 'Контур замкнут по GPS. Подтверди захват территории.'
        : closure.hasEnoughDistance
        ? 'До стартовой точки по GPS: $gap м. Для захвата нужно вернуться в радиус 20 м.'
        : 'Маршрут слишком короткий для захвата. Минимальный периметр: 50 м.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          canCapture ? 'Захватить территорию?' : 'Завершить пробежку?',
        ),
        content: Text(
          'Дистанция: $distance км\n'
          'Время: ${run.elapsedFormatted}\n'
          'До старта: $gap м\n'
          '$captureHint',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Продолжить'),
          ),
          if (!canCapture)
            TextButton(
              onPressed: () {
                ref.read(runProvider.notifier).stop();
                Navigator.pop(ctx);
                context.go('/map');
              },
              child: const Text('Завершить без захвата'),
            ),
          FilledButton(
            onPressed: canCapture
                ? () {
                    final captured = zoneNotifier.checkAndCaptureLoop(
                      run.route,
                    );
                    ref
                        .read(runProvider.notifier)
                        .stop(
                          capturedZones: captured.length,
                          capturedTerritory: true,
                        );
                    Navigator.pop(ctx);
                    context.go('/map');
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.electricBlue,
              disabledBackgroundColor: AppColors.bgElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Захватить'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 0.6,
                end: 1.5,
                duration: 700.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'ЗАПИСЬ' : 'ПАУЗА',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label, value;
  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.separator);
}

class _RunControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  const _RunControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.42),
      ),
    );
  }
}

// ── Run history widgets ───────────────────────────────────────────────────

class _EmptyRunsHint extends StatelessWidget {
  const _EmptyRunsHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: const Text(
        'Завершённые пробежки появятся здесь после первого старта.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const current = 16.7;
    const goal = 40.0;
    final progress = current / goal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${current.toStringAsFixed(1)} км',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'из ${goal.toStringAsFixed(0)} км',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.bgElevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.electricBlue),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Осталось ${(goal - current).toStringAsFixed(1)} км до цели',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  final CompletedRun run;
  const _RunTile({required this.run});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.electricBlue.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.location_north_fill,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.dateLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                Text(' км', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                run.elapsedFormatted,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '${run.paceFormatted} /км',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
