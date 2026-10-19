import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/game/world/enemy_entity.dart';
import 'package:muhtar_minigame/game/world/game_world.dart';
import 'package:muhtar_minigame/game/world/npc_entity.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';

Future<void> _mountWorld(WidgetTester tester, GameWorld world) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(GameWidget(game: FlameGame(world: world)));
    await world.loadLocation('meadow');
  });
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

GameWorld _world({
  void Function(EnemyEntity enemy)? onBattleStart,
  void Function(NpcEntity npc)? onNpcTalk,
}) {
  return GameWorld(
    gameState: GameState(),
    onLocationChange: (_) {},
    onBattleStart: onBattleStart ?? (_) {},
    onNpcTalk: onNpcTalk ?? (_) {},
  );
}

void main() {
  testWidgets('keyboard movement rejects invalid and blocked steps', (
    tester,
  ) async {
    final world = _world();
    await _mountWorld(tester, world);

    world.player
      ..col = 9
      ..row = 1
      ..syncPosition();

    expect(world.movePlayerBy(0, 0), isFalse);
    expect(world.movePlayerBy(1, 1), isFalse);
    // The right-hand station bench occupies meadow cells 10 and 11.
    expect(world.movePlayerBy(1, 0), isFalse);
    expect(world.movePlayerBy(-1, 0), isTrue);
    expect(world.player.movementTargetTile, (8, 1));
  });

  testWidgets('holding one direction queues contiguous walkable tiles', (
    tester,
  ) async {
    final world = _world();
    await _mountWorld(tester, world);

    world.player
      ..col = 7
      ..row = 10
      ..syncPosition();

    expect(world.movePlayerBy(1, 0), isTrue);
    expect(world.movePlayerBy(1, 0), isTrue);
    expect(world.player.path, [(8, 10), (9, 10)]);
  });

  testWidgets('stepping onto an enemy or NPC uses the matching callback', (
    tester,
  ) async {
    EnemyEntity? battled;
    NpcEntity? talked;
    final world = _world(
      onBattleStart: (enemy) => battled = enemy,
      onNpcTalk: (npc) => talked = npc,
    );
    await _mountWorld(tester, world);

    world.player
      ..col = 12
      ..row = 4
      ..syncPosition();
    expect(world.movePlayerBy(1, 0), isTrue);
    expect(battled?.enemyId, 'viktor_korneplod');
    expect(world.player.isMoving, isFalse);

    await world.loadLocation('meadow');
    world.player
      ..col = 1
      ..row = 8
      ..syncPosition();
    expect(world.movePlayerBy(1, 0), isTrue);
    expect(talked?.npcId, 'ariana');
  });
}
