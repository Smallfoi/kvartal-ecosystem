import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'account_data_screen.dart';
import 'edit_profile_screen.dart';
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
        title: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена', style: TextStyle(color: AppColors.grey600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // закрываем настройки
              auth.logout();
            },
            child: const Text('Выйти', style: TextStyle(color: AppColors.red)),
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
        title: Text(
          'НАСТРОЙКИ',
          style: GoogleFonts.oswald(
            fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            label: 'Редактировать профиль',
            onTap: () => _push(context, const EditProfileScreen()),
          ),
          _SettingsTile(
            icon: Icons.insights_outlined,
            label: 'Моя статистика',
            onTap: () => _push(context, const StatsScreen()),
          ),
          _SettingsTile(
            icon: Icons.notifications_none,
            label: 'Уведомления',
            onTap: () => context.push('/notifications'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Конфиденциальность и данные',
            onTap: () => _push(context, const AccountDataScreen()),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.logout,
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
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
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
      title: Text(
        label,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color),
      ),
      trailing: destructive
          ? null
          : const Icon(Icons.chevron_right, size: 20, color: AppColors.grey400),
    );
  }
}
