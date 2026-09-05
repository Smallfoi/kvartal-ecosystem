import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/kvartal_logo.dart';
import '../../auth/data/auth_provider.dart';
import '../data/medal_defs.dart';
import '../data/medals_provider.dart';
import 'medal_widgets.dart';

/// Шаринг медалей и Зала славы в сторис (дизайн «Хвастовство в сторис»,
/// утверждён владельцем 05.09.2026 с правками: кнопка — «Поделиться»,
/// стикер обязателен и редактируем, пустых слотов на карточке зала нет).
///
/// Два пути:
/// - «В сторис Инстаграма» — нативный интент как у Стравы: стикер приезжает
///   в редактор сторис ПОВЕРХ фона бегуна (двигается/масштабируется штатно),
///   карточка — фоном целиком. Требует Meta App ID — до его получения путь
///   честно падает в системный шит.
/// - «Отправить» — системный шит (share_plus): любой мессенджер.
///
/// Meta App ID приложения «MATA-ECOSYSTEM» (developers.facebook.com,
/// аккаунт владельца, создано 05.09.2026). App ID — публичное значение
/// (он виден в каждом APK любого приложения с шарингом в сторис);
/// секретом у Меты является только App Secret, который здесь не нужен.
/// CI может переопределить через --dart-define=META_APP_ID.
///
/// ГРАБЛЯ (поймана 05.09 на телефоне владельца): `--dart-define=META_APP_ID=`
/// с ПУСТЫМ значением (нераскрытый секрет CI) ПЕРЕКРЫВАЕТ defaultValue —
/// fromEnvironment возвращает "", нативный путь молча падал в фолбэк.
/// Поэтому пустое окружение всегда откатывается на вшитый ID.
const _envMetaAppId = String.fromEnvironment('META_APP_ID');
const kMetaAppId =
    _envMetaAppId == '' ? '1058928553560826' : _envMetaAppId;

const _instaChannel = MethodChannel('kvartal/instagram_share');

// Палитра карточек — константы сторис-мира (карточка живёт в чужой ленте,
// от темы приложения не зависит).
const _bg = Color(0xFF12161B);
const _panel = Color(0xFF1B2129);
const _ink = Color(0xFFEDEFE8);
const _muted = Color(0xFF97A0A6);
const _lime = Color(0xFFDFF45F);

/// Шит «Поделиться» для одной медали.
Future<void> showMedalShareSheet(BuildContext context, MedalFull medal) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF161B21),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ShareSheet(medal: medal),
  );
}

/// Шит «Поделиться» для всего Зала славы.
Future<void> showHallShareSheet(BuildContext context, List<MedalFull> earned) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF161B21),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ShareSheet(hall: earned),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  final MedalFull? medal;
  final List<MedalFull>? hall;
  const _ShareSheet({this.medal, this.hall});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _boundaryKey = GlobalKey();
  bool _stickerMode = false; // false = карточка 9:16, true = стикер
  bool _engraving = true; // гравировка на стикере (можно скрыть)
  bool _busy = false;

  bool get _isHall => widget.hall != null;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final runner = user?.name ?? 'Бегун КВАРТАЛ';
    final city = user?.city;

    final preview = _isHall
        ? HallStoryCard(medals: widget.hall!, runner: runner)
        : _stickerMode
            ? MedalSticker(medal: widget.medal!, engraving: _engraving)
            : MedalStoryCard(
                medal: widget.medal!, runner: runner, city: city);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isHall ? 'Поделиться залом' : 'Поделиться медалью',
              style: const TextStyle(
                fontFamily: AppTheme.fontDisplay,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            if (!_isHall) _modeSwitch(),
            const SizedBox(height: 12),
            // Превью на «шахматке», чтобы прозрачность стикера была видна.
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10141A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: RepaintBoundary(key: _boundaryKey, child: preview),
            ),
            if (!_isHall && _stickerMode) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeTrackColor: _lime.withValues(alpha: .5),
                title: const Text(
                  'Гравировка на стикере',
                  style: TextStyle(fontSize: 13.5, color: _ink),
                ),
                value: _engraving,
                onChanged: (v) => setState(() => _engraving = v),
              ),
            ] else
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

  Widget _modeSwitch() {
    Widget chip(String label, bool sticker) {
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip('Карточка', false),
        const SizedBox(width: 8),
        chip('Стикер на своё фото', true),
      ],
    );
  }

  Future<void> _send({required bool instagram}) async {
    setState(() => _busy = true);
    try {
      final file = await _renderToFile();
      if (file == null) return;
      if (instagram) {
        final method = (!_isHall && _stickerMode)
            ? 'shareSticker'
            : 'shareBackground';
        var ok = false;
        if (kMetaAppId.isNotEmpty && Platform.isAndroid) {
          ok = await _instaChannel.invokeMethod<bool>(method, {
                'path': file.path,
                'appId': kMetaAppId,
              }) ??
              false;
        }
        if (ok) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        // Инста недоступна (нет App ID / не установлена) — системный шит.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Инстаграм недоступен — отправляю обычным шарингом'),
          ));
        }
      }
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: _isHall
            ? 'Мой зал славы в КВАРТАЛЕ'
            : 'Моя медаль в КВАРТАЛЕ',
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File?> _renderToFile() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // 270 логических → 1080 px: сторис-стандарт.
    final image = await boundary.toImage(pixelRatio: 4);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final shareDir = Directory('${dir.path}/insta_share');
    await shareDir.create(recursive: true);
    final file = File(
      '${shareDir.path}/kvartal_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }
}

/// Сторис-карточка медали 9:16 (мокап A): медаль в луче, гравировка, имя,
/// плашка бренда. 270×480 логических — рендер ×4 даёт 1080×1920.
class MedalStoryCard extends StatelessWidget {
  final MedalFull medal;
  final String runner;
  final String? city;

  const MedalStoryCard({
    super.key,
    required this.medal,
    required this.runner,
    this.city,
  });

  @override
  Widget build(BuildContext context) {
    final e = medal.state.engraving;
    final date = medal.state.earnedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(medal.state.earnedAtMs!);
    return Container(
      width: 270,
      height: 480,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const RadialGradient(
          center: Alignment(0, -.7),
          radius: 1.4,
          colors: [Color(0xFF232B34), _bg, Color(0xFF0A0D11)],
          stops: [0, .55, 1],
        ),
      ),
      child: Stack(
        children: [
          // Луч прожектора.
          Positioned(
            top: -20,
            left: 60,
            right: 60,
            height: 280,
            child: ClipPath(
              clipper: _BeamClipper(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _ink.withValues(alpha: .10),
                      _ink.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              const Spacer(flex: 3),
              MedalImage(def: medal.def, earned: true, size: 168),
              const SizedBox(height: 16),
              Text(
                medal.def.name,
                style: const TextStyle(
                  fontFamily: AppTheme.fontDisplay,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              if (e != null && e.v.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  '${e.v} · ${e.u}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                    color: _lime,
                  ),
                ),
              ],
              if (date != null) ...[
                const SizedBox(height: 4),
                Text(
                  'ПОЛУЧЕНА ${_fmt(date)}${city == null ? '' : ' · ${city!.toUpperCase()}'}',
                  style: const TextStyle(
                    fontSize: 8.5,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                runner,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _ink.withValues(alpha: .75),
                ),
              ),
              const Spacer(flex: 4),
              const _BrandRow(),
              const SizedBox(height: 12),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

/// Прозрачный стикер (мокап B): штамп + опциональная плашка гравировки.
/// Фон полностью бегуна — Инста сама даёт двигать и масштабировать.
class MedalSticker extends StatelessWidget {
  final MedalFull medal;
  final bool engraving;

  const MedalSticker({
    super.key,
    required this.medal,
    required this.engraving,
  });

  @override
  Widget build(BuildContext context) {
    final e = medal.state.engraving;
    final showPlaque = engraving && e != null && e.v.isNotEmpty;
    return SizedBox(
      width: 220,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MedalImage(def: medal.def, earned: true, size: 190),
          if (showPlaque) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xF20F1216),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _lime.withValues(alpha: .5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    medal.def.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontDisplay,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${e.v} · ${e.u}'.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: _lime,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Сторис-карточка Зала славы (мокап C, БЕЗ пустых слотов — решение
/// владельца 05.09): сетка добытых штампов + счёт «N из 44».
class HallStoryCard extends StatelessWidget {
  final List<MedalFull> medals;
  final String runner;

  const HallStoryCard({super.key, required this.medals, required this.runner});

  @override
  Widget build(BuildContext context) {
    final earned = medals.where((m) => m.earned).toList();
    final shown = earned.take(12).toList();
    final extra = earned.length - shown.length;
    return Container(
      width: 270,
      height: 480,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const RadialGradient(
          center: Alignment(0, -.9),
          radius: 1.5,
          colors: [Color(0xFF232B34), _bg, Color(0xFF0A0D11)],
          stops: [0, .5, 1],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 26),
          const Text(
            'ЗАЛ СЛАВЫ',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: _lime,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            runner,
            style: const TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${earned.length} из ${kMedals.length} · Штамп МАТА',
            style: const TextStyle(fontSize: 10, color: _muted),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final m in shown)
                  MedalImage(def: m.def, earned: true, size: 64),
                if (extra > 0)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Center(
                      child: Text(
                        '+$extra',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontDisplay,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _lime,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          const _BrandRow(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Несмываемая плашка бренда — на каждом экспорте (вирусный контур).
class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
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

class _BeamClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .38, 0)
    ..lineTo(size.width * .62, 0)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
