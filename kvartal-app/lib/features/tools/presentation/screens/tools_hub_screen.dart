import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Хаб инструментов бегуна: калькуляторы и таймеры (офлайн, без бэкенда).
/// Вход — из профиля. Каждый инструмент открывается отдельным маршрутом в шелле,
/// поэтому таб-бар продолжает переключать экраны (см. [[feedback-no-repeat-fixed-bugs]]).
class ToolsHubScreen extends StatelessWidget {
  const ToolsHubScreen({super.key});

  static const _tools = <ToolEntry>[
    ToolEntry(
      icon: CupertinoIcons.speedometer,
      title: 'Темп и скорость',
      subtitle: 'Перевод темпа ↔ скорости и время забега',
      route: '/tools/pace',
    ),
    ToolEntry(
      icon: CupertinoIcons.heart_fill,
      title: 'Пульсовые зоны',
      subtitle: 'Z1–Z5 по возрасту и пульсу покоя',
      route: '/tools/hr-zones',
    ),
    ToolEntry(
      icon: Icons.straighten,
      title: 'Размер кроссовок',
      subtitle: 'Длина стопы → RU/EU, UK, US',
      route: '/tools/shoe-size',
    ),
    ToolEntry(
      icon: Icons.music_note,
      title: 'Метроном каденса',
      subtitle: 'Ритм шагов (шагов/мин) звуком и вибро',
      route: '/tools/metronome',
    ),
    ToolEntry(
      icon: Icons.timer,
      title: 'Интервальный таймер',
      subtitle: 'Работа/отдых по раундам, сигналы на сменах',
      route: '/tools/interval',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Инструменты'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _tools.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _ToolTile(entry: _tools[i]),
        ),
      ),
    );
  }
}

/// Описание одного инструмента в хабе.
class ToolEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  const ToolEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

class _ToolTile extends StatelessWidget {
  final ToolEntry entry;
  const _ToolTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(entry.route),
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
              child: Icon(entry.icon, color: AppColors.electricBlue, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    entry.subtitle,
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
