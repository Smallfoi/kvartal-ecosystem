import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/api/api_config.dart';
import '../../models/loyalty.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/tab_notifier.dart';
import '../../providers/wishlist_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_card.dart';
import '../auth/auth_screen.dart';
import '../loyalty/loyalty_screen.dart';
import 'order_detail_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Свежий профиль (в т.ч. единый аватар) при открытии экрана — без рестарта.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Вернулись в приложение (напр. сменили аватар в Квартале) → перечитать.
    if (state == AppLifecycleState.resumed) _refreshProfile();
  }

  void _refreshProfile() {
    if (mounted) context.read<AuthProvider>().refreshFromServer();
  }

  void _openAuth({bool register = false}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, b) => AuthScreen(startWithRegister: register),
        transitionsBuilder: (_, a, b, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            title: Text(
              'ПРОФИЛЬ',
              style: GoogleFonts.oswald(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            actions: auth.isLoggedIn
                ? [
                    // Единая шестерёнка настроек профиля (как в Квартале) — внутри
                    // редактирование, уведомления, конфиденциальность, выход.
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined, size: 22),
                      tooltip: 'Настройки',
                    ),
                  ]
                : null,
          ),
          body: Consumer<TabNotifier>(
            builder: (context, tabs, _) => KeyedSubtree(
              key: ValueKey('profile-${tabs.activationCount(3)}'),
              child: auth.isLoggedIn
                  ? _LoggedInBody(
                      user: auth.user!,
                      tab: _tab,
                      onTabChanged: (i) => setState(() => _tab = i),
                    )
                  : _GuestBody(onLogin: _openAuth),
            ),
          ),
        );
      },
    );
  }
}

// ─── Guest (not logged in) ────────────────────────────────────────────────────

class _GuestBody extends StatelessWidget {
  final void Function({bool register}) onLogin;

  const _GuestBody({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero section
          Container(
            color: Colors.black,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white54,
                    size: 32,
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOut),

                const SizedBox(height: 20),

                Text(
                  'ВОЙДИТЕ В\nАККАУНТ',
                  style: GoogleFonts.oswald(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
                    height: 1.05,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideX(begin: -0.1),

                const SizedBox(height: 10),

                const Text(
                  'Отслеживайте заказы, сохраняйте\nизбранное и получайте персональные предложения',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                    height: 1.5,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 180.ms),

                const SizedBox(height: 28),

                // Login button
                GestureDetector(
                  onTap: () => onLogin(),
                  child: Container(
                    height: 50,
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: Text(
                      'ВОЙТИ',
                      style: GoogleFonts.oswald(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: 260.ms)
                  .slideY(begin: 0.1),

                const SizedBox(height: 12),

                // Register button
                GestureDetector(
                  onTap: () => onLogin(register: true),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'СОЗДАТЬ АККАУНТ',
                      style: GoogleFonts.oswald(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 350.ms, delay: 320.ms)
                  .slideY(begin: 0.1),
              ],
            ),
          ),

          // Benefits
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _Benefit(
                  icon: Icons.local_shipping_outlined,
                  title: 'Отслеживание заказов',
                  subtitle: 'Следите за статусом доставки в реальном времени',
                  delay: 400,
                ),
                const SizedBox(height: 20),
                _Benefit(
                  icon: Icons.favorite_border,
                  title: 'Список избранного',
                  subtitle: 'Сохраняйте товары и покупайте позже',
                  delay: 480,
                ),
                const SizedBox(height: 20),
                _Benefit(
                  icon: Icons.percent,
                  title: 'Скидка 10% на первый заказ',
                  subtitle: 'Только для зарегистрированных покупателей',
                  delay: 560,
                ),
                const SizedBox(height: 20),
                _Benefit(
                  icon: Icons.notifications_none,
                  title: 'Уведомления о скидках',
                  subtitle: 'Узнавайте первыми о новых акциях',
                  delay: 640,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int delay;

  const _Benefit({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          color: AppColors.grey100,
          child: Icon(icon, size: 20, color: AppColors.black),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grey600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms, delay: Duration(milliseconds: delay))
      .slideX(begin: 0.1, curve: Curves.easeOut);
  }
}

// ─── Logged in ────────────────────────────────────────────────────────────────

class _LoggedInBody extends StatelessWidget {
  final AuthUser user;
  final int tab;
  final ValueChanged<int> onTabChanged;

  const _LoggedInBody({
    required this.user,
    required this.tab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UserHeader(user: user),
        const _LoyaltyCard(),
        const Divider(height: 1),
        _TabBar(selected: tab, onChanged: onTabChanged),
        const Divider(height: 1),
        Expanded(
          child: tab == 0 ? const _OrdersTab() : const _WishlistTab(),
        ),
      ],
    );
  }
}

// ─── Карточка баллов (вход в программу лояльности) ────────────────────────────

class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<LoyaltyProvider>(
      builder: (context, loyalty, _) {
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, a, b) => const LoyaltyScreen(),
              transitionsBuilder: (_, a, b, child) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(
                    CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 320),
            ),
          ),
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(24, 0, 20, 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded,
                      color: Colors.white, size: 26),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${loyalty.balance} баллов',
                        style: GoogleFonts.oswald(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Уровень: ${loyalty.level.label} · = ${loyalty.balance} ₽ скидки',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserHeader extends StatelessWidget {
  final AuthUser user;

  const _UserHeader({required this.user});

  String get _initials {
    final parts = user.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.grey800,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: user.avatarPath != null
                ? Image(
                    image: ApiConfig.isRemoteAvatar(user.avatarPath)
                        ? NetworkImage(ApiConfig.resolveMedia(user.avatarPath))
                        : FileImage(File(user.avatarPath!)) as ImageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(_initials,
                          style: GoogleFonts.oswald(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  )
                : Center(
                    child: Text(_initials,
                        style: GoogleFonts.oswald(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOut),

          const SizedBox(width: 16),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms)
            .slideX(begin: 0.1),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _TabBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Tab(label: 'Заказы', isSelected: selected == 0, onTap: () => onChanged(0)),
        _Tab(label: 'Избранное', isSelected: selected == 1, onTap: () => onChanged(1)),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.black : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? AppColors.black : AppColors.grey600,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orders, _) {
        if (orders.orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.receipt_long_outlined,
                    size: 56, color: AppColors.grey200),
                SizedBox(height: 12),
                Text('Заказов пока нет',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Ваши заказы появятся здесь',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.grey600)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final order = orders.orders[i];
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, a, b) =>
                      OrderDetailScreen(order: order),
                  transitionsBuilder: (_, a, b, child) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: a, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                  transitionDuration: const Duration(milliseconds: 320),
                ),
              ),
              child: _OrderCard(order: order)
                  .animate(delay: (i * 60).ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.08),
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final data = order.checkoutData;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Заказ №${order.id}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                color: AppColors.grey100,
                child: Text(
                  OrderProvider.statusLabel(order.status),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.items.length} '
            '${_plural(order.items.length)} · '
            '${order.total.toInt()} ₽',
            style: const TextStyle(
                fontSize: 13, color: AppColors.grey600),
          ),
          const SizedBox(height: 4),
          Text(
            OrderProvider.deliveryLabel(data.deliveryType),
            style: const TextStyle(
                fontSize: 12, color: AppColors.grey400),
          ),
        ],
      ),
    );
  }

  String _plural(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'товар';
    if (n % 10 >= 2 &&
        n % 10 <= 4 &&
        (n % 100 < 10 || n % 100 >= 20)) { return 'товара'; }
    return 'товаров';
  }
}

class _WishlistTab extends StatelessWidget {
  const _WishlistTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<WishlistProvider>(
      builder: (context, wishlist, _) {
        if (wishlist.ids.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.favorite_border, size: 56, color: AppColors.grey200),
                SizedBox(height: 12),
                Text(
                  'Избранное пусто',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Добавляйте понравившиеся товары',
                  style: TextStyle(fontSize: 13, color: AppColors.grey600),
                ),
              ],
            ),
          );
        }

        final products = context
            .watch<CatalogProvider>()
            .products
            .where((p) => wishlist.ids.contains(p.id))
            .toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: 0.58,
          ),
          itemCount: products.length,
          itemBuilder: (context, i) => ProductCard(product: products[i]),
        );
      },
    );
  }
}
