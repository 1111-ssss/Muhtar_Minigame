import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/locations.dart';
import 'package:muhtar_minigame/game/world/isometric_map.dart';
import 'package:muhtar_minigame/game_logic/pathfinding.dart';
import 'package:muhtar_minigame/game_logic/location_assets.dart';
import 'package:muhtar_minigame/domain/location.dart';

void main() {
  group('IsometricMap coordinate mapping', () {
    test('tile centers map back to the same tile on every quadrant', () {
      for (var row = 0; row < Locations.meadow.rows; row++) {
        for (var col = 0; col < Locations.meadow.cols; col++) {
          final world = IsometricMap.tileToWorld(col, row);
          expect(IsometricMap.worldToTileInLocation(Locations.meadow, world), (
            col,
            row,
          ), reason: 'tile ($col, $row) was mapped from $world');
        }
      }
    });

    test('negative world coordinates do not shift the selected tile', () {
      const location = Locations.meadow;
      final tile = IsometricMap.tileToWorld(0, 1);
      final points = [tile, tile + Vector2(10, 3), tile + Vector2(-10, -3)];

      for (final point in points) {
        expect(IsometricMap.worldToTileInLocation(location, point), (
          0,
          1,
        ), reason: 'point $point should remain inside tile (0, 1)');
      }
    });

    test('tile centers use a shallow isometric diamond basis', () {
      final right = IsometricMap.tileToWorld(1, 0);
      final left = IsometricMap.tileToWorld(0, 1);

      expect(right.x, greaterThan(0));
      expect(right.y, greaterThan(0));
      expect(left.x, lessThan(0));
      expect(left.y, greaterThan(0));
      expect(right.y, left.y);
    });

    test('rail geometry follows the isometric tile basis', () {
      final railStart = IsometricMap.projectTilePoint(0, .30);
      final railEnd = IsometricMap.projectTilePoint(1, .30);
      final sleeperStart = IsometricMap.projectTilePoint(.50, .18);
      final sleeperEnd = IsometricMap.projectTilePoint(.50, .82);

      expect(railEnd.dx - railStart.dx, IsometricMap.tileWidth / 2);
      expect(railEnd.dy - railStart.dy, IsometricMap.tileHeight / 2);
      // Шпала проходит от v=.18 до v=.82: фактический span равен .64,
      // а не всему единичному тайлу.
      const sleeperSpan = .64;
      expect(
        sleeperEnd.dx - sleeperStart.dx,
        closeTo(-IsometricMap.tileWidth * sleeperSpan / 2, 1e-9),
      );
      expect(
        sleeperEnd.dy - sleeperStart.dy,
        closeTo(IsometricMap.tileHeight * sleeperSpan / 2, 1e-9),
      );
    });

    test('first location is the station and leads to the long park', () {
      final exits = Locations.meadow.exits;
      expect(Locations.meadow.name, 'Вокзал');
      expect(exits.map((exit) => exit.targetId), contains('forest'));
      expect(
        Locations.forest.enemies.map((spawn) => spawn.enemyId),
        contains('gopnik'),
      );
      expect(Locations.forest.name, 'Парк');
      expect(Locations.meadow.npcs.single.id, 'ariana');
    });

    test('arrivals are beside, not on, return exits', () {
      expect(Locations.forest.cols, greaterThan(Locations.forest.rows));

      for (final location in Locations.all) {
        for (final exit in location.exits) {
          expect(
            exit.col == 0 ||
                exit.row == 0 ||
                exit.col == location.cols - 1 ||
                exit.row == location.rows - 1 ||
                (location.id == 'ruins' && exit.col == 28),
            isTrue,
            reason: '${location.id} exit should be on the map edge',
          );
          final arrival = exit.arrival;
          if (arrival == null) continue;
          final target = Locations.byId(exit.targetId)!;
          if (target.exits.isEmpty) continue;
          final returnExits = target.exits.where(
            (candidate) => candidate.targetId == location.id,
          );
          expect(
            target.exitAt(arrival.$1, arrival.$2),
            isNull,
            reason:
                '${location.id} -> ${exit.targetId} must not land on a portal',
          );
          final hasNearbyReturnExit = returnExits.any((returnExit) {
            final distance =
                (arrival.$1 - returnExit.col).abs() +
                (arrival.$2 - returnExit.row).abs();
            return distance <= 1 &&
                (arrival.$1 != returnExit.col || arrival.$2 != returnExit.row);
          });
          expect(
            hasNearbyReturnExit,
            isTrue,
            reason:
                '${location.id} -> ${exit.targetId} must arrive beside, not on, the return exit',
          );
        }
      }
    });

    test('ruins are a 40x8 bridge with tiled banks and exits', () {
      expect(Locations.ruins.name, 'Мост');
      expect(Locations.ruins.cols, 40);
      expect(Locations.ruins.rows, 8);
      expect(Locations.ruins.outsideTile, 6);
      expect(Locations.ruins.tiles.every((row) => row.length == 40), isTrue);
      expect(
        Locations.ruins.tiles.first.take(12).every((tile) => tile == 9),
        isTrue,
      );
      expect(Locations.ruins.tiles.first.skip(12).take(16), everyElement(7));
      expect(
        Locations.ruins.tiles.first.skip(28).every((tile) => tile == 9),
        isTrue,
      );
      expect(Locations.ruins.tiles.last, Locations.ruins.tiles.first);
      expect(
        Locations.ruins.props.where(
          (prop) => prop.kind == LocationPropKind.platform,
        ),
        isEmpty,
      );
      final potato = Locations.ruins.propById('bridge_potato')!;
      expect((potato.col, potato.row), (18, 3));
      expect(
        Locations.ruins.props.map((prop) => prop.id),
        containsAll(<String>[
          'bridge_tree_right_34_1',
          'bridge_bush_right_34_6',
          'bridge_flower_bed_right_36_4',
          'bridge_lamp_15_1',
          'bridge_lamp_24_6',
          'bridge_flower_bed_left_5_1',
        ]),
      );
      expect(
        Locations.ruins.props
            .where(
              (prop) =>
                  prop.id == 'bridge_lamp_15_1' ||
                  prop.id == 'bridge_lamp_15_6' ||
                  prop.id == 'bridge_lamp_24_6' ||
                  prop.id == 'bridge_flower_bed_left_5_1' ||
                  prop.id == 'bridge_flower_bed_right_35_6',
            )
            .every((prop) => !prop.blocksMovement),
        isTrue,
      );
      expect(
        Locations.ruins.props
            .where((prop) => prop.id == 'bridge_tree_right_34_1')
            .single,
        predicate<LocationProp>((prop) => prop.col == 30 && prop.row == 1),
      );
      expect(
        Locations.ruins.props
            .where((prop) => prop.id == 'bridge_bush_right_34_6')
            .single,
        predicate<LocationProp>((prop) => prop.col == 30 && prop.row == 6),
      );
      expect(
        Locations.ruins.props
            .where((prop) => prop.id == 'bridge_flower_bed_right_36_4')
            .single,
        predicate<LocationProp>((prop) => prop.col == 36 && prop.row == 1),
      );
      expect(
        Locations.ruins.props
            .where((prop) => prop.col >= 28)
            .every(
              (prop) => !Locations.ruins.exits.any(
                (exit) => exit.col == prop.col && exit.row == prop.row,
              ),
            ),
        isTrue,
      );
      for (var row = 0; row < Locations.ruins.rows; row++) {
        for (var col = 0; col < Locations.ruins.cols; col++) {
          final isExit = Locations.ruins.exitAt(col, row) != null;
          final isBank = col < 12 || col >= 28;
          if (isBank && !isExit) {
            expect(Locations.ruins.tileAt(col, row), 9);
          }
        }
      }
      for (var row = 0; row < Locations.ruins.rows; row++) {
        for (var col = 12; col <= 27; col++) {
          expect(
            Locations.ruins.tileAt(col, row),
            row == 0 || row == 7 ? 7 : 11,
          );
        }
      }
      expect(Locations.ruins.outsideGroundRegions, hasLength(2));
      expect(
        Locations.ruins.outsideGroundRegions,
        everyElement(
          predicate<OutsideGroundRegion>((region) => region.tile == 13),
        ),
      );
      expect(
        Locations.ruins.outsideGroundRegions.map(
          (region) => region.maxCol - region.minCol + 1,
        ),
        [14, 14],
      );
      expect(
        Locations.ruins.outsideGroundRegions.map(
          (region) => region.maxRow - region.minRow + 1,
        ),
        [12, 12],
      );
      expect(Locations.ruins.isOutsideGround(-2, -2), isTrue);
      expect(Locations.ruins.isOutsideGround(-1, 9), isTrue);
      expect(Locations.ruins.isOutsideGround(40, -2), isTrue);
      expect(Locations.ruins.isOutsideGround(41, 9), isTrue);
      expect(Locations.ruins.isOutsideGround(-3, 0), isFalse);
      expect(Locations.ruins.isOutsideGround(42, 0), isFalse);
      expect(Locations.ruins.outsideTileAt(-2, 3), 13);
      expect(Locations.ruins.outsideTileAt(40, 3), 13);
      expect(Locations.ruins.outsideTileAt(20, -2), 6);
      expect(Locations.ruins.inBounds(-1, 3), isFalse);
      expect(Locations.ruins.inBounds(40, 3), isFalse);
      expect(Locations.ruins.tileAt(0, 3), 4);
      expect(Locations.ruins.exitAt(0, 3)?.targetId, 'forest');
      expect(Locations.ruins.exitAt(39, 2)?.targetId, 'horse');
      expect(Locations.ruins.exitAt(28, 5)?.targetId, 'kopeechka');
      expect(Locations.ruins.exitAt(28, 6)?.targetId, 'cheburechnaya');
      expect(Locations.ruins.exitAt(28, 5)?.direction, ExitDirection.right);
      expect(Locations.ruins.exitAt(28, 6)?.direction, ExitDirection.right);
      expect(
        Locations.horse.exits.map((exit) => exit.targetId),
        containsAll(<String>['ruins', 'doner', 'college', 'dormitory', 'wb']),
      );
      expect(Locations.horse.cols, 16);
      expect(Locations.horse.rows, 8);
      expect(Locations.horse.outsideTile, 9);
      expect(Locations.horse.tileAt(0, 4), 4);
      expect(Locations.horse.tileAt(5, 0), 4);
      expect(Locations.horse.tileAt(10, 0), 9);
      expect(Locations.horse.tileAt(15, 2), 4);
      expect(Locations.horse.tileAt(15, 5), 4);
      expect(Locations.horse.tileAt(10, 7), 4);
      expect(
        Locations.horse.tiles.expand((row) => row),
        everyElement(isNot(6)),
      );
      // Платформа из камня и дерева убрана: площадка Коня теперь земля
      // с цветами, без каменных/деревянных тайлов (10, 11).
      expect(
        Locations.horse.tiles.expand((row) => row),
        everyElement(isNot(anyOf(10, 11))),
      );
      expect(Locations.ruins.isWalkable(20, 0), isFalse);
      expect(Locations.ruins.isWalkable(20, 7), isFalse);
      expect(Locations.ruins.isWalkable(2, 0), isTrue);
      expect(Locations.ruins.isWalkable(37, 7), isTrue);
      expect(Locations.ruins.isWalkable(0, 3), isTrue);
      expect(Locations.ruins.isWalkable(39, 2), isTrue);
      expect(
        Pathfinding(Locations.ruins).findPath((1, 3), (38, 3)),
        isNotEmpty,
      );
    });

    test('shop interiors return to the Bridge', () {
      expect(Locations.kopeechka.name, 'Копеечка');
      expect(Locations.cheburechnaya.name, 'Чебуречная');
      expect(Locations.doner.name, 'Донер (шаурмечная)');
      expect(Locations.kopeechka.exits.single.targetId, 'ruins');
      expect(Locations.cheburechnaya.exits.single.targetId, 'ruins');
    });

    test('station has rail tiles and a readable decorative layout', () {
      final stationKinds = Locations.meadow.props.map((prop) => prop.kind);
      expect(stationKinds, contains(LocationPropKind.lamp));
      expect(stationKinds, contains(LocationPropKind.bench));
      expect(stationKinds, contains(LocationPropKind.flowerBed));
      expect(stationKinds, contains(LocationPropKind.crate));
      expect(
        Locations.meadow.props.map((prop) => prop.id),
        containsAll(<String>[
          'meadow_lamp_left',
          'meadow_lamp_right',
          'meadow_bench_left',
          'meadow_bench_right',
          'meadow_flower_bed',
          'meadow_crate',
        ]),
      );
      expect(Locations.meadow.isWalkable(8, 1), isTrue);
      expect(Locations.meadow.isWalkable(10, 1), isFalse);
      expect(Locations.meadow.isWalkable(10, 2), isTrue);
      expect(Locations.meadow.isWalkable(8, 2), isTrue);
      expect([
        for (var col = 0; col <= 15; col++) Locations.meadow.tileAt(col, 2),
      ], everyElement(8));
      expect(Locations.meadow.tileAt(5, 4), 10);
      expect(Locations.meadow.tileAt(6, 5), 11);
      expect(
        Locations.meadow.enemies.map((spawn) => spawn.enemyId),
        contains('viktor_korneplod'),
      );
      expect(Locations.forest.tileAt(8, 4), 14);
      expect(Locations.forest.tileAt(14, 8), 13);
      expect(
        Locations.forest.props.map((prop) => prop.id),
        containsAll(<String>[
          'forest_lamp_west',
          'forest_lamp_east',
          'forest_flower_bed_west',
          'forest_flower_bed_east',
          'forest_tree_north_east',
        ]),
      );
      expect(Locations.forest.isWalkable(3, 2), isFalse);
      expect(Locations.forest.isWalkable(9, 3), isFalse);
    });

    test('park bench has a blocking three-tile col footprint', () {
      final bench = Locations.forest.props.singleWhere(
        (prop) => prop.kind == LocationPropKind.bench,
      );

      expect((bench.col, bench.row), (9, 3));
      expect(bench.width, 3);
      expect(bench.height, 1);
      expect(bench.blocksMovement, isTrue);
      expect(
        [for (var col = 8; col <= 12; col++) bench.occupies(col, 3)],
        [false, true, true, true, false],
      );
      expect(
        [
          for (var col = 9; col <= 11; col++)
            Locations.forest.isWalkable(col, 3),
        ],
        [false, false, false],
      );

      // The long edge follows col: every step is screen-right and screen-down.
      final first = IsometricMap.tileToWorld(bench.col, bench.row);
      final last = IsometricMap.tileToWorld(bench.col + 2, bench.row);
      expect(last.x - first.x, IsometricMap.tileWidth);
      expect(last.y - first.y, IsometricMap.tileHeight);
      expect(
        Pathfinding(Locations.forest).findPath(Locations.forest.spawn, (21, 5)),
        isNotEmpty,
      );
      expect(Locations.kopeechka.propById('kopeechka_bench')!.width, 1);
    });

    test(
      'cheburechnaya seating stays one tile and uses its larger variant',
      () {
        final seating = Locations.cheburechnaya.propById('cheburechnaya_table');

        expect(seating, isNotNull);
        expect(seating!.kind, LocationPropKind.bench);
        expect(seating.width, 1);
        expect(seating.height, 1);
        expect(seating.variant, 1);
        expect(seating.blocksMovement, isFalse);
        expect(
          Locations.cheburechnaya.props
              .where((prop) => prop.kind == LocationPropKind.bench)
              .map((prop) => prop.id),
          ['cheburechnaya_table'],
        );
      },
    );

    test('new decorative tiles are walkable and used in locations', () {
      // 12 песок, 13 цветочный луг, 14 гравий, 15 дерево, 16/17 плитка.
      expect(Locations.forest.tileAt(3, 7), 12);
      expect(Locations.forest.isWalkable(3, 7), isTrue);
      expect(Locations.meadow.tileAt(2, 8), 13);
      expect(Locations.meadow.isWalkable(2, 8), isTrue);
      expect(Locations.meadow.tileAt(7, 3), 14);
      expect(Locations.meadow.isWalkable(7, 3), isTrue);
      expect(Locations.doner.tileAt(1, 1), 15);
      expect(Locations.doner.tileAt(3, 1), 16);
      expect(Locations.doner.tileAt(2, 2), 17);
      expect(Locations.doner.isWalkable(1, 1), isTrue);
      expect(Locations.horse.isWalkable(3, 1), isTrue);
      // С Коня можно выйти: путь от точки появления до клетки перехода есть.
      expect(
        Pathfinding(Locations.horse).findPath(Locations.horse.spawn, (0, 3)),
        isNotEmpty,
      );
    });

    test('pathfinding stops at a transition instead of walking through it', () {
      const corridor = LocationDef(
        id: 'corridor',
        name: 'Коридор',
        tiles: [
          [0, 4, 0],
        ],
        spawn: (0, 0),
        exits: [LocationExit(col: 1, row: 0, targetId: 'other')],
      );
      final pathfinding = Pathfinding(corridor);

      expect(pathfinding.findPath((0, 0), (1, 0)), [(1, 0)]);
      expect(pathfinding.findPath((0, 0), (2, 0)), isEmpty);
    });

    testWidgets('published first maps keep their tiles and decorations', (
      tester,
    ) async {
      await LocationAssets.load();

      final station = Locations.byId('meadow')!;
      final park = Locations.byId('forest')!;
      final bridge = Locations.byId('ruins')!;

      expect(station.tileAt(7, 3), 14);
      expect(station.propById('meadow_lamp_left'), isNotNull);
      expect(station.propById('meadow_bench_right'), isNotNull);
      expect(park.tileAt(8, 4), 14);
      expect(park.tileAt(14, 8), 13);
      expect(park.propById('forest_flower_bed_east'), isNotNull);
      for (var row = 1; row <= 6; row++) {
        expect(bridge.tiles[row].sublist(12, 28), everyElement(11));
      }
      expect(bridge.propById('bridge_lamp_15_1'), isNotNull);
      expect(bridge.propById('bridge_lamp_24_6'), isNotNull);
      expect(bridge.propById('bridge_flower_bed_left_5_1'), isNotNull);
    });
  });
}
