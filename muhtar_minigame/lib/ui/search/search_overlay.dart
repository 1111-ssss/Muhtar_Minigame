import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/location.dart';
import '../../game_logic/game_state.dart';

/// Самостоятельный экран поиска куста или мусорного ведра.
///
/// [game] — это [GameState], а не [MuhtarGame]: экран не знает о маршрутизации
/// игры и подключается к ней одним внешним колбэком. Именованный [state] оставлен
/// для совместимости с прежним конструктором.
class SearchOverlay extends StatefulWidget {
  const SearchOverlay({
    this.game,
    this.state,
    required this.prop,
    this.title = 'Тщательный поиск',
    this.onClose,
    this.onResult,
    super.key,
  }) : assert(game != null || state != null, 'Передайте game или state'),
       assert(
         game == null || state == null,
         'Передавайте только один из game/state',
       );

  /// Основное имя параметра для нового подключения.
  final GameState? game;

  /// Старое имя параметра, сохранённое для существующих подключений.
  final GameState? state;
  final LocationProp prop;
  final String title;
  final VoidCallback? onClose;

  /// Получает каждый промежуточный результат и финальную награду.
  /// Сама [GameState] уже сохраняет прогресс поиска в `toJson`.
  final ValueChanged<SearchResult>? onResult;

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final AnimationController _revealController;
  final math.Random _random = math.Random();

  SearchResult? _result;
  late final bool _wasCompletedOnOpen;
  Offset _shakeOffset = Offset.zero;
  double _shakeAngle = 0;

  GameState get _state => widget.game ?? widget.state!;
  bool get _completed => _result?.completed ?? false;

  @override
  void initState() {
    super.initState();
    _result = _state.searchResult(widget.prop.id);
    _wasCompletedOnOpen =
        widget.prop.kind == LocationPropKind.bush && _result?.completed == true;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: _completed ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _search() {
    if (_completed) return;

    final result = _state.searchProp(widget.prop.id);
    final didComplete = result.completed;
    setState(() {
      _result = result;
      _shakeOffset = Offset(
        (_random.nextDouble() * 2 - 1) * 20,
        (_random.nextDouble() * 2 - 1) * 14,
      );
      _shakeAngle = (_random.nextDouble() * 2 - 1) * 0.075;
    });
    _shakeController.forward(from: 0);
    if (didComplete) _revealController.forward(from: 0);
    widget.onResult?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_wasCompletedOnOpen) return _buildAlreadySearched();

    final result = _result;
    final completed = result?.completed ?? false;
    if (completed && result?.rewardType == SearchRewardType.none) {
      return _buildEmptySearch();
    }
    final colors = _palette(widget.prop.kind);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE6131B2C), Color(0xF20A101C)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF171D2B),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.border, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: colors.glow.withValues(alpha: 0.18),
                          blurRadius: 42,
                          spreadRadius: 2,
                        ),
                        const BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 24,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Header(
                            title: widget.title,
                            completed: completed,
                            onClose: widget.onClose,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _propLabel(widget.prop),
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _IllustrationButton(
                            prop: widget.prop,
                            completed: completed,
                            shakeController: _shakeController,
                            revealController: _revealController,
                            shakeOffset: _shakeOffset,
                            shakeAngle: _shakeAngle,
                            colors: colors,
                            onTap: _search,
                          ),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: completed
                                ? _RewardPanel(
                                    key: const ValueKey('search-reward'),
                                    result: result,
                                    colors: colors,
                                  )
                                : _HintPanel(
                                    key: const ValueKey('search-hint'),
                                    colors: colors,
                                  ),
                          ),
                          const SizedBox(height: 20),
                          if (completed)
                            FilledButton.icon(
                              key: const ValueKey('search-close-reward'),
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Забрать находку'),
                            )
                          else
                            FilledButton.icon(
                              key: const ValueKey('search-prop'),
                              onPressed: _search,
                              icon: const Icon(Icons.touch_app_rounded),
                              label: const Text('Проверить объект'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadySearched() {
    if (_result?.rewardType == SearchRewardType.none) {
      return _buildEmptySearch();
    }
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE6131B2C), Color(0xF20A101C)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Здесь ничего нет...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: widget.onClose,
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearch() => Focus(
    autofocus: true,
    onKeyEvent: _handleEmptyKey,
    child: Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xE6131B2C), Color(0xF20A101C)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF171D2B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF3F805C)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.grass_rounded,
                          color: Color(0xFF8BE6A0),
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'В кусте ничего нет',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Поищи в другом месте.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: widget.onClose,
                          child: const Text('Закрыть'),
                        ),
                        const Text(
                          'Space / Enter / Esc',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  KeyEventResult _handleEmptyKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.escape)) {
      widget.onClose?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static _SearchPalette _palette(LocationPropKind kind) {
    switch (kind) {
      case LocationPropKind.trashBin:
        return const _SearchPalette(
          accent: Color(0xFFFFC46B),
          border: Color(0xFF80643B),
          glow: Color(0xFFFF9D5C),
          dark: Color(0xFF293849),
          mid: Color(0xFF52657A),
        );
      case LocationPropKind.bush:
        return const _SearchPalette(
          accent: Color(0xFF8BE6A0),
          border: Color(0xFF3F805C),
          glow: Color(0xFF63D88C),
          dark: Color(0xFF183C36),
          mid: Color(0xFF2D7755),
        );
      default:
        return const _SearchPalette(
          accent: Color(0xFF9AD8FF),
          border: Color(0xFF4B6F8B),
          glow: Color(0xFF6CB8E8),
          dark: Color(0xFF24364B),
          mid: Color(0xFF47718C),
        );
    }
  }

  static String _propLabel(LocationProp prop) => switch (prop.kind) {
    LocationPropKind.bush => 'ЗАРОСЛИ',
    LocationPropKind.trashBin => 'МУСОРНЫЙ БАК',
    LocationPropKind.bench => 'СКАМЕЙКА',
    _ => 'ОБЪЕКТ НА КАРТЕ',
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.completed, this.onClose});

  final String title;
  final bool completed;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: (completed ? const Color(0xFF7EE7A1) : const Color(0xFFFFD27D))
              .withValues(alpha: 0.13),
          shape: BoxShape.circle,
        ),
        child: Icon(
          completed ? Icons.auto_awesome_rounded : Icons.search_rounded,
          color: completed ? const Color(0xFF7EE7A1) : const Color(0xFFFFD27D),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      if (onClose != null)
        IconButton(
          tooltip: 'Закрыть',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          color: Colors.white70,
        ),
    ],
  );
}

class _IllustrationButton extends StatelessWidget {
  const _IllustrationButton({
    required this.prop,
    required this.completed,
    required this.shakeController,
    required this.revealController,
    required this.shakeOffset,
    required this.shakeAngle,
    required this.colors,
    required this.onTap,
  });

  final LocationProp prop;
  final bool completed;
  final AnimationController shakeController;
  final AnimationController revealController;
  final Offset shakeOffset;
  final double shakeAngle;
  final _SearchPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: completed
        ? 'Найденная награда'
        : 'Осмотреть ${prop.kind == LocationPropKind.trashBin ? 'мусорный бак' : 'куст'}',
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: completed ? null : onTap,
        child: SizedBox(
          height: 250,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: Listenable.merge([shakeController, revealController]),
            builder: (context, _) {
              final shake = Curves.easeOutBack.transform(shakeController.value);
              final reveal = Curves.easeOut.transform(revealController.value);
              return Transform.translate(
                offset: shakeOffset * (1 - shake),
                child: Transform.rotate(
                  angle: shakeAngle * math.sin(shake * math.pi),
                  child: CustomPaint(
                    painter: _SearchPropPainter(
                      kind: prop.kind,
                      variant: prop.variant,
                      colors: colors,
                      pulse: shakeController.value,
                      reveal: reveal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _HintPanel extends StatelessWidget {
  const _HintPanel({required this.colors, super.key});

  final _SearchPalette colors;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: colors.dark.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colors.border.withValues(alpha: 0.55)),
    ),
    child: const Row(
      children: [
        Icon(Icons.tips_and_updates_outlined, color: Color(0xFFFFD27D)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Нажимай на объект, пока он не выдаст свою находку.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _RewardPanel extends StatelessWidget {
  const _RewardPanel({required this.result, required this.colors, super.key});

  final SearchResult? result;
  final _SearchPalette colors;

  @override
  Widget build(BuildContext context) {
    final reward = _rewardText(result);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A4A3B).withValues(alpha: 0.95),
            colors.dark.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7EE7A1).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            color: Color(0xFFFFD27D),
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Находка обнаружена',
                  style: TextStyle(
                    color: Color(0xFFB8FFD0),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reward,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _rewardText(SearchResult? result) {
    if (result == null || result.rewardType == SearchRewardType.none) {
      return 'Внутри ничего не нашлось';
    }
    if (result.itemId != null) return 'Предмет: ${result.itemId}';
    final reward = switch (result.rewardType) {
      SearchRewardType.hp => 'здоровье',
      SearchRewardType.coins => 'монеты',
      SearchRewardType.xp => 'опыт',
      SearchRewardType.artifactCase => 'кейс артефакта',
      SearchRewardType.diceCase => 'кейс кости',
      SearchRewardType.item => 'предмет',
      SearchRewardType.none => 'ничего',
    };
    return '${result.amount} · $reward';
  }
}

class _SearchPalette {
  const _SearchPalette({
    required this.accent,
    required this.border,
    required this.glow,
    required this.dark,
    required this.mid,
  });

  final Color accent;
  final Color border;
  final Color glow;
  final Color dark;
  final Color mid;
}

class _SearchPropPainter extends CustomPainter {
  const _SearchPropPainter({
    required this.kind,
    required this.variant,
    required this.colors,
    required this.pulse,
    required this.reveal,
  });

  final LocationPropKind kind;
  final int variant;
  final _SearchPalette colors;
  final double pulse;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final paint = Paint()..isAntiAlias = true;
    final halo = 92 + math.sin(pulse * math.pi * 2) * 5;
    paint.color = colors.glow.withValues(alpha: 0.07 + reveal * 0.12);
    canvas.drawCircle(center, halo, paint);
    paint.color = const Color(0xFF0B111B).withValues(alpha: 0.6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 54),
        width: 190,
        height: 30,
      ),
      paint,
    );

    if (kind == LocationPropKind.trashBin) {
      _drawTrashBin(canvas, center, paint);
    } else {
      _drawBush(canvas, center, paint);
    }

    if (reveal > 0) _drawSparkles(canvas, center, paint);
  }

  void _drawBush(Canvas canvas, Offset center, Paint paint) {
    final sway = math.sin((variant + 1) * 0.9) * 3;
    paint.color = const Color(0xFF10271F);
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 74, center.dy + 12, 148, 40),
      paint,
    );

    final leaves = [
      Offset(-62, 5),
      Offset(-38, -26),
      Offset(-10, -40),
      Offset(18, -34),
      Offset(48, -19),
      Offset(66, 8),
      Offset(-43, 20),
      Offset(2, 12),
      Offset(38, 17),
    ];
    for (var i = 0; i < leaves.length; i++) {
      final leaf = leaves[i];
      final radius = 24 + (i + variant.abs()) % 3 * 4;
      paint.color = i.isEven ? colors.mid : colors.dark;
      canvas.drawCircle(
        center + Offset(leaf.dx + sway, leaf.dy),
        radius.toDouble(),
        paint,
      );
      paint.color = colors.accent.withValues(alpha: 0.38);
      canvas.drawRect(
        Rect.fromLTWH(
          center.dx + leaf.dx - 7 + sway,
          center.dy + leaf.dy - 10,
          8,
          5,
        ),
        paint,
      );
    }
    paint.color = const Color(0xFF6ECF78).withValues(alpha: 0.75);
    canvas.drawRect(Rect.fromLTWH(center.dx - 47, center.dy - 8, 7, 4), paint);
    canvas.drawRect(Rect.fromLTWH(center.dx + 27, center.dy - 24, 7, 4), paint);
  }

  void _drawTrashBin(Canvas canvas, Offset center, Paint paint) {
    final body = Rect.fromCenter(
      center: Offset(center.dx, center.dy + 4),
      width: 120,
      height: 130,
    );
    paint.color = const Color(0xFF172331);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body.inflate(7), const Radius.circular(12)),
      paint,
    );
    paint.color = colors.mid;
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(9)),
      paint,
    );
    paint.color = colors.dark;
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 42, center.dy - 20, 84, 8),
      paint,
    );
    paint.color = colors.accent.withValues(alpha: 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 66, center.dy - 68, 132, 16),
        const Radius.circular(7),
      ),
      paint,
    );
    paint.color = const Color(0xFF172331);
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 26, center.dy - 61, 52, 4),
      paint,
    );
    paint.color = colors.accent.withValues(alpha: 0.48);
    canvas.drawRect(Rect.fromLTWH(center.dx - 42, center.dy - 9, 7, 64), paint);
    canvas.drawRect(Rect.fromLTWH(center.dx + 35, center.dy - 9, 7, 64), paint);
    paint.color = const Color(0xFF101923);
    canvas.drawCircle(Offset(center.dx - 39, center.dy + 72), 10, paint);
    canvas.drawCircle(Offset(center.dx + 39, center.dy + 72), 10, paint);
    paint.color = const Color(0xFFFFD27D).withValues(alpha: 0.85);
    canvas.drawRect(Rect.fromLTWH(center.dx - 16, center.dy + 2, 32, 7), paint);
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 16, center.dy + 15, 32, 7),
      paint,
    );
  }

  void _drawSparkles(Canvas canvas, Offset center, Paint paint) {
    paint.color = const Color(0xFFFFD27D).withValues(alpha: reveal);
    for (var i = 0; i < 7; i++) {
      final angle = i * math.pi * 2 / 7;
      final distance = 70 + reveal * 35;
      final point =
          center +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);
      canvas.drawCircle(point, 2.5 + reveal * 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SearchPropPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.variant != variant ||
      oldDelegate.pulse != pulse ||
      oldDelegate.reveal != reveal;
}
