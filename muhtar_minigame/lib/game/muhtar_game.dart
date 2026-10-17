import 'dart:async';
import 'dart:async' as async;
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/game_content.dart';
import '../domain/location.dart';
import '../domain/locations.dart';
import '../domain/quest.dart';
import '../game_logic/battle_engine.dart';
import '../game_logic/audio_service.dart';
import '../game_logic/game_state.dart';
import '../game_logic/location_transition.dart';
import '../game_logic/notification_service.dart';
import 'world/enemy_entity.dart';
import 'world/game_world.dart';
import 'world/npc_entity.dart';
import 'world/player.dart';

/// Главная игра: мир + маршруты (мир / бой) + оверлеи Flutter.
///
/// Оверлеи: hud, battle, battle confirmation/pre-battle, upgrade, quests,
/// dialog, notifications.
class MuhtarGame extends FlameGame
    with HasKeyboardHandlerComponents, MultiTouchTapDetector {
  MuhtarGame({
    required this.gameState,
    required this.notifications,
    required this.audio,
    Random? random,
    this.saveDirectory = 'save',
  }) : _random = random ?? Random(),
       super();

  final GameState gameState;
  final NotificationService notifications;
  final AudioService audio;
  final String saveDirectory;
  final Random _random;
  bool modalDialogOpen = false;

  late final GameWorld world_ = GameWorld(
    gameState: gameState,
    onLocationChange: _changeLocation,
    onBattleStart: _startBattle,
    onNpcTalk: _talkToNpc,
    onPropSearch: _startPropSearch,
    onPropInteract: _interactWithProp,
  );

  BattleEngine? battle;
  EnemyEntity? _battleEnemy;
  EnemyEntity? _pendingBattleEnemy;
  bool _victorPreBattleActive = false;
  bool _endingBattle = false;
  NpcEntity? _talkingNpc;
  LocationProp? _searchingProp;
  String? _donerQuestId;
  String? _donerRecipeId;
  String? activeShopNpcId;

  /// Оверлей остаётся смонтированным, чтобы fade не обрывался при смене фаз.
  final ValueNotifier<LocationTransitionState> locationTransition =
      ValueNotifier(const LocationTransitionState.idle());
  bool _changingLocation = false;

  void Function(LogicalKeyboardKey key)? _dialogKeyboardHandler;
  VoidCallback? _battleKeyboardHandler;
  void Function(int index)? _battleDiceKeyboardHandler;
  final Map<String, VoidCallback> _windowCloseHandlers = {};

  final Set<LogicalKeyboardKey> _pressedKeys = {};
  final List<LogicalKeyboardKey> _movementKeyOrder = [];
  double _heldMoveTimer = 0;
  bool _heldRepeatStarted = false;

  /// Автосохранение: любое изменение состояния (взятие квеста, монеты, HP)
  /// уходит на диск не позже секунды спустя, чтобы закрытие окна не теряло
  /// прогресс между точками сохранения вроде перехода между локациями.
  async.Timer? _autosaveTimer;
  static const _autosaveDelay = Duration(seconds: 1);

  /// Пауза после первого шага перед автоповтором. Она длиннее анимации одного
  /// тайла, поэтому короткое нажатие не превращается в два шага.
  static const _heldMoveDelay = 0.24;

  /// Интервал последующих шагов при настоящем удержании клавиши.
  static const _heldMoveRepeat = 0.13;

  static const overlayHud = 'hud';
  static const overlayBattle = 'battle';
  static const overlayBattleConfirm = 'battle_confirm';
  static const overlayPreBattle = 'pre_battle';
  static const overlaySearch = 'search';
  static const overlaySongMiniGame = 'song_minigame';
  static const overlayDonerAssembly = 'doner_assembly';
  static const overlayVideoSequence = 'video_sequence';
  static const overlayShawarmaChoice = 'shawarma_choice';
  static const overlayUpgrade = 'upgrade';
  static const overlayInventory = 'inventory';
  static const overlayQuests = 'quests';
  static const overlayDialog = 'dialog';
  static const overlaySettings = 'settings';
  static const overlayLocationTransition = 'location_transition';

  @override
  Future<void> onLoad() async {
    camera = CameraComponent.withFixedResolution(
      width: 1280,
      height: 720,
      world: world_,
    );
    // Дожидаемся загрузки World, чтобы Player уже имел корректную позицию
    // до snap камеры. Ручной вызов world.onLoad() здесь создавал гонку между
    // камерой, коллизиями и первой отрисовкой карты.
    await add(world_);
    camera.follow(world_.player, snap: true);

    overlays.add(overlayHud);
    overlays.add('notifications', priority: 20);
    overlays.add(overlayLocationTransition, priority: 100);
    gameState.addListener(_scheduleAutosave);
  }

  @override
  void onRemove() {
    gameState.removeListener(_scheduleAutosave);
    _autosaveTimer?.cancel();
    super.onRemove();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = async.Timer(
      _autosaveDelay,
      () => unawaited(saveProgress()),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isInputBlocked) return;
    final direction = _directionFromPressedKeys();
    if (direction == null) {
      _heldMoveTimer = 0;
      _heldRepeatStarted = false;
      return;
    }

    // Первый шаг происходит на KeyDown. Здесь запускаются только повторные
    // шаги, после отдельной задержки удержания.
    _heldMoveTimer += dt;
    if (!_heldRepeatStarted && _heldMoveTimer >= _heldMoveDelay) {
      _heldMoveTimer = 0;
      _heldRepeatStarted = true;
      world_.movePlayerBy(direction.$1, direction.$2);
    } else if (_heldRepeatStarted && _heldMoveTimer >= _heldMoveRepeat) {
      _heldMoveTimer -= _heldMoveRepeat;
      world_.movePlayerBy(direction.$1, direction.$2);
    }
  }

  // --- Ввод: тапы по карте ---

  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    // Тапы игнорируются поверх полноэкранных оверлеев.
    if (_isInputBlocked) {
      return;
    }
    // Сначала переводим координату окна в локальную систему GameWidget,
    // затем один раз применяем обратное преобразование камеры. Нельзя
    // передавать global напрямую в CameraComponent: при вложенном GameWidget
    // это даёт стабильный сдвиг карты (обычно на один тайл влево).
    final gamePosition = convertGlobalToLocalCoordinate(
      info.eventPosition.global,
    );
    // FixedResolutionViewport оставляет поля на широких окнах. Точка в таком
    // поле не должна экстраполироваться в мир и выбирать дальний тайл.
    if (!camera.viewport.containsLocalPoint(gamePosition)) return;
    final worldPosition = camera.globalToLocal(gamePosition);
    world_.handleMapTap(worldPosition);
  }

  // --- Ввод: клавиатура ---

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (modalDialogOpen) return KeyEventResult.ignored;
    final wasDirection = _directionFromPressedKeys();

    if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
      _movementKeyOrder.remove(event.logicalKey);
    }

    // Escape закрывает верхнее окно с той же анимацией, что и кнопка X.
    // Обрабатываем его до общего блокиратора ввода, иначе модальные окна не
    // могли бы реагировать на клавишу.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_closeActiveWindow()) return KeyEventResult.handled;
    }

    // KeyRepeatEvent нужен только для движения, которое управляется своим
    // таймером. В диалогах повтор не должен выбирать один ответ несколько раз.
    if (event is KeyRepeatEvent) return KeyEventResult.handled;

    if (_isInputBlocked) {
      if (event is KeyDownEvent && overlays.isActive(overlayDialog)) {
        final isShortcut = _isDialogueShortcut(event.logicalKey);
        if (isShortcut) {
          _dialogKeyboardHandler?.call(event.logicalKey);
          return KeyEventResult.handled;
        }
      }
      if (event is KeyDownEvent &&
          overlays.isActive(overlayBattle) &&
          _battleDiceIndexForKey(event.logicalKey) != null) {
        _battleDiceKeyboardHandler?.call(
          _battleDiceIndexForKey(event.logicalKey)!,
        );
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          overlays.isActive(overlayBattle) &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        _battleKeyboardHandler?.call();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          overlays.isActive(overlaySearch) &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        final result = _searchingProp == null
            ? null
            : gameState.searchResult(_searchingProp!.id);
        if (result?.completed == true &&
            result?.rewardType == SearchRewardType.none) {
          closeSearch();
          return KeyEventResult.handled;
        }
      }
      if (event is KeyDownEvent &&
          overlays.isActive(overlayBattleConfirm) &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        confirmBattle();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          overlays.isActive(overlayPreBattle) &&
          (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter ||
              event.logicalKey == LogicalKeyboardKey.space)) {
        confirmBattle();
        return KeyEventResult.handled;
      }
      _pressedKeys.remove(event.logicalKey);
      _movementKeyOrder.remove(event.logicalKey);
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent) {
      _pressedKeys.add(event.logicalKey);
      _movementKeyOrder
        ..remove(event.logicalKey)
        ..add(event.logicalKey);
    }

    // Системный автоповтор KeyRepeatEvent намеренно игнорируется. Повтор
    // управляется одним таймером ниже, иначе Linux/Windows могут прислать
    // второй шаг раньше нашей задержки.
    if (event is KeyRepeatEvent) {
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent || event is KeyUpEvent) {
      final direction = _directionFromPressedKeys();
      final changed = direction != wasDirection;
      if (_isMovementKey(event.logicalKey) && changed && direction != null) {
        _beginMovementIntent(direction);
      }
      if (_isMovementKey(event.logicalKey)) {
        return KeyEventResult.handled;
      }
    }

    return super.onKeyEvent(event, keysPressed);
  }

  bool _closeActiveWindow() {
    const closableOverlays = [
      overlayDialog,
      overlayUpgrade,
      overlayInventory,
      overlayQuests,
      overlayBattleConfirm,
      overlayPreBattle,
      overlaySearch,
      overlaySongMiniGame,
      overlayDonerAssembly,
      overlayVideoSequence,
      overlayShawarmaChoice,
      overlayBattle,
      overlaySettings,
    ];
    for (final overlay in closableOverlays) {
      if (!overlays.isActive(overlay)) continue;
      final handler = _windowCloseHandlers[overlay];
      if (handler != null) {
        handler();
      } else {
        overlays.remove(overlay);
      }
      return true;
    }
    return false;
  }

  bool _isDialogueShortcut(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.digit1 ||
        key == LogicalKeyboardKey.digit2 ||
        key == LogicalKeyboardKey.digit3 ||
        key == LogicalKeyboardKey.digit4 ||
        key == LogicalKeyboardKey.digit5 ||
        key == LogicalKeyboardKey.digit6 ||
        key == LogicalKeyboardKey.digit7 ||
        key == LogicalKeyboardKey.digit8 ||
        key == LogicalKeyboardKey.digit9 ||
        key == LogicalKeyboardKey.numpad1 ||
        key == LogicalKeyboardKey.numpad2 ||
        key == LogicalKeyboardKey.numpad3 ||
        key == LogicalKeyboardKey.numpad4 ||
        key == LogicalKeyboardKey.numpad5 ||
        key == LogicalKeyboardKey.numpad6 ||
        key == LogicalKeyboardKey.numpad7 ||
        key == LogicalKeyboardKey.numpad8 ||
        key == LogicalKeyboardKey.numpad9;
  }

  int? _battleDiceIndexForKey(LogicalKeyboardKey key) {
    const topRow = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
    ];
    final topIndex = topRow.indexOf(key);
    if (topIndex >= 0) return topIndex;
    final numpadIndex = numpad.indexOf(key);
    return numpadIndex >= 0 ? numpadIndex : null;
  }

  // --- Локации ---

  void _changeLocation(LocationExit exit) {
    unawaited(_runLocationTransition(exit));
  }

  Future<void> _runLocationTransition(LocationExit exit) async {
    if (_changingLocation) return;
    _changingLocation = true;
    _pressedKeys.clear();
    _movementKeyOrder.clear();
    unawaited(audio.play(GameSound.transition));

    final destination = Locations.byId(exit.targetId) ?? Locations.meadow;
    locationTransition.value = LocationTransitionState(
      phase: LocationTransitionPhase.fadeOut,
      locationName: destination.name,
    );

    try {
      // Прогресс перехода меняется в GameWorld до запуска fade. Записываем его
      // сразу, иначе закрытие приложения во время перехода откатит задание.
      // Выполненные задания не забираются автоматически: награду должен
      // подтвердить игрок в журнале заданий.
      // Даём Flutter сначала показать fade-out. Иначе синхронный jsonEncode
      // внутри save() может задержать первый кадр перехода.
      await Future<void>.delayed(Duration.zero);
      // Полный fade-out должен закончиться до того, как содержимое мира будет
      // заменено, иначе на один кадр видны старые сущности.
      await Future.wait<void>([
        saveProgress(),
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);
      final sourceId = gameState.currentLocationId;
      gameState.currentLocationId = exit.targetId;
      await world_.loadLocation(
        exit.targetId,
        spawnOverride: exit.arrival,
        fromLocationId: sourceId,
      );
      camera.follow(world_.player, snap: true);
      await saveProgress();
      notifications.notify(
        'Локация: ${destination.name}',
        type: NotificationType.info,
      );

      locationTransition.value = LocationTransitionState(
        phase: LocationTransitionPhase.titleDrop,
        locationName: destination.name,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      locationTransition.value = LocationTransitionState(
        phase: LocationTransitionPhase.titleHold,
        locationName: destination.name,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      locationTransition.value = LocationTransitionState(
        phase: LocationTransitionPhase.titleExit,
        locationName: destination.name,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      locationTransition.value = LocationTransitionState(
        phase: LocationTransitionPhase.fadeIn,
        locationName: destination.name,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } finally {
      locationTransition.value = const LocationTransitionState.idle();
      _changingLocation = false;
    }
  }

  // --- Взаимодействия ---

  // Бой и диалоги инициируются миром: игрок подходит к сущности (тап по ней
  // или столкновение с клавиатуры), и GameWorld вызывает колбэки ниже.

  // --- Бой ---

  void _startBattle(EnemyEntity enemyEntity) {
    if (_endingBattle || battle != null || _pendingBattleEnemy != null) return;
    _pendingBattleEnemy = enemyEntity;
    world_.player.stop();
    _pressedKeys.clear();
    _movementKeyOrder.clear();
    overlays.add(overlayBattleConfirm, priority: 10);
  }

  EnemyEntity? get pendingBattleEnemy => _pendingBattleEnemy;

  /// Тесты не проходят через тап по карте, поэтому враг подставляется прямо.
  @visibleForTesting
  void setPendingBattleEnemyForTest(EnemyEntity enemy) {
    _pendingBattleEnemy = enemy;
  }

  void confirmBattle() {
    if (_endingBattle || battle != null) return;
    final enemy = _pendingBattleEnemy;
    if (enemy == null) return;

    if (enemy.enemyId == 'viktor_korneplod' && !_victorPreBattleActive) {
      _victorPreBattleActive = true;
      _clearBattleIntroOverlays();
      registerWindowCloseHandler(overlayPreBattle, confirmBattle);
      overlays.add(overlayPreBattle, priority: 10);
      return;
    }

    _pendingBattleEnemy = null;
    _victorPreBattleActive = false;
    _clearBattleIntroOverlays();
    _beginBattle(enemy);
  }

  void cancelBattle() {
    if (_endingBattle) return;
    _pendingBattleEnemy = null;
    _victorPreBattleActive = false;
    _clearBattleIntroOverlays();
  }

  void _clearBattleIntroOverlays() {
    overlays.remove(overlayBattleConfirm);
    overlays.remove(overlayPreBattle);
    unregisterWindowCloseHandler(overlayPreBattle);
  }

  // --- Поиск объектов и мини-игры ---

  LocationProp? get searchingProp => _searchingProp;

  void _startPropSearch(LocationProp prop) {
    if (_endingBattle || battle != null || overlays.isActive(overlaySearch)) {
      return;
    }
    _searchingProp = prop;
    world_.player.stop();
    _pressedKeys.clear();
    _movementKeyOrder.clear();
    registerWindowCloseHandler(overlaySearch, closeSearch);
    overlays.add(overlaySearch, priority: 10);
  }

  void _interactWithProp(LocationProp prop) {
    final questId = prop.interactionId;
    if (questId == null || _endingBattle || battle != null) return;

    final progress = gameState.quest(questId);
    if (progress?.state == QuestState.notStarted) {
      if (!gameState.activateQuest(questId, propId: prop.id)) return;
      notifications.notify(
        'Задание принято: три ролика в раздевалке ВБ',
        type: NotificationType.info,
      );
    }

    if (questId == 'q_kartofla_videos') openVideoSequence();
  }

  void closeSearch() {
    _searchingProp = null;
    unregisterWindowCloseHandler(overlaySearch);
    overlays.remove(overlaySearch);
  }

  void openSongMiniGame() {
    final progress = gameState.quest('q_song');
    if (progress?.state != QuestState.active ||
        overlays.isActive(overlaySongMiniGame)) {
      return;
    }
    world_.player.stop();
    _pressedKeys.clear();
    _movementKeyOrder.clear();
    registerWindowCloseHandler(overlaySongMiniGame, closeSongMiniGame);
    overlays.add(overlaySongMiniGame, priority: 20);
  }

  void closeSongMiniGame() {
    unregisterWindowCloseHandler(overlaySongMiniGame);
    overlays.remove(overlaySongMiniGame);
  }

  void completeSongMiniGame() {
    if (!gameState.completeSongQuest()) return;
    notifications.notify(
      'Песня сыграна! Награда уже ждёт в журнале заданий.',
      type: NotificationType.reward,
    );
    unawaited(saveProgress());
    closeSongMiniGame();
  }

  String? get donerQuestId => _donerQuestId;
  String? get donerRecipeId => _donerRecipeId;

  void openDonerAssembly({required String questId, required String recipeId}) {
    final progress = gameState.quest(questId);
    if (progress?.state != QuestState.active ||
        overlays.isActive(overlayDonerAssembly)) {
      return;
    }
    _donerQuestId = questId;
    _donerRecipeId = recipeId;
    world_.player.stop();
    _pressedKeys.clear();
    _movementKeyOrder.clear();
    registerWindowCloseHandler(overlayDonerAssembly, closeDonerAssembly);
    overlays.add(overlayDonerAssembly, priority: 20);
  }

  void closeDonerAssembly() {
    _donerQuestId = null;
    _donerRecipeId = null;
    unregisterWindowCloseHandler(overlayDonerAssembly);
    overlays.remove(overlayDonerAssembly);
  }

  void completeDonerAssembly() {
    final questId = _donerQuestId;
    final recipeId = _donerRecipeId;
    if (questId == null || recipeId == null) return;
    if (!gameState.completeMiniGameQuest(
      questId,
      miniGameId: 'doner_$recipeId',
    )) {
      return;
    }
    notifications.notify(
      'Шаурма собрана! Награда уже ждёт в журнале заданий.',
      type: NotificationType.reward,
    );
    unawaited(saveProgress());
    closeDonerAssembly();
  }

  void openVideoSequence() {
    final progress = gameState.quest('q_kartofla_videos');
    if (progress?.state != QuestState.active ||
        overlays.isActive(overlayVideoSequence)) {
      return;
    }
    world_.player.stop();
    _pressedKeys.clear();
    _movementKeyOrder.clear();
    registerWindowCloseHandler(overlayVideoSequence, closeVideoSequence);
    overlays.add(overlayVideoSequence, priority: 30);
  }

  void closeVideoSequence() {
    unregisterWindowCloseHandler(overlayVideoSequence);
    overlays.remove(overlayVideoSequence);
  }

  void completeVideoSequence() {
    if (!gameState.completeMiniGameQuest(
      'q_kartofla_videos',
      miniGameId: 'kartofla_videos',
    )) {
      return;
    }
    // Для этой награды нет отдельной кнопки «забрать»: скин выдаётся сразу
    // после финального кадра всех трёх роликов.
    gameState.claimQuest('q_kartofla_videos');
    notifications.notify(
      'Три ролика просмотрены! Скин «Картофля» разблокирован.',
      type: NotificationType.reward,
    );
    unawaited(saveProgress());
    closeVideoSequence();
  }

  void openShawarmaChoice() {
    overlays.remove(overlayUpgrade);
    registerWindowCloseHandler(overlayShawarmaChoice, () {});
    overlays.add(overlayShawarmaChoice, priority: 40);
  }

  void chooseShawarma(bool eat) {
    if (!gameState.resolveShawarmaChoice(eat: eat)) return;
    unregisterWindowCloseHandler(overlayShawarmaChoice);
    overlays.remove(overlayShawarmaChoice);
    notifications.notify(
      eat
          ? 'Шаурма съедена. Илья узнает о твоём выборе.'
          : 'Шаурма сохранена для Ильи.',
      type: NotificationType.info,
    );
    unawaited(saveProgress());
  }

  void _beginBattle(EnemyEntity enemyEntity) {
    if (_endingBattle || battle != null) return;
    final archetype = GameContent.enemyById(enemyEntity.enemyId);
    if (archetype == null) return;
    unawaited(audio.play(GameSound.battleStart));

    _battleEnemy = enemyEntity;
    _pressedKeys.clear();
    _movementKeyOrder.clear();

    final playerFighter = Fighter(
      name: gameState.playerName,
      maxHp: gameState.playerMaxHp,
      dice: List.from(gameState.dice),
      isPlayer: true,
      initialHp: gameState.playerHp,
      appearance: gameState.selectedSkin.portraitKey,
      attackPhrases: GameContent.playerAttackPhrases,
    );

    final enemyFighter = Fighter(
      name: archetype.name,
      maxHp: archetype.maxHp,
      dice: [],
      attackFaces: archetype.diceFaces,
      baseAttack: archetype.diceFaces.isEmpty ? 0 : archetype.diceFaces.first,
      baseShield: archetype.startingShield,
      actsFirst: archetype.actsFirst,
      burnDamage: archetype.appliesBurn ? archetype.burnDamage : 0,
      appearance: enemyEntity.enemyId,
      attackPhrases: archetype.attackPhrases,
      rootCells: archetype.rootCells,
    );

    battle = BattleEngine(
      player: playerFighter,
      enemy: enemyFighter,
      playerDiceCount: gameState.dicePerTurn,
      playerRerollsPerRound: gameState.rerollsPerRound,
      artifacts: gameState.artifacts,
      onDiceConsumed: (dice) {
        if (gameState.consumeDice(dice)) unawaited(saveProgress());
      },
      onDiceChanged: (before, after) {
        if (gameState.replaceDice(before, after)) unawaited(saveProgress());
      },
    );
    world_.player.stop();
    overlays.remove(overlayDialog);
    overlays.add(overlayBattle, priority: 10);
  }

  /// Завершает бой: начисляет награды или обрабатывает поражение.
  Future<void> endBattle() async {
    if (_endingBattle) return;
    final engine = battle;
    final enemyEntity = _battleEnemy;
    if (engine == null) return;
    _endingBattle = true;

    try {
      // Сохраняем остаток HP даже после победы — следующий бой начинается с
      // тем же значением, пока герой не восстановится эффектом или событием.
      if (!engine.player.isDead) {
        gameState.setPlayerHp(engine.player.hp);
      }

      if (engine.player.isDead) {
        unawaited(audio.play(GameSound.defeat));
        final archetype = enemyEntity == null
            ? null
            : GameContent.enemyById(enemyEntity.enemyId);
        final coinStealChance = archetype?.coinStealChance ?? 0;
        final stealsCoins =
            coinStealChance > 0 && _random.nextDouble() < coinStealChance;
        final lostCoins = stealsCoins ? (gameState.coins / 2).ceil() : 0;
        if (lostCoins > 0) gameState.loseCoins(lostCoins);
        gameState.setPlayerHp(gameState.playerMaxHp);
        final defeatMessage = lostCoins > 0
            ? 'Поражение! Потеряно $lostCoins монет. Вы вернулись на вокзал.'
            : 'Поражение! Монеты сохранены. Вы вернулись на вокзал.';
        notifications.notify(defeatMessage, type: NotificationType.warning);
        gameState.currentLocationId = 'meadow';
        unawaited(_respawnAtMeadow());
      } else if (engine.enemy.isDead && enemyEntity != null) {
        unawaited(audio.play(GameSound.victory));
        final archetype = GameContent.enemyById(enemyEntity.enemyId);
        if (archetype != null) {
          gameState.addCoins(archetype.coins);
          gameState.addXp(archetype.xp);
          world_.syncPlayerName();
          gameState.markEnemyDefeated(enemyEntity.spawnKey);
          gameState.progressQuests(
            enemyId: archetype.id,
            coinsEarned: archetype.coins,
          );
          final victoryHeal = gameState.healAfterVictory(archetype.maxHp);
          notifications.notify(
            'Победа! +${archetype.coins} монет, +${archetype.xp} опыта, '
            '+$victoryHeal HP',
            type: NotificationType.reward,
          );
          world_.removeEnemy(enemyEntity);
        }
      }

      await saveProgress();
    } finally {
      battle = null;
      _battleEnemy = null;
      overlays.remove(overlayBattle);
      _endingBattle = false;
    }
  }

  /// Esc во время активного боя означает отступление: враг остаётся на карте,
  /// а игрок возвращается к исследованию без награды за победу.
  void retreatBattle() {
    if (_endingBattle) return;
    final engine = battle;
    if (engine == null) return;
    // surrender() обнуляет временный HP бойца, поэтому забираем остаток до
    // его вызова. Иначе после отступления в GameState попадало здоровье до
    // начала боя (а при следующем чтении — не фактический остаток).
    final remainingHp = engine.player.hp;
    if (!engine.surrender()) return;
    unawaited(audio.play(GameSound.defeat));
    // Отступление не является смертью: сохраняем именно тот HP, который
    // остался в бою, чтобы он был виден на карте и в следующем бою.
    gameState.setPlayerHp(remainingHp);
    unawaited(saveProgress());
    battle = null;
    _battleEnemy = null;
    _pressedKeys.clear();
    _movementKeyOrder.clear();
    overlays.remove(overlayBattle);
    notifications.notify(
      'Вы отступили из боя.',
      type: NotificationType.warning,
    );
  }

  // --- NPC ---

  void _talkToNpc(NpcEntity npc) {
    _talkingNpc = npc;
    _pressedKeys.clear();
    _movementKeyOrder.clear();
    overlays.remove(overlayBattle);
    overlays.add(overlayDialog, priority: 10);
  }

  NpcEntity? get talkingNpc => _talkingNpc;

  /// Регистрирует обработчик клавиш только на время существования диалога.
  void registerDialogKeyboardHandler(
    void Function(LogicalKeyboardKey key)? handler,
  ) {
    _dialogKeyboardHandler = handler;
  }

  void registerBattleKeyboardHandler(VoidCallback? handler) {
    _battleKeyboardHandler = handler;
  }

  void registerBattleDiceKeyboardHandler(void Function(int index)? handler) {
    _battleDiceKeyboardHandler = handler;
  }

  void registerWindowCloseHandler(String overlay, VoidCallback handler) {
    _windowCloseHandlers[overlay] = handler;
  }

  void unregisterWindowCloseHandler(String overlay) {
    _windowCloseHandlers.remove(overlay);
  }

  Player get player => world_.player;

  // --- Прокачка ---

  void openUpgrade() {
    final npc = _talkingNpc;
    if (npc == null ||
        !gameState.hasNpcShopAccess(npc.npcId) ||
        !world_.isPlayerAdjacentTo(npc)) {
      notifications.notify(
        'Сначала подойдите к продавцу и откройте его магазин.',
        type: NotificationType.info,
      );
      return;
    }
    activeShopNpcId = npc.npcId;
    overlays.remove(overlayQuests);
    overlays.remove(overlayInventory);
    overlays.add(overlayUpgrade, priority: 10);
  }

  void openInventory() {
    world_.player.stop();
    _pressedKeys.clear();
    _movementKeyOrder.clear();
    overlays.remove(overlayUpgrade);
    overlays.remove(overlayQuests);
    overlays.add(overlayInventory, priority: 10);
  }

  void openQuests() {
    overlays.remove(overlayUpgrade);
    overlays.remove(overlayInventory);
    overlays.add(overlayQuests, priority: 10);
  }

  void openSettings() {
    overlays.remove(overlayUpgrade);
    overlays.remove(overlayInventory);
    overlays.remove(overlayQuests);
    overlays.add(overlaySettings, priority: 10);
  }

  Future<void> resetGame() async {
    overlays.remove(overlaySettings);
    _clearBattleIntroOverlays();
    closeSearch();
    closeSongMiniGame();
    closeDonerAssembly();
    closeVideoSequence();
    unregisterWindowCloseHandler(overlayShawarmaChoice);
    overlays.remove(overlayShawarmaChoice);
    _pendingBattleEnemy = null;
    _victorPreBattleActive = false;
    battle = null;
    _battleEnemy = null;
    gameState.reset();
    await gameState.clearSave(saveDirectory);
    await world_.loadLocation('meadow', spawnOverride: Locations.meadow.spawn);
    camera.follow(world_.player, snap: true);
    _pressedKeys.clear();
    _movementKeyOrder.clear();
  }

  Future<void> _respawnAtMeadow() async {
    await world_.loadLocation('meadow', spawnOverride: Locations.meadow.spawn);
    camera.follow(world_.player, snap: true);
    await saveProgress();
  }

  Future<void> saveProgress() => gameState.save(saveDirectory);

  bool get _isInputBlocked =>
      overlays.isActive(overlayBattleConfirm) ||
      overlays.isActive(overlayPreBattle) ||
      overlays.isActive(overlayBattle) ||
      overlays.isActive(overlayDialog) ||
      overlays.isActive(overlaySearch) ||
      overlays.isActive(overlaySongMiniGame) ||
      overlays.isActive(overlayDonerAssembly) ||
      overlays.isActive(overlayVideoSequence) ||
      overlays.isActive(overlayShawarmaChoice) ||
      overlays.isActive(overlayUpgrade) ||
      overlays.isActive(overlayInventory) ||
      overlays.isActive(overlayQuests) ||
      overlays.isActive(overlaySettings) ||
      locationTransition.value.phase != LocationTransitionPhase.idle;

  bool _isMovementKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.keyW ||
      key == LogicalKeyboardKey.keyA ||
      key == LogicalKeyboardKey.keyS ||
      key == LogicalKeyboardKey.keyD ||
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight;

  void _beginMovementIntent((int, int) direction) {
    _heldMoveTimer = 0;
    _heldRepeatStarted = false;
    world_.movePlayerBy(direction.$1, direction.$2);
  }

  (int, int)? _directionFromPressedKeys() {
    // Берём только последнюю активную клавишу. Это оставляет движение строго
    // по одному из четырёх направлений: если во время W нажать D, игрок
    // переключится на D, а не пойдёт по диагонали.
    for (final key in _movementKeyOrder.reversed) {
      if (!_pressedKeys.contains(key)) continue;
      final direction = _directionForKey(key);
      if (direction != null) return direction;
    }
    return null;
  }

  (int, int)? _directionForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyW || key == LogicalKeyboardKey.arrowUp) {
      return (0, -1);
    }
    if (key == LogicalKeyboardKey.keyS || key == LogicalKeyboardKey.arrowDown) {
      return (0, 1);
    }
    if (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.arrowLeft) {
      return (-1, 0);
    }
    if (key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowRight) {
      return (1, 0);
    }
    return null;
  }
}
