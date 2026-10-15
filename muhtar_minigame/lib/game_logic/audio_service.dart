import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Короткие звуковые события игры.
enum GameSound {
  ui,
  dialogueKey,
  battleStart,
  diePlace,
  dieReroll,
  hit,
  hurt,
  victory,
  defeat,
  transition,
  search,
  coins,
}

/// Локальный кроссплатформенный слой коротких звуков.
///
/// Файлы лежат в assets/audio/kenney и распространяются по CC0. Небольшой
/// пул плееров нужен для быстрых событий вроде печати диалога: новый символ не
/// должен обрывать звук предыдущего символа.
class AudioService extends ChangeNotifier {
  static const _assetRoot = 'audio/kenney/';

  bool _enabled = true;
  final List<AudioPlayer> _players = [];
  int _nextPlayer = 0;
  bool _disposed = false;

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  Future<void> play(GameSound sound) async {
    if (!_enabled || _disposed) return;
    final spec = _specFor(sound);
    final player = _player();
    try {
      await player.play(AssetSource(spec.asset), volume: spec.volume);
    } catch (error) {
      // Звук не должен ломать бой или переход между локациями, если на
      // конкретной платформе аудиоплагин недоступен.
      debugPrint('Не удалось воспроизвести звук $sound: $error');
      try {
        await SystemSound.play(spec.fallback);
      } catch (_) {
        // На headless/test-платформах нет ни аудиоплагина, ни системного канала.
      }
    }
  }

  AudioPlayer _player() {
    if (_players.length < 4) {
      _players.add(AudioPlayer());
    }
    final player = _players[_nextPlayer % _players.length];
    _nextPlayer++;
    return player;
  }

  _SoundSpec _specFor(GameSound sound) => switch (sound) {
    GameSound.ui => const _SoundSpec('ui_click.ogg', .32, SystemSoundType.click),
    GameSound.dialogueKey => const _SoundSpec(
      'dialogue_key.ogg',
      .18,
      SystemSoundType.click,
    ),
    GameSound.battleStart => const _SoundSpec(
      'draw_knife.ogg',
      .42,
      SystemSoundType.alert,
    ),
    GameSound.diePlace => const _SoundSpec('drop.ogg', .34, SystemSoundType.click),
    GameSound.dieReroll => const _SoundSpec(
      'select.ogg',
      .28,
      SystemSoundType.click,
    ),
    GameSound.hit => const _SoundSpec('hit.ogg', .48, SystemSoundType.alert),
    GameSound.hurt => const _SoundSpec(
      'heavy_hit.ogg',
      .52,
      SystemSoundType.alert,
    ),
    GameSound.victory => const _SoundSpec(
      'confirmation.ogg',
      .45,
      SystemSoundType.alert,
    ),
    GameSound.defeat => const _SoundSpec('error.ogg', .42, SystemSoundType.alert),
    GameSound.transition => const _SoundSpec('open.ogg', .3, SystemSoundType.alert),
    GameSound.search => const _SoundSpec('search.ogg', .35, SystemSoundType.click),
    GameSound.coins => const _SoundSpec('coins.ogg', .4, SystemSoundType.click),
  };

  @override
  void dispose() {
    _disposed = true;
    for (final player in _players) {
      unawaited(player.dispose());
    }
    _players.clear();
    super.dispose();
  }
}

class _SoundSpec {
  const _SoundSpec(this.fileName, this.volume, this.fallback);

  final String fileName;
  final double volume;
  final SystemSoundType fallback;

  String get asset => '${AudioService._assetRoot}$fileName';
}
