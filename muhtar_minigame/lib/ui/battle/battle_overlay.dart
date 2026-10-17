import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/dice.dart';
import '../../game/muhtar_game.dart';
import '../../game_logic/battle_engine.dart';
import '../../game_logic/audio_service.dart';
import '../common/animated_stat.dart';
import '../common/game_symbols.dart';
import 'dice_visual.dart';

class BattleOverlay extends StatefulWidget {
  const BattleOverlay(this.game, {super.key});
  final MuhtarGame game;

  @override
  State<BattleOverlay> createState() => _BattleOverlayState();
}

class _BattleOverlayState extends State<BattleOverlay> {
  static const _boardSize = 494.0;
  static const _boardCellSize = 90.0;
  static const _boardCellStep = 96.0;

  final _focus = FocusNode();
  int? _selectedHotbar;
  int? _selectedCell;
  int? _hoveredCell;
  _DieDrag? _dragging;
  BattleEvent? _activeEvent;
  String _resolvingPlayerPhrase = '';
  String _resolvingEnemyPhrase = '';
  bool _resolving = false;
  bool _endTurnQueued = false;
  late final BattleEngine _battle;

  @override
  void initState() {
    super.initState();
    _battle = widget.game.battle!;
    widget.game.registerBattleKeyboardHandler(_finishTurn);
    widget.game.registerBattleDiceKeyboardHandler(_selectHotbarByKeyboard);
    widget.game.registerWindowCloseHandler(MuhtarGame.overlayBattle, _close);
    _battle.startTurn();
  }

  @override
  void dispose() {
    widget.game.registerBattleKeyboardHandler(null);
    widget.game.registerBattleDiceKeyboardHandler(null);
    widget.game.unregisterWindowCloseHandler(MuhtarGame.overlayBattle);
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    if (_resolving) return;
    if (_battle.isOver) {
      widget.game.endBattle();
    } else {
      widget.game.retreatBattle();
    }
  }

  void _selectHotbarByKeyboard(int index) {
    if (_battle.isOver || !_battle.canAct) return;
    if (index < 0 || index >= _battle.hotbarSize) return;
    if (_battle.hotbar[index] == null) return;
    setState(() {
      _selectedHotbar = _selectedHotbar == index ? null : index;
      _selectedCell = null;
    });
  }

  Future<void> _finishTurn() async {
    if (_resolving) {
      _endTurnQueued = true;
      if (mounted) setState(() {});
      return;
    }
    if (_dragging != null) return;
    if (_battle.isOver) {
      _close();
      return;
    }
    final playerPhrase = _battle.player.attackPhrase;
    final enemyPhrase = _battle.enemy.attackPhrase;
    setState(() {
      _resolving = true;
      _resolvingPlayerPhrase = playerPhrase;
      _resolvingEnemyPhrase = enemyPhrase;
      _selectedHotbar = null;
      _selectedCell = null;
      _hoveredCell = null;
    });
    _battle.endTurn();
    for (final event in _battle.lastEvents) {
      if (!mounted) return;
      setState(() => _activeEvent = event);
      if (event.type == BattleEventType.attack) {
        widget.game.audio.play(
          event.target == BattleSide.player ? GameSound.hurt : GameSound.hit,
        );
      }
      final duration = switch (event.type) {
        BattleEventType.attack => 308,
        BattleEventType.blocked => 364,
        BattleEventType.damage => 616,
        BattleEventType.burn => 504,
        BattleEventType.shield => 364,
        BattleEventType.heal => 588,
      };
      if (!MediaQuery.disableAnimationsOf(context)) {
        await Future<void>.delayed(Duration(milliseconds: duration));
      }
    }
    if (mounted) {
      setState(() {
        _activeEvent = null;
        _resolving = false;
      });
      final queueNext = _endTurnQueued;
      _endTurnQueued = false;
      if (queueNext && !_battle.isOver) {
        await _finishTurn();
      }
    }
  }

  Future<void> _removeSelectedDie() async {
    final cell = _selectedCell;
    if (cell == null || !_battle.canAct) return;
    if (_battle.removeDie(cell)) {
      widget.game.audio.play(GameSound.ui);
      setState(() => _selectedCell = null);
    }
  }

  bool _accept(_DieDrag data, int cell) {
    if (!_battle.canAct ||
        data.round != _battle.round ||
        _battle.isCellRooted(cell)) {
      return false;
    }
    final source = data.fromBoard ? _battle.board : _battle.hotbar;
    if (data.index >= source.length ||
        !identical(source[data.index], data.die)) {
      return false;
    }
    if (data.fromBoard) {
      return data.index != cell &&
          data.die.dice.modifier != DiceModifier.heavy &&
          (_battle.board[cell] == null ||
              _battle.board[cell]!.dice.modifier != DiceModifier.heavy);
    }
    return _battle.board[cell] == null && _battle.canPlaceDie(data.index);
  }

  void _place(_DieDrag data, int cell) {
    if (!_accept(data, cell)) return;
    final success = data.fromBoard
        ? _battle.moveDie(data.index, cell)
        : _battle.placeDie(data.index, cell);
    if (success) {
      widget.game.audio.play(GameSound.diePlace);
      setState(() {
        _selectedHotbar = null;
        _selectedCell = null;
        _hoveredCell = null;
      });
    }
  }

  _DieDrag? get _selection {
    final fromBoard = _selectedCell != null;
    final index = _selectedCell ?? _selectedHotbar;
    if (index == null) return null;
    final die = (fromBoard ? _battle.board : _battle.hotbar)[index];
    if (die == null) return null;
    return _DieDrag(index, fromBoard, die, _battle.round);
  }

  void _tapCell(int cell) {
    if (_battle.isOver) return;
    final selection = _selection;
    if (selection != null && _accept(selection, cell)) {
      _place(selection, cell);
    } else if (_battle.board[cell] != null) {
      setState(() {
        _selectedCell = _selectedCell == cell ? null : cell;
        _selectedHotbar = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    autofocus: false,
    onKeyEvent: (_, event) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        if (event is KeyDownEvent) _finishTurn();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _close();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent) {
        final index = _hotbarIndexForKey(event.logicalKey);
        if (index != null) {
          _selectHotbarByKeyboard(index);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
    child: Listener(
      child: Material(
        color: const Color(0xFF11131D),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _battle,
            builder: (context, _) => LayoutBuilder(
              builder: (context, box) {
                // Один фиксированный дизайн-холст не меняет геометрию при
                // resize. Раньше ширина и высота вычислялись через уже
                // уменьшенный scale, из-за чего при расширении окна часть
                // оверлея могла остаться в старых ограничениях GameWidget.
                final portrait = box.maxWidth < box.maxHeight * .9;
                final designWidth = portrait ? 560.0 : 1100.0;
                final designHeight = portrait ? 980.0 : 740.0;
                final scale = math.min(
                  box.maxWidth / designWidth,
                  box.maxHeight / designHeight,
                );
                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: designWidth,
                      height: designHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: const [
                                    Color(0xFF383043),
                                    Color(0xFF11131D),
                                  ],
                                  radius: .9,
                                  center: const Alignment(0, -.2),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            top: 16,
                            right: 180,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final entry in _battle.artifacts.entries)
                                  ArtifactBadge(
                                    entry.key,
                                    count: entry.value,
                                    size: 44,
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 20,
                            top: 24,
                            child: Text(
                              'РАУНД ${_battle.round}',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFFE4CAA0),
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 20,
                            top: 54,
                            child: Text(
                              'ЭНЕРГИЯ ${_battle.energy}/${BattleEngine.maxEnergy}',
                              key: const ValueKey('battle-energy'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF78F3D0),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 24,
                            top: portrait ? 88 : (designHeight - 480) / 2,
                            child: _FighterPanel(
                              key: const ValueKey('hero-panel'),
                              fighter: _battle.player,
                              preview: _battle.previewFor(_battle.player),
                              hitVersion: _battle.playerHitVersion,
                              phrase: _resolving
                                  ? _resolvingPlayerPhrase
                                  : _battle.player.attackPhrase,
                              activeEvent: _activeEvent,
                              round: _battle.round,
                              width: portrait ? 176 : 230,
                            ),
                          ),
                          Positioned(
                            right: 24,
                            top: portrait ? 88 : (designHeight - 480) / 2,
                            child: _FighterPanel(
                              key: const ValueKey('enemy-panel'),
                              fighter: _battle.enemy,
                              preview: _battle.previewFor(_battle.enemy),
                              hitVersion: _battle.enemyHitVersion,
                              phrase: _resolving
                                  ? _resolvingEnemyPhrase
                                  : _battle.enemy.attackPhrase,
                              activeEvent: _activeEvent,
                              round: _battle.round,
                              width: portrait ? 176 : 230,
                            ),
                          ),
                          Positioned(
                            left: (designWidth - _boardSize) / 2,
                            top: portrait ? (designHeight - 600) * .65 : 32,
                            child: _buildBoard(scale),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 136,
                            child: Center(
                              child: _battle.isOver
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _battle.player.isDead
                                              ? 'Поражение'
                                              : 'Победа!',
                                          style: const TextStyle(
                                            fontSize: 30,
                                            color: Color(0xFFFFC857),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ExcludeFocus(
                                          child: FilledButton(
                                            onPressed: _resolving
                                                ? null
                                                : _close,
                                            child: const Text('Продолжить'),
                                          ),
                                        ),
                                      ],
                                    )
                                  : ExcludeFocus(
                                      child: FilledButton.icon(
                                        key: const ValueKey('end-turn'),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(260, 52),
                                          textStyle: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: _finishTurn,
                                        icon: const Icon(Icons.double_arrow),
                                        label: Text(
                                          _endTurnQueued
                                              ? 'Следующий ход поставлен в очередь'
                                              : _resolving
                                              ? 'Следующий ход · Enter / Space'
                                              : 'Завершить ход · Enter / Space',
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 8,
                            child: _buildHotbar(scale),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  int? _hotbarIndexForKey(LogicalKeyboardKey key) {
    const keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
    ];
    final index = keys.indexOf(key);
    if (index < 0) return null;
    return index % 6;
  }

  void _setHoveredCell(int? cell) {
    if (_hoveredCell == cell || !mounted) return;
    setState(() => _hoveredCell = cell);
  }

  Widget _buildBoard(double scale) {
    final targets = <int>{..._battle.upgradeTargetCells};
    final active = _dragging ?? _selection;
    if (_dragging?.die.dice.ability == DiceAbility.upgrade) {
      final source =
          _hoveredCell ?? (_dragging!.fromBoard ? _dragging!.index : null);
      if (source != null) {
        targets.addAll(
          BattleEngine.upgradeTargets(source, _dragging!.die.dice.level),
        );
      }
    }
    return SizedBox(
      key: const ValueKey('battle-board'),
      width: _boardSize,
      height: _boardSize,
      child: Stack(
        children: [
          Center(
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 344.5,
                height: 344.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFAF7845),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7BC7C), width: 5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      offset: Offset(8, 8),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (var cell = 0; cell < 9; cell++)
            Positioned(
              left:
                  _boardSize / 2 -
                  _boardCellSize / 2 +
                  ((cell % 3) - (cell ~/ 3)) * _boardCellStep,
              top:
                  _boardSize / 2 -
                  _boardCellSize / 2 +
                  ((cell % 3) + (cell ~/ 3) - 2) * _boardCellStep,
              child: MouseRegion(
                onEnter: (_) => _setHoveredCell(cell),
                onExit: (_) => _setHoveredCell(null),
                child: DragTarget<_DieDrag>(
                  onWillAcceptWithDetails: (details) =>
                      _accept(details.data, cell),
                  onMove: (_) => _setHoveredCell(cell),
                  onLeave: (_) => _setHoveredCell(null),
                  onAcceptWithDetails: (details) => _place(details.data, cell),
                  builder: (context, candidates, rejected) {
                    final die = _battle.board[cell];
                    final rooted = _battle.isCellRooted(cell);
                    final highlighted = !rooted && targets.contains(cell);
                    Widget child = InkWell(
                      key: ValueKey('board-cell-$cell'),
                      onTap: () => _tapCell(cell),
                      child: Container(
                        width: _boardCellSize,
                        height: _boardCellSize,
                        decoration: BoxDecoration(
                          color: rooted
                              ? const Color(0xFF3A302E)
                              : highlighted
                              ? const Color(0xFF5A4567)
                              : const Color(0xFF674530),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            width: 3,
                            color: rooted
                                ? const Color(0xFFE3A85E)
                                : candidates.isNotEmpty || highlighted
                                ? const Color(0xFF87FFE1)
                                : const Color(0xFF442D2A),
                          ),
                        ),
                        child: rooted
                            ? Semantics(
                                label:
                                    'Клетка ${cell + 1}: заблокирована корнями, '
                                    'размещение недоступно',
                                child: const _RootCellVisual(),
                              )
                            : die == null
                            ? Semantics(label: 'Пустая клетка ${cell + 1}')
                            : _DieFace(
                                die,
                                value: _battle.effectiveValueAt(cell),
                                selected: _selectedCell == cell,
                              ),
                      ),
                    );
                    if (die != null) {
                      child = _draggable(
                        child,
                        _DieDrag(cell, true, die, _battle.round),
                        scale,
                      );
                    }
                    return child;
                  },
                ),
              ),
            ),
          if (_selectedCell != null &&
              _battle.board[_selectedCell!]?.dice.modifier !=
                  DiceModifier.heavy)
            Positioned(
              left: 112,
              right: 112,
              bottom: 6,
              child: OutlinedButton.icon(
                key: const ValueKey('remove-die'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFD19A),
                  backgroundColor: const Color(0xDD171923),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: _removeSelectedDie,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Убрать кость'),
              ),
            ),
          if (_battle.rootedCells.isNotEmpty)
            Positioned(
              left: 8,
              right: 8,
              top: 4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xDD241C1D),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: const Color(0xFFE3A85E),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            key: ValueKey('rooted-legend-icon'),
                            size: 14,
                            color: Color(0xFFFFD18A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ВИКТОР · КОРНИ · ${_battle.rootedCells.length} '
                            'КЛЕТОК ЗАБЛОКИРОВАНО',
                            key: const ValueKey('rooted-legend'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFFD18A),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .4,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (active?.die.dice.ability == DiceAbility.upgrade)
            Positioned(
              left: 0,
              right: 0,
              top: _battle.rootedCells.isNotEmpty ? 28 : 4,
              child: IgnorePointer(
                child: Text(
                  'Кость улучшения: выбери клетку — подсветится зона влияния',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFF5C8FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _draggable(Widget child, _DieDrag data, double scale) =>
      Draggable<_DieDrag>(
        data: data,
        maxSimultaneousDrags:
            _battle.canAct && data.die.dice.modifier != DiceModifier.heavy
            ? 1
            : 0,
        // Центр кости остаётся под указателем, а не та точка, за которую
        // пользователь случайно схватил его.
        dragAnchorStrategy: childDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: _boardCellSize * scale,
            height: _boardCellSize * scale,
            child: FittedBox(
              child: SizedBox(
                width: _boardCellSize,
                height: _boardCellSize,
                child: _DieFace(
                  data.die,
                  value: data.die.value,
                  selected: true,
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: .3, child: child),
        onDragStarted: () => setState(() => _dragging = data),
        onDragEnd: (_) {
          if (mounted) {
            setState(() {
              _dragging = null;
              _hoveredCell = null;
            });
          }
        },
        child: child,
      );

  Widget _buildHotbar(double scale) => Container(
    key: const ValueKey('battle-hotbar'),
    height: 116,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF222331),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF8D7855), width: 2),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const rerollWidth = 90.0;
        const gap = 12.0;
        final diceZoneWidth = (constraints.maxWidth - rerollWidth - gap)
            .clamp(0.0, double.infinity)
            .toDouble();
        return Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: diceZoneWidth,
                height: 96,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < _battle.hotbarSize; index++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _hotbarSlot(index, scale),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: rerollWidth,
                height: 82,
                child: Tooltip(
                  message:
                      'Заменить выбранную кость. Осталось ${_battle.rerollsRemaining}',
                  child: ExcludeFocus(
                    child: OutlinedButton(
                      key: const ValueKey('reroll'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(rerollWidth, 82),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed:
                          _selectedHotbar != null &&
                              _battle.canAct &&
                              _battle.rerollsRemaining > 0
                          ? () {
                              if (_battle.rerollDie(_selectedHotbar!)) {
                                widget.game.audio.play(GameSound.dieReroll);
                              }
                            }
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const GameIcon(GameSymbol.reroll, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            '${_battle.rerollsRemaining}',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _hotbarSlot(int index, double scale) {
    final die = _battle.hotbar[index];
    Widget child = SizedBox(
      width: 72,
      height: 82,
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              key: ValueKey('hotbar-$index'),
              onTap: die == null || !_battle.canAct
                  ? null
                  : () => setState(() {
                      _selectedHotbar = _selectedHotbar == index ? null : index;
                      _selectedCell = null;
                    }),
              child: die == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                    )
                  : _DieFace(
                      die,
                      value: die.value,
                      selected: _selectedHotbar == index,
                      compact: true,
                    ),
            ),
          ),
          Positioned(
            left: 3,
            bottom: 2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xDD171923),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFFE7BC7C),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (die != null) {
      child = _draggable(
        child,
        _DieDrag(index, false, die, _battle.round),
        scale,
      );
    }
    return child;
  }
}

class _DieDrag {
  const _DieDrag(this.index, this.fromBoard, this.die, this.round);
  final int index;
  final bool fromBoard;
  final RolledDie die;
  final int round;
}

class _RootCellVisual extends StatefulWidget {
  const _RootCellVisual();

  @override
  State<_RootCellVisual> createState() => _RootCellVisualState();
}

class _RootCellVisualState extends State<_RootCellVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 840),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _RootCellPainter(pulse: _pulse.value)),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xCC241C1D),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x99E3A85E)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 12, color: Color(0xFFFFD18A)),
                SizedBox(width: 3),
                Text(
                  'КОРНИ',
                  style: TextStyle(
                    color: Color(0xFFFFD18A),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RootCellPainter extends CustomPainter {
  const _RootCellPainter({this.pulse = 0});

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = Color.fromRGBO(36, 211, 162, .12 + pulse * .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * .47),
      size.width * .25,
      glow,
    );

    final root = Paint()
      ..color = Color.lerp(
        const Color(0xFFE3A85E),
        const Color(0xFFFFE0A3),
        pulse,
      )!
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final center = Offset(size.width / 2, size.height * .35);
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(
        size.width * .47,
        size.height * .54,
        size.width * .33,
        size.height * .68,
      )
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(
        size.width * .53,
        size.height * .54,
        size.width * .67,
        size.height * .68,
      )
      ..moveTo(size.width * .33, size.height * .68)
      ..quadraticBezierTo(
        size.width * .25,
        size.height * .75,
        size.width * .2,
        size.height * .84,
      )
      ..moveTo(size.width * .67, size.height * .68)
      ..quadraticBezierTo(
        size.width * .75,
        size.height * .75,
        size.width * .8,
        size.height * .84,
      );
    canvas.drawPath(path, root);

    final crown = Paint()
      ..color = Color.lerp(const Color(0xFF8FE8D1), Colors.white, pulse * .35)!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6, crown);
    canvas.drawCircle(Offset(size.width * .33, size.height * .68), 3.5, crown);
    canvas.drawCircle(Offset(size.width * .67, size.height * .68), 3.5, crown);
  }

  @override
  bool shouldRepaint(covariant _RootCellPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

class _DieFace extends StatelessWidget {
  const _DieFace(
    this.die, {
    required this.value,
    this.selected = false,
    this.compact = false,
  });
  final RolledDie die;
  final int value;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasUpgrade = value != die.value;
    return Tooltip(
      message:
          '${die.dice.name} · уровень ${die.dice.level}\n'
          '${die.dice.ability.description}\n'
          '${die.dice.modifier.description}',
      child: SizedBox(
        width: compact ? 72 : 90,
        height: compact ? 82 : 90,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            DiceVisual(
              dice: die.dice,
              value: value,
              compact: compact,
              selected: selected,
            ),
            if (hasUpgrade)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE6171923),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'знач. ${die.value} → $value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF78F3D0),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FighterPanel extends StatefulWidget {
  const _FighterPanel({
    required this.fighter,
    required this.preview,
    required this.hitVersion,
    required this.phrase,
    required this.activeEvent,
    required this.round,
    required this.width,
    super.key,
  });
  final Fighter fighter;
  final BattlePreview preview;
  final int hitVersion;
  final String phrase;
  final BattleEvent? activeEvent;
  final int round;
  final double width;

  @override
  State<_FighterPanel> createState() => _FighterPanelState();
}

class _FighterPanelState extends State<_FighterPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hit;
  Timer? _typingTimer;
  String _typedPhrase = '';

  @override
  void initState() {
    super.initState();
    _hit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 168),
    );
    _startTyping(widget.phrase);
  }

  @override
  void didUpdateWidget(_FighterPanel old) {
    super.didUpdateWidget(old);
    if (widget.hitVersion != old.hitVersion) _hit.forward(from: 0);
    if (widget.phrase != old.phrase) {
      _startTyping(widget.phrase);
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _hit.dispose();
    super.dispose();
  }

  void _startTyping(String text) {
    _typingTimer?.cancel();
    _typedPhrase = '';
    if (text.isEmpty) return;

    var index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      index++;
      setState(() {
        _typedPhrase = text.substring(0, index);
      });
      if (index >= text.length) timer.cancel();
    });
  }

  Widget _attackPhraseText() {
    const style = TextStyle(
      color: Color(0xFFFFD9A8),
      fontSize: 13,
      height: 1.35,
      fontFamily: 'monospace',
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Opacity(opacity: 0, child: Text(widget.phrase, style: style)),
          Text(_typedPhrase, textAlign: TextAlign.center, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fighter = widget.fighter;
    final preview = widget.preview;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final side = fighter.isPlayer ? BattleSide.player : BattleSide.enemy;
    final activeEvent = widget.activeEvent;
    final eventTargetsThisFighter = activeEvent?.target == side;
    final eventLabel = eventTargetsThisFighter
        ? _eventLabel(activeEvent!)
        : activeEvent?.source == side
        ? _sourceEventLabel(activeEvent!)
        : null;
    final portrait = Container(
      width: widget.width,
      height: widget.width * 1.12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF262633),
        border: Border.all(
          color: fighter.isPlayer
              ? const Color(0xFF799DBD)
              : const Color(0xFFB77E73),
          width: 4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            offset: Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
       child: Image.asset(
         'assets/portraits/${fighter.appearance}.png',
         fit: BoxFit.cover,
         errorBuilder: (_, error, stack) => Center(
           child: fighter.appearance == 'player_kartofla'
               ? const SizedBox.expand(
                   child: CustomPaint(painter: _KartoflaPortraitPainter()),
                 )
               : Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(
                       Icons.image_outlined,
                       size: 48,
                       color: Color(0xFFABA1B5),
                     ),
                     const SizedBox(height: 12),
                     Text(
                       fighter.name,
                       textAlign: TextAlign.center,
                       style: const TextStyle(
                         color: Color(0xFFD4C8DD),
                         fontSize: 18,
                       ),
                     ),
                   ],
                 ),
         ),
       ),
    );
    return SizedBox(
      width: widget.width,
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              AnimatedStat(
                key: const ValueKey('hp'),
                symbol: GameSymbol.heart,
                value: fighter.hp,
                valueText: '${fighter.hp}',
                label: 'Здоровье',
                color: const Color(0xFFFF6A86),
                alwaysVisible: true,
              ),
              AnimatedStat(
                key: const ValueKey('attack'),
                symbol: GameSymbol.sword,
                value: preview.outgoingDamage,
                label: 'Нанесёт урон',
                color: const Color(0xFFFFD281),
              ),
              AnimatedStat(
                key: const ValueKey('incoming'),
                symbol: GameSymbol.incoming,
                value: preview.incomingDamage,
                label: 'Потеряет HP',
                color: const Color(0xFFFF946E),
              ),
              _shieldStat(side: side, value: preview.shield),
              AnimatedStat(
                key: const ValueKey('heal'),
                symbol: GameSymbol.heal,
                value: preview.healing,
                label: 'Вылечит в конце',
                color: const Color(0xFF70DC9C),
              ),
              AnimatedStat(
                key: const ValueKey('fire'),
                symbol: GameSymbol.fire,
                value: preview.burnApplied,
                label: 'Наложит горение',
                color: const Color(0xFFFF885A),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _hit,
                child: portrait,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    reduced
                        ? 0
                        : math.sin(_hit.value * math.pi * 6) *
                              6 *
                              (1 - _hit.value),
                    0,
                  ),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.red.withValues(
                        alpha:
                            .25 * (1 - _hit.value) * (_hit.isAnimating ? 1 : 0),
                      ),
                      BlendMode.srcATop,
                    ),
                    child: child,
                  ),
                ),
              ),
              if (eventTargetsThisFighter &&
                  activeEvent != null &&
                  activeEvent.type != BattleEventType.attack &&
                  activeEvent.type != BattleEventType.shield)
                Positioned(
                  top: -8,
                  left: 0,
                  right: 0,
                  child: _CombatFloat(
                    key: ValueKey('combat-${activeEvent.sequence}'),
                    event: activeEvent,
                  ),
                ),
            ],
          ),
          Text(
            fighter.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (eventLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                eventLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9FFFE7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (widget.phrase.isNotEmpty) _attackPhraseText(),
          if (fighter.actsFirst)
            const Text(
              'Атакует первым',
              style: TextStyle(fontSize: 13, color: Color(0xFFFFCF9C)),
            ),
        ],
      ),
    );
  }

  String _sourceEventLabel(BattleEvent event) => switch (event.type) {
    BattleEventType.attack => 'Атака · ${event.amount}',
    BattleEventType.shield => 'Щит · +${event.amount}',
    BattleEventType.heal => 'Лечение · +${event.amount}',
    BattleEventType.burn => 'Горение · ${event.amount}',
    BattleEventType.blocked => 'Удар заблокирован',
    BattleEventType.damage => 'Удар прошёл',
  };

  String _eventLabel(BattleEvent event) => switch (event.type) {
    BattleEventType.attack => 'Получает удар · ${event.amount}',
    BattleEventType.blocked => 'Щит поглотил · ${event.amount}',
    BattleEventType.damage => 'Урон · −${event.amount}',
    BattleEventType.burn => 'Горение · −${event.amount}',
    BattleEventType.shield => 'Щит · +${event.amount}',
    BattleEventType.heal => 'Исцеление · +${event.amount}',
  };

  Widget _shieldStat({required BattleSide side, required int value}) {
    final stat = AnimatedStat(
      key: const ValueKey('shield'),
      symbol: GameSymbol.shield,
      value: value,
      label: 'Щит на раунд',
      color: const Color(0xFF8BC8FF),
    );
    final event = widget.activeEvent;
    if (event?.type != BattleEventType.blocked || event?.target != side) {
      return stat;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('shield-pulse-${event!.sequence}'),
      tween: Tween(begin: .82, end: 1.08),
      duration: const Duration(milliseconds: 182),
      curve: Curves.easeOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: stat,
    );
  }
}

class _KartoflaPortraitPainter extends CustomPainter {
  const _KartoflaPortraitPainter();

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()..isAntiAlias = true;
    final center = ui.Offset(size.width / 2, size.height / 2);
    paint.color = const ui.Color(0xFF3A271F);
    canvas.drawRect(ui.Offset.zero & size, paint);
    paint.color = const ui.Color(0xFFC9854F);
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: center,
        width: size.width * .58,
        height: size.height * .68,
      ),
      paint,
    );
    paint.color = const ui.Color(0xFFF0C66D);
    canvas.drawRect(
      ui.Rect.fromLTWH(
        size.width * .19,
        size.height * .16,
        size.width * .62,
        size.height * .09,
      ),
      paint,
    );
    paint.color = const ui.Color(0xFF4C3024);
    canvas.drawCircle(
      ui.Offset(size.width * .39, size.height * .48),
      size.width * .035,
      paint,
    );
    canvas.drawCircle(
      ui.Offset(size.width * .61, size.height * .48),
      size.width * .035,
      paint,
    );
    paint.color = const ui.Color(0xFFFFD891);
    canvas.drawRect(
      ui.Rect.fromLTWH(
        size.width * .32,
        size.height * .66,
        size.width * .36,
        size.height * .055,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _KartoflaPortraitPainter oldDelegate) => false;
}

class _CombatFloat extends StatefulWidget {
  const _CombatFloat({required this.event, super.key});

  final BattleEvent event;

  @override
  State<_CombatFloat> createState() => _CombatFloatState();
}

class _CombatFloatState extends State<_CombatFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 588),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positive =
        widget.event.type == BattleEventType.heal ||
        widget.event.type == BattleEventType.shield ||
        widget.event.type == BattleEventType.blocked;
    final text = positive
        ? '+${widget.event.amount}'
        : '-${widget.event.amount}';
    final color = positive ? const Color(0xFF7DFFC1) : const Color(0xFFFF7189);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: 1 - Curves.easeOut.transform(_controller.value),
          child: Transform.translate(
            offset: Offset(
              0,
              -116 * Curves.easeOut.transform(_controller.value),
            ),
            child: child,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}
