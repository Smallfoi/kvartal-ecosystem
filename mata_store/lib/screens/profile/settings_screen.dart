import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/remote_text.dart';
import 'about_app_screen.dart';
import 'account_data_screen.dart';
import 'edit_profile_screen.dart';
import 'legal_documents_screen.dart';
import 'stats_screen.dart';

/// Настройки профиля Store — единый стиль с шестерёнкой Квартала (экосистема):
/// одна точка входа на редактирование профиля, уведомления, конфиденциальность и выход.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _confirmLogout(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const RemoteText('app.settings.logoutDialog.title', 'Выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const RemoteText('app.settings.logoutDialog.cancel', 'Отмена', style: TextStyle(color: AppColors.grey600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // закрываем настройки
              auth.logout();
            },
            child: const RemoteText('app.settings.logoutDialog.confirm', 'Выйти', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: RemoteText(
          'app.settings.title',
          'НАСТРОЙКИ',
          style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            contentKey: 'app.settings.editProfile',
            label: 'Редактировать профиль',
            onTap: () => _push(context, const EditProfileScreen()),
          ),
          _SettingsTile(
            icon: Icons.insights_outlined,
            contentKey: 'app.settings.stats',
            label: 'Моя статистика',
            onTap: () => _push(context, const StatsScreen()),
          ),
          _SettingsTile(
            icon: Icons.notifications_none,
            contentKey: 'app.settings.notifications',
            label: 'Уведомления',
            onTap: () => context.push('/notifications'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            contentKey: 'app.settings.privacy',
            label: 'Конфиденциальность и данные',
            onTap: () => _push(context, const AccountDataScreen()),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            contentKey: 'app.settings.legal',
            label: 'Документы',
            onTap: () => _push(context, const LegalDocumentsScreen()),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            contentKey: 'app.settings.about',
            label: 'О приложении',
            onTap: () => _push(context, const AboutAppScreen()),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.logout,
            contentKey: 'app.settings.logout',
            label: 'Выйти из аккаунта',
            destructive: true,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String contentKey;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.contentKey,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.red : AppColors.black;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: RemoteText(
        contentKey,
        label,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color),
      ),
      trailing: destructive
          ? null
          : const Icon(Icons.chevron_right, size: 20, color: AppColors.grey400),
    );
  }
}
