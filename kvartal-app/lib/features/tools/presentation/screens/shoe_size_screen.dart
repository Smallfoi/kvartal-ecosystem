import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../logic/shoe_size.dart';
import '../widgets/tool_widgets.dart';

/// Калькулятор размера кроссовок: длина стопы (см) → RU/EU, см, UK, US.
/// Связка со Store: подсказывает размер при покупке.
class ShoeSizeScreen extends StatefulWidget {
  const ShoeSizeScreen({super.key});

  @override
  State<ShoeSizeScreen> createState() => _ShoeSizeScreenState();
}

class _ShoeSizeScreenState extends State<ShoeSizeScreen> {
  final _foot = TextEditingController(text: '26');
  bool _running = false;

  @override
  void dispose() {
    _foot.dispose();
    super.dispose();
  }

  static String _fmt(double v) {
    final r = roundHalf(v);
    return r % 1 == 0 ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final footCm =
        double.tryParse(_foot.text.trim().replaceAll(',', '.')) ?? 0;
    final valid = footCm >= 15 && footCm <= 40;
    final s = valid ? sizesFromFootCm(footCm, running: _running) : null;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Размер кроссовок'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ToolCard(
              title: 'Длина стопы',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ToolNumField(
                    controller: _foot,
                    label: 'см',
                    allowDecimal: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Для бега (+0.5)',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      Switch(
                        value: _running,
                        onChanged: (v) => setState(() => _running = v),
                      ),
                    ],
                  ),
                  Text(
                    'Измерь стопу от пятки до большого пальца, стоя. Лучше '
                    'вечером — к вечеру стопа немного больше.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (s != null) ...[
              _SizeTile(label: 'RU / EU', sub: 'европейский', value: _fmt(s.eu)),
              const SizedBox(height: 10),
              _SizeTile(
                label: 'Mondopoint',
                sub: 'длина стопы, см',
                value: _fmt(s.mondo),
              ),
              const SizedBox(height: 10),
              _SizeTile(label: 'UK', sub: 'британский', value: _fmt(s.uk)),
              const SizedBox(height: 10),
              _SizeTile(label: 'US', sub: 'мужской', value: _fmt(s.usMen)),
              const SizedBox(height: 10),
              _SizeTile(label: 'US', sub: 'женский', value: _fmt(s.usWomen)),
            ] else
              ToolCard(
                child: Text(
                  'Введи длину стопы в сантиметрах (обычно 22–30 см).',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Размеры приблизительные — сетки брендов отличаются. Перед покупкой '
              'сверяйся с размерной таблицей конкретной модели.',
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

class _SizeTile extends StatelessWidget {
  final String label;
  final String sub;
  final String value;
  const _SizeTile({required this.label, required this.sub, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  sub,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.electricBlue,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
