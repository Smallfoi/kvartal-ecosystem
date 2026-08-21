import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/remote_content_provider.dart';
import '../theme/app_theme.dart';
import '../util/console_bridge.dart';

/// Пресеты анимации появления элемента (как editAnim на сайте). id → ключ `anim.<key>`.
const List<Map<String, String>> kAnimPresets = [
  {'id': '', 'label': 'Без анимации'},
  {'id': 'fade', 'label': 'Появление'},
  {'id': 'up', 'label': 'Выезд снизу'},
  {'id': 'down', 'label': 'Выезд сверху'},
  {'id': 'left', 'label': 'Выезд слева'},
  {'id': 'right', 'label': 'Выезд справа'},
  {'id': 'zoom', 'label': 'Зум'},
  {'id': 'pop', 'label': 'Пружина'},
];

/// Метка пресета по id (для UI).
String animLabel(String id) => kAnimPresets
    .firstWhere((p) => p['id'] == id, orElse: () => const {'label': ''})['label']!;

/// Обернуть [child] анимацией появления по пресету [name]. Пусто → без анимации.
/// Проигрывается один раз при появлении (и в проде, и в правке); при смене пресета
/// ключ меняется → перезапуск (превью в конструкторе).
Widget animatePreset(String name, Widget child) {
  if (name.isEmpty) return child;
  final key = ValueKey('anim-$name');
  switch (name) {
    case 'fade':
      return child.animate(key: key).fadeIn(duration: 500.ms, curve: Curves.easeOut);
    case 'up':
      return child.animate(key: key).fadeIn(duration: 450.ms).moveY(
          begin: 26, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
    case 'down':
      return child.animate(key: key).fadeIn(duration: 450.ms).moveY(
          begin: -26, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
    case 'left':
      return child.animate(key: key).fadeIn(duration: 450.ms).moveX(
          begin: -30, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
    case 'right':
      return child.animate(key: key).fadeIn(duration: 450.ms).moveX(
          begin: 30, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
    case 'zoom':
      return child.animate(key: key).fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: 450.ms,
          curve: Curves.easeOut);
    case 'pop':
      return child.animate(key: key).scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1, 1),
          duration: 600.ms,
          curve: Curves.elasticOut);
    default:
      return child;
  }
}

/// Нижняя шторка выбора анимации появления для элемента [contentKey].
/// Пишет `anim.<key>` тем же draftContent (консоль публикует); бэкенд не меняется.
Future<void> showAnimPicker(
    BuildContext context, String contentKey, String current) async {
  final prov = context.read<RemoteContentProvider>();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Анимация появления',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            for (final p in kAnimPresets)
              ListTile(
                dense: true,
                title: Text(p['label']!),
                trailing: p['id'] == current
                    ? const Icon(Icons.check, color: Color(0xFF0A84FF), size: 20)
                    : null,
                onTap: () {
                  final v = p['id']!;
                  postDraft('anim.$contentKey', v);
                  prov.applyDraft('anim.$contentKey', v);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}

/// Единая шторка действий для элемента конструктора (кнопка «⋯»): скрыть/вернуть,
/// удалить (если [onDelete] задан) + выбор анимации появления. Одна надёжно
/// нажимаемая кнопка вместо нескольких мелких бейджей по углам.
Future<void> showElementSheet(
  BuildContext context, {
  required String contentKey,
  required String animName,
  required bool hidden,
  bool showHide = true,
  VoidCallback? onDelete,
}) async {
  final prov = context.read<RemoteContentProvider>();
  void setKey(String k, String v) {
    postDraft(k, v);
    prov.applyDraft(k, v);
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHide)
              ListTile(
                leading: Icon(hidden ? Icons.visibility : Icons.visibility_off,
                    color: hidden ? const Color(0xFF16A34A) : const Color(0xFF374151)),
                title: Text(hidden ? 'Вернуть элемент' : 'Скрыть элемент',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  setKey('hidden.$contentKey', hidden ? '' : '1');
                  Navigator.of(ctx).pop();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                title: const Text('Удалить',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onDelete();
                },
              ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Анимация появления',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF6B7280))),
              ),
            ),
            for (final p in kAnimPresets)
              ListTile(
                dense: true,
                title: Text(p['label']!),
                trailing: p['id'] == animName
                    ? const Icon(Icons.check, color: Color(0xFF0A84FF), size: 20)
                    : null,
                onTap: () {
                  setKey('anim.$contentKey', p['id']!);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}
