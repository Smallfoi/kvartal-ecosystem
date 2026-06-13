import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../providers/cart_provider.dart';
import '../providers/tab_notifier.dart';
import '../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell shell;

  const MainShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.grey200, width: 1)),
        ),
        child: Consumer<CartProvider>(
          builder: (context, cart, _) {
            return BottomNavigationBar(
              currentIndex: shell.currentIndex,
              onTap: (index) {
                context.read<TabNotifier>().switchTo(index);
                shell.goBranch(
                  index,
                  initialLocation: index == shell.currentIndex,
                );
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Главная',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_outlined),
                  activeIcon: Icon(Icons.grid_view),
                  label: 'Каталог',
                ),
                BottomNavigationBarItem(
                  icon: badges.Badge(
                    showBadge: cart.itemCount > 0,
                    badgeContent: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    badgeStyle: const badges.BadgeStyle(
                      badgeColor: AppColors.black,
                      padding: EdgeInsets.all(4),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                  activeIcon: badges.Badge(
                    showBadge: cart.itemCount > 0,
                    badgeContent: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    badgeStyle: const badges.BadgeStyle(
                      badgeColor: AppColors.black,
                      padding: EdgeInsets.all(4),
                    ),
                    child: const Icon(Icons.shopping_bag),
                  ),
                  label: 'Корзина',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Профиль',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
