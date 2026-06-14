import 'dart:math' show max;
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/location_provider.dart';
import '../../data/zone_provider.dart';
import '../../../run/data/run_provider.dart';
import '../../../offline_maps/data/offline_maps_provider.dart';
import '../../../../shared/widgets/kvartal_logo.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  final _flashing = <String>{};

  bool _followUser = true;
  bool _baseMapFailed = false;
  int _tileErrorCount = 0;
  int _tileLayerReloadId = 0;

  void _handleTileError() {
    _tileErrorCount++;
    if (_tileErrorCount < 4 || _baseMapFailed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _baseMapFailed) return;
      setState(() => _baseMapFailed = true);
    });
  }

  void _retryBaseMap() {
    setState(() {
      _baseMapFailed = false;
      _tileErrorCount = 0;
      _tileLayerReloadId++;
    });
  }

  void _openOfflineMaps() => context.push('/offline-maps');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerOnCurrentLocation(),
    );
  }

  Future<void> _centerOnCurrentLocation() async {
    final pos = await ref.read(currentPositionProvider.future);
    if (!mounted || pos == null) return;
    _mapController.move(pos.toLatLng, max(_mapController.camera.zoom, 15));
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zoneProvider);
    final zones = zonesAsync.valueOrNull ?? const <BlockZone>[];
    final capturedAreas = ref.watch(capturedAreasProvider);
    final posAsync = ref.watch(positionStreamProvider);
    final runState = ref.watch(runProvider);
    final offlineMap = ref.watch(offlineMapsProvider);
    final offlineTileTemplate = offlineMap.isDownloaded
        ? offlineMap.tileUrlTemplate
        : null;
    final useOfflineBaseMap = offlineTileTemplate != null;
    final closureStatus = ref
        .read(zoneProvider.notifier)
        .inspectLoopClosure(runState.route);
    ref.listen(positionStreamProvider, (_, next) {
      final pos = next.valueOrNull;
      if (!_followUser || pos == null) return;
      _mapController.move(pos.toLatLng, _mapController.camera.zoom);
    });
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: yakutskCenter,
              initialZoom: 14,
              minZoom: 5,
              maxZoom: 20,
              onMapEvent: (e) {
                if (e is MapEventMove && e.source == MapEventSource.onDrag) {
                  if (_followUser) setState(() => _followUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(_tileLayerReloadId),
                // Стандартный OSM (Mapnik): рисует здания, POI, названия улиц и
                // НОМЕРА ДОМОВ на z18-19 (Voyager их не показывает вовсе).
                // ВНИМАНИЕ: tile.openstreetmap.org — community-сервис, для прод-нагрузки
                // нужен свой/платный тайл-провайдер (MapTiler/Thunderforest/self-host).
                urlTemplate:
                    offlineTileTemplate ??
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: useOfflineBaseMap ? FileTileProvider() : null,
                userAgentPackageName: 'com.kvartal.kvartal_app',
                // Онлайн: z19 — на этом зуме Voyager рисует номера домов.
                // Офлайн: тайлы скачаны только до z15, выше — переувеличение.
                maxNativeZoom: useOfflineBaseMap ? 15 : 19,
                errorTileCallback: (_, __, ___) {
                  if (!useOfflineBaseMap) _handleTileError();
                },
              ),

              if (capturedAreas.isNotEmpty)
                PolygonLayer(
                  polygons: capturedAreas
                      .map(
                        (area) => Polygon(
                          points: area.vertices,
                          color: AppColors.electricBlue.withValues(alpha: 0.18),
                          borderColor: AppColors.electricBlue.withValues(
                            alpha: 0.70,
                          ),
                          borderStrokeWidth: 1.2,
                        ),
                      )
                      .toList(),
                ),

              // City block territory polygons
              PolygonLayer(
                polygons: zones.map((z) {
                  final flash = _flashing.contains(z.id);
                  return Polygon(
                    points: z.vertices,
                    color: _fill(z.owner, flash: flash),
                    borderColor: _border(z.owner, flash: flash),
                    borderStrokeWidth: flash ? 3.5 : 1.5,
                  );
                }).toList(),
              ),

              // Run route line
              if (runState.status != RunStatus.idle &&
                  runState.route.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: runState.route,
                      color: AppColors.electricBlue,
                      strokeWidth: 2.4,
                      borderColor: AppColors.electricBlue.withValues(alpha: 0),
                      borderStrokeWidth: 0,
                    ),
                  ],
                ),
              if (runState.status != RunStatus.idle &&
                  runState.route.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: runState.route.first,
                      width: 30,
                      height: 34,
                      child: const _RoutePointMarker(
                        label: 'Старт',
                        color: AppColors.success,
                        icon: CupertinoIcons.play_fill,
                      ),
                    ),
                  ],
                ),

              // Маркер пользователя. Во время бега берём ПОСЛЕДНЮЮ точку
              // сглаженного трека — тогда маркер и линия совпадают и не прыгают.
              // Вне бега — текущая позиция из потока.
              Builder(
                builder: (_) {
                  final running = runState.status != RunStatus.idle &&
                      runState.route.isNotEmpty;
                  final point = running
                      ? runState.route.last
                      : posAsync.valueOrNull?.toLatLng;
                  if (point == null) return const MarkerLayer(markers: []);
                  return MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 26,
                        height: 26,
                        child: _UserMarker(
                          isRunning: runState.status == RunStatus.active,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),

          // ── Top bar + legend ─────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        _KvartalTopLogo(
                          cityName: offlineMap.name,
                          onTap: _openOfflineMaps,
                        ),
                        const Spacer(),
                        _WeatherChip(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2, bottom: 4),
                    child: _Legend(),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading indicator ────────────────────────────────────────────
          if (zonesAsync is AsyncLoading)
            const Center(
              child: _Glass(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.electricBlue,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Загружаем кварталы улиц Якутска...',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // ── Error banner (центр экрана) ──────────────────────────────────
          if (zonesAsync is AsyncError)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _Glass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.wifi_slash,
                        color: AppColors.error,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Зоны не загружены',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'GPS работает.\nЗапусти бэкенд и нажми «Повторить».',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => ref.read(zoneProvider.notifier).retry(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.electricBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.arrow_clockwise,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Повторить',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom area: buttons + stats ─────────────────────────────────
          if (_baseMapFailed)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _OfflineMapNotice(
                  onRetry: _retryBaseMap,
                  onOfflineMap: _openOfflineMaps,
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (offlineMap.isDownloading)
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 10),
                      child: _OfflineDownloadChip(
                        progress: offlineMap.progress,
                        onTap: _openOfflineMaps,
                      ),
                    ),
                  if (!_followUser)
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 10),
                      child: _IconBtn(
                        icon: CupertinoIcons.location_fill,
                        color: AppColors.electricBlue,
                        onTap: () {
                          setState(() => _followUser = true);
                          posAsync.whenData((p) {
                            if (p == null) return;
                            _mapController.move(
                              p.toLatLng,
                              _mapController.camera.zoom,
                            );
                          });
                        },
                      ),
                    ),
                  _BottomPanel(
                    runState: runState,
                    zones: zones,
                    closureStatus: closureStatus,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _fill(ZoneOwner owner, {bool flash = false}) {
    if (flash) return AppColors.warning.withValues(alpha: 0.42);
    return switch (owner) {
      ZoneOwner.mine => AppColors.hexOwned.withValues(alpha: 0.22),
      ZoneOwner.enemy => AppColors.hexEnemy.withValues(alpha: 0.18),
      ZoneOwner.club => AppColors.success.withValues(alpha: 0.18),
      ZoneOwner.free => Colors.transparent,
    };
  }

  Color _border(ZoneOwner owner, {bool flash = false}) {
    if (flash) return AppColors.warning;
    return switch (owner) {
      ZoneOwner.mine => AppColors.hexOwned.withValues(alpha: 0.70),
      ZoneOwner.enemy => AppColors.hexEnemy.withValues(alpha: 0.58),
      ZoneOwner.club => AppColors.success.withValues(alpha: 0.58),
      ZoneOwner.free => Colors.white.withValues(alpha: 0.08),
    };
  }
}

// ── Markers ───────────────────────────────────────────────────────────────────

class _OfflineDownloadChip extends StatelessWidget {
  final double progress;
  final VoidCallback onTap;

  const _OfflineDownloadChip({required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).round();
    return GestureDetector(
      onTap: onTap,
      child: _Glass(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: SizedBox(
          width: 178,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.cloud_download,
                    color: AppColors.electricBlue,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '\u041a\u0430\u0440\u0442\u0430 $percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.white38,
                    size: 12,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: progress.clamp(0, 1),
                  color: AppColors.electricBlue,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineMapNotice extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onOfflineMap;

  const _OfflineMapNotice({required this.onRetry, required this.onOfflineMap});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.map, color: AppColors.warning, size: 28),
          const SizedBox(height: 10),
          const Text(
            '\u041a\u0430\u0440\u0442\u0430 \u043d\u0435 \u0437\u0430\u0433\u0440\u0443\u0436\u0435\u043d\u0430',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            '\u041f\u043e\u0434\u043a\u043b\u044e\u0447\u0438\u0442\u0435\u0441\u044c \u043a \u0438\u043d\u0442\u0435\u0440\u043d\u0435\u0442\u0443 \u0438\u043b\u0438 \u0441\u043a\u0430\u0447\u0430\u0439\u0442\u0435 \u043e\u0444\u043b\u0430\u0439\u043d-\u043a\u0430\u0440\u0442\u0443.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.25),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _NoticeButton(
                  label:
                      '\u041f\u043e\u0432\u0442\u043e\u0440\u0438\u0442\u044c',
                  icon: CupertinoIcons.arrow_clockwise,
                  color: AppColors.electricBlue,
                  onTap: onRetry,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NoticeButton(
                  label: '\u041e\u0444\u043b\u0430\u0439\u043d',
                  icon: CupertinoIcons.arrow_down_circle,
                  color: AppColors.bgElevated,
                  onTap: onOfflineMap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoticeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NoticeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserMarker extends StatefulWidget {
  final bool isRunning;
  const _UserMarker({required this.isRunning});

  @override
  State<_UserMarker> createState() => _UserMarkerState();
}

class _UserMarkerState extends State<_UserMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat();
    _scale = Tween<double>(
      begin: 1.0,
      end: 2.6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.isRunning ? AppColors.success : AppColors.electricBlue;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Пульсирующее кольцо
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c, width: 2),
                ),
              ),
            ),
          ),
        ),
        // Основная точка
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: 0.22),
            border: Border.all(color: c, width: 2),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
      ],
    );
  }
}

class _RoutePointMarker extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _RoutePointMarker({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.76),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 13),
      ),
    );
  }
}

// ── Frosted glass ─────────────────────────────────────────────────────────────

class _Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  const _Glass({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _KvartalTopLogo extends StatelessWidget {
  final String cityName;
  final VoidCallback onTap;

  const _KvartalTopLogo({required this.cityName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _Glass(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KvartalLogoBadge(size: 24),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '\u0433\u043e\u0440\u043e\u0434 ',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                Text(
                  cityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  CupertinoIcons.chevron_down,
                  color: Colors.white38,
                  size: 9,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip();

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.snow, size: 12, color: AppColors.info),
          const SizedBox(width: 4),
          Text(
            '−24°C',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.electricBlue.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'x1.4',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          _LegendDot(color: AppColors.hexOwned, label: 'Мои'),
          SizedBox(height: 3),
          _LegendDot(color: AppColors.hexEnemy, label: 'Чужие'),
          SizedBox(height: 3),
          _LegendDot(color: AppColors.success, label: 'Клуб'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Glass(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── Bottom panel ──────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final RunState runState;
  final List<BlockZone> zones;
  final LoopClosureStatus closureStatus;

  const _BottomPanel({
    required this.runState,
    required this.zones,
    required this.closureStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = runState.status != RunStatus.idle;
    final mine = zones.where((z) => z.owner == ZoneOwner.mine).length;
    final enemy = zones.where((z) => z.owner == ZoneOwner.enemy).length;
    final club = zones.where((z) => z.owner == ZoneOwner.club).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: _Glass(
        padding: const EdgeInsets.all(12),
        child: isRunning
            ? Row(
                children: [
                  _Stat(
                    label: 'Дистанция',
                    value: '${runState.distanceKm.toStringAsFixed(2)} км',
                  ),
                  _Div(),
                  _Stat(label: 'Время', value: runState.elapsedFormatted),
                  _Div(),
                  _Stat(
                    label: 'До старта',
                    value: runState.route.length < 2
                        ? '-- м'
                        : '${closureStatus.gapMeters.round()} м',
                  ),
                ],
              )
            : Row(
                children: [
                  _Stat(
                    label: 'Мои',
                    value: '$mine',
                    icon: CupertinoIcons.hexagon,
                    color: AppColors.hexOwned,
                  ),
                  _Div(),
                  _Stat(
                    label: 'Чужих',
                    value: '$enemy',
                    icon: CupertinoIcons.flag,
                    color: AppColors.hexEnemy,
                  ),
                  _Div(),
                  _Stat(
                    label: 'Клуб',
                    value: '$club',
                    icon: CupertinoIcons.person_2,
                    color: AppColors.success,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData? icon;
  final Color? color;
  const _Stat({
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: c),
            const SizedBox(height: 4),
          ],
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: c),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.bgElevated);
}
