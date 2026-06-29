import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../logic/pace_math.dart';

/// Конвертер темпа и скорости + расчёт времени забега.
/// Полностью офлайн: меняешь любое поле — результаты пересчитываются мгновенно.
class PaceConverterScreen extends StatefulWidget {
  const PaceConverterScreen({super.key});

  @override
  State<PaceConverterScreen> createState() => _PaceConverterScreenState();
}

class _PaceConverterScreenState extends State<PaceConverterScreen> {
  final _paceMin = TextEditingController(text: '5');
  final _paceSec = TextEditingController(text: '30');
  final _speed = TextEditingController(text: '10');

  /// Популярные дистанции для расчёта времени забега (км).
  static const _distances = <({String label, double km})>[
    (label: '5 км', km: 5),
    (label: '10 км', km: 10),
    (label: '21.1', km: 21.0975),
    (label: '42.2', km: 42.195),
  ];
  double _distanceKm = 10;

  @override
  void dispose() {
    _paceMin.dispose();
    _paceSec.dispose();
    _speed.dispose();
    super.dispose();
  }

  double get _paceSecPerKm {
    final m = int.tryParse(_paceMin.text.trim()) ?? 0;
    final s = int.tryParse(_paceSec.text.trim()) ?? 0;
    return (m * 60 + s).toDouble();
  }

  double get _speedInput =>
      double.tryParse(_speed.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final speedFromPace = speedKmhFromPace(_paceSecPerKm);
    final paceFromSpeed = paceSecPerKmFromSpeed(_speedInput);
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
            _ToolCard(
              title: 'Темп → скорость',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NumField(
                          controller: _paceMin,
                          label: 'мин',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _NumField(
                          controller: _paceSec,
                          label: 'сек',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ResultLine(
                    value: speedFromPace > 0
                        ? '${speedFromPace.toStringAsFixed(1)} км/ч'
                        : '—',
                    hint: 'при темпе ${formatPace(_paceSecPerKm)} /км',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ToolCard(
              title: 'Скорость → темп',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NumField(
                    controller: _speed,
                    label: 'км/ч',
                    allowDecimal: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  _ResultLine(
                    value: paceFromSpeed > 0
                        ? '${formatPace(paceFromSpeed)} /км'
                        : '—',
                    hint: 'при скорости '
                        '${_speedInput > 0 ? _speedInput.toStringAsFixed(1) : '0'} км/ч',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ToolCard(
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
                  const SizedBox(height: 14),
                  _ResultLine(
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
              'Подсказка: меняй темп (мин/сек) или скорость — остальное пересчитается. '
              'Дистанция считается по выбранному выше темпу.',
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

class _ToolCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ToolCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool allowDecimal;
  final ValueChanged<String> onChanged;

  const _NumField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.allowDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        allowDecimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.bgElevated,
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

class _ResultLine extends StatelessWidget {
  final String value;
  final String hint;
  const _ResultLine({required this.value, required this.hint});

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
