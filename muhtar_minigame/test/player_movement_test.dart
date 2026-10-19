import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';
import 'package:muhtar_minigame/game/world/game_world.dart';
import 'package:muhtar_minigame/game/world/isometric_map.dart';
import 'package:muhtar_minigame/game/world/player.dart';

void main() {
  group('Player movement', () {
    test('exposes the current cardinal movement direction', () {
      final player = Player(col: 5, row: 5)
        ..position = IsometricMap.tileToWorld(5, 5);

      player.moveTo([(6, 5)]);

      expect(player.isMoving, isTrue);
      expect(player.movementTargetTile, (6, 5));
      expect(player.movementDirection, (1, 0));
    });

    test('can replace a transition with a return to the current tile', () {
      final origin = IsometricMap.tileToWorld(5, 5);
      final player = Player(col: 5, row: 5)..position = origin.clone();

      player.moveTo([(6, 5)]);
      player.update(0.05);
      expect(player.position, isNot(equals(origin)));

      // Это операция, которую вызывает обратная клавиша во время перехода.
      player.moveTo([player.tile]);
      player.update(0.25);

      expect(player.tile, (5, 5));
      expect(player.position, origin);
      expect(player.isMoving, isFalse);
    });

    test('queues the next tile while the current tile is moving', () {
      final player = Player(col: 5, row: 5)
        ..position = IsometricMap.tileToWorld(5, 5);

      player.moveTo([(6, 5)]);
      player.queueMoveTo((7, 5));

      expect(player.movementPathTailTile, (7, 5));
      player.update(.2);

      expect(player.tile, (6, 5));
      expect(player.isMoving, isTrue);
      player.update(.2);

      expect(player.tile, (7, 5));
      expect(player.isMoving, isFalse);
    });

    test('stop snaps the visual foot point to the logical tile center', () {
      final player = Player(col: 3, row: 7)..position = Vector2(123, 456);

      player.stop();

      expect(player.position, IsometricMap.tileToWorld(3, 7));
    });
  });

  group('GameWorld loadLocation', () {
    testWidgets('игрок остаётся на карте после телепорта', (tester) async {
      final world = GameWorld(
        gameState: GameState(),
        onLocationChange: (_) {},
        onBattleStart: (_) {},
        onNpcTalk: (_) {},
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(GameWidget(game: FlameGame(world: world)));
        await world.loadLocation('meadow');
        await world.loadLocation('ruins', fromLocationId: 'meadow');
      });
      // Отложенное удаление Flame обрабатывается на кадре — именно оно
      // раньше снимало игрока после телепорта.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        world.player.isMounted,
        isTrue,
        reason: 'игрок не должен пропадать после смены локации',
      );
      expect(world.player.tile, world.location.spawn);
    });
  });
}
