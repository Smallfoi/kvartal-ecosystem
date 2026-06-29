import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../logic/interval_plan.dart';

/// Метроном каденса: задаёт частоту шагов (шагов/мин) звуком + вибро,
/// чтобы держать ритм бега. Звук — встроенный системный клик (без ассетов).
class CadenceMetronomeScreen extends StatefulWidget {
  const CadenceMetronomeScreen({super.key});

  @override
  State<CadenceMetronomeScreen> createState() => _CadenceMetronomeScreenState();
}

class _CadenceMetronomeScreenState extends State<CadenceMetronomeScreen> {
  static const _min = 120;
  static const _max = 220;

  int _spm = 170;
  bool _running = false;
  bool _beat = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() => _running ? _stop() : _start();

  void _start() {
    _timer?.cancel();
    final ms = metronomeIntervalMs(_spm);
    if (ms <= 0) return;
    setState(() => _running = true);
    _tick();
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) => _tick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() {
        _running = false;
        _beat = false;
      });
    }
  }

  void _tick() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
    if (mounted) setState(() => _beat = !_beat);
  }

  void _setSpm(int v) {
    setState(() => _spm = v.clamp(_min, _max));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        title: const Text('Метроном каденса'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    width: _beat ? 210 : 180,
                    height: _beat ? 210 : 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.electricBlue.withValues(
                        alpha: _beat ? 0.28 : 0.12,
                      ),
                      border: Border.all(
                        color: AppColors.electricBlue.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_spm',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'шагов/мин',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    onTap: () => _setSpm(_spm - 1),
                  ),
                  Expanded(
                    child: Slider(
                      value: _spm.toDouble(),
                      min: _min.toDouble(),
                      max: _max.toDouble(),
                      onChanged: (v) => _setSpm(v.round()),
                      onChangeEnd: (_) {
                        if (_running) _start();
                      },
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    onTap: () => _setSpm(_spm + 1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: const [160, 170, 180]
                    .map(
                      (p) => ActionChip(
                        label: Text('$p'),
                        backgroundColor: AppColors.bgElevated,
                        side: BorderSide(color: AppColors.separator),
                        labelStyle: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                        onPressed: () {
                          _setSpm(p);
                          if (_running) _start();
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _toggle,
                  style: FilledButton.styleFrom(
                    backgroundColor: _running
                        ? AppColors.error
                        : AppColors.electricBlue,
                  ),
                  icon: Icon(_running ? Icons.stop : Icons.play_arrow),
                  label: Text(_running ? 'Стоп' : 'Старт'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Оптимальный беговой каденс обычно 170–185 шагов/мин. '
                'Звук тихий — лучше слышно в наушниках; есть вибрация.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.textPrimary),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
