import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_access.dart';

class LocationAccessState {
  final LocationLevel level;
  final bool batteryUnrestricted;
  final String manufacturer;
  final bool loaded;

  const LocationAccessState({
    this.level = LocationLevel.denied,
    this.batteryUnrestricted = true,
    this.manufacturer = '',
    this.loaded = false,
  });

  bool get canRun => level != LocationLevel.denied;
  bool get backgroundReady => level == LocationLevel.always;

  /// Фон будет работать стабильно: есть «всегда» И снято ограничение батареи
  /// (на агрессивных брендах батарея критична).
  bool get fullyReady => backgroundReady && batteryUnrestricted;
  bool get aggressiveOem => isAggressiveOem(manufacturer);

  LocationAccessState copyWith({
    LocationLevel? level,
    bool? batteryUnrestricted,
    String? manufacturer,
    bool? loaded,
  }) => LocationAccessState(
    level: level ?? this.level,
    batteryUnrestricted: batteryUnrestricted ?? this.batteryUnrestricted,
    manufacturer: manufacturer ?? this.manufacturer,
    loaded: loaded ?? this.loaded,
  );
}

class LocationAccessNotifier extends StateNotifier<LocationAccessState> {
  LocationAccessNotifier() : super(const LocationAccessState()) {
    refresh();
  }

  Future<void> refresh() async {
    final level = await LocationAccess.level();
    final battery = await LocationAccess.isBatteryUnrestricted();
    final man = state.manufacturer.isEmpty
        ? await LocationAccess.manufacturer()
        : state.manufacturer;
    state = state.copyWith(
      level: level,
      batteryUnrestricted: battery,
      manufacturer: man,
      loaded: true,
    );
  }

  Future<void> requestWhenInUse() async {
    await LocationAccess.requestWhenInUse();
    await refresh();
  }

  Future<void> requestAlways() async {
    await LocationAccess.requestAlways();
    await refresh();
  }

  Future<void> requestBattery() async {
    await LocationAccess.requestBatteryUnrestricted();
    await refresh();
  }

  Future<void> openSettings() => LocationAccess.openSettings();
}

final locationAccessProvider =
    StateNotifierProvider<LocationAccessNotifier, LocationAccessState>(
      (_) => LocationAccessNotifier(),
    );
