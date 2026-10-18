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

  bool _enabled = true;
  final List<AudioPlayer> _players = [];
  int _nextPlayer = 0;
  AudioPlayer? _musicPlayer;
  MusicTrack? _currentMusic;
  bool _musicPlaying = false;
  bool _disposed = false;

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!_enabled) {
      _musicPlaying = false;
      final player = _musicPlayer;
      if (player != null) unawaited(player.pause());
    } else {
      final track = _currentMusic;
      if (track != null) unawaited(playMusic(track));
    }
    notifyListeners();
  }

  /// Включает зацикленную фоновую композицию, не перезапуская тот же трек.
  Future<void> playMusic(MusicTrack track) async {
    if (_disposed) return;
    if (_currentMusic == track && _musicPlaying) return;
    _currentMusic = track;
    if (!_enabled) return;
    final player = _musicPlayer ??= AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource('$_musicAssetRoot${track.fileName}'),
        volume: .24,
      );
      _musicPlaying = true;
    } catch (error) {
      _musicPlaying = false;
      debugPrint('Не удалось воспроизвести музыку $track: $error');
    }
  }

  Future<void> playLocationMusic(String locationId) =>
      playMusic(musicTrackForLocation(locationId));

  Future<void> playShopMusic(String npcId) =>
      playMusic(musicTrackForShop(npcId));

  Future<void> playBattleMusic({bool boss = false}) =>
      playMusic(boss ? MusicTrack.boss : MusicTrack.fight);

  Future<void> pauseMusic() async {
    _musicPlaying = false;
    final player = _musicPlayer;
    if (player != null) await player.pause();
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
    final musicPlayer = _musicPlayer;
    _musicPlayer = null;
    if (musicPlayer != null) unawaited(musicPlayer.dispose());
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
