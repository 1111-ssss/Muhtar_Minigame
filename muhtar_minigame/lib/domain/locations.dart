import 'location.dart';

/// Тайлы: 0=пол, 1=стена, 2=дорога, 3=дерево, 4=переход, 5=пустота,
/// 6=вода, 7=край, 8=рельсы, 9=земля, 10=камень, 11=дерево.
/// Внутренние id сохранены ради совместимости со старыми сохранениями.
class Locations {
  /// Стартовая локация — вокзал с рельсовой площадкой без состава.
  static const LocationDef meadow = LocationDef(
    id: 'meadow',
    name: 'Вокзал',
    tiles: [
      [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
      [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3],
      [8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8],
      [3, 0, 0, 0, 0, 0, 0, 14, 0, 0, 0, 0, 0, 0, 0, 3],
      [3, 0, 0, 2, 2, 10, 10, 2, 2, 2, 2, 0, 0, 0, 0, 3],
      [3, 0, 0, 2, 2, 10, 11, 2, 2, 2, 2, 0, 0, 0, 0, 3],
      [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4],
      [3, 0, 13, 0, 0, 0, 0, 0, 0, 0, 0, 0, 13, 0, 0, 3],
      [3, 0, 13, 13, 0, 0, 0, 0, 0, 0, 0, 0, 13, 13, 0, 3],
      [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3],
      [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3],
      [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
    ],
    spawn: (7, 8),
    npcs: [NpcSpawn('ariana', 'Ариана', 2, 8)],
    exits: [LocationExit(col: 15, row: 6, targetId: 'forest', arrival: (1, 5))],
    enemies: [
      EnemySpawn('shaurmek', 10, 8),
      EnemySpawn('viktor_korneplod', 13, 4),
    ],
    props: [
      LocationProp(kind: LocationPropKind.tree, col: 1, row: 3, variant: 0),
      LocationProp(kind: LocationPropKind.tree, col: 13, row: 3, variant: 1),
      LocationProp(kind: LocationPropKind.tree, col: 2, row: 9, variant: 2),
      LocationProp(kind: LocationPropKind.tree, col: 12, row: 9, variant: 1),
      LocationProp(kind: LocationPropKind.rock, col: 6, row: 3, variant: 0),
      LocationProp(kind: LocationPropKind.rock, col: 10, row: 3, variant: 1),
      LocationProp(kind: LocationPropKind.bush, col: 4, row: 3, variant: 0),
      LocationProp(kind: LocationPropKind.bush, col: 14, row: 8, variant: 1),
    ],
  );

  /// Длинный парк — первая опасная локация с гопниками.
  static const LocationDef forest = LocationDef(
    id: 'forest',
    name: 'Парк',
    tiles: [
      [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
      [3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 3],
      [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3],
      [3, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 3],
      [3, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 3],
      [4, 11, 11, 2, 2, 2, 10, 2, 2, 2, 2, 2, 2, 10, 2, 2, 2, 2, 2, 2, 2, 4],
      [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3],
      [3, 0, 0, 12, 12, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 3],
      [3, 0, 0, 12, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 3],
      [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
    ],
    spawn: (1, 5),
    npcs: [NpcSpawn('sofia', 'София', 4, 2)],
    enemies: [
      EnemySpawn('gopnik', 4, 4),
      EnemySpawn('gopnik', 11, 2),
      EnemySpawn('gopnik', 17, 6),
    ],
    exits: [
      LocationExit(col: 0, row: 5, targetId: 'meadow', arrival: (14, 6)),
      LocationExit(col: 21, row: 5, targetId: 'ruins', arrival: (1, 3)),
    ],
    props: [
      LocationProp(kind: LocationPropKind.tree, col: 3, row: 2, variant: 0),
      LocationProp(kind: LocationPropKind.tree, col: 8, row: 1, variant: 2),
      LocationProp(kind: LocationPropKind.tree, col: 15, row: 2, variant: 1),
      LocationProp(kind: LocationPropKind.tree, col: 18, row: 7, variant: 0),
      LocationProp(kind: LocationPropKind.tree, col: 5, row: 7, variant: 2),
      LocationProp(kind: LocationPropKind.rock, col: 6, row: 3, variant: 1),
      LocationProp(kind: LocationPropKind.rock, col: 13, row: 6, variant: 2),
      LocationProp(kind: LocationPropKind.rock, col: 11, row: 2, variant: 0),
      LocationProp(
        id: 'forest_search_bush_1',
        kind: LocationPropKind.bush,
        col: 2,
        row: 7,
        variant: 1,
        searchable: true,
      ),
      LocationProp(
        id: 'forest_search_bush_2',
        kind: LocationPropKind.bush,
        col: 10,
        row: 7,
        variant: 0,
        searchable: true,
      ),
      LocationProp(
        id: 'forest_search_bush_sync_async',
        kind: LocationPropKind.bush,
        col: 19,
        row: 3,
        variant: 2,
        searchable: true,
        specialItemId: 'sync_async',
      ),
      LocationProp(
        kind: LocationPropKind.bench,
        col: 9,
        row: 3,
        // Лавочка лежит на трёх последовательных тайлах по оси col (x).
        // Ряд 9..11 идёт по экрану слева-сверху направо-вниз и не перекрывает
        // центральную дорожку парка на rows 4..5.
        width: 3,
        blocksMovement: true,
      ),
    ],
  );

  static const _bridgeBank = <int>[9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9];
  static const _bridgeBankWithExit = <int>[9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9];
  static const _bridgeDeck = <int>[
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];
  static const _bridgeRailing = <int>[
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
    7,
  ];
  static const _bridgeLand = <int>[
    ..._bridgeBank,
    ..._bridgeDeck,
    ..._bridgeBank,
  ];
  static const _bridgeEdge = <int>[
    ..._bridgeBank,
    ..._bridgeRailing,
    ..._bridgeBank,
  ];
  static const _bridgeLeftExit = <int>[
    4,
    ..._bridgeBankWithExit,
    ..._bridgeDeck,
    ..._bridgeBank,
  ];
  static const _bridgeHorseExit = <int>[
    ..._bridgeBank,
    ..._bridgeDeck,
    ..._bridgeBankWithExit,
    4,
  ];
  static const _bridgeShopKopeechka = <int>[
    ..._bridgeBank,
    ..._bridgeDeck,
    4,
    ..._bridgeBankWithExit,
  ];
  static const _bridgeShopCheburechnaya = <int>[
    ..._bridgeBank,
    ..._bridgeDeck,
    4,
    ..._bridgeBankWithExit,
  ];

  /// Мост с травяными площадками и серым центральным пролётом.
  /// Внутренний id `ruins` сохранён для сейвов.
  static const LocationDef ruins = LocationDef(
    id: 'ruins',
    name: 'Мост',
    tiles: [
      _bridgeEdge,
      _bridgeLand,
      _bridgeHorseExit,
      _bridgeLeftExit,
      _bridgeLand,
      _bridgeShopKopeechka,
      _bridgeShopCheburechnaya,
      _bridgeEdge,
    ],
    outsideTile: 6,
    outsideGroundRegions: [
      OutsideGroundRegion(
        minCol: -2,
        maxCol: 11,
        minRow: -2,
        maxRow: 9,
        tile: 13,
      ),
      OutsideGroundRegion(
        minCol: 28,
        maxCol: 41,
        minRow: -2,
        maxRow: 9,
        tile: 13,
      ),
    ],
    spawn: (2, 3),
    npcs: [NpcSpawn('ribka', 'Рибка', 21, 3)],
    exits: [
      LocationExit(col: 0, row: 3, targetId: 'forest', arrival: (20, 5)),
      LocationExit(col: 39, row: 2, targetId: 'horse', arrival: (1, 3)),
      LocationExit(
        col: 28,
        row: 5,
        targetId: 'kopeechka',
        arrival: (1, 3),
        direction: ExitDirection.right,
      ),
      LocationExit(
        col: 28,
        row: 6,
        targetId: 'cheburechnaya',
        arrival: (1, 4),
        direction: ExitDirection.right,
      ),
    ],
  );

  /// Небольшая площадка для телепорта «Конь».
  static const LocationDef horse = LocationDef(
    id: 'horse',
    name: 'Конь',
    tiles: [
      [6, 6, 6, 6, 6, 6, 6, 6],
      [6, 9, 9, 13, 9, 9, 9, 6],
      [6, 9, 9, 9, 9, 13, 9, 6],
      [4, 9, 9, 9, 9, 9, 9, 6],
      [6, 9, 9, 9, 9, 9, 9, 6],
      [6, 6, 6, 6, 6, 6, 6, 6],
    ],
    outsideTile: 6,
    spawn: (1, 3),
    exits: [LocationExit(col: 0, row: 3, targetId: 'ruins', arrival: (38, 2))],
  );

  /// Небольшой интерьер Копеечки в здании у Моста.
  static const LocationDef kopeechka = LocationDef(
    id: 'kopeechka',
    name: 'Копеечка',
    tiles: [
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1],
      [4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 1],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    ],
    spawn: (2, 4),
    npcs: [NpcSpawn('alenka', 'Алёнка', 9, 3)],
    additionalNpcs: [NpcSpawn('malek', 'Малёк', 2, 2)],
    props: [
      LocationProp(
        id: 'kopeechka_counter',
        kind: LocationPropKind.platform,
        col: 2,
        row: 1,
        width: 3,
        blocksMovement: false,
      ),
      LocationProp(
        id: 'kopeechka_shelf',
        kind: LocationPropKind.platform,
        col: 6,
        row: 1,
        width: 3,
        blocksMovement: false,
        variant: 1,
      ),
      LocationProp(
        id: 'kopeechka_bench',
        kind: LocationPropKind.bench,
        col: 4,
        row: 5,
        blocksMovement: false,
      ),
    ],
    exits: [LocationExit(col: 0, row: 3, targetId: 'ruins', arrival: (29, 5))],
  );

  /// Небольшой интерьер Чебуречной в том же здании у Моста.
  static const LocationDef cheburechnaya = LocationDef(
    id: 'cheburechnaya',
    name: 'Чебуречная',
    tiles: [
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1],
      [1, 0, 0, 2, 2, 2, 2, 2, 0, 0, 0, 1],
      [4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1],
      [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
      [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1],
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    ],
    spawn: (8, 4),
    npcs: [NpcSpawn('baba_galya', 'Баба Галя', 7, 3)],
    props: [
      LocationProp(
        id: 'cheburechnaya_counter',
        kind: LocationPropKind.platform,
        col: 3,
        row: 2,
        width: 4,
        blocksMovement: false,
      ),
      LocationProp(
        id: 'cheburechnaya_table',
        kind: LocationPropKind.bench,
        col: 2,
        row: 5,
        blocksMovement: false,
        variant: 1,
      ),
      LocationProp(
        id: 'cheburechnaya_trash_bin',
        kind: LocationPropKind.trashBin,
        col: 8,
        row: 2,
        blocksMovement: false,
        searchable: true,
      ),
    ],
    exits: [LocationExit(col: 0, row: 4, targetId: 'ruins', arrival: (29, 6))],
  );

  static const List<LocationDef> builtIn = [
    meadow,
    forest,
    ruins,
    horse,
    kopeechka,
    cheburechnaya,
  ];

  static final Map<String, LocationDef> _overrides = {};

  /// Applied MuhtarBuild maps replace built-ins by their stable IDs.
  static List<LocationDef> get all => {
    for (final location in builtIn) location.id: location,
    ..._overrides,
  }.values.toList(growable: false);

  static void replaceOverrides(Iterable<LocationDef> locations) {
    _overrides
      ..clear()
      ..addEntries(
        locations.map((location) => MapEntry(location.id, location)),
      );
  }

  static LocationDef? byId(String id) {
    for (final loc in all) {
      if (loc.id == id) return loc;
    }
    return null;
  }

  static LocationProp? propById(String id) {
    for (final location in all) {
      final prop = location.propById(id);
      if (prop != null) return prop;
    }
    return null;
  }
}
