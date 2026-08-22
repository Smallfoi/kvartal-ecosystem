// Инструмент генерации иконки: рендерит знак из KvartalMarkPainter в PNG
// 1024×1024 (close=0 — состояние иконки), чтобы иконка приложения всегда
// строилась ровно из того же кода, что рисует знак в приложении.
// Пайплайн: `flutter test test/render_mark_png_test.dart` →
// `python tools/brand/make_kvartal_icons.py` (из корня mata_kvartal).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvartal_app/shared/widgets/kvartal_logo.dart';

void main() {
  testWidgets('render mark png for app icon', (tester) async {
    await tester.runAsync(() async {
      const size = 1024.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      KvartalMarkPainter(
        outline: const Color(0xFFEDEFE8),
        fill: const Color(0xFFDFF45F),
        close: 0,
      ).paint(canvas, const Size(size, size));
      final image = await recorder.endRecording().toImage(1024, 1024);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File('build/mark_icon_1024.png');
      out.parent.createSync(recursive: true);
      out.writeAsBytesSync(bytes!.buffer.asUint8List());
      expect(out.existsSync(), isTrue);
    });
  });
}
