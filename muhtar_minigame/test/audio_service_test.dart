import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/game_logic/audio_service.dart';

void main() {
  test('each shop uses its own background track', () {
    final tracks = [
      musicTrackForLocation('doner'),
      musicTrackForLocation('kopeechka'),
      musicTrackForLocation('cheburechnaya'),
      musicTrackForShop('ariana'),
    ];

    expect(tracks.toSet(), hasLength(4));
    expect(tracks[0].fileName, 'shop_bg_music_1.wav');
    expect(tracks[1].fileName, 'shop_bg_music_2.wav');
    expect(tracks[2].fileName, 'shop_bg_music_3.wav');
    expect(tracks[3].fileName, 'shop_bg_music_4.wav');
    expect(musicTrackForShop('baba_galya'), MusicTrack.cheburechnayaShop);
    expect(musicTrackForShop('alenka'), MusicTrack.kopeechkaShop);
    expect(musicTrackForShop('shaurmek'), MusicTrack.donerShop);
  });

  test('main menu has a dedicated track', () {
    expect(MusicTrack.menu.fileName, 'menu_bg_music_1.wav');
    expect(musicTrackForLocation('meadow'), MusicTrack.station);
  });

  test('volume channels are independent and clamped', () {
    final audio = AudioService();
    addTearDown(audio.dispose);

    expect(audio.masterVolume, 1);
    expect(audio.musicVolume, 1);
    expect(audio.effectsVolume, 1);

    audio.setMasterVolume(.35);
    audio.setMusicVolume(-1);
    audio.setEffectsVolume(2);

    expect(audio.masterVolume, .35);
    expect(audio.musicVolume, 0);
    expect(audio.effectsVolume, 1);

    audio.setMusicVolume(.6);
    audio.setEffectsVolume(.2);

    expect(audio.masterVolume, .35);
    expect(audio.musicVolume, .6);
    expect(audio.effectsVolume, .2);
  });

  test('music exposes the configured crossfade duration', () {
    final audio = AudioService();
    addTearDown(audio.dispose);

    expect(audio.currentMusic, isNull);
    expect(audio.musicFadeDuration, const Duration(milliseconds: 900));
  });
}
