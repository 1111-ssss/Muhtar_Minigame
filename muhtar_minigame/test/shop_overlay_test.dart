import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/locations.dart';
import 'package:muhtar_minigame/domain/quest.dart';
import 'package:muhtar_minigame/game/muhtar_game.dart';
import 'package:muhtar_minigame/game_logic/audio_service.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';
import 'package:muhtar_minigame/game_logic/notification_service.dart';
import 'package:muhtar_minigame/ui/upgrade/upgrade_overlay.dart';

void main() {
  late GameState gameState;
  late MuhtarGame game;
  late Directory saveDir;

  /// MuhtarGame вне GameWidget не знает билдеры оверлеев — регистрируем заглушки.
  void registerStubOverlays() {
    for (final name in [
      MuhtarGame.overlayHud,
      MuhtarGame.overlayBattle,
      MuhtarGame.overlayBattleConfirm,
      MuhtarGame.overlayQuests,
      MuhtarGame.overlayDialog,
      MuhtarGame.overlayUpgrade,
      MuhtarGame.overlayInventory,
      MuhtarGame.overlaySettings,
      'notifications',
      MuhtarGame.overlayLocationTransition,
    ]) {
      game.overlays.addEntry(name, (_, _) => const SizedBox.shrink());
    }
  }

  Future<void> pumpAlenkaShop(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpgradeOverlay(game, shop: true, shopNpcId: 'alenka'),
        ),
      ),
    );
    // Завершаем входную анимацию AnimatedOverlay и не оставляем тикер.
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<GameState> saveAndLoad(WidgetTester tester) async {
    late GameState loaded;
    await tester.runAsync(() async {
      await game.saveProgress();
      loaded = GameState();
      expect(await loaded.load(saveDir.path), isTrue);
    });
    return loaded;
  }

  setUp(() {
    gameState = GameState();
    saveDir = Directory.systemTemp.createTempSync('muhtar-shop-overlay-');
    game = MuhtarGame(
      gameState: gameState,
      notifications: NotificationService(),
      audio: AudioService(),
      saveDirectory: saveDir.path,
    );
    registerStubOverlays();
  });

  tearDown(() async {
    saveDir.deleteSync(recursive: true);
  });

  testWidgets(
    'магазин реактивно открывается до квеста и разблокирует Альпен Гольд без пересоздания',
    (tester) async {
      // Проверяем граничное условие: ровно 25 монет достаточно для покупки.
      expect(gameState.spendCoins(25), isTrue);
      await pumpAlenkaShop(tester);

      final buyFinder = find.byKey(const ValueKey('shop-buy-alpen_gold'));
      expect(buyFinder, findsOneWidget);
      expect(tester.widget<FilledButton>(buyFinder).onPressed, isNull);
      expect(find.text('Сначала возьмите задание'), findsOneWidget);

      // Оверлей уже смонтирован: после изменения GameState он должен
      // разблокировать ту же кнопку, без повторного pumpWidget.
      expect(
        gameState.activateQuest('q_alpen_gold', npcId: 'baba_galya'),
        isTrue,
      );
      await tester.pump();

      expect(tester.widget<FilledButton>(buyFinder).onPressed, isNotNull);
      expect(find.text('Сначала возьмите задание'), findsNothing);

      // Два быстрых тапа проходят через один и тот же видимый контрол: второй
      // не должен выдать второй предмет или повторно списать монеты.
      await tester.tap(buyFinder);
      await tester.tap(buyFinder);
      await tester.pump();

      expect(gameState.coins, 0);
      expect(gameState.itemCount('alpen_gold'), 1);
      expect(gameState.hasPurchasedShopItem('alpen_gold'), isTrue);
      expect(find.text('Куплено'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('inventory-item-alpen_gold')),
        findsOneWidget,
      );
      expect(find.text('Альпен Гольд'), findsOneWidget);

      final loaded = await saveAndLoad(tester);
      expect(loaded.quest('q_alpen_gold')!.state, QuestState.active);
      expect(loaded.coins, 0);
      expect(loaded.itemCount('alpen_gold'), 1);
      expect(loaded.hasPurchasedShopItem('alpen_gold'), isTrue);

      // Одноразовость сохраняется и после нового состояния GameState.
      expect(loaded.buyShopItem('alpen_gold'), isFalse);
      expect(loaded.coins, 0);
      expect(loaded.itemCount('alpen_gold'), 1);
    },
  );

  testWidgets('магазин показывает дефицит монет и полное здоровье Алёнки', (
    tester,
  ) async {
    expect(gameState.spendCoins(45), isTrue);
    expect(
      gameState.activateQuest('q_alpen_gold', npcId: 'baba_galya'),
      isTrue,
    );
    await pumpAlenkaShop(tester);

    final buyFinder = find.byKey(const ValueKey('shop-buy-alpen_gold'));
    expect(buyFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(buyFinder).onPressed, isNull);
    expect(find.text('Не хватает монет: 20'), findsOneWidget);
    expect(find.text('Здоровье полное'), findsOneWidget);
    expect(gameState.itemCount('alpen_gold'), 0);
  });

  testWidgets(
    'инвентарь показывает найденный предмет и убирает его после сдачи',
    (tester) async {
      final prop = Locations.ruins.props.singleWhere(
        (candidate) => candidate.specialItemId == 'potato',
      );
      expect(
        gameState.activateQuest('q_potato_bridge', npcId: 'wb_employee'),
        isTrue,
      );
      for (var tap = 0; tap < SearchResult.requiredTaps; tap++) {
        gameState.searchProp(prop.id);
      }

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: UpgradeOverlay(game))),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('inventory-item-potato')),
        findsOneWidget,
      );
      expect(find.text('Картошка'), findsOneWidget);
      expect(find.text('×1'), findsOneWidget);

      expect(gameState.completeDeliveryQuest('q_potato_bridge'), isTrue);
      await tester.pump();
      expect(find.byKey(const ValueKey('inventory-item-potato')), findsNothing);
    },
  );

  testWidgets('магазин Арианы не прокачивает хотбар выше третьего места', (
    tester,
  ) async {
    gameState.addCoins(1000);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpgradeOverlay(game, shop: true, shopNpcId: 'ariana'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final hotbarCard = find.byKey(const ValueKey('shop-upgrade-hotbar'));
    expect(hotbarCard, findsOneWidget);
    expect(find.text('Хотбар: 1/3'), findsOneWidget);

    final hotbarButton = find.descendant(
      of: hotbarCard,
      matching: find.byType(FilledButton),
    );
    await tester.tap(hotbarButton);
    await tester.pump();
    await tester.tap(hotbarButton);
    await tester.pump();

    expect(gameState.dicePerTurn, 3);
    expect(find.text('Хотбар: 3/3'), findsOneWidget);
    expect(find.text('Максимум'), findsOneWidget);
    expect(tester.widget<FilledButton>(hotbarButton).onPressed, isNull);
  });

  testWidgets('инвентарь содержит отдельный раздел с картинками скинов', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: UpgradeOverlay(game))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pump();

    expect(find.text('Скины героя'), findsOneWidget);
    expect(find.byKey(const ValueKey('skin-image-default')), findsOneWidget);
    expect(find.byKey(const ValueKey('skin-image-ribka_reward')), findsOneWidget);
    expect(find.byKey(const ValueKey('skin-image-kartofla')), findsOneWidget);
    expect(find.byKey(const ValueKey('skin-select-default')), findsOneWidget);
  });
}
