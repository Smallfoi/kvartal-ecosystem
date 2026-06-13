import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'location_provider.dart';

// ~65m ≈ one city block — user sees which block to run through
const _hexRadius = 65.0; // meters, center-to-vertex
const _metersPerDegLat = 111000.0;
const _sqrt3 = 1.7320508075688772;

enum HexOwner { free, mine, club, enemy }

class HexTile {
  final int q, r;
  final List<LatLng> vertices;
  final HexOwner owner;
  final int stars;

  const HexTile({
    required this.q,
    required this.r,
    required this.vertices,
    required this.owner,
    required this.stars,
  });

  String get id => '$q:$r';
}

// ── Geometry ─────────────────────────────────────────────────────────────────

// Axial (q, r) → geographic center relative to origin
LatLng _axialToLatLng(int q, int r, LatLng origin) {
  final cosLat = cos(origin.latitude * pi / 180);
  final metersPerDegLng = _metersPerDegLat * cosLat;
  // pointy-top: x = √3*(q + r/2), y = 3/2*r
  final xMeters = _hexRadius * _sqrt3 * (q + r / 2.0);
  final yMeters = _hexRadius * 1.5 * r;
  return LatLng(
    origin.latitude + yMeters / _metersPerDegLat,
    origin.longitude + xMeters / metersPerDegLng,
  );
}

// 6 vertices of a pointy-top hex (slightly smaller than grid to show borders)
List<LatLng> _hexVertices(LatLng center) {
  final cosLat = cos(center.latitude * pi / 180);
  final metersPerDegLng = _metersPerDegLat * cosLat;
  const r = _hexRadius * 0.96;
  return List.generate(6, (i) {
    final angle = (60.0 * i - 30.0) * pi / 180; // pointy-top, start at -30°
    return LatLng(
      center.latitude + r * sin(angle) / _metersPerDegLat,
      center.longitude + r * cos(angle) / metersPerDegLng,
    );
  });
}

// Geographic point → nearest axial (q, r) relative to origin
(int, int) _latLngToAxial(LatLng point, LatLng origin) {
  final cosLat = cos(origin.latitude * pi / 180);
  final metersPerDegLng = _metersPerDegLat * cosLat;
  final x = (point.longitude - origin.longitude) * metersPerDegLng;
  final y = (point.latitude - origin.latitude) * _metersPerDegLat;
  // Pointy-top fractional axial
  final qf = (x * _sqrt3 / 3 - y / 3) / _hexRadius;
  final rf = y * 2 / 3 / _hexRadius;
  // Cube rounding
  final sf = -qf - rf;
  var qi = qf.round();
  var ri = rf.round();
  final si = sf.round();
  final dq = (qi - qf).abs();
  final dr = (ri - rf).abs();
  final ds = (si - sf).abs();
  if (dq > dr && dq > ds) {
    qi = -ri - si;
  } else if (dr > ds) {
    ri = -qi - si;
  }
  return (qi, ri);
}

// ── Mock data ────────────────────────────────────────────────────────────────

HexOwner _mockOwner(int q, int r) {
  final h = ((q * 73856093) ^ (r * 19349663)).abs() % 13;
  if (h < 2) return HexOwner.mine;
  if (h < 5) return HexOwner.club;
  if (h < 7) return HexOwner.enemy;
  return HexOwner.free;
}

// ── Provider ─────────────────────────────────────────────────────────────────

final hexTilesProvider = Provider<List<HexTile>>((ref) {
  final posAsync = ref.watch(positionStreamProvider);
  final pos = posAsync.valueOrNull?.toLatLng ?? yakutskCenter;
  final (cq, cr) = _latLngToAxial(pos, yakutskCenter);

  const k = 10; // radius in hex steps (331 hexes, covers ~1.3km at 65m each)
  final tiles = <HexTile>[];

  for (var dq = -k; dq <= k; dq++) {
    final rMin = max(-k, -dq - k);
    final rMax = min(k, -dq + k);
    for (var dr = rMin; dr <= rMax; dr++) {
      final q = cq + dq;
      final r = cr + dr;
      final center = _axialToLatLng(q, r, yakutskCenter);
      tiles.add(
        HexTile(
          q: q,
          r: r,
          vertices: _hexVertices(center),
          owner: _mockOwner(q, r),
          stars: ((q.abs() * 3 + r.abs() * 7) % 5) + 1,
        ),
      );
    }
  }

  return tiles;
});
