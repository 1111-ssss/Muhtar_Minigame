import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/location.dart';
import '../domain/locations.dart';
import '../game/muhtar_game.dart';
import '../game_logic/game_state.dart';
import '../game_logic/audio_service.dart';
import '../game_logic/notification_service.dart';
import '../game_logic/location_assets.dart';
import '../game/world/isometric_map.dart';
import 'battle/battle_overlay.dart';
import 'battle/battle_confirm_overlay.dart';
import 'battle/pre_battle_overlay.dart';
import 'dialog/dialog_overlay.dart';
import 'hud/hud_overlay.dart';
import 'notifications/notifications_overlay.dart';
import 'quest/quest_overlay.dart';
import 'quest/doner_assembly_overlay.dart';
import 'quest/song_minigame_overlay.dart';
import 'quest/shawarma_choice_overlay.dart';
import 'quest/insulin_choice_overlay.dart';
import 'quest/trip_overlay.dart';
import 'quest/video_sequence_overlay.dart';
import 'search/search_overlay.dart';
import 'search/potato_pickup_overlay.dart';
import 'transition/location_transition_overlay.dart';
import 'upgrade/upgrade_overlay.dart';
import 'settings/settings_overlay.dart';
import 'main_menu.dart';

/// Корневой виджет: связывает Flame-игру с Flutter-оверлеями.
class GameApp extends StatefulWidget {
  const GameApp({super.key});

  @override
  State<GameApp> createState() => _GameAppState();
}

class _GameAppState extends State<GameApp> with WidgetsBindingObserver {
  late final GameState _gameState;
  late final NotificationService _notifications;
  late final AudioService _audio;
  MuhtarGame? _game;
  String? _loadError;
  String _loadStage = 'Подготавливаем игру…';
  late String _saveDirectory;
  bool _hasSave = false;
  bool _showMainMenu = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameState = GameState();
    _notifications = NotificationService();
    _audio = AudioService();
    unawaited(_audio.playMusic(MusicTrack.menu));
    _loadGame();
  }

  Future<void> _loadGame() async {
    if (mounted) {
      setState(() {
        _loadError = null;
        _loadStage = 'Загрузка карт и сохранения…';
      });
    }
    try {
      // Сначала применяем карты, затем читаем сохранение: fromJson проверяет
      // searchable-пропы через реестр Locations. Параллельный запуск мог
      // разобрать сейв раньше editor overrides и потерять валидные результаты.
      await LocationAssets.load();
      _saveDirectory = await _loadProgress();

      if (mounted) {
        setState(() => _loadStage = 'Прогрев первой карты…');
      }
      await _precacheInitialLocations();

      if (!mounted) return;
      setState(() {
        _game = MuhtarGame(
          gameState: _gameState,
          notifications: _notifications,
          audio: _audio,
          saveDirectory: _saveDirectory,
        );
      });
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = '$error');
    }
  }

  Future<String> _loadProgress() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final saveDirectory = p.join(supportDirectory.path, 'MuhtarMinigame');

    // До введения постоянного каталога сохранения были относительными. Один
    // раз переносим такой сейв, чтобы уже сыгранный прогресс не потерялся.
    var loaded = await _gameState.load(saveDirectory);
    if (!loaded) {
      final migrated = await _gameState.load('save');
      if (migrated) await _gameState.save(saveDirectory);
      loaded = migrated;
    }
    _hasSave = loaded;
    return saveDirectory;
  }

  Future<void> _startGame() async {
    if (!mounted) return;
    setState(() => _showMainMenu = false);
    unawaited(_audio.playLocationMusic(_gameState.currentLocationId));
  }

  Future<void> _startNewGame() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Начать новую игру?'),
        content: const Text(
          'Текущий прогресс будет удалён. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить прогресс'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _gameState.clearSave(_saveDirectory);
    _gameState.reset();
    await _gameState.save(_saveDirectory);
    _hasSave = false;
    if (!mounted) return;
    setState(() => _showMainMenu = false);
    unawaited(_audio.playLocationMusic('meadow'));
  }

  Future<void> _precacheInitialLocations() async {
    final current =
        Locations.byId(_gameState.currentLocationId) ?? Locations.meadow;
    final firstDestination = current.exits
        .map((exit) => Locations.byId(exit.targetId))
        .whereType<LocationDef>()
        .firstOrNull;
    final locations = [current, ?firstDestination];
    await Future.wait(locations.map(IsometricMap.precache));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_game?.saveProgress());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muhtar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: false).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C1010),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'monospace'),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFC857),
          secondary: Color(0xFF5BC0EB),
          surface: Color(0xFF171923),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF171923),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      home: _loadError != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Не удалось загрузить игру'),
                      const SizedBox(height: 12),
                      SelectableText(_loadError!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadGame,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _game == null
          ? _LoadingSplash(stage: _loadStage)
          : _showMainMenu
          ? MainMenu(
              gameState: _gameState,
              hasSave: _hasSave,
              onStart: _startGame,
              onNewGame: _startNewGame,
            )
          : GameView(game: _game!),
    );
  }
}

class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C1010), Color(0xFF171923)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFF20242C),
                      border: Border.all(
                        color: const Color(0xFFFFC857),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          offset: Offset(6, 6),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: Color(0xFFFFC857),
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'МУХТАР',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'MINIGAME',
                    style: TextStyle(
                      color: Color(0xFF5BC0EB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor: Color(0xFF303541),
                      color: Color(0xFFFFC857),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    stage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD7E2FF),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Первый запуск готовит мир к плавной игре',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8993A5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Material задаёт нормальный стиль текста всем оверлеям, включая HUD,
/// уведомления и плашку перехода (без служебного двойного подчёркивания).
class GameView extends StatelessWidget {
  const GameView({required this.game, super.key});

  final MuhtarGame game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget<MuhtarGame>(
        game: game,
        overlayBuilderMap: {
          MuhtarGame.overlayHud: (context, MuhtarGame game) => HudOverlay(game),
          MuhtarGame.overlayBattle: (context, MuhtarGame game) =>
              BattleOverlay(game),
          MuhtarGame.overlayBattleConfirm: (context, MuhtarGame game) =>
              BattleConfirmOverlay(game),
          MuhtarGame.overlayPreBattle: (context, MuhtarGame game) =>
              PreBattleOverlay(
                game,
                onContinue: game.confirmBattle,
                onSkip: game.confirmBattle,
              ),
          MuhtarGame.overlaySearch: (context, MuhtarGame game) {
            final prop = game.searchingProp;
            if (prop == null) return const SizedBox.shrink();
            return SearchOverlay(
              game: game.gameState,
              prop: prop,
              onClose: game.closeSearch,
              onResult: (result) {
                unawaited(
                  game.audio.play(
                    result.completed ? GameSound.coins : GameSound.search,
                  ),
                );
                unawaited(game.saveProgress());
                game.handleSearchResult(result);
              },
            );
          },
          MuhtarGame.overlayPotatoPickup: (context, MuhtarGame game) =>
              PotatoPickupOverlay(
                onPickUp: () {
                  game.pickUpPotato();
                },
                onClose: game.closePotatoPickup,
              ),
          MuhtarGame.overlaySongMiniGame: (context, MuhtarGame game) =>
              SongMinigameOverlay(
                onSolved: game.completeSongMiniGame,
                onClose: game.closeSongMiniGame,
              ),
          MuhtarGame.overlayDonerAssembly: (context, MuhtarGame game) =>
              DonerAssemblyOverlay(
                recipeId: game.donerRecipeId ?? 'classic',
                onSolved: game.completeDonerAssembly,
                onClose: game.closeDonerAssembly,
              ),
          MuhtarGame.overlayVideoSequence: (context, MuhtarGame game) =>
              VideoSequenceOverlay(
                onCompleted: game.completeVideoSequence,
                onClose: game.closeVideoSequence,
              ),
          MuhtarGame.overlayShawarmaChoice: (context, MuhtarGame game) =>
              ShawarmaChoiceOverlay(onChoice: game.chooseShawarma),
          MuhtarGame.overlayUpgrade: (context, MuhtarGame game) =>
              UpgradeOverlay(game, shop: true, shopNpcId: game.activeShopNpcId),
          MuhtarGame.overlayInventory: (context, MuhtarGame game) =>
              UpgradeOverlay(game),
          MuhtarGame.overlayQuests: (context, MuhtarGame game) =>
              QuestOverlay(game),
          MuhtarGame.overlayDialog: (context, MuhtarGame game) =>
              DialogOverlay(game),
          'notifications': (context, MuhtarGame game) =>
              NotificationsOverlay(game.notifications),
          MuhtarGame.overlayLocationTransition: (context, MuhtarGame game) =>
              LocationTransitionOverlay(game),
          MuhtarGame.overlaySettings: (context, MuhtarGame game) =>
              SettingsOverlay(game),
          MuhtarGame.overlayInsulinChoice: (context, MuhtarGame game) =>
              InsulinChoiceOverlay(
                onChoice: (inject) => game.chooseInsulin(inject: inject),
              ),
          MuhtarGame.overlayTrip: (context, MuhtarGame game) =>
              const TripOverlay(),
        },
      ),
    );
  }
}
