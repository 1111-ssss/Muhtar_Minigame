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
}
