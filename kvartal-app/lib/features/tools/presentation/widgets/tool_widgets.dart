import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Карточка-секция инструмента: фоновый блок с опциональным заголовком.
class ToolCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const ToolCard({super.key, this.title, required this.child});

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
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

/// Барабан-пикер времени (мин : сек) в стиле будильника iOS.
/// Свайпом выставляешь минуты и секунды — всё на одном экране.
class ToolTimePicker extends StatelessWidget {
  final Duration initial;
  final ValueChanged<Duration> onChanged;

  /// Ключ для пере-инициализации барабана (напр. при выборе пресета).
  final Key? pickerKey;
  final double height;

  const ToolTimePicker({
    super.key,
    required this.initial,
    required this.onChanged,
    this.pickerKey,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CupertinoTheme(
        data: const CupertinoThemeData(
          brightness: Brightness.dark,
          textTheme: CupertinoTextThemeData(
            pickerTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        child: CupertinoTimerPicker(
          key: pickerKey,
          mode: CupertinoTimerPickerMode.ms,
          initialTimerDuration: initial,
          onTimerDurationChanged: onChanged,
        ),
      ),
    );
  }
}

/// Барабан-пикер выбора значения из списка (числа) в стиле iOS.
class ToolValuePicker extends StatefulWidget {
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  const ToolValuePicker({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.height = 150,
  });

  @override
  State<ToolValuePicker> createState() => _ToolValuePickerState();
}

class _ToolValuePickerState extends State<ToolValuePicker> {
  late final FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(initialItem: widget.index);
  }

  @override
  void didUpdateWidget(covariant ToolValuePicker old) {
    super.didUpdateWidget(old);
    // Внешнее изменение (напр. пресет) — плавно докручиваем барабан.
    if (widget.index != old.index &&
        _ctrl.hasClients &&
        _ctrl.selectedItem != widget.index) {
      _ctrl.animateToItem(
        widget.index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.dark),
        child: CupertinoPicker(
          scrollController: _ctrl,
          itemExtent: 40,
          onSelectedItemChanged: widget.onChanged,
          selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
            background: AppColors.electricBlue.withValues(alpha: 0.10),
          ),
          children: [
            for (final s in widget.items)
              Center(
                child: Text(
                  s,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
