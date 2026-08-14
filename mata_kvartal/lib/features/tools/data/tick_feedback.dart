import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Тип сигнала обратной связи (свой звук + свой паттерн вибрации).
enum TickKind { count, work, rest, finish }

/// Звук + вибрация для инструментов (метроном, интервальный таймер).
///
/// Звук — через **пул `AudioPlayer`** с round-robin: каждый следующий сигнал
/// играется на следующем плеере пула, поэтому быстрые повторы (метроном, отсчёт)
/// не «глотаются» одним занятым плеером. Вибрация — через `vibration` (VIBRATE).
class ToolTick {
  static const _poolSize = 6;
  final List<AudioPlayer> _players = [];
  int _next = 0;
  bool _canVibrate = false;

  static const _assets = <TickKind, String>{
    TickKind.count: 'audio/tick.wav',
    TickKind.work: 'audio/work.wav',
    TickKind.rest: 'audio/rest.wav',
    TickKind.finish: 'audio/finish.wav',
  };

  /// Готовит пул плееров и проверяет вибромотор. Вызывать в initState.
  Future<void> init() async {
    try {
      _canVibrate = (await Vibration.hasVibrator()) == true;
    } catch (_) {
      _canVibrate = false;
    }
    for (var i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      try {
        await p.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
      _players.add(p);
    }
  }

  /// Проиграть сигнал: звук (на следующем плеере пула) + вибро.
  Future<void> play(TickKind kind) async {
    if (_players.isNotEmpty) {
      final p = _players[_next];
      _next = (_next + 1) % _players.length;
      try {
        await p.stop();
        await p.play(AssetSource(_assets[kind]!));
      } catch (_) {}
    }
    _vibrate(kind);
  }

  void _vibrate(TickKind kind) {
    if (!_canVibrate) {
      if (kind == TickKind.count) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.heavyImpact();
      }
      return;
    }
    switch (kind) {
      case TickKind.count:
        Vibration.vibrate(duration: 30);
      case TickKind.work:
        Vibration.vibrate(pattern: const [0, 70, 60, 70]);
      case TickKind.rest:
        Vibration.vibrate(duration: 90);
      case TickKind.finish:
        Vibration.vibrate(pattern: const [0, 130, 90, 130, 90, 220]);
    }
  }

  void dispose() {
    for (final p in _players) {
      p.dispose();
    }
  }
}
