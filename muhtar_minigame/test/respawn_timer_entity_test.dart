import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/game/world/isometric_map.dart';
import 'package:muhtar_minigame/game/world/respawn_timer_entity.dart';

void main() {
  test('respawn timer keeps its tile position and renders countdown text', () {
    final entity = RespawnTimerEntity(
      col: 4,
      row: 3,
      remaining: const Duration(minutes: 2, seconds: 7),
    );

    expect(entity.position, IsometricMap.tileToWorld(4, 3));
    expect(entity.size.x, 120);
    expect(entity.size.y, 28);
    expect(entity.remaining, const Duration(minutes: 2, seconds: 7));

    entity.setRemaining(const Duration(seconds: 12));
    expect(entity.remaining, const Duration(seconds: 12));

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    entity.render(canvas);
    recorder.endRecording().dispose();
  });
}
