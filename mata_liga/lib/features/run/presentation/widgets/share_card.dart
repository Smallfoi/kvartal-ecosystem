import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/kvartal_logo.dart';
import '../screens/run_result_screen.dart';

/// Шаринг-карточка пробежки 9:16 (Ф1 «Праздник», сцена 3, утверждено 31.08).
///
/// Показываем превью в шите — владелец видит, что уйдёт в сториз; кнопка
/// «Отправить» рендерит карточку в PNG и открывает системный шаринг.
Future<void> showShareCardSheet(BuildContext context, RunResult result) {
  final boundaryKey = GlobalKey();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFFF5F4EE),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Карточка пробежки',
              style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF20252B),
              ),
            ),
            const SizedBox(height: 14),
            RepaintBoundary(
              key: boundaryKey,
              child: ShareCard(result: result),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF20252B),
                  foregroundColor: const Color(0xFFDFF45F),
                  minimumSize: const Size(64, 52),
                ),
                onPressed: () => _share(boundaryKey),
                child: const Text('Отправить'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _share(GlobalKey boundaryKey) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/liga_run_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(bytes.buffer.asUint8List());
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png')],
    text: 'Моя пробежка в ЛИГЕ',
  );
}

/// Сама карточка: графит, трек, цифры, знак. 9:16.
class ShareCard extends StatelessWidget {
  final RunResult result;

  const ShareCard({super.key, required this.result});

  static const _bg = Color(0xFF20252B);
  static const _light = Color(0xFFEDEFE8);
  static const _dim = Color(0xFF9AA59D);
  static const _lime = Color(0xFFDFF45F);

  @override
  Widget build(BuildContext context) {
    final r = result;
    final date =
        '${r.finishedAt.day.toString().padLeft(2, '0')}.${r.finishedAt.month.toString().padLeft(2, '0')}.${r.finishedAt.year}';
    return Container(
      width: 234,
      height: 416,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                CustomPaint(
                  size: const Size(20, 20),
                  painter: KvartalMarkPainter(
                    outline: _lime,
                    fill: Colors.transparent,
                    close: 1,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ЛИГА',
                  style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: _light,
                  ),
                ),
                const Spacer(),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _dim,
                  ),
                ),
              ],
            ),
          ),
          // Трек.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: CustomPaint(
                painter: RoutePainter(
                  route: r.route,
                  progress: 1,
                  fill: r.hasCapture ? 1 : 0,
                  fitFactor: 1,
                  topInset: 6,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.distanceKm.toStringAsFixed(2)} км',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    color: _light,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _chip(r.elapsedFormatted),
                    const SizedBox(width: 6),
                    _chip('${r.paceFormatted} /км'),
                    if (r.hasCapture) ...[
                      const SizedBox(width: 6),
                      _chip(
                        '+${r.quarters} кв.',
                        color: _lime,
                        textColor: const Color(0xFF171C19),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'МАТА · беги и забирай кварталы',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .6,
                    color: _dim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {Color color = const Color(0xFF2F362F),
      Color textColor = _light}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
          color: textColor,
        ),
      ),
    );
  }
}
