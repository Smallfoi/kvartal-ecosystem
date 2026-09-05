import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/kvartal_logo.dart';
import '../../../auth/data/auth_provider.dart';
import '../screens/run_result_screen.dart' show RoutePainter;

/// Шаринг пробежки «Росчерк» (дизайн утверждён 05.09.2026): маршрут — герой.
/// Карточка 9:16 — неоновый росчерк на сетке города, при захвате — заголовок
/// вызова «Забрал N кварталов»; прозрачный стикер — только трек и цифры на
/// собственное фото бегуна. Механика Инсты общая с медалями (тот же канал).
const _instaChannel = MethodChannel('kvartal/instagram_share');

const _bg = Color(0xFF12161B);
const _panel = Color(0xFF1B2129);
const _ink = Color(0xFFEDEFE8);
const _muted = Color(0xFF97A0A6);
const _lime = Color(0xFFDFF45F);

// Meta App ID — публичный (см. medal_share.dart), продублирован константой,
// чтобы не тянуть медали в модуль пробежек.
const _metaAppId = String.fromEnvironment(
  'META_APP_ID',
  defaultValue: '1058928553560826',
);

/// Данные для карточки: у пробежки может не быть routeTimes/баллов — карточка
/// строится из того, что есть.
class RunShareData {
  final List<LatLng> route;
  final Duration elapsed;
  final double distanceMeters;
  final int capturedZones;
  final DateTime finishedAt;

  const RunShareData({
    required this.route,
    required this.elapsed,
    required this.distanceMeters,
    required this.capturedZones,
    required this.finishedAt,
  });

  double get distanceKm => distanceMeters / 1000;
}

Future<void> showRunShareSheet(BuildContext context, RunShareData data) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF161B21),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _RunShareSheet(data: data),
  );
}

class _RunShareSheet extends ConsumerStatefulWidget {
  final RunShareData data;
  const _RunShareSheet({required this.data});

  @override
  ConsumerState<_RunShareSheet> createState() => _RunShareSheetState();
}

class _RunShareSheetState extends ConsumerState<_RunShareSheet> {
  final _boundaryKey = GlobalKey();
  bool _stickerMode = false;
  bool _showStats = true; // на стикере цифры можно скрыть — чистый росчерк
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final runner = ref.watch(authProvider).user?.name ?? 'Бегун КВАРТАЛ';
    final city = ref.watch(authProvider).user?.city;
    final preview = _stickerMode
        ? RunSticker(data: widget.data, showStats: _showStats)
        : RunStoryCard(data: widget.data, runner: runner, city: city);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Поделиться пробежкой',
              style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chip('Карточка', false),
                const SizedBox(width: 8),
                _chip('Стикер на своё фото', true),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10141A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: RepaintBoundary(key: _boundaryKey, child: preview),
            ),
            if (_stickerMode)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeTrackColor: _lime.withValues(alpha: .5),
                title: const Text(
                  'Цифры на стикере',
                  style: TextStyle(fontSize: 13.5, color: _ink),
                ),
                value: _showStats,
                onChanged: (v) => setState(() => _showStats = v),
              )
            else
              const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _lime,
                  foregroundColor: const Color(0xFF171C19),
                  minimumSize: const Size(64, 52),
                ),
                onPressed: _busy ? null : () => _send(instagram: true),
                child: const Text(
                  'В сторис Инстаграма',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: BorderSide(color: _ink.withValues(alpha: .3)),
                  minimumSize: const Size(64, 48),
                ),
                onPressed: _busy ? null : () => _send(instagram: false),
                child: const Text('Отправить в другое приложение'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool sticker) {
    final selected = _stickerMode == sticker;
    return GestureDetector(
      onTap: () => setState(() => _stickerMode = sticker),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _lime.withValues(alpha: .16) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _lime.withValues(alpha: .8)
                : _ink.withValues(alpha: .25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? _lime : _ink.withValues(alpha: .65),
          ),
        ),
      ),
    );
  }

  Future<void> _send({required bool instagram}) async {
    setState(() => _busy = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final shareDir = Directory('${dir.path}/insta_share');
      await shareDir.create(recursive: true);
      final file = File(
        '${shareDir.path}/kvartal_run_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());

      if (instagram) {
        var ok = false;
        if (_metaAppId.isNotEmpty && Platform.isAndroid) {
          ok = await _instaChannel.invokeMethod<bool>(
                _stickerMode ? 'shareSticker' : 'shareBackground',
                {'path': file.path, 'appId': _metaAppId},
              ) ??
              false;
        }
        if (ok) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Инстаграм недоступен — отправляю обычным шарингом'),
          ));
        }
      }
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Моя пробежка в КВАРТАЛЕ',
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Сторис-карточка 9:16: неон-росчерк над сеткой города; при захвате —
/// заголовок-вызов вместо сухих цифр (вариант B дизайна).
class RunStoryCard extends StatelessWidget {
  final RunShareData data;
  final String runner;
  final String? city;

  const RunStoryCard({
    super.key,
    required this.data,
    required this.runner,
    this.city,
  });

  @override
  Widget build(BuildContext context) {
    final d = data;
    final captured = d.capturedZones > 0;
    final date =
        '${d.finishedAt.day.toString().padLeft(2, '0')}.${d.finishedAt.month.toString().padLeft(2, '0')}.${d.finishedAt.year}';
    final time =
        '${d.finishedAt.hour.toString().padLeft(2, '0')}:${d.finishedAt.minute.toString().padLeft(2, '0')}';
    final pace = d.distanceKm < .01 || d.elapsed.inSeconds == 0
        ? '--:--'
        : _fmtPace((d.elapsed.inSeconds / d.distanceKm).round());

    return Container(
      width: 270,
      height: 480,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const RadialGradient(
          center: Alignment(0, -.8),
          radius: 1.5,
          colors: [Color(0xFF222A33), _bg, Color(0xFF090C10)],
          stops: [0, .55, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: d.route.length >= 2
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: CustomPaint(
                      painter: RoutePainter(
                        route: d.route,
                        progress: 1,
                        fill: captured ? 1 : 0,
                        fitFactor: 1,
                        topInset: 8,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.route,
                      size: 64,
                      color: _lime.withValues(alpha: .4),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (captured) ...[
                  Text(
                    'Забрал ${d.capturedZones} ${_qWord(d.capturedZones)}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${d.distanceKm.toStringAsFixed(2)} км · вернуть можно только бегом',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        d.distanceKm.toStringAsFixed(2),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          height: 1,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'КМ',
                        style: TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _lime,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  '$date · $time${city == null ? '' : ' · ${city!.toUpperCase()}'} · $runner',
                  style: const TextStyle(
                    fontSize: 8.5,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statChip(_fmtElapsed(d.elapsed), 'ВРЕМЯ'),
                    const SizedBox(width: 7),
                    _statChip(pace, 'ТЕМП /КМ'),
                    if (captured) ...[
                      const SizedBox(width: 7),
                      _statChip('+${d.capturedZones}', 'КВАРТАЛА', lime: true),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const _BrandRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String v, String l, {bool lime = false}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: _panel.withValues(alpha: .75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: lime
                  ? _lime.withValues(alpha: .55)
                  : Colors.white.withValues(alpha: .09),
            ),
          ),
          child: Column(
            children: [
              Text(
                v,
                style: TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                  color: lime ? _lime : _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l,
                style: const TextStyle(
                  fontSize: 7.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      );
}

/// Прозрачный стикер: росчерк + (опционально) цифры с тенями. Ноль подложки.
class RunSticker extends StatelessWidget {
  final RunShareData data;
  final bool showStats;

  const RunSticker({super.key, required this.data, required this.showStats});

  @override
  Widget build(BuildContext context) {
    final d = data;
    final pace = d.distanceKm < .01 || d.elapsed.inSeconds == 0
        ? '--:--'
        : _fmtPace((d.elapsed.inSeconds / d.distanceKm).round());
    return SizedBox(
      width: 230,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 230,
            height: 190,
            child: d.route.length >= 2
                ? CustomPaint(painter: _StickerTrackPainter(d.route))
                : const SizedBox.shrink(),
          ),
          if (showStats) ...[
            const SizedBox(height: 8),
            Text(
              '${d.distanceKm.toStringAsFixed(2)} КМ',
              style: TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                height: 1,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 14,
                    color: Colors.black.withValues(alpha: .6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${_fmtElapsed(d.elapsed)} · $pace /км',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black.withValues(alpha: .65),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xF20F1216),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _lime.withValues(alpha: .5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(15, 15),
                  painter: KvartalMarkPainter(
                    outline: _lime,
                    fill: Colors.transparent,
                    close: 1,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'КВАРТАЛ',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Трек стикера: неоновый росчерк со свечением, старт-точка и финиш-флаг.
/// Без сетки и подложки — прозрачность священна.
class _StickerTrackPainter extends CustomPainter {
  final List<LatLng> route;
  _StickerTrackPainter(this.route);

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;
    var minLat = route.first.latitude, maxLat = minLat;
    var minLng = route.first.longitude, maxLng = minLng;
    for (final p in route) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    final latSpan = (maxLat - minLat).abs().clamp(1e-6, double.infinity);
    final lngSpan = (maxLng - minLng).abs().clamp(1e-6, double.infinity);
    const pad = 18.0;
    final scale = ((size.width - pad * 2) / lngSpan)
        .clamp(0, (size.height - pad * 2) / latSpan)
        .toDouble();
    final w = lngSpan * scale, h = latSpan * scale;
    final ox = (size.width - w) / 2, oy = (size.height - h) / 2;
    Offset pt(LatLng p) => Offset(
          ox + (p.longitude - minLng) * scale,
          oy + (maxLat - p.latitude) * scale,
        );

    final path = Path()..moveTo(pt(route.first).dx, pt(route.first).dy);
    for (final p in route.skip(1)) {
      path.lineTo(pt(p).dx, pt(p).dy);
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = _lime.withValues(alpha: .55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = _lime;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);

    // Старт-точка.
    final start = pt(route.first);
    canvas.drawCircle(
      start,
      6,
      Paint()..color = const Color(0xFF171C19),
    );
    canvas.drawCircle(
      start,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _lime,
    );
    // Финиш-флаг.
    final fin = pt(route.last);
    final pole = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(fin, fin - const Offset(0, 20), pole);
    final flag = Path()
      ..moveTo(fin.dx, fin.dy - 20)
      ..lineTo(fin.dx + 15, fin.dy - 15.5)
      ..lineTo(fin.dx, fin.dy - 11)
      ..close();
    canvas.drawPath(flag, Paint()..color = _lime);
  }

  @override
  bool shouldRepaint(covariant _StickerTrackPainter old) =>
      old.route != route;
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _lime.withValues(alpha: .4)),
      ),
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
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'КВАРТАЛ — беги и захватывай',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .3,
                      color: _ink,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'mata-club.ru/app',
                  style: TextStyle(fontSize: 8.5, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtElapsed(Duration e) {
  final h = e.inHours;
  final m = e.inMinutes % 60;
  final s = e.inSeconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _fmtPace(int sec) =>
    '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

String _qWord(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'кварталов';
  return switch (n % 10) {
    1 => 'квартал',
    2 || 3 || 4 => 'квартала',
    _ => 'кварталов',
  };
}
