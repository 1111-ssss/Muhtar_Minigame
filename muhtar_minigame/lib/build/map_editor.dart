import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/location.dart';
import '../domain/locations.dart';
import 'build_models.dart';
import 'map_canvas.dart';

enum _Tool {
  inspect('Выбор', Icons.ads_click),
  paint('Кисть', Icons.brush_outlined),
  move('Перемещение', Icons.open_with),
  spawn('Игрок', Icons.person_pin_circle_outlined),
  prop('Объект', Icons.park_outlined),
  enemy('Враг', Icons.sports_martial_arts),
  npc('NPC', Icons.person_outline),
  additionalNpc('Сюжетный NPC', Icons.person_add_alt),
  exit('Переход', Icons.exit_to_app),
  erase('Удаление', Icons.delete_sweep_outlined);

  const _Tool(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _History {
  final undo = <String>[];
  final redo = <String>[];
}

enum _MoveKind { spawn, prop, enemy, npc, additionalNpc, exit }

class _MoveTarget {
  const _MoveTarget(this.kind, this.entity);

  final _MoveKind kind;
  final Object entity;
}

String _snapshot(BuildMapDocument map) => jsonEncode(map.toJson());
BuildMapDocument _restore(String value) => BuildMapDocument.fromJson(
  Map<String, dynamic>.from(jsonDecode(value) as Map),
);

/// MuhtarBuild's body-only, self-contained map editor.
class MapEditor extends StatefulWidget {
  const MapEditor({super.key, required this.repository});
  final BuildMapRepository repository;

  @override
  MapEditorState createState() => MapEditorState();
}

class MapEditorState extends State<MapEditor> {
  bool get hasUnsavedChanges => _maps.any(_dirty);
  final _maps = <BuildMapDocument>[];
  final _saved = <String, String>{};
  final _histories = <String, _History>{};
  final _templates = <_Tool, Map<String, dynamic>>{};
  String? _selectedId;
  String? _loadError;
  String? _strokeBefore;
  bool _loading = true;
  bool _busy = false;
  bool _dialogOpen = false;
  bool _panMode = false;
  bool _grid = true;
  bool _collision = false;
  bool _labels = true;
  int _revision = 0;
  int _tile = 0;
  _Tool _tool = _Tool.paint;
  (int, int)? _selectedCell;
  _MoveTarget? _moveTarget;

  BuildMapDocument? get _document {
    for (final map in _maps) {
      if (map.id == _selectedId) return map;
    }
    return null;
  }

  bool _dirty(BuildMapDocument map) => _saved[map.id] != _snapshot(map);
  _History get _history => _histories.putIfAbsent(_selectedId!, _History.new);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded = await widget.repository.loadAll();
      if (!mounted) return;
      final byId = {
        for (final location in Locations.all)
          location.id: BuildMapDocument.fromLocation(location),
        for (final map in loaded) map.id: _restore(_snapshot(map)),
      };
      setState(() {
        _maps
          ..clear()
          ..addAll(byId.values);
        _saved
          ..clear()
          ..addEntries(_maps.map((m) => MapEntry(m.id, _snapshot(m))));
        _histories.clear();
        _selectedId = _maps.firstOrNull?.id;
        _loading = false;
        _revision++;
      });
      if (widget.repository.loadWarnings.isNotEmpty) {
        _message(
          'Некоторые черновики не загружены. Файлы не изменены:\n'
          '${widget.repository.loadWarnings.join('\n')}',
          error: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$error';
      });
      _message('Не удалось загрузить карты: $error', error: true);
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFF873B46) : null,
        duration: Duration(seconds: error ? 8 : 4),
        showCloseIcon: true,
      ),
    );
  }

  void _record(String before) {
    final map = _document;
    if (map == null || before == _snapshot(map)) return;
    final history = _history;
    history.undo.add(before);
    if (history.undo.length > 60) history.undo.removeAt(0);
    history.redo.clear();
  }

  void _change(VoidCallback mutate) {
    if (_busy || _document == null) return;
    _endStroke();
    final before = _snapshot(_document!);
    setState(() {
      mutate();
      _record(before);
      _revision++;
    });
  }

  void _endStroke() {
    final before = _strokeBefore;
    _strokeBefore = null;
    if (before != null && mounted) {
      setState(() => _record(before));
    }
    _moveTarget = null;
  }

  void _undo({bool redo = false}) {
    _endStroke();
    if (_busy || _document == null) return;
    final from = redo ? _history.redo : _history.undo;
    final to = redo ? _history.undo : _history.redo;
    if (from.isEmpty) return;
    setState(() {
      to.add(_snapshot(_document!));
      final index = _maps.indexOf(_document!);
      _maps[index] = _restore(from.removeLast());
      _revision++;
      _clampSelection();
    });
  }

  void _clampSelection() {
    final cell = _selectedCell;
    final map = _document;
    if (cell != null &&
        map != null &&
        (cell.$1 >= map.cols || cell.$2 >= map.rows)) {
      _selectedCell = null;
    }
  }

  Future<bool> _save() async {
    _endStroke();
    final map = _document;
    if (_busy || map == null) return false;
    final copy = _restore(_snapshot(map));
    setState(() => _busy = true);
    try {
      final file = await widget.repository.save(copy);
      if (!mounted) return false;
      setState(() => _saved[copy.id] = _snapshot(copy));
      _message('Черновик сохранён: ${file.path}');
      return true;
    } catch (error) {
      _message('Не удалось сохранить «${map.name}»: $error', error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmLeave() async {
    _endStroke();
    final map = _document;
    if (map == null || !_dirty(map)) return true;
    final result = await _editorDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Несохранённый черновик'),
        content: Text(
          'В карте «${map.name}» есть изменения. '
          'Можно сохранить их на диск или оставить в памяти редактора.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Отбросить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('Оставить в памяти'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (result == 'save') return _save();
    if (result == 'discard') {
      setState(() {
        final saved = _saved[map.id];
        final index = _maps.indexOf(map);
        if (saved == null) {
          _maps.removeAt(index);
          _selectedId = _maps.firstOrNull?.id;
        } else {
          _maps[index] = _restore(saved);
        }
        _histories.remove(map.id);
        _revision++;
      });
      return true;
    }
    return result == 'keep';
  }

  Future<void> _switchMap(String? id) async {
    if (_busy || id == null || id == _selectedId) return;
    if (!await _confirmLeave() || !mounted) return;
    setState(() {
      _selectedId = id;
      _selectedCell = null;
      _revision++;
    });
  }

  List<String> _errorsFor(BuildMapDocument map) {
    final errors = <String>[...map.validationErrors()];
    if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(map.id)) {
      errors.add(
        'ID: латинская буква, затем a–z, 0–9, _ или -, до 64 символов.',
      );
    }
    if (map.name.trim().isEmpty) errors.add('Название не должно быть пустым.');
    if (map.cols < 1 || map.rows < 1 || map.cols > 128 || map.rows > 128) {
      errors.add('Размер карты должен быть от 1×1 до 128×128.');
    }
    final exitCells = {for (final exit in map.exits) (exit.col, exit.row)};
    for (var r = 0; r < map.rows; r++) {
      for (var c = 0; c < map.tiles[r].length; c++) {
        if (map.tiles[r][c] == 4 && !exitCells.contains((c, r))) {
          errors.add('Тайл перехода ($c, $r) не связан с выходом.');
        }
      }
    }
    for (final exit in map.exits) {
      final target = exit.targetId == map.id
          ? map
          : _maps.where((m) => m.id == exit.targetId).firstOrNull;
      if (target == null) {
        errors.add(
          'Выход (${exit.col}, ${exit.row}): карта «${exit.targetId}» не найдена.',
        );
      } else if (exit.arrivalCol != null && exit.arrivalRow != null) {
        final c = exit.arrivalCol!;
        final r = exit.arrivalRow!;
        if (c < 0 || r < 0 || c >= target.cols || r >= target.rows) {
          errors.add(
            'Выход (${exit.col}, ${exit.row}): точка прибытия вне «${target.name}».',
          );
        } else if (mapCellBlocked(target, c, r)) {
          errors.add(
            'Выход (${exit.col}, ${exit.row}): точка прибытия заблокирована.',
          );
        }
      }
    }
    return errors.toSet().toList();
  }

  Future<void> _showErrors(Map<String, List<String>> errors) =>
      _editorDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Исправьте карты перед применением'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Проверены все черновики, включая изменения в памяти.',
                  ),
                  for (final entry in errors.entries) ...[
                    const SizedBox(height: 16),
                    Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final error in entry.value)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text('• $error'),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('К редактированию'),
            ),
          ],
        ),
      );

  Future<void> _apply() async {
    if (_busy) return;
    _endStroke();
    final errors = <String, List<String>>{};
    for (final map in _maps) {
      final list = _errorsFor(map);
      if (list.isNotEmpty) errors['${map.name} (${map.id})'] = list;
    }
    if (errors.isNotEmpty) {
      await _showErrors(errors);
      return;
    }
    final confirmed = await _editorDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Применить все карты к игре?'),
        content: Text(
          'Будут сохранены и применены все ${_maps.length} карт: '
          'встроенные и пользовательские, включая несохранённые изменения. '
          'Для запущенной игры может потребоваться перезапуск.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить и применить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final copies = _maps.map((m) => _restore(_snapshot(m))).toList();
    setState(() => _busy = true);
    try {
      for (final map in copies) {
        await widget.repository.save(map);
        if (!mounted) return;
        setState(() => _saved[map.id] = _snapshot(map));
      }
      final file = await widget.repository.applyToGame(copies);
      _message('Применено карт: ${copies.length}. Файл игры: ${file.path}');
    } catch (error) {
      _message(
        'Не удалось применить карты: $error. '
        'Уже сохранённые черновики доступны на диске.',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createMap() async {
    if (_busy) return;
    final created = await _editorDialog<BuildMapDocument>(
      context: context,
      builder: (_) => _NewMapDialog(existing: _maps),
    );
    if (created == null || !mounted || !await _confirmLeave() || !mounted) {
      return;
    }
    setState(() {
      _maps.add(created);
      _selectedId = created.id;
      _selectedCell = null;
      _revision++;
    });
  }

  Future<void> _jsonDialog() async {
    _endStroke();
    final map = _document;
    if (map == null || _busy) return;
    final edited = await _editorDialog<BuildMapDocument>(
      context: context,
      builder: (_) => _JsonMapDialog(document: map, validate: _errorsFor),
    );
    if (edited == null || !mounted) return;
    _change(() {
      _maps[_maps.indexOf(map)] = edited;
      _clampSelection();
    });
  }

  void _clearExitTile(BuildMapDocument map, int col, int row) {
    if (!map.exits.any((e) => e.col == col && e.row == row) &&
        mapEditorTileAt(map, col, row) == 4) {
      map.setTile(col, row, 0);
    }
  }

  void _paintCell(int col, int row) {
    final map = _document!;
    if (row >= map.rows || col >= map.tiles[row].length) {
      _message(
        'В матрице нет этой клетки. Исправьте размер карты в JSON.',
        error: true,
      );
      return;
    }
    map.setTile(col, row, _tile);
    if (_tile != 4) {
      map.exits = map.exits.where((e) => e.col != col || e.row != row).toList();
    } else if (!map.exits.any((e) => e.col == col && e.row == row)) {
      final target =
          _templates[_Tool.exit]?['targetId'] as String? ??
          _maps.where((m) => m.id != map.id).firstOrNull?.id ??
          map.id;
      map.exits = [
        ...map.exits,
        BuildExit(col, row, target, null, null, 'auto'),
      ];
    }
  }

  _MoveTarget? _moveTargetAt(BuildMapDocument map, int col, int row) {
    if (map.spawnCol == col && map.spawnRow == row) {
      return _MoveTarget(_MoveKind.spawn, map);
    }
    for (final prop in map.props.reversed) {
      if (mapPropContains(prop, col, row)) {
        return _MoveTarget(_MoveKind.prop, prop);
      }
    }
    for (final enemy in map.enemies.reversed) {
      if (enemy.col == col && enemy.row == row) {
        return _MoveTarget(_MoveKind.enemy, enemy);
      }
    }
    for (final npc in map.additionalNpcs.reversed) {
      if (npc.col == col && npc.row == row) {
        return _MoveTarget(_MoveKind.additionalNpc, npc);
      }
    }
    for (final npc in map.npcs.reversed) {
      if (npc.col == col && npc.row == row) {
        return _MoveTarget(_MoveKind.npc, npc);
      }
    }
    for (final exit in map.exits.reversed) {
      if (exit.col == col && exit.row == row) {
        return _MoveTarget(_MoveKind.exit, exit);
      }
    }
    return null;
  }

  void _beginMove(BuildMapDocument map, int col, int row) {
    _moveTarget = _moveTargetAt(map, col, row);
    if (_moveTarget == null) {
      _message(
        'В этой клетке нет сущности. Перемещать можно игрока, объекты, NPC, врагов и переходы.',
      );
    }
  }

  bool _moveTo(BuildMapDocument map, int col, int row) {
    final target = _moveTarget;
    if (target == null ||
        col < 0 ||
        row < 0 ||
        col >= map.cols ||
        row >= map.rows) {
      return false;
    }
    switch (target.kind) {
      case _MoveKind.spawn:
        map.spawnCol = col;
        map.spawnRow = row;
      case _MoveKind.prop:
        final prop = target.entity as BuildProp;
        if (col + prop.width > map.cols || row + prop.height > map.rows) {
          return false;
        }
        prop.col = col;
        prop.row = row;
      case _MoveKind.enemy:
        final enemy = target.entity as BuildEnemySpawn;
        enemy.col = col;
        enemy.row = row;
      case _MoveKind.npc:
        final npc = target.entity as BuildNpcSpawn;
        npc.col = col;
        npc.row = row;
      case _MoveKind.additionalNpc:
        final npc = target.entity as BuildNpcSpawn;
        npc.col = col;
        npc.row = row;
      case _MoveKind.exit:
        final exit = target.entity as BuildExit;
        if (map.exits.any(
          (other) => other != exit && other.col == col && other.row == row,
        )) {
          return false;
        }
        if (exit.col != col || exit.row != row) {
          map.setTile(exit.col, exit.row, 0);
          exit.col = col;
          exit.row = row;
          map.setTile(col, row, 4);
        }
    }
    return true;
  }

  void _visitCell(int col, int row, bool first) {
    if (_busy || _dialogOpen || _document == null) return;
    final map = _document!;
    setState(() => _selectedCell = (col, row));
    if (_tool == _Tool.inspect) return;
    if (_tool == _Tool.move) {
      if (first) {
        _beginMove(map, col, row);
      } else if (_moveTo(map, col, row)) {
        setState(() => _selectedCell = (col, row));
        _revision++;
      }
      return;
    }
    if (_tool == _Tool.paint || _tool == _Tool.spawn || _tool == _Tool.erase) {
      setState(() {
        if (_tool == _Tool.paint) _paintCell(col, row);
        if (_tool == _Tool.spawn) {
          map.spawnCol = col;
          map.spawnRow = row;
        }
        if (_tool == _Tool.erase) {
          map.props = map.props
              .where((p) => !mapPropContains(p, col, row))
              .toList();
          map.enemies = map.enemies
              .where((e) => e.col != col || e.row != row)
              .toList();
          map.npcs = map.npcs
              .where((n) => n.col != col || n.row != row)
              .toList();
          map.additionalNpcs = map.additionalNpcs
              .where((n) => n.col != col || n.row != row)
              .toList();
          map.exits = map.exits
              .where((e) => e.col != col || e.row != row)
              .toList();
          _clearExitTile(map, col, row);
        }
        _revision++;
      });
    } else if (first) {
      _editEntity(_tool, col, row);
    }
  }

  Future<void> _editEntity(
    _Tool tool,
    int col,
    int row, {
    Object? existing,
  }) async {
    final map = _document;
    if (map == null || _dialogOpen || _busy) return;
    _endStroke();
    _dialogOpen = true;
    try {
      final result = await _editorDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _EntityDialog(
          tool: tool,
          map: map,
          maps: _maps,
          col: col,
          row: row,
          existing: existing,
          template: _templates[tool],
        ),
      );
      if (result == null || !mounted) return;
      _templates[tool] = result;
      _change(() {
        switch (tool) {
          case _Tool.prop:
            final prop = BuildProp.fromJson(result);
            map.props = [...map.props];
            if (existing is BuildProp) {
              map.props[map.props.indexOf(existing)] = prop;
            } else {
              map.props.add(prop);
            }
          case _Tool.enemy:
            final enemy = BuildEnemySpawn.fromJson(result);
            map.enemies = [...map.enemies];
            if (existing is BuildEnemySpawn) {
              map.enemies[map.enemies.indexOf(existing)] = enemy;
            } else {
              map.enemies.add(enemy);
            }
          case _Tool.npc:
          case _Tool.additionalNpc:
            final npc = BuildNpcSpawn.fromJson(result);
            final list = [
              ...(tool == _Tool.npc ? map.npcs : map.additionalNpcs),
            ];
            if (existing is BuildNpcSpawn) {
              list[list.indexOf(existing)] = npc;
            } else {
              list.add(npc);
            }
            if (tool == _Tool.npc) {
              map.npcs = list;
            } else {
              map.additionalNpcs = list;
            }
          case _Tool.exit:
            final exit = BuildExit.fromJson(result);
            // Exactly one exit per cell; replacing its record retains tile 4.
            map.exits =
                map.exits
                    .where(
                      (e) =>
                          e != existing &&
                          (e.col != exit.col || e.row != exit.row),
                    )
                    .toList()
                  ..add(exit);
            if (existing is BuildExit) {
              _clearExitTile(map, existing.col, existing.row);
            }
            map.setTile(exit.col, exit.row, 4);
          default:
            break;
        }
        _selectedCell = (result['col'] as int, result['row'] as int);
      });
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _editSpawn() async {
    final map = _document!;
    final form = GlobalKey<FormState>();
    var col = map.spawnCol;
    var row = map.spawnRow;
    final result = await _editorDialog<(int, int)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Точка появления игрока'),
        content: SizedBox(
          width: 320,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: '$col',
                  decoration: const InputDecoration(
                    labelText: 'Столбец (с нуля)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed < 0 || parsed >= map.cols) {
                      return 'Столбец: 0…${map.cols - 1}';
                    }
                    col = parsed;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '$row',
                  decoration: const InputDecoration(
                    labelText: 'Строка (с нуля)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed < 0 || parsed >= map.rows) {
                      return 'Строка: 0…${map.rows - 1}';
                    }
                    if (mapCellBlocked(map, col, parsed)) {
                      return 'Клетка заблокирована';
                    }
                    row = parsed;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text('Точка должна находиться на проходимой клетке.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              Navigator.pop(context, (col, row));
            },
            child: const Text('Установить'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      _change(() {
        map.spawnCol = result.$1;
        map.spawnRow = result.$2;
      });
    }
  }

  Widget _action(String tooltip, IconData icon, VoidCallback? onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
      );

  Widget _toolbar(BuildMapDocument map) {
    final builtInIds = Locations.all.map((l) => l.id).toSet();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 290,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Локация / черновик',
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('map-location'),
                  value: _selectedId,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    for (final item in _maps)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          '${_dirty(item) ? '● ' : ''}${item.name} '
                          '${builtInIds.contains(item.id) ? '• встроенная' : '• своя'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy ? null : _switchMap,
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Создать пустую карту с уникальным ID',
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _createMap,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Новая карта'),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _action(
                'Отменить • Ctrl+Z',
                Icons.undo,
                !_busy && _history.undo.isNotEmpty ? _undo : null,
              ),
              _action(
                'Повторить • Ctrl+Shift+Z / Ctrl+Y',
                Icons.redo,
                !_busy && _history.redo.isNotEmpty
                    ? () => _undo(redo: true)
                    : null,
              ),
              _action(
                'Полный JSON: метаданные, импорт и экспорт',
                Icons.data_object,
                _busy ? null : _jsonDialog,
              ),
            ],
          ),
          Tooltip(
            message: 'Сохранить выбранный черновик на диск • Ctrl+S',
            child: FilledButton.tonalIcon(
              key: const Key('save-map'),
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Сохранить черновик'),
            ),
          ),
          Tooltip(
            message: 'Проверить, сохранить и применить все карты к игре',
            child: FilledButton.icon(
              key: const Key('apply-maps'),
              onPressed: _busy ? null : _apply,
              icon: const Icon(Icons.publish_outlined, size: 18),
              label: const Text('Применить к игре'),
            ),
          ),
          Text(
            _dirty(map) ? '● Есть изменения' : '✓ Черновик сохранён',
            style: TextStyle(
              fontSize: 12,
              color: _dirty(map)
                  ? const Color(0xFFFFD28C)
                  : const Color(0xFF8BD6B4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewToolbar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message:
              'Обзор отключает рисование и включает панорамирование и масштаб',
          child: FilterChip(
            label: Text(_panMode ? 'Перемещение карты' : 'Редактирование'),
            avatar: Icon(
              _panMode ? Icons.pan_tool_outlined : Icons.edit_outlined,
              size: 17,
            ),
            selected: _panMode,
            onSelected: (value) {
              _endStroke();
              setState(() => _panMode = value);
            },
          ),
        ),
        FilterChip(
          label: const Text('Сетка'),
          selected: _grid,
          onSelected: (value) => setState(() => _grid = value),
        ),
        Tooltip(
          message: 'Красная штриховка: непроходимые тайлы и объекты',
          child: FilterChip(
            label: const Text('Коллизии'),
            selected: _collision,
            onSelected: (value) => setState(() => _collision = value),
          ),
        ),
        FilterChip(
          label: const Text('Подписи'),
          selected: _labels,
          onSelected: (value) => setState(() => _labels = value),
        ),
        const Text(
          'И — игрок  •  В — враг  •  Н / Н+ — NPC  •  О — объект  •  ↗ — выход',
          style: TextStyle(fontSize: 12, color: Color(0xFFB1BED1)),
        ),
      ],
    ),
  );

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _tools() => _section(
    'ИНСТРУМЕНТЫ',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tool in _Tool.values)
              Tooltip(
                message: tool == _Tool.erase
                    ? 'Удалить все объекты, NPC, врагов и выходы в клетке; игрок и земля сохраняются'
                    : '${tool.label}: выберите инструмент, затем нажмите на клетку',
                child: ChoiceChip(
                  avatar: Icon(tool.icon, size: 17),
                  label: Text(tool.label),
                  selected: _tool == tool,
                  onSelected: (_) {
                    _endStroke();
                    setState(() {
                      _tool = tool;
                      _panMode = false;
                    });
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(switch (_tool) {
          _Tool.paint =>
            'Протяните кисть по карте. Один штрих — один шаг истории.',
          _Tool.move =>
            'Зажмите сущность и протяните её в другую клетку. Объекты сохраняют размер.',
          _Tool.spawn =>
            'Нажмите на клетку для переноса игрока. Коллизии видны отдельным слоем.',
          _Tool.inspect =>
            'Выберите клетку: её тайл и содержимое появятся ниже.',
          _Tool.erase =>
            'Удаляет всё содержимое клетки, включая целые объекты, которые её занимают.',
          _ => 'Нажмите на клетку, заполните форму и подтвердите размещение.',
        }, style: const TextStyle(fontSize: 12, color: Color(0xFFAFBED2))),
      ],
    ),
  );

  Widget _palette() => _section(
    'ТАЙЛЫ • 15 ТИПОВ',
    Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var i = 0; i < mapTileNames.length; i++)
          Tooltip(
            message:
                '$i — ${mapTileNames[i]}${i == 4 ? '. Автоматически создаёт выход; цель меняется в инспекторе.' : ''}',
            child: ChoiceChip(
              avatar: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: mapTileColors[i],
                  border: Border.all(color: Colors.white38),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              label: Text('$i ${mapTileNames[i]}'),
              selected: _tile == i && _tool == _Tool.paint,
              onSelected: (_) {
                _endStroke();
                setState(() {
                  _tile = i;
                  _tool = _Tool.paint;
                  _panMode = false;
                });
              },
            ),
          ),
      ],
    ),
  );

  Widget _entityRow(
    String title,
    _Tool tool,
    Object entity,
    int col,
    int row,
    VoidCallback remove,
  ) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF253141),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
            _action(
              'Изменить: $title',
              Icons.edit_outlined,
              () => _editEntity(tool, col, row, existing: entity),
            ),
            _action(
              'Удалить: $title',
              Icons.delete_outline,
              () => _change(remove),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _inspector(BuildMapDocument map) {
    final cell = _selectedCell;
    if (cell == null) {
      return _section(
        'ИНСПЕКТОР КЛЕТКИ',
        const Text('Выберите клетку на карте.', style: TextStyle(fontSize: 12)),
      );
    }
    final col = cell.$1;
    final row = cell.$2;
    final tile = mapEditorTileAt(map, col, row);
    return _section(
      'КЛЕТКА ($col, $row)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            mapCellBlocked(map, col, row) ? 'Непроходима' : 'Проходима',
            style: TextStyle(
              fontSize: 12,
              color: mapCellBlocked(map, col, row)
                  ? const Color(0xFFFF9BA8)
                  : const Color(0xFF8BD6B4),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey('cell-$col-$row-$tile-$_revision'),
            initialValue: tile >= 0 && tile < mapTileNames.length ? tile : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Тип тайла'),
            items: [
              for (var i = 0; i < mapTileNames.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('$i — ${mapTileNames[i]}'),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              _change(() {
                final old = _tile;
                _tile = value;
                _paintCell(col, row);
                _tile = old;
              });
            },
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => _change(() {
              map.spawnCol = col;
              map.spawnRow = row;
            }),
            icon: const Icon(Icons.person_pin_circle_outlined, size: 18),
            label: Text(
              map.spawnCol == col && map.spawnRow == row
                  ? 'Игрок появляется здесь'
                  : 'Поместить игрока сюда',
            ),
          ),
          for (final prop in map.props.where(
            (p) => mapPropContains(p, col, row),
          ))
            _entityRow(
              'Объект: ${prop.id}\n${_propNames[prop.kind] ?? prop.kind} '
              '• ${prop.width}×${prop.height}',
              _Tool.prop,
              prop,
              prop.col,
              prop.row,
              () => map.props = map.props.where((p) => p != prop).toList(),
            ),
          for (final enemy in map.enemies.where(
            (e) => e.col == col && e.row == row,
          ))
            _entityRow(
              'Враг: ${enemy.enemyId}',
              _Tool.enemy,
              enemy,
              col,
              row,
              () => map.enemies = map.enemies.where((e) => e != enemy).toList(),
            ),
          for (final npc in map.npcs.where((n) => n.col == col && n.row == row))
            _entityRow(
              'NPC: ${npc.name}\n${npc.id}',
              _Tool.npc,
              npc,
              col,
              row,
              () => map.npcs = map.npcs.where((n) => n != npc).toList(),
            ),
          for (final npc in map.additionalNpcs.where(
            (n) => n.col == col && n.row == row,
          ))
            _entityRow(
              'Сюжетный NPC: ${npc.name}\n${npc.id}',
              _Tool.additionalNpc,
              npc,
              col,
              row,
              () => map.additionalNpcs = map.additionalNpcs
                  .where((n) => n != npc)
                  .toList(),
            ),
          for (final exit in map.exits.where(
            (e) => e.col == col && e.row == row,
          ))
            _entityRow(
              'Выход → ${exit.targetId}',
              _Tool.exit,
              exit,
              col,
              row,
              () {
                map.exits = map.exits.where((e) => e != exit).toList();
                _clearExitTile(map, col, row);
              },
            ),
          const SizedBox(height: 6),
          const Text(
            'Удаление последнего выхода заменяет тайл 4 на траву (0). '
            'Закрашивание выхода другим тайлом удаляет его связь.',
            style: TextStyle(fontSize: 12, color: Color(0xFFAFBED2)),
          ),
        ],
      ),
    );
  }

  Widget _mapInfo(BuildMapDocument map) => _section(
    'ПАРАМЕТРЫ КАРТЫ',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          '${map.name}\nID: ${map.id}\n${map.cols}×${map.rows} клеток',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          'Объекты: ${map.props.length} • враги: ${map.enemies.length}\n'
          'NPC: ${map.npcs.length} + ${map.additionalNpcs.length} • выходы: ${map.exits.length}',
          style: const TextStyle(fontSize: 12, color: Color(0xFFAFBED2)),
        ),
        TextButton.icon(
          onPressed: _editSpawn,
          icon: const Icon(Icons.my_location, size: 18),
          label: Text('Спавн игрока: ${map.spawnCol}, ${map.spawnRow}'),
        ),
        DropdownButtonFormField<int>(
          key: ValueKey('outside-${map.id}-${map.outsideTile}'),
          initialValue:
              map.outsideTile >= 0 && map.outsideTile < mapTileNames.length
              ? map.outsideTile
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Фон за границами карты',
          ),
          items: [
            for (var i = 0; i < mapTileNames.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text('$i — ${mapTileNames[i]}'),
              ),
          ],
          onChanged: (value) {
            if (value != null) _change(() => map.outsideTile = value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Внешних зон земли: ${map.outsideGroundRegions.length}. '
          'Название, размер и все метаданные доступны в JSON.',
          style: const TextStyle(fontSize: 12, color: Color(0xFFAFBED2)),
        ),
        OutlinedButton.icon(
          onPressed: _jsonDialog,
          icon: const Icon(Icons.data_object, size: 18),
          label: const Text('JSON / импорт / экспорт'),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );

  Widget _sidePanel(BuildMapDocument map, {required bool scroll}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tools(),
        const Divider(),
        _palette(),
        const Divider(),
        _inspector(map),
        const Divider(),
        _mapInfo(map),
      ],
    );
    return ColoredBox(
      color: const Color(0xFF1B2330),
      child: scroll ? SingleChildScrollView(child: content) : content,
    );
  }

  Widget _canvas(BuildMapDocument map) => MapCanvas(
    key: const Key('map-canvas'),
    document: map,
    revision: _revision,
    panMode: _panMode,
    showGrid: _grid,
    showCollision: _collision,
    showLabels: _labels,
    selected: _selectedCell,
    onStrokeStart: () {
      if (_busy || _dialogOpen) return;
      _endStroke();
      _strokeBefore = _snapshot(map);
    },
    onCell: _visitCell,
    onStrokeEnd: _endStroke,
  );

  Widget _workspace(BuildMapDocument map) => LayoutBuilder(
    builder: (context, constraints) {
      final header = [
        _toolbar(map),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        _viewToolbar(),
      ];
      if (constraints.maxWidth < 960 || constraints.maxHeight < 440) {
        return SingleChildScrollView(
          child: Column(
            children: [
              ...header,
              SizedBox(height: 460, child: _canvas(map)),
              _sidePanel(map, scroll: false),
            ],
          ),
        );
      }
      return Column(
        children: [
          ...header,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _canvas(map)),
                SizedBox(width: 330, child: _sidePanel(map, scroll: true)),
              ],
            ),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final map = _document;
    return Theme(
      data: _editorTheme(),
      child: Material(
        color: const Color(0xFF171E29),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
                _undo(),
            const SingleActivator(
              LogicalKeyboardKey.keyZ,
              control: true,
              shift: true,
            ): () =>
                _undo(redo: true),
            const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
                _undo(redo: true),
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
              _save();
            },
          },
          child: Focus(
            autofocus: true,
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Загрузка карт…'),
                      ],
                    ),
                  )
                : _loadError != null
                ? Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              'Не удалось прочитать черновики:\n$_loadError',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Повторить загрузку'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : map == null
                ? const Center(child: Text('Нет доступных карт.'))
                : AbsorbPointer(absorbing: _busy, child: _workspace(map)),
          ),
        ),
      ),
    );
  }
}

Future<T?> _editorDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  builder: (_) => Theme(
    data: _editorTheme(),
    child: Builder(builder: builder),
  ),
);

ThemeData _editorTheme() => ThemeData.dark(useMaterial3: true).copyWith(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF8DAEFA),
    brightness: Brightness.dark,
    surface: const Color(0xFF1B2330),
  ),
  scaffoldBackgroundColor: const Color(0xFF171E29),
  visualDensity: VisualDensity.compact,
  inputDecorationTheme: const InputDecorationTheme(
    isDense: true,
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
  ),
  chipTheme: const ChipThemeData(
    labelStyle: TextStyle(fontSize: 12),
    padding: EdgeInsets.symmetric(horizontal: 3, vertical: 4),
  ),
);

Widget _integerField(
  TextEditingController controller,
  String label, {
  int min = 0,
  int max = 128,
  bool optional = false,
}) => TextFormField(
  controller: controller,
  decoration: InputDecoration(labelText: label),
  keyboardType: const TextInputType.numberWithOptions(signed: true),
  validator: (value) {
    if (optional && (value == null || value.trim().isEmpty)) return null;
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < min || number > max) {
      return 'Целое число: $min…$max';
    }
    return null;
  },
);

const _propNames = <String, String>{
  'tree': 'Дерево',
  'rock': 'Камень',
  'bush': 'Куст',
  'platform': 'Платформа',
  'bench': 'Скамья',
  'trashBin': 'Урна',
};

class _NewMapDialog extends StatefulWidget {
  const _NewMapDialog({required this.existing});
  final List<BuildMapDocument> existing;
  @override
  State<_NewMapDialog> createState() => _NewMapDialogState();
}

class _NewMapDialogState extends State<_NewMapDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _id;
  late final TextEditingController _name;
  final _width = TextEditingController(text: '24');
  final _height = TextEditingController(text: '16');

  @override
  void initState() {
    super.initState();
    var suffix = 1;
    while (widget.existing.any(
      (m) =>
          m.id == 'map_$suffix' ||
          m.name.toLowerCase() == 'новая карта $suffix',
    )) {
      suffix++;
    }
    _id = TextEditingController(text: 'map_$suffix');
    _name = TextEditingController(text: 'Новая карта $suffix');
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Новая карта'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _id,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Уникальный ID',
                  helperText: 'a–z, 0–9, _ и -; начинается с буквы',
                ),
                validator: (value) {
                  final id = value?.trim() ?? '';
                  if (!RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(id)) {
                    return 'Безопасный ID: от 1 до 64 символов';
                  }
                  if (widget.existing.any(
                    (m) => m.id.toLowerCase() == id.toLowerCase(),
                  )) {
                    return 'Этот ID уже занят';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Введите название';
                  if (widget.existing.any(
                    (m) => m.name.trim().toLowerCase() == name.toLowerCase(),
                  )) {
                    return 'Название уже используется';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _integerField(_width, 'Ширина (столбцы)', min: 1),
              const SizedBox(height: 14),
              _integerField(_height, 'Высота (строки)', min: 1),
              const SizedBox(height: 14),
              const Text(
                'Пустая карта заполняется травой. Игрок появится в центре. '
                'Черновик создаётся в памяти до первого сохранения.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final width = int.parse(_width.text.trim());
          final height = int.parse(_height.text.trim());
          Navigator.pop(
            context,
            BuildMapDocument(
              id: _id.text.trim(),
              name: _name.text.trim(),
              tiles: List.generate(height, (_) => List.filled(width, 0)),
              spawnCol: width ~/ 2,
              spawnRow: height ~/ 2,
            ),
          );
        },
        child: const Text('Создать карту'),
      ),
    ],
  );
}

class _EntityDialog extends StatefulWidget {
  const _EntityDialog({
    required this.tool,
    required this.map,
    required this.maps,
    required this.col,
    required this.row,
    this.existing,
    this.template,
  });
  final _Tool tool;
  final BuildMapDocument map;
  final List<BuildMapDocument> maps;
  final int col;
  final int row;
  final Object? existing;
  final Map<String, dynamic>? template;
  @override
  State<_EntityDialog> createState() => _EntityDialogState();
}

class _EntityDialogState extends State<_EntityDialog> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  late final Map<String, dynamic> _initial;
  late String _kind;
  late String _target;
  late String _direction;
  late bool _blocks;
  late bool _searchable;
  String? _error;

  TextEditingController _field(String key, Object? initial) =>
      _fields.putIfAbsent(
        key,
        () => TextEditingController(text: initial?.toString() ?? ''),
      );

  bool get _prop => widget.tool == _Tool.prop;
  bool get _exit => widget.tool == _Tool.exit;
  bool get _enemy => widget.tool == _Tool.enemy;

  @override
  void initState() {
    super.initState();
    _initial = switch (widget.existing) {
      BuildProp p => p.toJson(),
      BuildEnemySpawn e => e.toJson(),
      BuildNpcSpawn n => n.toJson(),
      BuildExit e => e.toJson(),
      _ => {...?widget.template},
    };
    final occupied = _prop
        ? widget.map.props.map((p) => p.id).toSet()
        : [
            ...widget.map.npcs,
            ...widget.map.additionalNpcs,
          ].map((n) => n.id).toSet();
    final prefix = _prop ? 'prop' : 'npc';
    var id = '${prefix}_${widget.col}_${widget.row}';
    var suffix = 2;
    while (occupied.contains(id)) {
      id = '${prefix}_${widget.col}_${widget.row}_${suffix++}';
    }
    _field('id', widget.existing == null ? id : _initial['id']);
    _field('name', _initial['name'] ?? 'Персонаж');
    _field('enemyId', _initial['enemyId'] ?? 'gopnik');
    _field('col', widget.col);
    _field('row', widget.row);
    _field('width', _initial['width'] ?? 1);
    _field('height', _initial['height'] ?? 1);
    _field('variant', _initial['variant'] ?? 0);
    _field('specialItemId', _initial['specialItemId']);
    _field('interactionId', _initial['interactionId']);
    final arrival = _initial['arrival'] as List?;
    _field('arrivalCol', arrival?.firstOrNull);
    _field(
      'arrivalRow',
      arrival != null && arrival.length > 1 ? arrival[1] : null,
    );
    _kind = _initial['kind'] as String? ?? 'tree';
    _target =
        _initial['targetId'] as String? ??
        widget.maps.where((m) => m.id != widget.map.id).firstOrNull?.id ??
        widget.map.id;
    _direction = _initial['direction'] as String? ?? 'auto';
    _blocks = _initial['blocksMovement'] as bool? ?? true;
    _searchable = _initial['searchable'] as bool? ?? false;
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _text(
    String key,
    String label, {
    String? hint,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      decoration: InputDecoration(labelText: label, helperText: hint),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty && !optional) return 'Обязательное поле';
        if (key == 'id') {
          final duplicate = _prop
              ? widget.map.props.any(
                  (p) => p != widget.existing && p.id == text,
                )
              : [
                  ...widget.map.npcs,
                  ...widget.map.additionalNpcs,
                ].any((n) => n != widget.existing && n.id == text);
          if (duplicate) return 'Этот ID уже используется на карте';
        }
        return null;
      },
    ),
  );

  void _submit() {
    if (!_form.currentState!.validate()) return;
    int number(String key) => int.parse(_fields[key]!.text.trim());
    String text(String key) => _fields[key]!.text.trim();
    final col = number('col');
    final row = number('row');
    final result = <String, dynamic>{..._initial, 'col': col, 'row': row};
    String? error;
    if (col >= widget.map.tiles[row].length) {
      setState(
        () => _error = 'Клетка отсутствует в матрице. Исправьте карту в JSON.',
      );
      return;
    }
    if (_prop) {
      if (col + number('width') > widget.map.cols ||
          row + number('height') > widget.map.rows) {
        error = 'Размер объекта выходит за границы карты.';
      }
      result.addAll({
        'id': text('id'),
        'kind': _kind,
        'width': number('width'),
        'height': number('height'),
        'blocksMovement': _blocks,
        'variant': number('variant'),
        'searchable': _searchable,
        'specialItemId': text('specialItemId').isEmpty
            ? null
            : text('specialItemId'),
        'interactionId': text('interactionId').isEmpty
            ? null
            : text('interactionId'),
      });
    } else if (_exit) {
      final ac = int.tryParse(text('arrivalCol'));
      final ar = int.tryParse(text('arrivalRow'));
      if ((ac == null) != (ar == null)) {
        error = 'Укажите обе координаты прибытия или оставьте обе пустыми.';
      }
      final target = widget.maps.where((m) => m.id == _target).firstOrNull;
      if (target == null) error = 'Выберите существующую целевую карту.';
      if (target != null && ac != null && ar != null) {
        if (ac < 0 || ar < 0 || ac >= target.cols || ar >= target.rows) {
          error =
              'Точка прибытия вне целевой карты (${target.cols}×${target.rows}).';
        } else if (mapCellBlocked(target, ac, ar)) {
          error = 'Точка прибытия на целевой карте заблокирована.';
        }
      }
      result.addAll({'targetId': _target, 'direction': _direction});
      result.remove('arrival');
      if (ac != null && ar != null) result['arrival'] = [ac, ar];
    } else if (_enemy) {
      result['enemyId'] = text('enemyId');
    } else {
      result.addAll({'id': text('id'), 'name': text('name')});
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.existing == null ? 'Разместить' : 'Изменить'}: ${widget.tool.label}',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _integerField(
                      _fields['col']!,
                      'Столбец (с нуля)',
                      max: widget.map.cols - 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _integerField(
                      _fields['row']!,
                      'Строка (с нуля)',
                      max: widget.map.rows - 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_prop) ...[
                _text('id', 'ID объекта'),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Тип объекта'),
                  items: [
                    for (final kind in {
                      ...LocationPropKind.values.map((k) => k.name),
                      _kind,
                    })
                      DropdownMenuItem(
                        value: kind,
                        child: Text(_propNames[kind] ?? kind),
                      ),
                  ],
                  onChanged: (value) => setState(() => _kind = value!),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _integerField(_fields['width']!, 'Ширина', min: 1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _integerField(
                        _fields['height']!,
                        'Высота',
                        min: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _integerField(
                  _fields['variant']!,
                  'Визуальный вариант',
                  max: 1000000,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Блокирует движение'),
                  value: _blocks,
                  onChanged: (value) => setState(() => _blocks = value!),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Можно обыскать'),
                  value: _searchable,
                  onChanged: (value) => setState(() => _searchable = value!),
                ),
                _text(
                  'specialItemId',
                  'ID особого предмета (необязательно)',
                  optional: true,
                ),
                _text(
                  'interactionId',
                  'ID действия (необязательно)',
                  hint: 'Например, q_kartofla_videos',
                  optional: true,
                ),
              ] else if (_exit) ...[
                DropdownButtonFormField<String>(
                  initialValue: _target,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Целевая карта'),
                  items: [
                    for (final map in widget.maps)
                      DropdownMenuItem(
                        value: map.id,
                        child: Text(
                          '${map.name} (${map.id})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (!widget.maps.any((m) => m.id == _target))
                      DropdownMenuItem(
                        value: _target,
                        child: Text('Не найдена: $_target'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _target = value!),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _direction,
                  decoration: const InputDecoration(
                    labelText: 'Направление стрелки',
                  ),
                  items: [
                    for (final direction in ExitDirection.values)
                      DropdownMenuItem(
                        value: direction.name,
                        child: Text(switch (direction) {
                          ExitDirection.auto => 'Автоматически',
                          ExitDirection.left => 'Влево',
                          ExitDirection.right => 'Вправо',
                          ExitDirection.up => 'Вверх',
                          ExitDirection.down => 'Вниз',
                        }),
                      ),
                  ],
                  onChanged: (value) => setState(() => _direction = value!),
                ),
                const SizedBox(height: 14),
                _integerField(
                  _fields['arrivalCol']!,
                  'Прибытие: столбец (необязательно)',
                  max: 127,
                  optional: true,
                ),
                const SizedBox(height: 14),
                _integerField(
                  _fields['arrivalRow']!,
                  'Прибытие: строка (необязательно)',
                  max: 127,
                  optional: true,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Без координат используется спавн целевой карты. '
                  'Выход установит тайл 4; существующий выход в клетке будет заменён.',
                  style: TextStyle(fontSize: 12),
                ),
              ] else if (_enemy) ...[
                _text(
                  'enemyId',
                  'ID типа врага',
                  hint: 'Например: gopnik, slime, goblin, shaurmek',
                ),
              ] else ...[
                _text('id', 'Уникальный ID NPC'),
                _text('name', 'Имя NPC'),
                Text(
                  widget.tool == _Tool.additionalNpc
                      ? 'Сохраняется в additionalNpcs (сюжетные NPC).'
                      : 'Сохраняется в основном списке npcs.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFFADB5)),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.existing == null ? 'Разместить' : 'Обновить'),
      ),
    ],
  );
}

class _JsonMapDialog extends StatefulWidget {
  const _JsonMapDialog({required this.document, required this.validate});
  final BuildMapDocument document;
  final List<String> Function(BuildMapDocument) validate;
  @override
  State<_JsonMapDialog> createState() => _JsonMapDialogState();
}

class _JsonMapDialogState extends State<_JsonMapDialog> {
  late final TextEditingController _json;
  final _path = TextEditingController();
  List<String> _errors = [];
  String? _status;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _json = TextEditingController(
      text: const JsonEncoder.withIndent(
        '  ',
      ).convert(widget.document.toJson()),
    );
  }

  @override
  void dispose() {
    _json.dispose();
    _path.dispose();
    super.dispose();
  }

  BuildMapDocument? _decode() {
    try {
      final data = jsonDecode(_json.text);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Корень JSON должен быть объектом.');
      }
      if (data['id'] != widget.document.id) {
        throw FormatException(
          'ID выбранной карты неизменяем: ${widget.document.id}. '
          'Для другой карты сначала создайте карту с нужным ID.',
        );
      }
      final tiles = data['tiles'];
      if (tiles is! List ||
          tiles.isEmpty ||
          tiles.length > 128 ||
          tiles.first is! List ||
          (tiles.first as List).isEmpty ||
          (tiles.first as List).length > 128) {
        throw const FormatException(
          'Матрица tiles должна иметь размер 1×1…128×128.',
        );
      }
      final width = (tiles.first as List).length;
      if (tiles.any(
        (r) =>
            r is! List ||
            r.length != width ||
            r.any((t) => t is! int || t < 0 || t > 14),
      )) {
        throw const FormatException(
          'Строки tiles должны иметь одинаковую длину; коды тайлов — целые 0…14.',
        );
      }
      final map = BuildMapDocument.fromJson(data);
      // Existing exit records own their tiles. Orphan tile-4 cells are errors.
      for (final exit in map.exits) {
        map.setTile(exit.col, exit.row, 4);
      }
      final errors = widget.validate(map);
      setState(() {
        _errors = errors;
        _status = errors.isEmpty
            ? 'JSON корректен. Выходы синхронизированы с тайлом 4.'
            : null;
      });
      return errors.isEmpty ? map : null;
    } catch (error) {
      setState(() {
        _errors = ['$error'];
        _status = null;
      });
      return null;
    }
  }

  Future<void> _io(Future<String> Function() operation) async {
    setState(() {
      _working = true;
      _errors = [];
      _status = null;
    });
    try {
      final status = await operation();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errors = ['Ошибка ввода-вывода: $error']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка JSON: $error'),
          showCloseIcon: true,
          backgroundColor: const Color(0xFF873B46),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Полный JSON карты'),
    content: SizedBox(
      width: 860,
      height: (MediaQuery.sizeOf(context).height * .72).clamp(220.0, 800.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Все метаданные: объекты, враги, оба списка NPC, выходы, спавн и внешние зоны. '
              'ID: ${widget.document.id} (неизменяемый).',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () => _io(() async {
                          await Clipboard.setData(
                            ClipboardData(text: _json.text),
                          );
                          return 'JSON скопирован в буфер обмена.';
                        }),
                  icon: const Icon(Icons.copy, size: 17),
                  label: const Text('Копировать'),
                ),
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () => _io(() async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (!mounted) return '';
                          if (data?.text == null) {
                            throw const FormatException('В буфере нет текста.');
                          }
                          _json.text = data!.text!;
                          return 'Текст вставлен. Проверьте JSON перед заменой черновика.';
                        }),
                  icon: const Icon(Icons.paste, size: 17),
                  label: const Text('Вставить'),
                ),
                TextButton.icon(
                  onPressed: _working ? null : _decode,
                  icon: const Icon(Icons.fact_check_outlined, size: 17),
                  label: const Text('Проверить JSON'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: (MediaQuery.sizeOf(context).height * .38).clamp(
                200.0,
                460.0,
              ),
              child: TextField(
                key: const Key('map-json'),
                controller: _json,
                expands: true,
                maxLines: null,
                minLines: null,
                enabled: !_working,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Документ карты',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) {
                  if (_status != null || _errors.isNotEmpty) {
                    setState(() {
                      _status = null;
                      _errors = [];
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _path,
              enabled: !_working,
              decoration: const InputDecoration(
                labelText: 'Путь к JSON-файлу для импорта / экспорта',
                hintText: '/путь/к/карте.json',
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                TextButton.icon(
                  onPressed: _working
                      ? null
                      : () => _io(() async {
                          if (_path.text.trim().isEmpty) {
                            throw const FormatException(
                              'Введите путь к файлу.',
                            );
                          }
                          final text = await File(
                            _path.text.trim(),
                          ).readAsString();
                          if (!mounted) return '';
                          _json.text = text;
                          return 'Файл прочитан. Нажмите «Проверить JSON», затем «Заменить черновик».';
                        }),
                  icon: const Icon(Icons.file_open_outlined, size: 17),
                  label: const Text('Прочитать файл'),
                ),
                TextButton.icon(
                  onPressed: _working
                      ? null
                      : () {
                          final map = _decode();
                          if (map == null) return;
                          _io(() async {
                            if (_path.text.trim().isEmpty) {
                              throw const FormatException(
                                'Введите путь к файлу.',
                              );
                            }
                            final file = File(_path.text.trim());
                            if (await file.exists()) {
                              if (!context.mounted) return '';
                              final overwrite = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Перезаписать файл?'),
                                  content: Text(file.path),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Отмена'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Перезаписать'),
                                    ),
                                  ],
                                ),
                              );
                              if (overwrite != true) return 'Экспорт отменён.';
                            }
                            await file.writeAsString(
                              const JsonEncoder.withIndent(
                                '  ',
                              ).convert(map.toJson()),
                            );
                            return 'JSON экспортирован: ${file.path}';
                          });
                        },
                  icon: const Icon(Icons.download_outlined, size: 17),
                  label: const Text('Экспортировать файл'),
                ),
              ],
            ),
            if (_working) const LinearProgressIndicator(),
            if (_status != null)
              Text(
                _status!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8BD6B4)),
              ),
            if (_errors.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Text(
                    _errors.join('\n'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFFFADB5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _working ? null : () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
      FilledButton(
        onPressed: _working
            ? null
            : () {
                final map = _decode();
                if (map != null) Navigator.pop(context, map);
              },
        child: const Text('Заменить черновик'),
      ),
    ],
  );
}
