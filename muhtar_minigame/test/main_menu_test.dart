import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/game_logic/audio_service.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';
import 'package:muhtar_minigame/ui/main_menu.dart';
import 'package:muhtar_minigame/ui/settings/main_menu_settings_dialog.dart';

void main() {
  testWidgets('shows saved progress and continues the game', (tester) async {
    var started = false;
    final state = GameState();
    state.addCoins(12);

    await tester.pumpWidget(
      MaterialApp(
        home: MainMenu(
          gameState: state,
          hasSave: true,
          onStart: () async => started = true,
          onNewGame: () async {},
          onSettings: (_) async {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('main-menu-title')), findsOneWidget);
    expect(find.text('BUBER Adventure'), findsOneWidget);
    expect(find.text('ОДИНОЧНАЯ ИГРА  •  OFFLINE'), findsNothing);
    expect(find.text('Продолжить игру'), findsOneWidget);
    expect(find.text('62'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-menu-panel')), findsOneWidget);
    expect(find.text('ГЛАВНОЕ МЕНЮ'), findsNothing);
    expect(find.text('ПИКСЕЛЬНОЕ ПРИКЛЮЧЕНИЕ'), findsNothing);
    expect(find.text('ТАП ДЛЯ ДВИЖЕНИЯ'), findsNothing);
    expect(find.text('WASD / СТРЕЛКИ'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('main-menu-start')));
    await tester.pump();

    expect(started, isTrue);
  });

  testWidgets('shows a fresh start when there is no save', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainMenu(
          gameState: GameState(),
          hasSave: false,
          onStart: () async {},
          onNewGame: () async {},
          onSettings: (_) async {},
        ),
      ),
    );

    expect(find.text('Начать игру'), findsOneWidget);
    expect(find.text('Новый забег'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-menu-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('main-menu-progress-card')), findsOneWidget);
  });

  testWidgets('animates the main menu background', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainMenu(
          gameState: GameState(),
          hasSave: false,
          onStart: () async {},
          onNewGame: () async {},
          onSettings: (_) async {},
        ),
      ),
    );

    final firstPainter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('main-menu-background')),
        )
        .painter;

    await tester.pump(const Duration(milliseconds: 500));

    final secondPainter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('main-menu-background')),
        )
        .painter;
    expect(identical(firstPainter, secondPainter), isFalse);
  });

  testWidgets('opens settings from the main menu', (tester) async {
    var settingsOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MainMenu(
          gameState: GameState(),
          hasSave: false,
          onStart: () async {},
          onNewGame: () async {},
          onSettings: (_) async => settingsOpened = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-settings')));
    await tester.pump();

    expect(settingsOpened, isTrue);
  });

  testWidgets('does not show a loading spinner while settings are open', (
    tester,
  ) async {
    final settingsClosed = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: MainMenu(
          gameState: GameState(),
          hasSave: false,
          onStart: () async {},
          onNewGame: () async {},
          onSettings: (_) => settingsClosed.future,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('main-menu-settings')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);

    settingsClosed.complete();
    await tester.pump();
  });

  testWidgets('changes separate volume settings in the menu dialog', (
    tester,
  ) async {
    final audio = AudioService();
    addTearDown(audio.dispose);

    await tester.pumpWidget(
      MaterialApp(home: MainMenuSettingsDialog(audio: audio)),
    );

    expect(find.text('Общая громкость'), findsOneWidget);
    expect(find.text('Музыка'), findsOneWidget);
    expect(find.text('Эффекты'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byKey(const ValueKey('audio-master-slider')), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-music-slider')), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-effects-slider')), findsOneWidget);

    audio.setMasterVolume(.4);
    audio.setMusicVolume(.7);
    audio.setEffectsVolume(.2);
    await tester.pump();

    expect(
      tester.widget<Slider>(
        find.byKey(const ValueKey('audio-master-slider')),
      ).value,
      .4,
    );
    expect(
      tester.widget<Slider>(
        find.byKey(const ValueKey('audio-music-slider')),
      ).value,
      .7,
    );
    expect(
      tester.widget<Slider>(
        find.byKey(const ValueKey('audio-effects-slider')),
      ).value,
      .2,
    );
  });
}
