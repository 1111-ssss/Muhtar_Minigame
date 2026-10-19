import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/game/muhtar_game.dart';
import 'package:muhtar_minigame/game_logic/audio_service.dart';
import 'package:muhtar_minigame/game_logic/game_state.dart';
import 'package:muhtar_minigame/game_logic/notification_service.dart';
import 'package:muhtar_minigame/ui/settings/settings_overlay.dart';

void main() {
  testWidgets('in-game settings shows main menu action first', (tester) async {
    final saveDirectory = Directory.systemTemp.createTempSync(
      'muhtar-settings-overlay-',
    );
    final audio = AudioService();
    var mainMenuCalled = false;
    final game = MuhtarGame(
      gameState: GameState(),
      notifications: NotificationService(),
      audio: audio,
      saveDirectory: saveDirectory.path,
    );
    game.overlays.addEntry(
      MuhtarGame.overlaySettings,
      (_, _) => const SizedBox.shrink(),
    );
    addTearDown(() {
      audio.dispose();
      saveDirectory.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsOverlay(
            game,
            onMainMenu: () async => mainMenuCalled = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('settings-main-menu')), findsOneWidget);
    expect(find.text('В главное меню'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-gameplay')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-audio')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-danger')), findsOneWidget);
    expect(find.text('Автосохранение'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-audio')));
    await tester.pump();
    expect(find.text('Громкость'), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-master-slider')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('settings-gameplay')));
    await tester.pump();
    expect(find.text('Автосохранение'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-audio')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('settings-main-menu')),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    expect(mainMenuCalled, isTrue);
  });
}
