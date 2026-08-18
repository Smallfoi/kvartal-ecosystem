import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Шторка-проезд — мобильная адаптация эталона «Auth Slider» (стандарт
/// анимаций МАТА): чёрная бренд-панель проезжает через весь экран по кривой
/// easeInOutSine (точный аналог cubic-bezier(.37,0,.63,1) из спеки), текст на
/// ней едет НАВСТРЕЧУ вдвое медленнее — тот же параллакс, что у панели
/// эталона. Смена контента происходит в момент полного покрытия экрана.
///
/// Живёт в корневом Overlay. Если [onCovered] возвращает Future, шторка
/// держит покрытие до его завершения. При reduced motion шторки нет — сразу
/// вызывается [onCovered].
Future<void> playBrandSweep(
  BuildContext context, {
  required String title,
  String? subtitle,
  bool leftToRight = true,
  Future<void> Function()? onCovered,
}) async {
  if (MediaQuery.of(context).disableAnimations) {
    if (onCovered != null) await onCovered();
    return;
  }
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _BrandSweep(
      title: title,
      subtitle: subtitle,
      leftToRight: leftToRight,
      onCovered: onCovered,
      onDone: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _BrandSweep extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool leftToRight;
  final Future<void> Function()? onCovered;
  final VoidCallback onDone;

  const _BrandSweep({
    required this.title,
    this.subtitle,
    required this.leftToRight,
    this.onCovered,
    required this.onDone,
  });

  @override
  State<_BrandSweep> createState() => _BrandSweepState();
}

class _BrandSweepState extends State<_BrandSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await _c.animateTo(
      0.5,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutSine,
    );
    if (!mounted) return;
    if (widget.onCovered != null) {
      try {
        await widget.onCovered!();
      } catch (_) {}
    }
    // Кадр на смену контента под шторкой.
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    await _c.animateTo(
      1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutSine,
    );
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Positioned.fill(
      child: AbsorbPointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // Панель: -W → +W (или зеркально), полное покрытие при t=0.5.
            final dir = widget.leftToRight ? 1.0 : -1.0;
            final x = (_c.value * 2 - 1) * w * dir;
            return Transform.translate(
              offset: Offset(x, 0),
              child: ClipRect(
                child: Container(
                  color: AppColors.black,
                  alignment: Alignment.center,
                  // Текст едет навстречу вдвое медленнее панели — параллакс.
                  child: Transform.translate(
                    offset: Offset(-x / 2, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.oswald(
                            color: AppColors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              widget.subtitle!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.grey400,
                                fontSize: 13.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
