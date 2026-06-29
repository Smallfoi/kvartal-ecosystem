import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_provider.dart';
import '../../../loyalty/data/loyalty_provider.dart';
import '../../../notifications/data/notifications_provider.dart';
import '../../../run/data/completed_runs_provider.dart';
import '../../../shoes/data/shoes_provider.dart';
import '../../../territory/data/territory_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // При показе профиля тянем баланс/обувь И свежий профиль (единый аватар).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loyaltyProvider.notifier).refresh();
      ref.read(shoesProvider.notifier).refresh();
      ref.read(authProvider.notifier).restoreSession();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Вернулись в приложение → перечитать профиль (аватар мог смениться в другом).
    if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).restoreSession();
      ref.read(loyaltyProvider.notifier).refresh();
    }
  }

  /// Pull-to-refresh: тянем баланс/профиль/статистику с бэка прямо на экране.
  /// (обновление между переходами экранов остаётся — это в дополнение к нему).
  Future<void> _refresh() async {
    ref.invalidate(footprintAreaProvider);
    await Future.wait([
      ref.read(loyaltyProvider.notifier).refresh(),
      ref.read(shoesProvider.notifier).refresh(),
      ref.read(authProvider.notifier).restoreSession(),
      ref.read(completedRunsProvider.notifier).load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.electricBlue,
        backgroundColor: AppColors.bgCard,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _ProfileAppBar(user: user),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PointsCard(),
                    const SizedBox(height: 12),
                    const _StatsRow(),
                    const SizedBox(height: 12),
                    const _FootprintCard(),
                    const SizedBox(height: 12),
                    const _ShoesCard(),
                    const SizedBox(height: 12),
                    const _ToolsCard(),
                    const SizedBox(height: 12),
                    _AccountCard(user: user),
                    const SizedBox(height: 24),
                    Text(
                      'Достижения',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _BadgesGrid(),
                    const SizedBox(height: 24),
                    Text(
                      'Активность',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _ActivityHeatmap(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsBell extends StatelessWidget {
  final int unread;
  const _NotificationsBell({required this.unread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Уведомления',
          icon: const Icon(CupertinoIcons.bell, size: 20),
          onPressed: () => context.push('/profile/notifications'),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.bgDark, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileAppBar extends ConsumerWidget {
  final AuthUser? user;
  const _ProfileAppBar({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name
        : 'Бегун КВАРТАЛ';
    final city = user?.city?.trim().isNotEmpty == true
        ? user!.city!
        : 'Город не выбран';

    return SliverAppBar(
      expandedHeight: 228,
      pinned: true,
      backgroundColor: AppColors.bgDark,
      actions: [
        _NotificationsBell(unread: ref.watch(notificationsProvider).unread),
        IconButton(
          tooltip: 'Настройки',
          icon: const Icon(CupertinoIcons.settings, size: 20),
          onPressed: () => context.push('/profile/settings'),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A1628), AppColors.bgDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => context.push('/profile/edit'),
                  child: Stack(
                    children: [
                      _Avatar(name: name, size: 84, avatarPath: user?.avatarPath),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppColors.electricBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.pencil,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gradientStart, AppColors.gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    city,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: Text(
        '\u041f\u0440\u043e\u0444\u0438\u043b\u044c',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;

  /// Единый аватар экосистемы (URL с сервера) — если задан, рисуем фото.
  final String? avatarPath;

  const _Avatar({required this.name, required this.size, this.avatarPath});

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  bool get _hasPhoto {
    final p = avatarPath;
    return p != null && (p.startsWith('http') || p.startsWith('/media'));
  }

  Widget _initialsCircle() => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.electricBlue.withValues(alpha: 0.2),
      border: Border.all(
        color: AppColors.electricBlue.withValues(alpha: 0.5),
        width: 2,
      ),
    ),
    child: Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: AppColors.electricBlue,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!_hasPhoto) return _initialsCircle();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.electricBlue.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          ApiConfig.resolveMedia(avatarPath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsCircle(),
        ),
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final AuthUser? user;
  const _AccountCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Аккаунт',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Редактировать',
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(CupertinoIcons.pencil, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _InfoLine(
            icon: CupertinoIcons.phone,
            label: 'Телефон',
            value: user?.phone ?? 'Не указан',
          ),
          _InfoLine(
            icon: CupertinoIcons.mail,
            label: 'Email',
            value:
                (user?.email.isNotEmpty == true &&
                    !user!.email.endsWith('@kvartal.local'))
                ? user!.email
                : '\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d',
          ),
          _InfoLine(
            icon: CupertinoIcons.location,
            label: '\u0413\u043e\u0440\u043e\u0434',
            value: user?.city?.isNotEmpty == true
                ? user!.city!
                : '\u041d\u0435 \u0443\u043a\u0430\u0437\u0430\u043d',
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _cityCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(
      text: user?.name == 'Runner' ? '' : user?.name ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: user?.phone ?? ref.read(authProvider).phone,
    );
    _emailCtrl = TextEditingController(
      text: user?.email.endsWith('@kvartal.local') == true
          ? ''
          : user?.email ?? '',
    );
    _cityCtrl = TextEditingController(text: user?.city ?? 'Якутск');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(
        () => _error =
            '\u0412\u0432\u0435\u0434\u0438 \u0438\u043c\u044f \u0438\u043b\u0438 \u043d\u0438\u043a',
      );
      return;
    }

    final ok = await ref
        .read(authProvider.notifier)
        .updateProfile(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      context.pop();
    } else {
      setState(
        () => _error =
            ref.read(authProvider).error ?? 'Не удалось сохранить профиль',
      );
    }
  }

  Future<void> _pickAvatar() async {
    final hasPhoto = (ref.read(authProvider).user?.avatarPath ?? '').isNotEmpty;
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Фото профиля'),
        message: const Text('Один аватар для всех приложений экосистемы STAW.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'upload'),
            child: Text(hasPhoto ? 'Сменить фото' : 'Загрузить фото'),
          ),
          if (hasPhoto)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx, 'remove'),
              child: const Text('Убрать фото'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (action == 'upload') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        await ref.read(authProvider.notifier).uploadAvatar(picked.path);
      }
    } else if (action == 'remove') {
      await ref.read(authProvider.notifier).removeAvatar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Редактировать профиль'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: auth.isLoading ? null : _pickAvatar,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _Avatar(
                        name: _nameCtrl.text.trim().isEmpty
                            ? 'КВАРТАЛ'
                            : _nameCtrl.text,
                        size: 92,
                        avatarPath: auth.user?.avatarPath,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.electricBlue,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.bgDark,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.camera_fill,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _EditField(
                controller: _nameCtrl,
                label: 'Имя, фамилия или ник',
                icon: CupertinoIcons.person,
              ),
              const SizedBox(height: 12),
              _EditField(
                controller: _phoneCtrl,
                label: '\u0422\u0435\u043b\u0435\u0444\u043e\u043d',
                icon: CupertinoIcons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _EditField(
                controller: _emailCtrl,
                label: 'Email',
                icon: CupertinoIcons.mail,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _EditField(
                controller: _cityCtrl,
                label: '\u0413\u043e\u0440\u043e\u0434',
                icon: CupertinoIcons.location,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: auth.isLoading ? null : _save,
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.separator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.separator),
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Настройки'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsTile(
              icon: CupertinoIcons.person_crop_circle,
              label: '\u041f\u0440\u043e\u0444\u0438\u043b\u044c',
              onTap: () => context.push('/profile/edit'),
            ),
            _SettingsTile(
              icon: CupertinoIcons.location_solid,
              label:
                  '\u0413\u0435\u043e\u043b\u043e\u043a\u0430\u0446\u0438\u044f \u0438 \u0444\u043e\u043d\u043e\u0432\u044b\u0439 \u0440\u0435\u0436\u0438\u043c',
              onTap: () => context.push('/run/location-access'),
            ),
            _SettingsTile(
              icon: CupertinoIcons.bell_fill,
              label:
                  '\u0423\u0432\u0435\u0434\u043e\u043c\u043b\u0435\u043d\u0438\u044f',
              onTap: () => context.push('/profile/notifications'),
            ),
            _SettingsTile(
              icon: CupertinoIcons.lock_fill,
              label:
                  '\u041a\u043e\u043d\u0444\u0438\u0434\u0435\u043d\u0446\u0438\u0430\u043b\u044c\u043d\u043e\u0441\u0442\u044c \u0438 \u0434\u0430\u043d\u043d\u044b\u0435',
              onTap: () => context.push('/profile/privacy'),
            ),
            _SettingsTile(
              icon: CupertinoIcons.question_circle_fill,
              label: '\u041f\u043e\u0434\u0434\u0435\u0440\u0436\u043a\u0430',
              onTap: () {},
            ),
            _SettingsTile(
              icon: CupertinoIcons.info_circle_fill,
              label:
                  '\u041e \u043f\u0440\u0438\u043b\u043e\u0436\u0435\u043d\u0438\u0438',
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _SettingsTile(
              icon: CupertinoIcons.square_arrow_right,
              label:
                  '\u0412\u044b\u0439\u0442\u0438 \u0438\u0437 \u0430\u043a\u043a\u0430\u0443\u043d\u0442\u0430',
              destructive: true,
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/auth/phone');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.separator),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
        trailing: const Icon(
          CupertinoIcons.chevron_right,
          color: AppColors.textDisabled,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PointsCard extends ConsumerWidget {
  const _PointsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loyalty = ref.watch(loyaltyProvider);

    return GestureDetector(
      onTap: () => context.push('/profile/points'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A1628), AppColors.bgCard],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.electricBlue.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.star_fill,
                color: AppColors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Баллы экосистемы',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loyalty.isLoading && !loyalty.loaded
                        ? '…'
                        : '${loyalty.balance}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                loyalty.levelTitle,
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Источник баллов → иконка и подпись для истории.
({IconData icon, String label}) _loyaltySourceMeta(String source) {
  switch (source) {
    case 'runnerRun':
      return (icon: Icons.directions_run, label: 'Пробежка');
    case 'runnerTerritory':
      return (icon: CupertinoIcons.flag_fill, label: 'Захват территории');
    case 'runnerCompetition':
      return (icon: Icons.emoji_events, label: 'Соревнование');
    case 'registration':
      return (icon: CupertinoIcons.gift_fill, label: 'Бонус');
    case 'purchase':
      return (icon: CupertinoIcons.bag_fill, label: 'Покупка');
    case 'redeem':
      return (icon: CupertinoIcons.minus_circle, label: 'Списание');
    default:
      return (icon: CupertinoIcons.star_fill, label: 'Баллы');
  }
}

String _formatTxnDate(String? iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

/// История баллов экосистемы (за что начислено/списано). Открывается тапом по карточке.
class PointsHistoryScreen extends ConsumerStatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  ConsumerState<PointsHistoryScreen> createState() =>
      _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends ConsumerState<PointsHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(loyaltyProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loyalty = ref.watch(loyaltyProvider);
    final txns = loyalty.transactions;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('История баллов'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1628), AppColors.bgCard],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.electricBlue.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.star_fill,
                    color: AppColors.warning,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${loyalty.balance}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'баллов',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      loyalty.levelTitle,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (txns.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    loyalty.isLoading
                        ? 'Загрузка…'
                        : 'Пока нет операций с баллами',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: txns.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final t = txns[i];
                    final meta = _loyaltySourceMeta(t.source);
                    final positive = t.amount >= 0;
                    final accent = positive
                        ? AppColors.success
                        : AppColors.error;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.separator),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(meta.icon, size: 20, color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.description.isNotEmpty
                                      ? t.description
                                      : meta.label,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatTxnDate(t.createdAt),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${positive ? '+' : ''}${t.amount}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(completedRunsProvider);
    final totalKm = runs.fold<double>(0, (s, r) => s + r.distanceKm);
    final zones = runs.fold<int>(0, (s, r) => s + r.capturedZones);
    final wins = runs.where((r) => r.capturedTerritory).length;
    final kmText = totalKm >= 100
        ? totalKm.round().toString()
        : totalKm.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          _ProfileStat(value: kmText, label: 'км всего'),
          _Div(),
          _ProfileStat(value: '$zones', label: '\u0437\u043e\u043d'),
          _Div(),
          _ProfileStat(
            value: '${runs.length}',
            label: '\u043f\u0440\u043e\u0431\u0435\u0436\u0435\u043a',
          ),
          _Div(),
          _ProfileStat(value: '$wins', label: '\u043f\u043e\u0431\u0435\u0434'),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value, label;
  const _ProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.electricBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Div extends StatelessWidget {
  const _Div();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.separator);
}

/// Вечный личный след: исследованная площадь навсегда (не уменьшается со временем,
/// в отличие от живой территории на карте, которая распадается через 7 дней).
class _FootprintCard extends ConsumerWidget {
  const _FootprintCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(footprintAreaProvider).valueOrNull ?? 0;
    return Container(
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
              color: AppColors.electricBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.map_fill,
              color: AppColors.electricBlue,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Личная территория',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'исследовано навсегда',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            formatAreaM2(area),
            style: const TextStyle(
              color: AppColors.electricBlue,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Кроссовки из Store: остаток ресурса активной пары. Тап → трекер износа.
class _ShoesCard extends ConsumerWidget {
  const _ShoesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(shoesProvider);
    final active = st.active;
    final String subtitle;
    final String? value;
    if (st.hasPending) {
      final n = st.pending.length;
      subtitle = n == 1
          ? 'новая пара — подтвердите'
          : '$n новых пар — подтвердите';
      value = null;
    } else if (!st.hasShoes) {
      subtitle = 'купи в магазине STAW';
      value = null;
    } else if (active != null) {
      subtitle = 'активная пара · износ ${active.wearPercent}%';
      value = '${active.remainingKm.toStringAsFixed(0)} км';
    } else {
      subtitle = 'ресурс исчерпан — пора заменить';
      value = null;
    }

    return GestureDetector(
      onTap: () => context.push('/profile/shoes'),
      child: Container(
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
                color: AppColors.electricBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_run,
                color: AppColors.electricBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Кроссовки',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            if (value != null) ...[
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.electricBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Вход в раздел «Инструменты бегуна» (офлайн-калькуляторы и таймеры).
class _ToolsCard extends StatelessWidget {
  const _ToolsCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/tools'),
      child: Container(
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
                color: AppColors.electricBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.wrench_fill,
                color: AppColors.electricBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Инструменты бегуна',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    'калькуляторы и таймеры для тренировок',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgesGrid extends ConsumerWidget {
  const _BadgesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(completedRunsProvider);
    final loyalty = ref.watch(loyaltyProvider);
    final totalKm = runs.fold<double>(0, (s, r) => s + r.distanceKm);
    final runsCount = runs.length;
    final captures = runs.where((r) => r.capturedTerritory).length;
    final badges = [
      (
        CupertinoIcons.snow,
        '\u0410\u0440\u043a\u0442\u0438\u0447\u0435\u0441\u043a\u0438\u0439',
        AppColors.info,
        runsCount >= 1,
      ),
      (
        CupertinoIcons.bolt_fill,
        '\u0421\u043f\u0440\u0438\u043d\u0442\u0435\u0440',
        AppColors.warning,
        totalKm >= 5,
      ),
      (
        CupertinoIcons.flame_fill,
        '\u0421\u0435\u0440\u0438\u044f 7',
        AppColors.error,
        runsCount >= 7,
      ),
      (
        CupertinoIcons.moon_stars_fill,
        '\u042f\u043a\u0443\u0442\u0441\u043a',
        AppColors.textSecondary,
        totalKm >= 10,
      ),
      (
        CupertinoIcons.star_fill,
        '\u041b\u0435\u0433\u0435\u043d\u0434\u0430',
        AppColors.warning,
        loyalty.balance >= 500,
      ),
      (
        CupertinoIcons.location_north_fill,
        '\u0412\u044b\u0441\u043e\u0442\u043d\u0438\u043a',
        AppColors.success,
        captures >= 3,
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.02,
      children: badges
          .map(
            (b) => _BadgeTile(
              icon: b.$1,
              label: b.$2,
              color: b.$3,
              unlocked: b.$4,
            ),
          )
          .toList(),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool unlocked;
  const _BadgeTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: unlocked ? color.withValues(alpha: 0.12) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: unlocked
            ? Border.all(color: color.withValues(alpha: 0.3))
            : Border.all(color: AppColors.separator),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: unlocked ? color : AppColors.textDisabled,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: unlocked
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityHeatmap extends ConsumerWidget {
  const _ActivityHeatmap();

  static const _months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(completedRunsProvider);
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final activeDays = <int>{
      for (final r in runs)
        if (r.finishedAt.year == now.year && r.finishedAt.month == now.month)
          r.finishedAt.day,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_months[now.month - 1]} ${now.year}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                '${activeDays.length} \u0430\u043a\u0442\u0438\u0432\u043d\u044b\u0445 \u0434\u043d\u0435\u0439',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(daysInMonth, (i) {
              final day = i + 1;
              final active = activeDays.contains(day);
              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: active ? AppColors.electricBlue : AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? Colors.white : AppColors.textDisabled,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
