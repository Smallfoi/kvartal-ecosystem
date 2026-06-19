import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../features/shoes/data/shoes_provider.dart';
import '../../features/shoes/presentation/shoe_prompt.dart';
import 'kvartal_logo.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  // Спрашиваем про новые покупки один раз за запуск приложения.
  bool _askedPending = false;
  bool _asking = false;

  int _locationToIndex(String location) {
    if (location.startsWith('/map')) return 0;
    if (location.startsWith('/run')) return 1;
    if (location.startsWith('/leaderboard')) return 2;
    if (location.startsWith('/club')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    const routes = ['/map', '/run', '/leaderboard', '/club', '/profile'];
    context.go(routes[index]);
  }

  /// При открытии приложения, как только подгрузились купленные кроссовки,
  /// всплывает окно «Добавить кроссовки в приложение?» — глобально, на любом табе.
  Future<void> _maybeAskPending() async {
    if (_askedPending || _asking) return;
    final st = ref.read(shoesProvider);
    if (!st.loaded || st.pending.isEmpty) return;
    _asking = true;
    _askedPending = true;
    await promptPendingShoes(context, ref);
    _asking = false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskPending());
  }

  @override
  Widget build(BuildContext context) {
    // Новые покупки могли подгрузиться позже первого кадра — реагируем на это.
    ref.listen<ShoesState>(shoesProvider, (_, __) => _maybeAskPending());

    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _KvartalNavBar(
        currentIndex: currentIndex,
        onTap: (i) => _onTap(context, i),
      ),
    );
  }
}

class _KvartalNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _KvartalNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glass,
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.10),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  _NavItem(
                    icon: CupertinoIcons.map,
                    activeIcon: CupertinoIcons.map_fill,
                    label: AppStrings.tabMap,
                    isActive: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    activeIcon: CupertinoIcons.chart_bar_alt_fill,
                    label: AppStrings.tabLeaderboard,
                    isActive: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  _RunNavItem(
                    isActive: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: CupertinoIcons.person_2,
                    activeIcon: CupertinoIcons.person_2_fill,
                    label: AppStrings.tabClub,
                    isActive: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                  _NavItem(
                    icon: CupertinoIcons.person,
                    activeIcon: CupertinoIcons.person_fill,
                    label: AppStrings.tabProfile,
                    isActive: currentIndex == 4,
                    onTap: () => onTap(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Центральная кнопка «Бег» ──────────────────────────────────────────────────

class _RunNavItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _RunNavItem({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.electricBlue
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: KvartalLogoMark(
                  size: 24,
                  animated: isActive,
                  glow: false,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              AppStrings.tabRun,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? AppColors.electricBlue
                    : Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Обычный таб ───────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.electricBlue
        : Colors.white.withValues(alpha: 0.45);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: color,
                size: 23,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
