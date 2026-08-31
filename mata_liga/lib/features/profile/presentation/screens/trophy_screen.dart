import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../celebration/medal_ceremony.dart';
import '../../../loyalty/data/loyalty_provider.dart';
import '../../../run/data/completed_runs_provider.dart';
import '../../data/badge_defs.dart';

/// Трофейный зал (Ф4 «Статус бегуна», утверждено 31.08.2026).
///
/// Медали — плиты; открытые лаймовые, закрытые показывают полосу прогресса.
/// Тап по открытой — повтор церемонии (Вариант A). Накопленное не отнимается.
class TrophyScreen extends ConsumerWidget {
  const TrophyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(completedRunsProvider);
    final loyalty = ref.watch(loyaltyProvider);
    final facts = BadgeFacts.fromRuns(runs, balance: loyalty.balance);
    final unlockedCount = kBadgeDefs.where((d) => d.unlocked(facts)).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Трофейный зал'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Открыто $unlockedCount из ${kBadgeDefs.length} · '
                'накопленное не отнимается',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            for (final def in kBadgeDefs) ...[
              _TrophyRow(def: def, facts: facts),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrophyRow extends StatelessWidget {
  final BadgeDef def;
  final BadgeFacts facts;

  const _TrophyRow({required this.def, required this.facts});

  @override
  Widget build(BuildContext context) {
    final unlocked = def.unlocked(facts);
    final (cur, target) = def.progress(facts);
    final frac = (cur / target).clamp(0.0, 1.0);

    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppTheme.rSm),
      child: InkWell(
        onTap: unlocked ? () => showMedalCeremony(context, badge: def) : null,
        borderRadius: BorderRadius.circular(AppTheme.rSm),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.rSm),
            border: Border.all(
              color: unlocked ? AppColors.limeDeep : AppColors.line,
            ),
          ),
          child: Row(
            children: [
              // Плита медали.
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlocked ? AppColors.lime : AppColors.soft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  def.icon,
                  size: 24,
                  color: unlocked
                      ? const Color(0xFF171C19)
                      : AppColors.disabled,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontDisplay,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      def.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.muted,
                      ),
                    ),
                    if (!unlocked) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 5,
                          backgroundColor: AppColors.soft,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.limeDeep,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _progressLabel(cur, target),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.faint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (unlocked) ...[
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.play_circle,
                  size: 20,
                  color: AppColors.accentInk,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _progressLabel(double cur, double target) {
    String f(double v) => v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return '${f(cur.clamp(0, target))} из ${f(target)}';
  }
}
