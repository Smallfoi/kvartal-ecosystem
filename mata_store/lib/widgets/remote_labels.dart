import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/remote_content_provider.dart';
import '../theme/app_theme.dart';
import '../util/console_bridge.dart';
import 'remote_text.dart';

/// Слой ДОБАВЛЕННЫХ текстовых подписей поверх экрана — «➕ добавить текст», как на
/// сайте (staw-addlabel). Модель 1:1 с сайтом: список `applabels`=[{id, s=экран}],
/// текст каждой — ключ `app.xl.<id>`, позиция — `pos.app.xl.<id>` (тот же drag).
///
/// Показывается и в проде (опубликованные подписи), и в правке. В режиме правки —
/// плавающая кнопка ➕ (добавить в центр) и крестик ✕ у каждой подписи (удалить).
/// Хранение — тем же `draftContent`, что публикует консоль; бэкенд не меняется.
class RemoteLabelsLayer extends StatelessWidget {
  final String screenKey;
  const RemoteLabelsLayer(this.screenKey, {super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RemoteContentProvider>();
    final ids = prov.labels(screenKey);
    return ValueListenableBuilder<bool>(
      valueListenable: consoleEditNotifier,
      builder: (context, editing, _) {
        // Пустой слой без правки и без подписей — ничего не рисуем (и не перехватываем).
        if (!editing && ids.isEmpty) return const SizedBox.shrink();
        return Stack(
          children: [
            for (final id in ids)
              _AddedLabel(id: id, screenKey: screenKey, editing: editing),
            if (editing)
              Positioned(right: 16, bottom: 16, child: _AddButton(screenKey)),
          ],
        );
      },
    );
  }
}

/// Одна добавленная подпись: свободно позиционируется (`pos.app.xl.<id>`), в правке —
/// тап=правка текста, перетаскивание=позиция, ✕=удалить.
class _AddedLabel extends StatefulWidget {
  final String id;
  final String screenKey;
  final bool editing;
  const _AddedLabel({required this.id, required this.screenKey, required this.editing});

  @override
  State<_AddedLabel> createState() => _AddedLabelState();
}

class _AddedLabelState extends State<_AddedLabel> {
  Offset _drag = Offset.zero;
  bool _dragging = false;
  String get _key => 'app.xl.${widget.id}';

  void _commitPos(RemoteContentProvider prov, Offset off) {
    final v = '${off.dx.round()},${off.dy.round()}';
    postDraft('pos.$_key', v);
    prov.applyDraft('pos.$_key', v);
  }

  void _delete(RemoteContentProvider prov) {
    final rest = prov.allLabels().where((m) => m['id'] != widget.id).toList();
    final json = jsonEncode(rest);
    postDraft('applabels', json);
    prov.applyDraft('applabels', json);
    // Подчистить текст и позицию удалённой подписи.
    for (final k in [_key, 'pos.$_key', 'color.$_key']) {
      postDraft(k, '');
      prov.applyDraft(k, '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RemoteContentProvider>();
    final text = prov.text(_key, 'Новая надпись');
    final base = prov.posOffset(_key);
    final colorHex = prov.color(_key);
    final col = RemoteText.parseHex(colorHex);
    final label = Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: col ?? AppColors.black),
    );

    if (!widget.editing) {
      return Positioned(
        left: 0,
        top: 0,
        child: Transform.translate(offset: base, child: label),
      );
    }

    final off = base + _drag;
    return Positioned(
      left: 0,
      top: 0,
      child: Transform.translate(
        offset: off,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => postEditContent(_key, text, color: colorHex, hasColor: colorHex.isNotEmpty),
          onPanStart: (_) => setState(() => _dragging = true),
          onPanUpdate: (d) => setState(() => _drag += d.delta),
          onPanEnd: (_) {
            _commitPos(prov, base + _drag);
            setState(() {
              _drag = Offset.zero;
              _dragging = false;
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x1A0A84FF),
                  border: Border.all(
                    color: _dragging ? const Color(0xFFFF2D9B) : const Color(0xFF0A84FF),
                    width: _dragging ? 1.8 : 1.4,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(padding: const EdgeInsets.all(2), child: label),
              ),
              Positioned(
                right: -9,
                top: -9,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _delete(prov),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(color: Color(0xFFFF2D5B), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Плавающая кнопка «➕ Текст» — добавляет новую подпись в центр текущего экрана.
class _AddButton extends StatelessWidget {
  final String screenKey;
  const _AddButton(this.screenKey);

  void _add(BuildContext context) {
    final prov = context.read<RemoteContentProvider>();
    // id уникален по времени (рантайм Dart — DateTime доступен).
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final list = prov.allLabels()..add({'id': id, 's': screenKey});
    final json = jsonEncode(list);
    postDraft('applabels', json);
    prov.applyDraft('applabels', json);

    const defText = 'Новая надпись';
    postDraft('app.xl.$id', defText);
    prov.applyDraft('app.xl.$id', defText);

    // Позиция — примерно центр экрана.
    final size = MediaQuery.of(context).size;
    final pos = '${(size.width / 2 - 70).round()},${(size.height / 2 - 40).round()}';
    postDraft('pos.app.xl.$id', pos);
    prov.applyDraft('pos.app.xl.$id', pos);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0A84FF),
      shape: const StadiumBorder(),
      elevation: 3,
      child: InkWell(
        onTap: () => _add(context),
        customBorder: const StadiumBorder(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Текст',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
