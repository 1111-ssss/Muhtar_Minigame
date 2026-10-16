import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../domain/location.dart';
import '../domain/locations.dart';
import '../domain/game_content.dart';
import '../domain/player_skin.dart';

/// Editable copy of a game location used by MuhtarBuild.
///
/// Dart locations are the built-in defaults. Applied JSON locations override
/// them at game startup; incomplete editor drafts are kept separately.
class BuildMapDocument {
  BuildMapDocument({
    required this.id,
    required this.name,
    required this.tiles,
    required this.spawnCol,
    required this.spawnRow,
    List<BuildEnemySpawn> enemies = const [],
    List<BuildNpcSpawn> npcs = const [],
    List<BuildNpcSpawn> additionalNpcs = const [],
    List<BuildExit> exits = const [],
    List<BuildProp> props = const [],
    this.outsideTile = 5,
    List<BuildGroundRegion> outsideGroundRegions = const [],
  }) : enemies = List.of(enemies),
       npcs = List.of(npcs),
       additionalNpcs = List.of(additionalNpcs),
       exits = List.of(exits),
       props = List.of(props),
       outsideGroundRegions = List.of(outsideGroundRegions);

  factory BuildMapDocument.fromLocation(LocationDef location) {
    return BuildMapDocument(
      id: location.id,
      name: location.name,
      tiles: location.tiles.map(List<int>.from).toList(),
      spawnCol: location.spawn.$1,
      spawnRow: location.spawn.$2,
      enemies: location.enemies
          .map((enemy) => BuildEnemySpawn(enemy.enemyId, enemy.col, enemy.row))
          .toList(),
      npcs: location.npcs
          .map((npc) => BuildNpcSpawn(npc.id, npc.name, npc.col, npc.row))
          .toList(),
      additionalNpcs: location.additionalNpcs
          .map((npc) => BuildNpcSpawn(npc.id, npc.name, npc.col, npc.row))
          .toList(),
      exits: location.exits
          .map(
            (exit) => BuildExit(
              exit.col,
              exit.row,
              exit.targetId,
              exit.arrival?.$1,
              exit.arrival?.$2,
              exit.direction.name,
            ),
          )
          .toList(),
      props: location.props
          .map(
            (prop) => BuildProp(
              id: prop.id,
              kind: prop.kind.name,
              col: prop.col,
              row: prop.row,
              width: prop.width,
              height: prop.height,
              blocksMovement: prop.blocksMovement,
              variant: prop.variant,
              searchable: prop.searchable,
              specialItemId: prop.specialItemId,
              interactionId: prop.interactionId,
            ),
          )
          .toList(),
      outsideTile: location.outsideTile,
      outsideGroundRegions: location.outsideGroundRegions
          .map(
            (region) => BuildGroundRegion(
              region.minCol,
              region.maxCol,
              region.minRow,
              region.maxRow,
              region.tile,
            ),
          )
          .toList(),
    );
  }

  factory BuildMapDocument.fromJson(Map<String, dynamic> json) {
    if (json['format'] != null && json['format'] != 1) {
      throw const FormatException('Неизвестная версия формата карты.');
    }
    final rawTiles = json['tiles'] as List?;
    final parsedTiles =
        rawTiles
            ?.map(
              (row) => (row as List).map((value) {
                if (value is! int) {
                  throw const FormatException(
                    'Код тайла должен быть целым числом.',
                  );
                }
                return value;
              }).toList(),
            )
            .toList() ??
        <List<int>>[];
    final normalizedTiles = _normalizeTiles(parsedTiles);
    final spawn = _intList(json['spawn']);

    return BuildMapDocument(
      id: _string(json['id'], 'new_map'),
      name: _string(json['name'], 'Новая карта'),
      tiles: normalizedTiles,
      spawnCol: spawn.elementAtOrNull(0) ?? 0,
      spawnRow: spawn.elementAtOrNull(1) ?? 0,
      enemies: _list(json['enemies']).map(BuildEnemySpawn.fromJson).toList(),
      npcs: _list(json['npcs']).map(BuildNpcSpawn.fromJson).toList(),
      additionalNpcs: _list(
        json['additionalNpcs'],
      ).map(BuildNpcSpawn.fromJson).toList(),
      exits: _list(json['exits']).map(BuildExit.fromJson).toList(),
      props: _list(json['props']).map(BuildProp.fromJson).toList(),
      outsideTile: (json['outsideTile'] as num?)?.toInt() ?? 5,
      outsideGroundRegions: _list(
        json['outsideGroundRegions'],
      ).map(BuildGroundRegion.fromJson).toList(),
    );
  }

  String id;
  String name;
  List<List<int>> tiles;
  int spawnCol;
  int spawnRow;
  List<BuildEnemySpawn> enemies;
  List<BuildNpcSpawn> npcs;
  List<BuildNpcSpawn> additionalNpcs;
  List<BuildExit> exits;
  List<BuildProp> props;
  int outsideTile;
  List<BuildGroundRegion> outsideGroundRegions;

  int get rows => tiles.length;
  int get cols => tiles.isEmpty ? 0 : tiles.first.length;

  int tileAt(int col, int row) =>
      row >= 0 && row < rows && col >= 0 && col < cols ? tiles[row][col] : 1;

  void setTile(int col, int row, int tile) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return;
    tiles[row][col] = tile;
  }

  List<String> validationErrors() {
    final errors = <String>[];
    if (!isBuildId(id)) errors.add('ID: только латинские буквы, цифры, _ и -.');
    if (name.trim().isEmpty) errors.add('Укажите название карты.');
    if (rows < 1 ||
        cols < 1 ||
        rows > 128 ||
        cols > 128 ||
        tiles.any((row) => row.length != cols)) {
      errors.add('Карта должна быть прямоугольной, от 1×1 до 128×128.');
      return errors;
    }
    if (tiles.expand((row) => row).any((tile) => tile < 0 || tile > 14) ||
        outsideTile < 0 ||
        outsideTile > 14) {
      errors.add('Коды тайлов должны быть от 0 до 14.');
    }
    bool inside(int col, int row) =>
        col >= 0 && col < cols && row >= 0 && row < rows;
    if (!inside(spawnCol, spawnRow) ||
        !toLocation().isWalkable(spawnCol, spawnRow)) {
      errors.add('Точка игрока должна быть на проходимом тайле.');
    }
    final propIds = <String>{};
    for (final prop in props) {
      if (prop.id.isEmpty || !propIds.add(prop.id)) {
        errors.add('Повторяющийся или пустой ID объекта: ${prop.id}.');
      }
      if (!LocationPropKind.values.any((kind) => kind.name == prop.kind)) {
        errors.add('Неизвестный вид объекта: ${prop.kind}.');
      }
      if (prop.width < 1 ||
          prop.height < 1 ||
          prop.width > 128 ||
          prop.height > 128 ||
          !inside(prop.col, prop.row) ||
          !inside(prop.col + prop.width - 1, prop.row + prop.height - 1)) {
        errors.add('Объект ${prop.id} выходит за границы карты.');
      }
    }
    for (final enemy in enemies) {
      if (GameContent.enemyById(enemy.enemyId) == null) {
        errors.add('Неизвестный враг: ${enemy.enemyId}.');
      }
      if (!inside(enemy.col, enemy.row)) {
        errors.add('Враг ${enemy.enemyId} за границами.');
      }
    }
    final npcIds = <String>{};
    for (final npc in [...npcs, ...additionalNpcs]) {
      if (!isBuildId(npc.id) ||
          !npcIds.add(npc.id) ||
          npc.name.trim().isEmpty) {
        errors.add('NPC: нужен уникальный ID и непустое имя (${npc.id}).');
      }
      if (!inside(npc.col, npc.row)) errors.add('NPC ${npc.id} за границами.');
    }
    final exitCells = <(int, int)>{};
    for (final exit in exits) {
      if (!inside(exit.col, exit.row) ||
          tileAt(exit.col, exit.row) != 4 ||
          !exitCells.add((exit.col, exit.row))) {
        errors.add(
          'Переход (${exit.col}, ${exit.row}) должен быть единственным на тайле 4.',
        );
      }
      if (!isBuildId(exit.targetId) ||
          !ExitDirection.values.any(
            (direction) => direction.name == exit.direction,
          )) {
        errors.add('Некорректная цель или направление перехода.');
      }
      if ((exit.arrivalCol == null) != (exit.arrivalRow == null)) {
        errors.add('Укажите обе координаты прибытия перехода.');
      }
    }
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if (tileAt(col, row) == 4 && !exitCells.contains((col, row))) {
          errors.add('Тайл перехода ($col, $row) не имеет цели.');
        }
      }
    }
    for (final region in outsideGroundRegions) {
      if (region.minCol > region.maxCol ||
          region.minRow > region.maxRow ||
          region.tile < 0 ||
          region.tile > 14) {
        errors.add('Некорректная внешняя область карты.');
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'format': 1,
    'id': id,
    'name': name,
    'tiles': tiles,
    'spawn': [spawnCol, spawnRow],
    'enemies': enemies.map((enemy) => enemy.toJson()).toList(),
    'npcs': npcs.map((npc) => npc.toJson()).toList(),
    'additionalNpcs': additionalNpcs.map((npc) => npc.toJson()).toList(),
    'exits': exits.map((exit) => exit.toJson()).toList(),
    'props': props.map((prop) => prop.toJson()).toList(),
    'outsideTile': outsideTile,
    'outsideGroundRegions': outsideGroundRegions
        .map((region) => region.toJson())
        .toList(),
  };

  LocationDef toLocation() => LocationDef(
    id: id,
    name: name,
    tiles: tiles.map(List<int>.unmodifiable).toList(growable: false),
    spawn: (spawnCol, spawnRow),
    enemies: enemies
        .map((enemy) => EnemySpawn(enemy.enemyId, enemy.col, enemy.row))
        .toList(growable: false),
    npcs: npcs
        .map((npc) => NpcSpawn(npc.id, npc.name, npc.col, npc.row))
        .toList(growable: false),
    additionalNpcs: additionalNpcs
        .map((npc) => NpcSpawn(npc.id, npc.name, npc.col, npc.row))
        .toList(growable: false),
    exits: exits
        .map(
          (exit) => LocationExit(
            col: exit.col,
            row: exit.row,
            targetId: exit.targetId,
            arrival: exit.arrivalCol == null || exit.arrivalRow == null
                ? null
                : (exit.arrivalCol!, exit.arrivalRow!),
            direction: ExitDirection.values.firstWhere(
              (direction) => direction.name == exit.direction,
              orElse: () => ExitDirection.auto,
            ),
          ),
        )
        .toList(growable: false),
    props: props
        .map(
          (prop) => LocationProp(
            id: prop.id,
            kind: LocationPropKind.values.firstWhere(
              (kind) => kind.name == prop.kind,
              orElse: () => LocationPropKind.tree,
            ),
            col: prop.col,
            row: prop.row,
            width: prop.width,
            height: prop.height,
            blocksMovement: prop.blocksMovement,
            variant: prop.variant,
            searchable: prop.searchable,
            specialItemId: prop.specialItemId,
            interactionId: prop.interactionId,
          ),
        )
        .toList(growable: false),
    outsideTile: outsideTile,
    outsideGroundRegions: outsideGroundRegions
        .map(
          (region) => OutsideGroundRegion(
            minCol: region.minCol,
            maxCol: region.maxCol,
            minRow: region.minRow,
            maxRow: region.maxRow,
            tile: region.tile,
          ),
        )
        .toList(growable: false),
  );

  static List<List<int>> _normalizeTiles(List<List<int>> input) {
    if (input.isEmpty ||
        input.length > 128 ||
        input.first.isEmpty ||
        input.first.length > 128 ||
        input.any((row) => row.length != input.first.length)) {
      throw const FormatException(
        'Нужна прямоугольная карта размером от 1×1 до 128×128.',
      );
    }
    return input;
  }

  static List<dynamic> _list(Object? value) =>
      value is List ? value : const <dynamic>[];

  static List<int> _intList(Object? value) => value is List
      ? value.whereType<num>().map((number) => number.toInt()).toList()
      : const <int>[];

  static String _string(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}

class BuildEnemySpawn {
  BuildEnemySpawn(this.enemyId, this.col, this.row);

  factory BuildEnemySpawn.fromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return BuildEnemySpawn(
      json['enemyId'] as String? ?? 'gopnik',
      (json['col'] as num?)?.toInt() ?? 0,
      (json['row'] as num?)?.toInt() ?? 0,
    );
  }

  String enemyId;
  int col;
  int row;

  Map<String, dynamic> toJson() => {'enemyId': enemyId, 'col': col, 'row': row};
}

class BuildNpcSpawn {
  BuildNpcSpawn(this.id, this.name, this.col, this.row);

  factory BuildNpcSpawn.fromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return BuildNpcSpawn(
      json['id'] as String? ?? 'npc',
      json['name'] as String? ?? 'NPC',
      (json['col'] as num?)?.toInt() ?? 0,
      (json['row'] as num?)?.toInt() ?? 0,
    );
  }

  String id;
  String name;
  int col;
  int row;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'col': col,
    'row': row,
  };
}

class BuildExit {
  BuildExit(
    this.col,
    this.row,
    this.targetId,
    this.arrivalCol,
    this.arrivalRow,
    this.direction,
  );

  factory BuildExit.fromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final arrival = json['arrival'];
    return BuildExit(
      (json['col'] as num?)?.toInt() ?? 0,
      (json['row'] as num?)?.toInt() ?? 0,
      json['targetId'] as String? ?? '',
      arrival is List && arrival.isNotEmpty
          ? (arrival[0] as num).toInt()
          : null,
      arrival is List && arrival.length > 1
          ? (arrival[1] as num).toInt()
          : null,
      json['direction'] as String? ?? 'auto',
    );
  }

  int col;
  int row;
  String targetId;
  int? arrivalCol;
  int? arrivalRow;
  String direction;

  Map<String, dynamic> toJson() => {
    'col': col,
    'row': row,
    'targetId': targetId,
    if (arrivalCol != null && arrivalRow != null)
      'arrival': [arrivalCol, arrivalRow],
    'direction': direction,
  };
}

class BuildProp {
  BuildProp({
    required this.id,
    required this.kind,
    required this.col,
    required this.row,
    required this.width,
    required this.height,
    required this.blocksMovement,
    required this.variant,
    required this.searchable,
    required this.specialItemId,
    required this.interactionId,
  });

  factory BuildProp.fromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final col = (json['col'] as num?)?.toInt() ?? 0;
    final row = (json['row'] as num?)?.toInt() ?? 0;
    return BuildProp(
      id: json['id'] as String? ?? 'prop_${col}_$row',
      kind: json['kind'] as String? ?? 'tree',
      col: col,
      row: row,
      width: (json['width'] as num?)?.toInt() ?? 1,
      height: (json['height'] as num?)?.toInt() ?? 1,
      blocksMovement: json['blocksMovement'] as bool? ?? true,
      variant: (json['variant'] as num?)?.toInt() ?? 0,
      searchable: json['searchable'] as bool? ?? false,
      specialItemId: json['specialItemId'] as String?,
      interactionId: json['interactionId'] as String?,
    );
  }

  String id;
  String kind;
  int col;
  int row;
  int width;
  int height;
  bool blocksMovement;
  int variant;
  bool searchable;
  String? specialItemId;
  String? interactionId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'col': col,
    'row': row,
    'width': width,
    'height': height,
    'blocksMovement': blocksMovement,
    'variant': variant,
    'searchable': searchable,
    if (specialItemId != null) 'specialItemId': specialItemId,
    if (interactionId != null) 'interactionId': interactionId,
  };
}

class BuildGroundRegion {
  BuildGroundRegion(
    this.minCol,
    this.maxCol,
    this.minRow,
    this.maxRow,
    this.tile,
  );

  factory BuildGroundRegion.fromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return BuildGroundRegion(
      (json['minCol'] as num?)?.toInt() ?? 0,
      (json['maxCol'] as num?)?.toInt() ?? 0,
      (json['minRow'] as num?)?.toInt() ?? 0,
      (json['maxRow'] as num?)?.toInt() ?? 0,
      (json['tile'] as num?)?.toInt() ?? 9,
    );
  }

  int minCol;
  int maxCol;
  int minRow;
  int maxRow;
  int tile;

  Map<String, dynamic> toJson() => {
    'minCol': minCol,
    'maxCol': maxCol,
    'minRow': minRow,
    'maxRow': maxRow,
    'tile': tile,
  };
}

/// Persists map documents inside the project checkout when MuhtarBuild is run
/// from `muhtar_minigame/`.
class BuildMapRepository {
  BuildMapRepository({String? rootPath, String? projectRoot})
    : rootDirectory = Directory(
        rootPath ??
            p.join(projectRoot ?? Directory.current.path, 'muhtar_build'),
      ),
      projectDirectory = Directory(projectRoot ?? Directory.current.path);

  final Directory rootDirectory;
  final Directory projectDirectory;
  final List<String> loadWarnings = [];
  static final Map<String, Future<void>> _loadLocks = {};

  File get appliedFile =>
      File(p.join(projectDirectory.path, 'assets', 'maps', 'locations.json'));

  Directory get mapsDirectory => Directory(p.join(rootDirectory.path, 'maps'));

  Future<List<BuildMapDocument>> loadAll() async {
    final key = rootDirectory.absolute.path;
    final previous = _loadLocks[key];
    final gate = Completer<void>();
    _loadLocks[key] = gate.future;
    if (previous != null) await previous;
    try {
      return await _loadAllUnlocked();
    } finally {
      gate.complete();
      if (identical(_loadLocks[key], gate.future)) _loadLocks.remove(key);
    }
  }

  Future<List<BuildMapDocument>> _loadAllUnlocked() async {
    loadWarnings.clear();
    mapsDirectory.createSync(recursive: true);
    final documents = Locations.builtIn
        .map(BuildMapDocument.fromLocation)
        .toList(growable: true);
    final byId = {for (final document in documents) document.id: document};

    if (appliedFile.existsSync()) {
      final applied = decodeBuildMaps(appliedFile.readAsStringSync());
      for (final document in applied) {
        byId[document.id] = document;
      }
    }

    for (final entity in mapsDirectory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(entity.readAsStringSync());
        if (decoded is! Map) {
          throw const FormatException('Ожидается объект JSON.');
        }
        final document = BuildMapDocument.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        _requireBuildId(document.id);
        byId[document.id] = document;
      } on Object catch (error) {
        loadWarnings.add('${entity.path}: $error');
      }
    }

    return byId.values.toList();
  }

  Future<File> save(BuildMapDocument document) async {
    _requireBuildId(document.id);
    await mapsDirectory.create(recursive: true);
    final file = File(p.join(mapsDirectory.path, '${document.id}.json'));
    return _atomicWrite(
      file,
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert(document.toJson()),
      ),
    );
  }

  /// Publish a validated snapshot consumed by the game's bundled asset loader.
  Future<File> applyToGame(List<BuildMapDocument> maps) async {
    final errors = validateBuildMaps(maps);
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    await appliedFile.parent.create(recursive: true);
    if (await appliedFile.exists()) {
      await _backup(appliedFile, rootDirectory);
    }
    final result = await _atomicWrite(
      appliedFile,
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'format': 1,
          'locations': maps.map((map) => map.toJson()).toList(),
        }),
      ),
    );
    for (final map in maps) {
      await save(map);
    }
    return result;
  }

  Future<void> reset(String id) async {
    _requireBuildId(id);
    final file = File(p.join(mapsDirectory.path, '$id.json'));
    if (await file.exists()) await file.delete();
  }
}

bool isBuildId(String value) =>
    value.length <= 80 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);

void _requireBuildId(String value) {
  if (!isBuildId(value)) throw ArgumentError('Недопустимый ID файла: $value');
}

List<BuildMapDocument> decodeBuildMaps(String source) {
  final value = jsonDecode(source);
  if (value is! Map || value['format'] != 1 || value['locations'] is! List) {
    throw const FormatException(
      'Ожидается MuhtarBuild JSON: format=1, locations=[...].',
    );
  }
  return (value['locations'] as List).map((item) {
    if (item is! Map) {
      throw const FormatException('Локация должна быть объектом JSON.');
    }
    return BuildMapDocument.fromJson(Map<String, dynamic>.from(item));
  }).toList();
}

List<String> validateBuildMaps(List<BuildMapDocument> maps) {
  final errors = <String>[];
  final byId = <String, BuildMapDocument>{};
  for (final map in maps) {
    if (byId.containsKey(map.id)) {
      errors.add('Повторяющийся ID карты: ${map.id}.');
    }
    byId[map.id] = map;
    errors.addAll(map.validationErrors().map((error) => '${map.name}: $error'));
  }
  for (final map in maps) {
    for (final exit in map.exits) {
      final builtIn = Locations.builtIn
          .where((map) => map.id == exit.targetId)
          .firstOrNull;
      final target =
          byId[exit.targetId] ??
          (builtIn == null ? null : BuildMapDocument.fromLocation(builtIn));
      if (target == null) {
        errors.add('${map.name}: отсутствует карта ${exit.targetId}.');
      } else if (exit.arrivalCol != null &&
          exit.arrivalRow != null &&
          !target.toLocation().isWalkable(exit.arrivalCol!, exit.arrivalRow!)) {
        errors.add('${map.name}: точка прибытия в ${target.name} непроходима.');
      }
    }
  }
  return errors;
}

Future<File> _atomicWrite(File destination, List<int> bytes) async {
  await destination.parent.create(recursive: true);
  final temporary = File(
    '${destination.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    return await temporary.rename(destination.path);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

Future<void> _backup(File file, Directory buildDirectory) async {
  final directory = Directory(p.join(buildDirectory.path, 'backups'));
  await directory.create(recursive: true);
  await file.copy(
    p.join(
      directory.path,
      '${DateTime.now().microsecondsSinceEpoch}_${p.basename(file.path)}',
    ),
  );
}

class CharacterDocument {
  CharacterDocument({
    required this.id,
    required this.name,
    required this.portraitKey,
  });

  factory CharacterDocument.fromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return CharacterDocument(
      id: json['id'] as String? ?? 'character',
      name: json['name'] as String? ?? 'Персонаж',
      portraitKey:
          json['portraitKey'] as String? ??
          json['id'] as String? ??
          'character',
    );
  }

  String id;
  String name;
  String portraitKey;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'portraitKey': portraitKey,
  };
}

class CharacterRepository {
  CharacterRepository({String? projectRoot})
    : projectDirectory = Directory(projectRoot ?? Directory.current.path);

  final Directory projectDirectory;

  Directory get portraitsDirectory =>
      Directory(p.join(projectDirectory.path, 'assets', 'portraits'));

  File get metadataFile =>
      File(p.join(projectDirectory.path, 'muhtar_build', 'characters.json'));

  static final defaults = <CharacterDocument>[
    CharacterDocument(id: 'player', name: 'Игрок', portraitKey: 'player'),
    CharacterDocument(id: 'slime', name: 'Слизень', portraitKey: 'slime'),
    CharacterDocument(id: 'gopnik', name: 'Гопник', portraitKey: 'gopnik'),
    CharacterDocument(id: 'shaurmek', name: 'Шаурмек', portraitKey: 'shaurmek'),
    CharacterDocument(
      id: 'viktor_korneplod',
      name: 'Виктор Корнеплод',
      portraitKey: 'viktor_korneplod',
    ),
  ];

  Future<List<CharacterDocument>> loadAll() async {
    portraitsDirectory.createSync(recursive: true);
    final documents = defaults
        .map(
          (document) => CharacterDocument(
            id: document.id,
            name: document.name,
            portraitKey: document.portraitKey,
          ),
        )
        .toList(growable: true);
    final byId = {for (final document in documents) document.id: document};
    for (final enemy in GameContent.enemies) {
      byId[enemy.id] = CharacterDocument(
        id: enemy.id,
        name: enemy.name,
        portraitKey: enemy.id,
      );
    }
    for (final skin in PlayerSkin.catalog) {
      byId[skin.portraitKey] = CharacterDocument(
        id: skin.portraitKey,
        name: skin.name,
        portraitKey: skin.portraitKey,
      );
    }
    final maps = await BuildMapRepository(
      projectRoot: projectDirectory.path,
    ).loadAll();
    for (final map in maps) {
      for (final npc in [...map.npcs, ...map.additionalNpcs]) {
        if (!isBuildId(npc.id)) continue;
        byId[npc.id] = CharacterDocument(
          id: npc.id,
          name: npc.name,
          portraitKey: npc.id,
        );
      }
    }
    if (metadataFile.existsSync()) {
      try {
        final decoded = jsonDecode(metadataFile.readAsStringSync());
        if (decoded is List) {
          for (final item in decoded) {
            final document = CharacterDocument.fromJson(item);
            _requireBuildId(document.portraitKey);
            _requireBuildId(document.id);
            byId[document.id] = document;
          }
        }
      } on Object {
        // Keep default characters available if metadata is incomplete.
      }
    }
    for (final file in portraitsDirectory.listSync()) {
      if (file is! File || p.extension(file.path).toLowerCase() != '.png') {
        continue;
      }
      final id = p.basenameWithoutExtension(file.path);
      if (!isBuildId(id)) continue;
      byId.putIfAbsent(
        id,
        () => CharacterDocument(id: id, name: id, portraitKey: id),
      );
    }
    return byId.values.toList();
  }

  Future<void> saveMetadata(Iterable<CharacterDocument> documents) async {
    await metadataFile.parent.create(recursive: true);
    await metadataFile.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(documents.map((document) => document.toJson()).toList()),
    );
  }

  File portraitFile(CharacterDocument document) {
    _requireBuildId(document.portraitKey);
    return File(p.join(portraitsDirectory.path, '${document.portraitKey}.png'));
  }

  Future<File> savePng(CharacterDocument document, Uint8List bytes) async {
    final destination = portraitFile(document);
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 33 ||
        bytes.length > 32 * 1024 * 1024 ||
        !signature.asMap().entries.every((e) => bytes[e.key] == e.value)) {
      throw const FormatException('Некорректный PNG-портрет.');
    }
    if (await destination.exists()) {
      await _backup(
        destination,
        Directory(p.join(projectDirectory.path, 'muhtar_build')),
      );
    }
    return _atomicWrite(destination, bytes);
  }

  Future<File> importPng({
    required CharacterDocument document,
    required String sourcePath,
  }) async {
    final source = File(sourcePath.trim());
    if (!await source.exists()) {
      throw ArgumentError('Файл не найден: ${source.path}');
    }
    if (p.extension(source.path).toLowerCase() != '.png') {
      throw ArgumentError(
        'Muhtar использует PNG-портреты. Выберите файл .png.',
      );
    }
    await portraitsDirectory.create(recursive: true);
    return savePng(document, await source.readAsBytes());
  }
}
