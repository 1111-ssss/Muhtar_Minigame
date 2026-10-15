import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Самостоятельная мини-игра на сборку фразы из двух слов.
///
/// Виджет самостоятелен: родитель решает, как открыть/закрыть его и что
/// делать после правильного ответа.
class SongMinigameOverlay extends StatefulWidget {
  const SongMinigameOverlay({
    required this.onSolved,
    required this.onClose,
    super.key,
  });

  /// Вызывается один раз после выбора правильной пары слов.
  final VoidCallback onSolved;

  /// Вызывается кнопкой закрытия или клавишей Escape.
  final VoidCallback onClose;

  @override
  State<SongMinigameOverlay> createState() => _SongMinigameOverlayState();
}

class _SongMinigameOverlayState extends State<SongMinigameOverlay>
    with SingleTickerProviderStateMixin {
  static const _words = [
    _WordChoice(index: 0, text: 'сломал'),
    _WordChoice(index: 1, text: 'был там'),
    _WordChoice(index: 2, text: 'не видел'),
    _WordChoice(index: 3, text: 'упал'),
    _WordChoice(index: 4, text: 'не сломал'),
    _WordChoice(index: 5, text: 'сделал слайм'),
    _WordChoice(index: 6, text: 'был там'),
    _WordChoice(index: 7, text: 'себе'),
  ];

  late final AnimationController _entranceController;
  late final CurvedAnimation _entrance;

  final List<int?> _selectedIndexes = [null, null];
  Timer? _resetTimer;
  String? _feedback;
  bool _feedbackIsPositive = false;
  bool _isResetting = false;
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _entrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        _entranceController.value = 1;
      } else {
        _entranceController.forward();
      }
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _entrance.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Duration _duration(BuildContext context, int milliseconds) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false
        ? Duration.zero
        : Duration(milliseconds: milliseconds);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: const Color(0xFF0D111B),
        child: Stack(
          children: [
            const _BackgroundGlow(),
            SafeArea(
              child: FadeTransition(
                opacity: _entrance,
                child: ScaleTransition(
                  scale: Tween<double>(begin: .96, end: 1).animate(_entrance),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: _content(context, constraints),
                        ),
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
  }

  Widget _content(BuildContext context, BoxConstraints constraints) {
    final compact = constraints.maxWidth < 520;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const SizedBox(height: 20),
        _panel(
          compact: compact,
          children: [
            _buildPrompt(),
            const SizedBox(height: 22),
            _buildPhrase(compact: compact),
            const SizedBox(height: 20),
            _buildFeedback(context),
          ],
        ),
        const SizedBox(height: 18),
        _buildWordTray(context, compact: compact),
        const SizedBox(height: 16),
        _buildFooter(),
      ],
    );
  }

  Widget _header() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF26334D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF7EE7CF)),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          color: Color(0xFF7EE7CF),
          size: 25,
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'МИНИ-ИГРА',
              style: TextStyle(
                color: Color(0xFF7EE7CF),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Поймай правильную фразу',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Закрыть мини-игру',
        onPressed: widget.onClose,
        icon: const Icon(Icons.close_rounded),
        color: Colors.white70,
        iconSize: 27,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    ],
  );

  Widget _panel({required bool compact, required List<Widget> children}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE61A2130),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF394A68)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildPrompt() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'СОБЕРИ ОТГОВОР',
        style: TextStyle(
          color: Colors.white.withValues(alpha: .62),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.7,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Выбери по одному слову для каждого пропуска.',
        style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.35),
      ),
    ],
  );

  Widget _buildPhrase({required bool compact}) {
    final phraseStyle = TextStyle(
      color: Colors.white,
      fontSize: compact ? 19 : 24,
      height: 1.25,
      fontWeight: FontWeight.w800,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 12,
      children: [
        Text('Я недавно', style: phraseStyle),
        _PhraseSlot(
          key: const ValueKey('song-slot-first'),
          label: 'первый пропуск',
          selectedWord: _selectedWord(0),
          acceptsWord: !_isResetting && !_solved,
          compact: compact,
          onAccept: (choice) => _dropWord(0, choice.index),
        ),
        Text('но ничего', style: phraseStyle),
        _PhraseSlot(
          key: const ValueKey('song-slot-second'),
          label: 'второй пропуск',
          selectedWord: _selectedWord(1),
          acceptsWord: !_isResetting && !_solved,
          compact: compact,
          onAccept: (choice) => _dropWord(1, choice.index),
        ),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context) {
    final feedback = _feedback;
    return AnimatedSwitcher(
      duration: _duration(context, 180),
      child: feedback == null
          ? const SizedBox(key: ValueKey('empty-feedback'), height: 22)
          : Row(
              key: ValueKey(feedback),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _feedbackIsPositive
                      ? Icons.check_circle_rounded
                      : Icons.refresh_rounded,
                  color: _feedbackIsPositive
                      ? const Color(0xFF7EE7CF)
                      : const Color(0xFFFFD58E),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    feedback,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _feedbackIsPositive
                          ? const Color(0xFF7EE7CF)
                          : const Color(0xFFFFD58E),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWordTray(BuildContext context, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
            'СЛОВА',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.7,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: compact ? 8 : 10,
          runSpacing: compact ? 8 : 10,
          children: [
            for (var index = 0; index < _words.length; index++)
              _AnimatedWordBlock(
                index: index,
                controller: _entranceController,
                child: _buildWordBlock(context, _words[index]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWordBlock(BuildContext context, _WordChoice choice) {
    final selectedSlot = _selectedIndexes.indexOf(choice.index);
    final selected = selectedSlot >= 0;
    final disabled = _isResetting || _solved;
    final word = _WordBlock(
      choice: choice,
      selected: selected,
      disabled: disabled,
      onTap: disabled ? null : () => _chooseWord(choice.index),
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      selected: selected,
      label: selected
          ? '${choice.text}, выбрано для ${selectedSlot == 0 ? 'первого' : 'второго'} пропуска'
          : choice.text,
      child: LongPressDraggable<_WordChoice>(
        data: choice,
        maxSimultaneousDrags: disabled ? 0 : 1,
        feedback: Material(
          color: Colors.transparent,
          child: _WordBlock(
            choice: choice,
            selected: true,
            disabled: false,
            onTap: null,
          ),
        ),
        childWhenDragging: Opacity(opacity: .32, child: word),
        child: word,
      ),
    );
  }

  Widget _buildFooter() => Row(
    children: [
      const Expanded(
        child: Text(
          'Нажми на слово или зажми его, чтобы перетащить.',
          style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.3),
        ),
      ),
      const SizedBox(width: 12),
      OutlinedButton(
        onPressed: _isResetting || _solved ? null : _clearSelection,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB5C4E3),
          side: const BorderSide(color: Color(0xFF526481)),
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: const Text('Сбросить'),
      ),
    ],
  );

  String? _selectedWord(int slot) {
    final index = _selectedIndexes[slot];
    return index == null ? null : _words[index].text;
  }

  void _chooseWord(int wordIndex) {
    if (_isResetting || _solved) return;
    final selectedSlot = _selectedIndexes.indexOf(wordIndex);
    if (selectedSlot >= 0) {
      setState(() => _selectedIndexes[selectedSlot] = null);
      return;
    }

    final slot = _selectedIndexes.indexOf(null);
    if (slot < 0) return;
    _placeWord(slot, wordIndex);
  }

  void _dropWord(int slot, int wordIndex) {
    if (_isResetting || _solved) return;
    _placeWord(slot, wordIndex);
  }

  void _placeWord(int slot, int wordIndex) {
    final selectedElsewhere = _selectedIndexes.indexOf(wordIndex);
    setState(() {
      if (selectedElsewhere >= 0 && selectedElsewhere != slot) {
        _selectedIndexes[selectedElsewhere] = null;
      }
      _selectedIndexes[slot] = wordIndex;
    });

    if (_selectedIndexes.every((index) => index != null)) {
      _checkPair();
    }
  }

  void _checkPair() {
    final first = _selectedWord(0);
    final second = _selectedWord(1);
    if (first == 'упал' && second == 'не сломал') {
      _solved = true;
      setState(() {
        _feedback = 'Верно! Фраза звучит естественно.';
        _feedbackIsPositive = true;
      });
      widget.onSolved();
      return;
    }

    _isResetting = true;
    setState(() {
      _feedback = 'Почти! Попробуй собрать фразу ещё раз.';
      _feedbackIsPositive = false;
    });
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 720), () {
      if (!mounted) return;
      setState(() {
        _selectedIndexes[0] = null;
        _selectedIndexes[1] = null;
        _feedback = null;
        _isResetting = false;
      });
    });
  }

  void _clearSelection() {
    if (_isResetting || _solved) return;
    setState(() {
      _selectedIndexes[0] = null;
      _selectedIndexes[1] = null;
      _feedback = null;
    });
  }
}

class _WordChoice {
  const _WordChoice({required this.index, required this.text});

  final int index;
  final String text;
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: _GlowOrb(
            color: const Color(0xFF3D6D87).withValues(alpha: .3),
            size: 300,
          ),
        ),
        Positioned(
          bottom: -150,
          left: -90,
          child: _GlowOrb(
            color: const Color(0xFF594E83).withValues(alpha: .3),
            size: 340,
          ),
        ),
      ],
    ),
  );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 35)],
    ),
    child: SizedBox(width: size, height: size),
  );
}

class _PhraseSlot extends StatelessWidget {
  const _PhraseSlot({
    super.key,
    required this.label,
    required this.selectedWord,
    required this.acceptsWord,
    required this.compact,
    required this.onAccept,
  });

  final String label;
  final String? selectedWord;
  final bool acceptsWord;
  final bool compact;
  final ValueChanged<_WordChoice> onAccept;

  @override
  Widget build(BuildContext context) {
    final selected = selectedWord != null;
    return Semantics(
      label: selected ? '$label: $selectedWord' : '$label: пусто',
      container: true,
      child: DragTarget<_WordChoice>(
        onWillAcceptWithDetails: (_) => acceptsWord,
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidateData, _) {
          final hovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: BoxConstraints(
              minWidth: compact ? 112 : 138,
              minHeight: compact ? 48 : 54,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hovering
                  ? const Color(0xFF2D5360)
                  : selected
                  ? const Color(0xFF263F50)
                  : const Color(0xFF111827),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: hovering || selected
                    ? const Color(0xFF7EE7CF)
                    : const Color(0xFF5B6B88),
                width: selected || hovering ? 2 : 1,
              ),
            ),
            child: AnimatedSwitcher(
              duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: Text(
                selectedWord ?? '___',
                key: ValueKey(selectedWord),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: compact ? 15 : 17,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WordBlock extends StatelessWidget {
  const _WordBlock({
    required this.choice,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final _WordChoice choice;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: disabled ? .55 : 1,
    duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
        ? Duration.zero
        : const Duration(milliseconds: 160),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
              ? Duration.zero
              : const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF304A5E) : const Color(0xFF202B40),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? const Color(0xFF7EE7CF)
                  : const Color(0xFF465876),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x447EE7CF),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            choice.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AnimatedWordBlock extends StatelessWidget {
  const _AnimatedWordBlock({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (0.16 + index * 0.06).clamp(0.0, 0.58).toDouble();
    final end = (start + 0.3).clamp(0.3, 1.0).toDouble();
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
