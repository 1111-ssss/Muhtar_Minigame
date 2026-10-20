import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/location.dart';
import 'package:muhtar_minigame/domain/locations.dart';
import 'package:muhtar_minigame/domain/quest.dart';
import 'package:muhtar_minigame/game/muhtar_game.dart';
import 'package:muhtar_minigame/game/world/enemy_entity.dart';
import 'package:muhtar_minigame/game_logic/audio_service.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';
import 'package:muhtar_minigame/game_logic/notification_service.dart';
import 'package:muhtar_minigame/ui/battle/pre_battle_overlay.dart';
import 'package:muhtar_minigame/ui/search/potato_pickup_overlay.dart';
import 'package:muhtar_minigame/ui/search/search_overlay.dart';

class _FixedRandom implements Random {
  const _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => value == 0 ? 0 : 0.5;

  @override
  int nextInt(int max) => value % max;
}

void main() {
  late GameState gameState;
  late MuhtarGame game;

  void registerStubOverlays() {
    for (final name in [
      MuhtarGame.overlayHud,
      MuhtarGame.overlayBattle,
      MuhtarGame.overlayBattleConfirm,
      MuhtarGame.overlayPreBattle,
      MuhtarGame.overlaySearch,
      MuhtarGame.overlayPotatoPickup,
      MuhtarGame.overlayVideoSequence,
      MuhtarGame.overlayDialog,
      'notifications',
      MuhtarGame.overlayLocationTransition,
    ]) {
      game.overlays.addEntry(name, (_, _) => const SizedBox.shrink());
    }
  }

  setUp(() {
    gameState = GameState();
    game = MuhtarGame(
      gameState: gameState,
      notifications: NotificationService(),
      audio: AudioService(),
    );
    registerStubOverlays();
  });

  tearDown(() {
    game.audio.dispose();
  });

  test(
    'Виктор сначала требует подтверждение, а отмена не открывает заставку',
    () {
      final enemy = EnemyEntity(
        enemyId: 'viktor_korneplod',
        col: 1,
        row: 1,
        label: 'Виктор Корнеплод',
        spawnKey: 'story-viktor-cancel',
      );

      game.world_.onBattleStart(enemy);

      expect(game.overlays.isActive(MuhtarGame.overlayBattleConfirm), isTrue);
      expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isFalse);
      game.cancelBattle();

      expect(game.pendingBattleEnemy, isNull);
      expect(game.battle, isNull);
      expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isFalse);
    },
  );

  testWidgets(
    'подтверждение Виктора открывает заставку, пропуск сразу начинает бой',
    (tester) async {
      final enemy = EnemyEntity(
        enemyId: 'viktor_korneplod',
        col: 1,
        row: 1,
        label: 'Виктор Корнеплод',
        spawnKey: 'story-viktor-skip',
      );
      game.world_.onBattleStart(enemy);
      game.confirmBattle();

      expect(game.overlays.isActive(MuhtarGame.overlayBattleConfirm), isFalse);
      expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isTrue);
      expect(game.pendingBattleEnemy, same(enemy));
      expect(game.battle, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreBattleOverlay(game, onContinue: game.confirmBattle),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pre-battle-skip')));
      await tester.pump();

      final startedBattle = game.battle;
      expect(startedBattle, isNotNull);
      expect(game.pendingBattleEnemy, isNull);
      expect(game.overlays.isActive(MuhtarGame.overlayPreBattle), isFalse);

      game.confirmBattle();
      expect(identical(game.battle, startedBattle), isTrue);
    },
  );

  testWidgets('повторно открытый куст показывает только пустой результат', (
    tester,
  ) async {
    final state = GameState();
    final prop = Locations.forest.props.firstWhere(
      (candidate) => candidate.specialItemId == 'sync_async',
    );
    for (var tap = 0; tap < 10; tap++) {
      state.searchProp(prop.id);
    }

    final loaded = GameState()..fromJson(state.toJson());
    final itemCountBefore = loaded.itemCount('sync_async');
    await tester.pumpWidget(
      MaterialApp(
        home: SearchOverlay(game: loaded, prop: prop, onClose: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Больше ничего нет'), findsOneWidget);
    expect(find.text('Тщательный поиск'), findsNothing);
    expect(find.text('Проверить объект'), findsNothing);
    expect(find.text('Находка обнаружена'), findsNothing);
    expect(find.text('Забрать находку'), findsNothing);

    await tester.tap(find.text('Закрыть'));
    expect(loaded.itemCount('sync_async'), itemCountBefore);
  });

  test('опустевший куст показывает нижнее уведомление без поиска', () {
    gameState = GameState(random: const _FixedRandom(0));
    game = MuhtarGame(
      gameState: gameState,
      notifications: NotificationService(),
      audio: AudioService(),
    );
    registerStubOverlays();
    final prop = Locations.forest.props.firstWhere(
      (candidate) => candidate.searchable && candidate.specialItemId == null,
    );

    for (var tap = 0; tap < 10; tap++) {
      gameState.searchProp(prop.id);
    }
    game.world_.onPropSearch!(prop);

    expect(game.overlays.isActive(MuhtarGame.overlaySearch), isFalse);
    expect(game.notifications.notifications.single.message, contains('ничего'));
  });

  test('повторный обыск мусорки показывает уведомление без окна поиска', () {
    final prop = Locations.doner.props.firstWhere(
      (candidate) => candidate.kind == LocationPropKind.trashBin,
    );

    for (var tap = 0; tap < SearchResult.requiredTaps; tap++) {
      gameState.searchProp(prop.id);
    }
    game.world_.onPropSearch!(prop);

    expect(game.overlays.isActive(MuhtarGame.overlaySearch), isFalse);
    expect(
      game.notifications.notifications.single.message,
      contains('мусорке'),
    );
  });

  testWidgets('удержание клавиши у пустого куста не повторяет уведомление', (
    tester,
  ) async {
    gameState.currentLocationId = 'forest';
    final prop = Locations.forest.props.firstWhere(
      (candidate) => candidate.searchable && candidate.specialItemId == null,
    );
    for (var tap = 0; tap < SearchResult.requiredTaps; tap++) {
      gameState.searchProp(prop.id);
    }

    await tester.runAsync(() async {
      await tester.pumpWidget(GameWidget(game: FlameGame(world: game.world_)));
      await game.world_.loadLocation('forest');
    });
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    game.player
      ..col = prop.col
      ..row = prop.row + 1
      ..syncPosition();
    final key = KeyDownEvent(
      logicalKey: LogicalKeyboardKey.keyW,
      physicalKey: PhysicalKeyboardKey.keyW,
      timeStamp: Duration.zero,
    );
    expect(
      game.onKeyEvent(key, {LogicalKeyboardKey.keyW}),
      KeyEventResult.handled,
    );

    // Первый шаг приводит к уже осмотренному кусту и показывает одно
    // уведомление. Следующий повтор проходит через тот же update-цикл.
    await tester.pump(const Duration(milliseconds: 16));
    game.update(0.5);
    await tester.pump(const Duration(milliseconds: 16));

    expect(game.notifications.notifications, hasLength(1));
    expect(game.overlays.isActive(MuhtarGame.overlaySearch), isFalse);
  });

  testWidgets('картошка в поиске имеет собственное представление', (
    tester,
  ) async {
    final prop = Locations.ruins.props.singleWhere(
      (candidate) => candidate.specialItemId == 'potato',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SearchOverlay(game: gameState, prop: prop, onClose: () {}),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Осмотреть картошку'), findsOneWidget);
    expect(find.bySemanticsLabel('Осмотреть куст'), findsNothing);
  });

  test('тап по картошке открывает диалог подбора, а не обычный поиск', () {
    final prop = Locations.ruins.props.singleWhere(
      (candidate) => candidate.specialItemId == 'potato',
    );

    game.world_.onPropSearch!(prop);

    expect(game.overlays.isActive(MuhtarGame.overlayPotatoPickup), isTrue);
    expect(game.overlays.isActive(MuhtarGame.overlaySearch), isFalse);
    expect(game.potatoPickupProp, same(prop));
  });

  testWidgets('диалог картошки подбирает предмет одним подтверждением', (
    tester,
  ) async {
    var picked = false;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PotatoPickupOverlay(
          onPickUp: () => picked = true,
          onClose: () => closed = true,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('potato-pickup-dialog')), findsOneWidget);
    expect(find.text('Картошка'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('potato-pickup')));
    await tester.tap(find.byKey(const ValueKey('potato-pickup-cancel')));

    expect(picked, isTrue);
    expect(closed, isTrue);
  });

  test('интерактивная раздевалка ВБ принимает и продолжает квест', () {
    final prop = Locations.wb.props.singleWhere(
      (candidate) => candidate.id == 'wb_fitting_room',
    );

    game.world_.onPropInteract!(prop);
    expect(gameState.quest('q_kartofla_videos')!.state, QuestState.active);
    expect(game.overlays.isActive(MuhtarGame.overlayVideoSequence), isTrue);

    game.closeVideoSequence();
    game.world_.onPropInteract!(prop);
    expect(gameState.quest('q_kartofla_videos')!.state, QuestState.active);
    expect(game.overlays.isActive(MuhtarGame.overlayVideoSequence), isTrue);
  });
}
