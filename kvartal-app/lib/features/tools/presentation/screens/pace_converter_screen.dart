import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../logic/pace_math.dart';
import '../widgets/tool_widgets.dart';

/// Конвертер темпа и скорости + расчёт времени забега.
/// Ввод времени — барабаном (мин : сек) как в будильнике iOS.
class PaceConverterScreen extends StatefulWidget {
  const PaceConverterScreen({super.key});

  @override
  State<PaceConverterScreen> createState() => _PaceConverterScreenState();
}

class _PaceConverterScreenState extends State<PaceConverterScreen> {
  Duration _pace = const Duration(minutes: 5, seconds: 30);

  // Скорости 3.0 … 25.0 км/ч с шагом 0.5 (барабан).
  static final _speeds = List<double>.generate(45, (i) => 3.0 + i * 0.5);
  int _speedIdx = 14; // 10.0 км/ч

  static const _distances = <({String label, double km})>[
    (label: '5 км', km: 5),
    (label: '10 км', km: 10),
    (label: '21.1', km: 21.0975),
    (label: '42.2', km: 42.195),
  ];
  double _distanceKm = 10;

  double get _paceSecPerKm => _pace.inSeconds.toDouble();

  @override
  Widget build(BuildContext context) {
    final speedFromPace = speedKmhFromPace(_paceSecPerKm);
    final speed = _speeds[_speedIdx];
    final paceFromSpeed = paceSecPerKmFromSpeed(speed);
    final raceTime = timeSecFromDistancePace(_distanceKm, _paceSecPerKm);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Темп и скорость'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ToolCard(
              title: 'Темп → скорость',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ToolTimeField(
                    label: 'Темп',
                    value: _pace,
                    onChanged: (d) => setState(() => _pace = d),
                  ),
                  const SizedBox(height: 8),
                  _Result(
                    value: speedFromPace > 0
                        ? '${speedFromPace.toStringAsFixed(1)} км/ч'
                        : '—',
                    hint: 'при темпе ${formatPace(_paceSecPerKm)} /км',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ToolCard(
              title: 'Скорость → темп',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ToolValueField(
                    label: 'Скорость',
                    items: [
                      for (final s in _speeds) '${s.toStringAsFixed(1)} км/ч',
                    ],
                    index: _speedIdx,
                    onChanged: (i) => setState(() => _speedIdx = i),
                  ),
                  const SizedBox(height: 8),
                  _Result(
                    value: '${formatPace(paceFromSpeed)} /км',
                    hint: 'при скорости ${speed.toStringAsFixed(1)} км/ч',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ToolCard(
              title: 'Время забега',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _distances.map((d) {
                      final selected = (d.km - _distanceKm).abs() < 0.001;
                      return ChoiceChip(
                        label: Text(d.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _distanceKm = d.km),
                        showCheckmark: false,
                        backgroundColor: AppColors.bgElevated,
                        selectedColor: AppColors.electricBlue,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(color: AppColors.separator),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  _Result(
                    value: formatDuration(raceTime),
                    hint:
                        '${_distanceKm.toStringAsFixed(_distanceKm % 1 == 0 ? 0 : 1)}'
                        ' км в темпе ${formatPace(_paceSecPerKm)} /км',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Крути барабан темпа (мин : сек) или выбери скорость — остальное '
              'посчитается само.',
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

class _Result extends StatelessWidget {
  final String value;
  final String hint;
  const _Result({required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.electricBlue,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
      ],
    );
  }
}
