import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/muhtar_game.dart';

/// Сюжетная сцена перед боем с Виктором Корнеплодом.
///
/// [onContinue] и [onSkip] позволяют подключить сцену к отдельному игровому
/// сценарию. Если их не передать, завершение и пропуск используют
/// [MuhtarGame.confirmBattle].
class PreBattleOverlay extends StatefulWidget {
  const PreBattleOverlay(
    this.game, {
    this.playerName,
    this.onContinue,
    this.onSkip,
    super.key,
  });

  final MuhtarGame game;
  final String? playerName;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;

  @override
  State<PreBattleOverlay> createState() => _PreBattleOverlayState();
}

class _PreBattleOverlayState extends State<PreBattleOverlay> {
  bool _handled = false;

  String get _resolvedPlayerName {
    final provided = widget.playerName?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return widget.game.gameState.playerName;
  }

  void _continue() {
    if (_handled) return;
    _handled = true;
    (widget.onContinue ?? widget.game.confirmBattle)();
  }

  void _skip() {
    if (_handled) return;
    _handled = true;
    (widget.onSkip ?? widget.game.confirmBattle)();
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _continue();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _skip();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Material(
      color: const Color(0xFF0C1112),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final portrait = constraints.maxWidth < constraints.maxHeight * .86;
          final imageWidth = portrait
              ? constraints.maxWidth * .94
              : constraints.maxWidth * .52;
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: imageWidth,
                child: Image.asset(
                  'assets/portraits/viktor_korneplod.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: Color(0xFF25251E),
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFFE3A85E),
                            size: 56,
                          ),
                        ),
                      ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF0C1112),
                        const Color(0xE60C1112),
                        const Color(
                          0xFF0C1112,
                        ).withValues(alpha: portrait ? .38 : .08),
                      ],
                      stops: const [0, .47, 1],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: Align(
                          alignment: portrait
                              ? Alignment.bottomCenter
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: portrait ? constraints.maxWidth : 590,
                            ),
                            child: _buildDialogue(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _buildHeader() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xD9211B19),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3A85E), width: 1.5),
        ),
        child: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFFFC857),
          size: 27,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ПЕРЕД БОЕМ',
              style: TextStyle(
                color: Color(0xFFFFC857),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Виктор Корнеплод',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildDialogue() => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE8171B1C),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x80E3A85E), width: 1.5),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogueLine(
            speaker: 'ВИКТОР',
            color: const Color(0xFFFFC857),
            text:
                'Твои мышцы, $_resolvedPlayerName, слишком слабые. Тебе не победить меня!',
          ),
          const SizedBox(height: 14),
          _DialogueLine(
            speaker: _resolvedPlayerName,
            color: const Color(0xFF8FE8D1),
            text: 'Очко твое слабое',
          ),
        ],
      ),
    ),
  );

  Widget _buildActions() => Wrap(
    spacing: 12,
    runSpacing: 10,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('pre-battle-skip'),
        onPressed: _skip,
        icon: const Icon(Icons.skip_next_rounded),
        label: const Text('Пропустить'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(150, 50),
          foregroundColor: const Color(0xFFE9D9C1),
          side: const BorderSide(color: Color(0xFFA9957E)),
        ),
      ),
      FilledButton.icon(
        key: const ValueKey('pre-battle-continue'),
        onPressed: _continue,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Продолжить'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(180, 50),
          backgroundColor: const Color(0xFFD68B3D),
          foregroundColor: const Color(0xFF211612),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );
}

class _DialogueLine extends StatelessWidget {
  const _DialogueLine({
    required this.speaker,
    required this.color,
    required this.text,
  });

  final String speaker;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        speaker,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
