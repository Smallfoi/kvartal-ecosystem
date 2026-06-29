import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../logic/hr_zones.dart';
import '../widgets/tool_widgets.dart';

/// Калькулятор пульсовых зон: возраст (+ необязательный пульс покоя) → 5 зон.
class HrZonesScreen extends StatefulWidget {
  const HrZonesScreen({super.key});

  @override
  State<HrZonesScreen> createState() => _HrZonesScreenState();
}

class _HrZonesScreenState extends State<HrZonesScreen> {
  final _age = TextEditingController(text: '30');
  final _rest = TextEditingController();

  static const _zoneColors = <Color>[
    AppColors.info,
    AppColors.success,
    AppColors.warning,
    Color(0xFFFF9F0A),
    AppColors.error,
  ];

  @override
  void dispose() {
    _age.dispose();
    _rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final age = int.tryParse(_age.text.trim()) ?? 0;
    final maxHr = age > 0 ? maxHrByAge(age) : 0;
    final rest = int.tryParse(_rest.text.trim());
    final karvonen = rest != null && rest > 0 && rest < maxHr;
    final zones = maxHr > 0 ? hrZones(maxHr: maxHr, restHr: rest) : <HrZone>[];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Пульсовые зоны'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ToolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ToolNumField(
                          controller: _age,
                          label: 'Возраст',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ToolNumField(
                          controller: _rest,
                          label: 'Пульс покоя',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Максимальный пульс',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        maxHr > 0 ? '$maxHr уд/мин' : '—',
                        style: const TextStyle(
                          color: AppColors.electricBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  if (karvonen) ...[
                    const SizedBox(height: 4),
                    Text(
                      'расчёт по методу Карвонена (резерв пульса)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < zones.length; i++) ...[
              _ZoneRow(zone: zones[i], color: _zoneColors[i]),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            Text(
              'Зоны рекомендательные. Формула «220 − возраст» приблизительная; '
              'для точных значений нужен тест с пульсометром.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final HrZone zone;
  final Color color;
  const _ZoneRow({required this.zone, required this.color});

  @override
  Widget build(BuildContext context) {
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
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  zone.purpose,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${zone.lowBpm}–${zone.highBpm}',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${zone.lowPct}–${zone.highPct}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
