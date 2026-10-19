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

/// Фоновые композиции, подобранные для текущих локаций и режимов игры.
enum MusicTrack {
  menu,
  station,
  park,
  bridge,
  exploration,
  donerShop,
  kopeechkaShop,
  cheburechnayaShop,
  arianaShop,
  college,
  chill,
  retro,
  fight,
  boss,
  puzzle,
}

extension MusicTrackInfo on MusicTrack {
  String get fileName => switch (this) {
    MusicTrack.menu => 'menu_bg_music_1.wav',
    MusicTrack.station => 'station_bg_music_1.wav',
    MusicTrack.park => 'park_bg_music_1.wav',
    MusicTrack.bridge => 'bridge_bg_music_1.wav',
    MusicTrack.exploration => 'exploration_bg_music_1.wav',
    MusicTrack.donerShop => 'shop_bg_music_1.wav',
    MusicTrack.kopeechkaShop => 'shop_bg_music_2.wav',
    MusicTrack.cheburechnayaShop => 'shop_bg_music_3.wav',
    MusicTrack.arianaShop => 'shop_bg_music_4.wav',
    MusicTrack.college => 'college_bg_music_1.wav',
    MusicTrack.chill => 'chill_bg_music_1.wav',
    MusicTrack.retro => 'retro_bg_music_1.wav',
    MusicTrack.fight => 'fight_bg_music_1.wav',
    MusicTrack.boss => 'boss_bg_music_1.wav',
    MusicTrack.puzzle => 'puzzle_bg_music_1.wav',
  };
}

MusicTrack musicTrackForShop(String npcId) => switch (npcId) {
  'ariana' => MusicTrack.arianaShop,
  'baba_galya' => MusicTrack.cheburechnayaShop,
  'alenka' => MusicTrack.kopeechkaShop,
  'shaurmek' => MusicTrack.donerShop,
  _ => MusicTrack.donerShop,
};

MusicTrack musicTrackForLocation(String locationId) => switch (locationId) {
  'meadow' => MusicTrack.station,
  'forest' => MusicTrack.park,
  'ruins' => MusicTrack.bridge,
  'horse' => MusicTrack.exploration,
  'doner' => MusicTrack.donerShop,
  'kopeechka' => MusicTrack.kopeechkaShop,
  'cheburechnaya' => MusicTrack.cheburechnayaShop,
  'college' => MusicTrack.college,
  'dormitory' => MusicTrack.chill,
  'wb' => MusicTrack.retro,
  _ => MusicTrack.exploration,
};

/// Локальный кроссплатформенный слой коротких звуков.
///
/// Файлы лежат в assets/audio/kenney и распространяются по CC0. Небольшой
/// пул плееров нужен для быстрых событий вроде печати диалога: новый символ не
/// должен обрывать звук предыдущего символа.
class AudioService extends ChangeNotifier {
  static const _assetRoot = 'audio/kenney/';
  static const _musicAssetRoot = 'audio/music/';

  static const _baseMusicVolume = .24;
  // 18 × 50 ms = 900 ms плавного перехода.
  static const _musicFadeStep = Duration(milliseconds: 50);
  static const _musicFadeSteps = 18;

  double _masterVolume = 1;
  double _musicVolume = 1;
  double _effectsVolume = 1;
  final List<AudioPlayer> _players = [];
  int _nextPlayer = 0;
  final List<AudioPlayer?> _musicPlayers = [null, null];
  final List<double> _musicLevels = [0, 0];
  int _activeMusicSlot = 0;
  MusicTrack? _currentMusic;
  bool _musicPlaying = false;
  bool _disposed = false;
  Future<void> _musicQueue = Future.value();

  double get masterVolume => _masterVolume;

  double get musicVolume => _musicVolume;

  double get effectsVolume => _effectsVolume;

  MusicTrack? get currentMusic => _currentMusic;

  Duration get musicFadeDuration => _musicFadeStep * _musicFadeSteps;

  /// Совместимость со старым API: нулевая общая громкость означает mute.
  @Deprecated('Use masterVolume and setMasterVolume instead.')
  bool get enabled => _masterVolume > 0;

  /// Совместимость со старым API настроек.
  @Deprecated('Use masterVolume and setMasterVolume instead.')
  void setEnabled(bool value) {
    if (value == enabled) return;
    if (!value) {
      setMasterVolume(0);
      // Помечаем музыку остановленной сразу, чтобы повторное включение могло
      // поставить playMusic после уже запланированного fade-out.
      _musicPlaying = false;
      unawaited(pauseMusic());
      return;
    }

    setMasterVolume(1);
    final track = _currentMusic;
    if (track != null) unawaited(playMusic(track));
  }

  void setMasterVolume(double value) {
    final next = _clampVolume(value);
    if (_masterVolume == next) return;
    _masterVolume = next;
    _syncMusicVolume();
    notifyListeners();
  }

  void setMusicVolume(double value) {
    final next = _clampVolume(value);
    if (_musicVolume == next) return;
    _musicVolume = next;
    _syncMusicVolume();
    notifyListeners();
  }

  void setEffectsVolume(double value) {
    final next = _clampVolume(value);
    if (_effectsVolume == next) return;
    _effectsVolume = next;
    notifyListeners();
  }

  double _clampVolume(double value) => value.clamp(0.0, 1.0).toDouble();

  double get _musicOutputVolume =>
      _baseMusicVolume * _masterVolume * _musicVolume;

  double _effectsOutputVolume(double baseVolume) =>
      baseVolume * _masterVolume * _effectsVolume;

  void _syncMusicVolume() {
    for (var slot = 0; slot < _musicPlayers.length; slot++) {
      final player = _musicPlayers[slot];
      if (player == null) continue;
      unawaited(player.setVolume(_musicOutputVolume * _musicLevels[slot]));
    }
  }

  /// Включает зацикленную фоновую композицию с кроссфейдом.
  ///
  /// Два плеера нужны намеренно: новый трек начинает играть на нулевой
  /// громкости, пока старый одновременно затихает. Последовательная очередь
  /// защищает от гонки, когда игрок быстро открывает и закрывает несколько
  /// экранов с разной музыкой.
  Future<void> playMusic(MusicTrack track) {
    final operation = _musicQueue.then((_) => _playMusic(track));
    _musicQueue = operation.catchError((Object error) {
      debugPrint('Не удалось переключить музыку на $track: $error');
    });
    return operation;
  }

  Future<void> _playMusic(MusicTrack track) async {
    if (_disposed) return;
    if (_currentMusic == track && _musicPlaying) return;

    final oldSlot = _activeMusicSlot;
    final oldPlayer = _musicPlaying ? _musicPlayers[oldSlot] : null;
    final newSlot = oldPlayer == null ? oldSlot : 1 - oldSlot;
    var player = _musicPlayers[newSlot];

    try {
      if (player != null) await player.stop();
      player ??= AudioPlayer();
      _musicPlayers[newSlot] = player;
      await player.setReleaseMode(ReleaseMode.loop);
      _musicLevels[newSlot] = 0;
      await player.setVolume(0);
      await player.play(
        AssetSource('$_musicAssetRoot${track.fileName}'),
        volume: 0,
      );
      if (_disposed) return;

      _currentMusic = track;
      _musicPlaying = true;
      await _crossfade(oldPlayer: oldPlayer, oldSlot: oldSlot, newSlot: newSlot);
    } catch (error) {
      _musicLevels[newSlot] = 0;
      final failedPlayer = player;
      if (failedPlayer != null) unawaited(failedPlayer.stop());
      _musicPlaying = oldPlayer != null;
      debugPrint('Не удалось воспроизвести музыку $track: $error');
    }
  }

  Future<void> _crossfade({
    required AudioPlayer? oldPlayer,
    required int oldSlot,
    required int newSlot,
  }) async {
    for (var step = 1; step <= _musicFadeSteps; step++) {
      await Future<void>.delayed(_musicFadeStep);
      if (_disposed) return;

      final progress = step / _musicFadeSteps;
      _musicLevels[newSlot] = progress;
      if (oldPlayer != null) _musicLevels[oldSlot] = 1 - progress;
      _syncMusicVolume();
    }

    if (oldPlayer != null) {
      _musicLevels[oldSlot] = 0;
      await oldPlayer.stop();
    }
    _musicLevels[newSlot] = 1;
    _activeMusicSlot = newSlot;
    _syncMusicVolume();
  }

  Future<void> playLocationMusic(String locationId) =>
      playMusic(musicTrackForLocation(locationId));

  Future<void> playShopMusic(String npcId) =>
      playMusic(musicTrackForShop(npcId));

  Future<void> playBattleMusic({bool boss = false}) =>
      playMusic(boss ? MusicTrack.boss : MusicTrack.fight);

  Future<void> pauseMusic() async {
    final operation = _musicQueue.then((_) => _pauseMusic());
    _musicQueue = operation.catchError((Object error) {
      debugPrint('Не удалось поставить музыку на паузу: $error');
    });
    await operation;
  }

  Future<void> _pauseMusic() async {
    if (_disposed) return;
    final slot = _activeMusicSlot;
    final player = _musicPlayers[slot];
    if (player == null) return;

    _musicPlaying = false;
    for (var step = _musicFadeSteps; step >= 0; step--) {
      await Future<void>.delayed(_musicFadeStep);
      if (_disposed) return;
      _musicLevels[slot] = step / _musicFadeSteps;
      _syncMusicVolume();
    }
    await player.pause();
  }

  Future<void> play(GameSound sound) async {
    if (_disposed) return;
    final spec = _specFor(sound);
    final volume = _effectsOutputVolume(spec.volume);
    if (volume <= 0) return;
    final player = _player();
    try {
      await player.play(AssetSource(spec.asset), volume: volume);
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
    for (final player in _musicPlayers) {
      if (player != null) unawaited(player.dispose());
    }
    _musicPlayers.fillRange(0, _musicPlayers.length, null);
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
