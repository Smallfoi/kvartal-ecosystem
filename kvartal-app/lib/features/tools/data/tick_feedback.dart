import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Тип сигнала обратной связи (свой звук + свой паттерн вибрации).
enum TickKind { count, work, rest, finish }

/// Звук + вибрация для инструментов (метроном, интервальный таймер).
/// Надёжная замена тихого `SystemSound`: реальный аудио-тик (ассеты) + сильная
/// вибрация через пакет `vibration`. Разные сигналы для разных событий.
class ToolTick {
  final AudioPlayer _player = AudioPlayer();
  bool _canVibrate = false;

  static const _assets = <TickKind, String>{
    TickKind.count: 'audio/tick.wav',
    TickKind.work: 'audio/work.wav',
    TickKind.rest: 'audio/rest.wav',
    TickKind.finish: 'audio/finish.wav',
  };

  /// Готовит плеер и проверяет наличие вибромотора. Вызывать в initState.
  Future<void> init() async {
    try {
      _canVibrate = (await Vibration.hasVibrator()) == true;
    } catch (_) {
      _canVibrate = false;
    }
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {}
  }

  /// Проиграть сигнал: звук + вибро.
  Future<void> play(TickKind kind) async {
    try {
      await _player.play(AssetSource(_assets[kind]!));
    } catch (_) {}
    _vibrate(kind);
  }

  void _vibrate(TickKind kind) {
    if (!_canVibrate) {
      // Запасной вариант, если пакет вибрации недоступен.
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
    _player.dispose();
  }
}
