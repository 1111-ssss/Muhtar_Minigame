import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../game/muhtar_game.dart';
import '../game_logic/game_state.dart';
import '../game_logic/audio_service.dart';
import '../game_logic/notification_service.dart';
import '../game_logic/location_assets.dart';
import 'battle/battle_overlay.dart';
import 'battle/battle_confirm_overlay.dart';
import 'battle/pre_battle_overlay.dart';
import 'dialog/dialog_overlay.dart';
import 'hud/hud_overlay.dart';
import 'notifications/notifications_overlay.dart';
import 'quest/quest_overlay.dart';
import 'quest/song_minigame_overlay.dart';
import 'search/search_overlay.dart';
import 'transition/location_transition_overlay.dart';
import 'upgrade/upgrade_overlay.dart';
import 'settings/settings_overlay.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gameState = GameState();
    _notifications = NotificationService();
    _audio = AudioService();
    _loadGame();
  }

  Future<void> _loadGame() async {
    if (mounted) setState(() => _loadError = null);
    try {
      await LocationAssets.load();
      await _loadProgress();
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = '$error');
    }
  }

  Future<void> _loadProgress() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final saveDirectory = p.join(supportDirectory.path, 'MuhtarMinigame');

    // До введения постоянного каталога сохранения были относительными. Один
    // раз переносим такой сейв, чтобы уже сыгранный прогресс не потерялся.
    final loaded = await _gameState.load(saveDirectory);
    if (!loaded) {
      final migrated = await _gameState.load('save');
      if (migrated) await _gameState.save(saveDirectory);
    }
    if (!mounted) return;
    setState(() {
      _game = MuhtarGame(
        gameState: _gameState,
        notifications: _notifications,
        audio: _audio,
        saveDirectory: saveDirectory,
      );
    });
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
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : GameView(game: _game!),
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
              },
            );
          },
          MuhtarGame.overlaySongMiniGame: (context, MuhtarGame game) =>
              SongMinigameOverlay(
                onSolved: game.completeSongMiniGame,
                onClose: game.closeSongMiniGame,
              ),
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
        },
      ),
    );
  }
}
