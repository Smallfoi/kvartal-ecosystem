import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/loyalty.dart';
import '../../providers/loyalty_provider.dart';
import '../../theme/app_theme.dart';

class LoyaltyScreen extends StatelessWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Consumer<LoyaltyProvider>(
        builder: (context, loyalty, _) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(loyalty: loyalty)),
              SliverToBoxAdapter(child: _LevelCard(loyalty: loyalty)),
              const SliverToBoxAdapter(child: _EarnHint()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    'ИСТОРИЯ',
                    style: GoogleFonts.oswald(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.grey600,
                    ),
                  ),
                ),
              ),
              if (loyalty.transactions.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text('Пока нет операций с баллами',
                          style: TextStyle(color: AppColors.grey600)),
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: loyalty.transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _TxnTile(tx: loyalty.transactions[i])
                          .animate(delay: (i * 30).ms)
                          .fadeIn(duration: 250.ms),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

// ─── Header с балансом ────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final LoyaltyProvider loyalty;
  const _Header({required this.loyalty});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'МОИ БАЛЛЫ',
                    style: GoogleFonts.oswald(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${loyalty.balance}',
                    style: GoogleFonts.oswald(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'баллов',
                      style: GoogleFonts.oswald(
                        fontSize: 18,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05),
              const SizedBox(height: 4),
              const Text(
                '1 балл = 1 ₽ скидки · до 30% от заказа',
                style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Карточка уровня ──────────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final LoyaltyProvider loyalty;
  const _LevelCard({required this.loyalty});

  @override
  Widget build(BuildContext context) {
    final level = loyalty.level;
    final next = level.next;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: AppColors.grey200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                'Уровень: ${level.label}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                color: AppColors.grey100,
                child: Text('кэшбэк ${level.cashbackPercent}%',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(level.perk,
              style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
          if (next != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: loyalty.levelProgress,
                minHeight: 6,
                backgroundColor: AppColors.grey200,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.black),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'До уровня «${next.label}» — ${loyalty.pointsToNextLevel} баллов',
              style: const TextStyle(fontSize: 12, color: AppColors.grey600),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.08);
  }
}

// ─── Подсказка как зарабатывать ───────────────────────────────────────────────

class _EarnHint extends StatelessWidget {
  const _EarnHint();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Бег и территории в «Квартал»', Icons.directions_run),
      ('Покупки: +1 балл за каждые 10 ₽', Icons.shopping_bag_outlined),
      ('Отзыв с фото: +10 баллов', Icons.rate_review_outlined),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.all(14),
      color: AppColors.grey100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('КАК ЗАРАБОТАТЬ БАЛЛЫ',
              style: GoogleFonts.oswald(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.grey600)),
          const SizedBox(height: 10),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(it.$2, size: 16, color: AppColors.black),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(it.$1,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.black)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Строка истории ───────────────────────────────────────────────────────────

class _TxnTile extends StatelessWidget {
  final LoyaltyTransaction tx;
  const _TxnTile({required this.tx});

  IconData get _icon {
    if (tx.source.isRunner) return Icons.directions_run;
    switch (tx.source) {
      case LoyaltySource.purchase:
        return Icons.shopping_bag_outlined;
      case LoyaltySource.redeem:
        return Icons.remove_circle_outline;
      case LoyaltySource.review:
        return Icons.rate_review_outlined;
      default:
        return Icons.card_giftcard_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tx.source.isRunner ? AppColors.black : AppColors.grey100,
            ),
            child: Icon(_icon,
                size: 18,
                color: tx.source.isRunner ? Colors.white : AppColors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_date(tx.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.grey400)),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}${tx.amount}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: positive ? const Color(0xFF2E7D32) : AppColors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime dt) {
    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}
