import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/dialogue.dart';
import '../../domain/game_content.dart';
import '../../domain/quest.dart';
import '../../game/muhtar_game.dart';
import '../../game/world/npc_entity.dart';
import '../../game_logic/notification_service.dart';
import '../../game_logic/audio_service.dart';

/// Диалоговое окно с NPC. Реплики и ответы приходят из [DialogueTree].
class DialogOverlay extends StatefulWidget {
  const DialogOverlay(this.game, {super.key});

  final MuhtarGame game;

  @override
  State<DialogOverlay> createState() => _DialogOverlayState();
}

class _DialogOverlayState extends State<DialogOverlay>
    with SingleTickerProviderStateMixin {
  late String _nodeId;
  late final AnimationController _motionController;
  late final CurvedAnimation _motionAnimation;

  Timer? _typingTimer;
  String _typedText = '';
  bool _isTyping = false;
  bool _closing = false;
  bool _choosing = false;

  DialogueTree? get _tree {
    final npc = widget.game.talkingNpc;
    return npc == null ? null : GameContent.dialogueForNpc(npc.npcId);
  }

  DialogueNode? get _node => _tree?.nodeById(_nodeId);

  List<DialogueChoice> get _visibleChoices {
    final node = _node;
    if (node == null) return const [];
    return node.choices
        .where((choice) {
          final requiredQuestId = choice.requiredQuestId;
          if (requiredQuestId != null) {
            final progress = widget.game.gameState.quest(requiredQuestId);
            if (progress == null ||
                (choice.requiredQuestStates.isNotEmpty &&
                    !choice.requiredQuestStates.contains(progress.state))) {
              return false;
            }
          }
          final requiredEnemyId = choice.requiredEnemyId;
          final requiredLocationId = choice.requiredLocationId;
          if (requiredEnemyId != null && requiredLocationId != null &&
              !widget.game.gameState.hasDefeatedEnemyAt(
                requiredLocationId,
                requiredEnemyId,
              )) {
            return false;
          }
          final questId = choice.questId;
          if (questId != null) {
            final npcId = widget.game.talkingNpc?.npcId;
            if (!widget.game.gameState.canActivateQuest(
              questId,
              npcId: npcId,
            )) {
              return false;
            }
          }
          final deliveryId = choice.completeQuestId;
          if (deliveryId != null) {
            final progress = widget.game.gameState.quest(deliveryId);
            return progress?.state == QuestState.active &&
                progress?.quest.itemId != null &&
                widget.game.gameState.hasItem(progress!.quest.itemId!);
          }
          return true;
        })
        .toList(growable: false);
  }

  String _nodeText(DialogueNode node) {
    final questId = node.textQuestId;
    if (questId == null) {
      return node.text;
    }
    final state = widget.game.gameState.quest(questId)?.state;
    final outcome = widget.game.gameState.shawarmaOutcome;
    return node.textByShawarmaOutcome[outcome] ??
        node.textByQuestState[state] ??
        node.text;
  }

  @override
  void initState() {
    super.initState();
    _nodeId = _tree?.startNodeId ?? '';
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _motionAnimation = CurvedAnimation(
      parent: _motionController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    widget.game.registerDialogKeyboardHandler(_handleKeyboard);
    widget.game.registerWindowCloseHandler(MuhtarGame.overlayDialog, _close);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _motionController.forward();
      final node = _node;
      if (node != null) _startTyping(_resolvedText(_nodeText(node)));
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    widget.game.registerDialogKeyboardHandler(null);
    widget.game.unregisterWindowCloseHandler(MuhtarGame.overlayDialog);
    _motionAnimation.dispose();
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final npc = widget.game.talkingNpc;
    final node = _node;
    if (npc == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _motionAnimation,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.72),
        body: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.96,
                  end: 1,
                ).animate(_motionAnimation),
                child: _dialogPanel(context, npc, node),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogPanel(BuildContext context, NpcEntity npc, DialogueNode? node) {
    if (node == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: _panelDecoration(),
        child: FilledButton(
          onPressed: _close,
          child: const Text('Закрыть диалог'),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NpcPortrait(npcId: npc.npcId, label: npc.label),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    npc.label,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Закрыть диалог (Esc)',
                onPressed: _close,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _typewriterText(_resolvedText(_nodeText(node))),
          const SizedBox(height: 18),
          if (_visibleChoices.isEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: _ChoiceButton(
                label: 'Закрыть',
                onPressed: _close,
                primary: true,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < _visibleChoices.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AnimatedChoice(
                      index: index,
                      controller: _motionController,
                      child: _ChoiceButton(
                        label: _visibleChoices[index].label,
                        shortcut: index < 9 ? '${index + 1}' : null,
                        onPressed: () => _choose(_visibleChoices[index]),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 2),
          const Text(
            'Esc — закрыть   •   Пробел/клик по реплике — показать текст целиком',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: const Color(0xFF171923),
      border: Border.all(color: Colors.amber, width: 2),
      boxShadow: const [
        BoxShadow(color: Colors.black54, offset: Offset(6, 6), blurRadius: 0),
      ],
    );
  }

  Widget _typewriterText(String fullText) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 15,
      height: 1.45,
      fontFamily: 'monospace',
    );

    // Невидимый полный текст участвует в layout до старта печати. Поэтому
    // высота карточки стабильна и не прыгает на каждой новой букве.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skipTyping,
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          Opacity(opacity: 0, child: Text(fullText, style: style)),
          Text(_typedText, style: style),
        ],
      ),
    );
  }

  void _startTyping(String text) {
    _typingTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _typedText = '';
      _isTyping = text.isNotEmpty;
    });
    if (text.isEmpty) return;

    var index = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      index++;
      setState(() {
        _typedText = text.substring(0, index);
        _isTyping = index < text.length;
      });
      if (text.codeUnitAt(index - 1) != 0x20 &&
          text.codeUnitAt(index - 1) != 0x0A &&
          text.codeUnitAt(index - 1) != 0x09) {
        unawaited(widget.game.audio.play(GameSound.dialogueKey));
      }
      if (index >= text.length) timer.cancel();
    });
  }

  void _skipTyping() {
    if (!_isTyping) return;
    final node = _node;
    if (node == null) return;
    _typingTimer?.cancel();
    setState(() {
      _typedText = _resolvedText(_nodeText(node));
      _isTyping = false;
    });
  }

  String _resolvedText(String text) =>
      text.replaceAll('{playerName}', widget.game.gameState.playerName);

  void _handleKeyboard(LogicalKeyboardKey key) {
    if (_closing) return;
    if (key == LogicalKeyboardKey.space) {
      _skipTyping();
      return;
    }

    final index = _choiceIndexForKey(key);
    final node = _node;
    if (index == null || node == null || index >= _visibleChoices.length) {
      return;
    }
    _choose(_visibleChoices[index]);
  }

  int? _choiceIndexForKey(LogicalKeyboardKey key) {
    const digitKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const numpadKeys = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final digitIndex = digitKeys.indexOf(key);
    if (digitIndex >= 0) return digitIndex;
    final numpadIndex = numpadKeys.indexOf(key);
    return numpadIndex >= 0 ? numpadIndex : null;
  }

  Future<void> _choose(DialogueChoice choice) async {
    if (_choosing || !_visibleChoices.contains(choice)) return;
    _choosing = true;
    widget.game.audio.play(GameSound.ui);
    try {
      final questId = choice.questId;
      if (questId != null) {
        if (!widget.game.gameState.activateQuest(
          questId,
          npcId: widget.game.talkingNpc?.npcId,
        )) {
          return;
        }
        await widget.game.saveProgress();
      }
      final completeQuestId = choice.completeQuestId;
      if (completeQuestId != null) {
        if (!widget.game.gameState.completeDeliveryQuest(completeQuestId)) {
          return;
        }
        await widget.game.saveProgress();
      }
      final notification = choice.notification;
      if (notification != null) {
        widget.game.notifications.notify(
          notification,
          type: NotificationType.quest,
        );
      }

      if (choice.openQuestLog) {
        _close();
        widget.game.openQuests();
        return;
      }

      if (choice.openShop) {
        _close();
        widget.game.openUpgrade();
        return;
      }

      if (choice.openSongGame) {
        // Переключаемся на самостоятельное окно мини-игры: его состояние и
        // награда не смешиваются с узлами обычного диалога NPC.
        _typingTimer?.cancel();
        _closing = true;
        widget.game.overlays.remove(MuhtarGame.overlayDialog);
        widget.game.openSongMiniGame();
        return;
      }

      if (choice.openDonerGame) {
        _typingTimer?.cancel();
        _closing = true;
        widget.game.overlays.remove(MuhtarGame.overlayDialog);
        widget.game.openDonerAssembly(
          questId: choice.donerQuestId ?? choice.questId!,
          recipeId: choice.donerRecipeId ?? 'classic',
        );
        return;
      }

      if (choice.openVideoSequence) {
        _typingTimer?.cancel();
        _closing = true;
        widget.game.overlays.remove(MuhtarGame.overlayDialog);
        widget.game.openVideoSequence();
        return;
      }

      final nextNodeId = choice.nextNodeId;
      final nextNode = nextNodeId == null ? null : _tree?.nodeById(nextNodeId);
      if (nextNode == null) {
        _close();
        return;
      }
      setState(() => _nodeId = nextNodeId!);
      _startTyping(_resolvedText(_nodeText(nextNode)));
    } finally {
      _choosing = false;
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _typingTimer?.cancel();
    _motionController.reverse().whenCompleteOrCancel(() {
      if (mounted) widget.game.overlays.remove(MuhtarGame.overlayDialog);
    });
  }
}

class _AnimatedChoice extends StatelessWidget {
  const _AnimatedChoice({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (0.18 + index * 0.11).clamp(0.0, 0.72).toDouble();
    final end = (start + 0.28).clamp(0.28, 1.0).toDouble();
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _ChoiceButton extends StatefulWidget {
  const _ChoiceButton({
    required this.label,
    required this.onPressed,
    this.shortcut,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final String? shortcut;
  final bool primary;

  @override
  State<_ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<_ChoiceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.primary ? Colors.amber : Colors.amber.shade700;
    return Semantics(
      button: true,
      label: widget.shortcut == null
          ? widget.label
          : '${widget.shortcut}. ${widget.label}',
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Material(
          color: widget.primary ? Colors.amber.shade700 : Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                color: widget.primary ? Colors.amber.shade700 : null,
              ),
              child: Row(
                children: [
                  if (widget.shortcut != null) ...[
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        widget.shortcut!,
                        style: TextStyle(
                          color: Colors.brown.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.primary ? Colors.black : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NpcPortrait extends StatelessWidget {
  const _NpcPortrait({required this.npcId, required this.label});

  final String npcId;
  final String label;

  @override
  Widget build(BuildContext context) {
    final assetPath = 'assets/portraits/$npcId.png';
    return Semantics(
      image: true,
      label: 'Портрет персонажа $label',
      child: Container(
        width: 64,
        height: 78,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF252733),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade700),
        ),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) =>
              _PortraitFallback(label: label),
        ),
      ),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF252733),
    child: Center(
      child: Icon(
        Icons.person_outline,
        semanticLabel: 'Портрет $label недоступен',
        color: Colors.amber.shade300,
        size: 32,
      ),
    ),
  );
}
