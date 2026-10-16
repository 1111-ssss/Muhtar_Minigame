import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/build/build_app.dart';
import 'package:muhtar_minigame/build/build_models.dart';
import 'package:muhtar_minigame/build/portrait_document.dart';
import 'package:muhtar_minigame/domain/locations.dart';

void main() {
  test('map JSON round-trip keeps gameplay metadata', () {
    final original = BuildMapDocument.fromLocation(Locations.forest);
    final restored = BuildMapDocument.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.tiles, original.tiles);
    expect(restored.spawnCol, original.spawnCol);
    expect(restored.spawnRow, original.spawnRow);
    expect(restored.exits.length, original.exits.length);
    expect(restored.exits.first.arrivalCol, original.exits.first.arrivalCol);
    expect(restored.props.length, original.props.length);
    expect(restored.props.first.id, original.props.first.id);
    expect(restored.validationErrors(), isEmpty);

    final wb = BuildMapDocument.fromJson(
      BuildMapDocument.fromLocation(Locations.wb).toJson(),
    );
    expect(wb.props.single.interactionId, 'q_kartofla_videos');
  });

  test('repository saves a custom draft and loads it back', () async {
    final directory = await Directory.systemTemp.createTemp(
      'muhtar_build_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = BuildMapRepository(
      rootPath: '${directory.path}/muhtar_build',
      projectRoot: directory.path,
    );
    final draft = BuildMapDocument(
      id: 'test_map',
      name: 'Тестовая карта',
      tiles: [
        [0, 4],
      ],
      spawnCol: 0,
      spawnRow: 0,
      exits: [BuildExit(1, 0, 'test_map', 0, 0, 'auto')],
    );

    final file = await repository.save(draft);
    final maps = await repository.loadAll();

    expect(file.path, endsWith('muhtar_build/maps/test_map.json'));
    expect(
      maps.singleWhere((map) => map.id == 'test_map').name,
      'Тестовая карта',
    );
  });

  test('invalid map IDs never become filesystem paths', () async {
    final directory = await Directory.systemTemp.createTemp(
      'muhtar_build_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = BuildMapRepository(
      rootPath: '${directory.path}/muhtar_build',
      projectRoot: directory.path,
    );
    final map = BuildMapDocument(
      id: '../escape',
      name: 'Небезопасная',
      tiles: [
        [0],
      ],
      spawnCol: 0,
      spawnRow: 0,
    );

    await expectLater(repository.save(map), throwsArgumentError);
    expect(map.validationErrors(), contains(startsWith('ID:')));
  });

  test(
    'portrait editing paints, undoes and encodes without writing files',
    () async {
      final portrait = PortraitDocument.blank(width: 8, height: 8);
      addTearDown(portrait.dispose);
      portrait.beginStroke();
      portrait.paintLine(1, 1, 6, 1, color: 0xFFFF8800, brushSize: 2);
      portrait.endStroke();

      expect(portrait.pixelAt(3, 1), 0xFFFF8800);
      expect(portrait.isDirty, isTrue);
      expect(portrait.undo(), isTrue);
      expect(portrait.pixelAt(3, 1), 0x00000000);
      expect(portrait.redo(), isTrue);
      expect((await portrait.encodePng()).take(8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
    },
  );

  testWidgets('MuhtarBuild exposes map and portrait workspaces', (
    tester,
  ) async {
    final projectRoot = File('pubspec.yaml').existsSync()
        ? Directory.current.path
        : '${Directory.current.path}/muhtar_minigame';
    await tester.pumpWidget(MuhtarBuildApp(projectRoot: projectRoot));
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('MuhtarBuild'), findsOneWidget);
    expect(find.text('Карты •'), findsOneWidget);
    expect(find.text('Персонажи'), findsOneWidget);
    expect(find.text('Перемещение'), findsOneWidget);
    expect(find.byKey(const ValueKey('map-canvas')), findsOneWidget);

    await tester.tap(find.text('Персонажи'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Персонажи •'), findsOneWidget);
  });
}
