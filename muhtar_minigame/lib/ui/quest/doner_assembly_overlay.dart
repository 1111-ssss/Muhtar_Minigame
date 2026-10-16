import 'dart:async';

import 'package:flutter/material.dart';

/// Мини-игра Донера. Компоненты нарисованы процедурно, поэтому экран не
/// зависит от отсутствующих в репозитории спрайтов еды.
class DonerAssemblyOverlay extends StatefulWidget {
  const DonerAssemblyOverlay({
    required this.recipeId,
    required this.onSolved,
    required this.onClose,
    super.key,
  });

  final String recipeId;
  final VoidCallback onSolved;
  final VoidCallback onClose;

  @override
  State<DonerAssemblyOverlay> createState() => _DonerAssemblyOverlayState();
}

class _Ingredient {
  const _Ingredient(this.id, this.label, this.color, this.shape);

  final String id;
  final String label;
  final Color color;
  final int shape;
}

class _Recipe {
  const _Recipe(this.title, this.subtitle, this.steps);

  final String title;
  final String subtitle;
  final List<_Ingredient> steps;
}

const _lavash = _Ingredient('lavash', 'Лаваш', Color(0xFFE3B86B), 0);
const _meat = _Ingredient('meat', 'Мясо', Color(0xFFB9573B), 1);
const _chicken = _Ingredient('chicken', 'Курица', Color(0xFFD98C4A), 1);
const _cabbage = _Ingredient('cabbage', 'Капуста', Color(0xFF78B86A), 2);
const _onion = _Ingredient('onion', 'Лук', Color(0xFFC583C8), 2);
const _fries = _Ingredient('fries', 'Картошка', Color(0xFFE5C55B), 3);
const _sauce = _Ingredient('sauce', 'Соус', Color(0xFFD75D46), 4);
const _hotSauce = _Ingredient('hot_sauce', 'Острый соус', Color(0xFFF04E35), 4);
const _garlic = _Ingredient('garlic', 'Чесночный соус', Color(0xFFF0D5A0), 4);

const _recipes = <String, _Recipe>{
  'classic': _Recipe(
    'Классическая шаурма',
    'Соберите слои в правильном порядке: от лаваша до соуса.',
    [_lavash, _meat, _cabbage, _sauce],
  ),
  'spicy': _Recipe(
    'Острая шаурма',
    'Шаурмек проверяет внимательность: курица и острый соус идут строго по рецепту.',
    [_lavash, _chicken, _onion, _hotSauce],
  ),
  'signature': _Recipe(
    'Фирменный свёрток',
    'Фирменный порядок Донера: мясо, картошка и чесночный соус.',
    [_lavash, _meat, _fries, _garlic],
  ),
};

class _DonerAssemblyOverlayState extends State<DonerAssemblyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final CurvedAnimation _entrance;
  Timer? _feedbackTimer;

  int _nextStep = 0;
  String? _feedback;
  bool _positiveFeedback = false;
  bool _solved = false;

  _Recipe get _recipe => _recipes[widget.recipeId] ?? _recipes['classic']!;

  List<_Ingredient> get _tray {
    final steps = _recipe.steps;
    final decoy = steps.first.id == 'lavash' ? _fries : _lavash;
    return [...steps.skip(1).toList().reversed, decoy, steps.first];
  }

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
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _entrance.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _choose(_Ingredient ingredient) {
    if (_solved || _nextStep >= _recipe.steps.length) return;
    final expected = _recipe.steps[_nextStep];
    final correct = expected.id == ingredient.id;
    _feedbackTimer?.cancel();
    setState(() {
      _positiveFeedback = correct;
      _feedback = correct
          ? '${ingredient.label} добавлен'
          : 'Сначала нужен компонент «${expected.label}»';
      if (correct) _nextStep++;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  void _finish() {
    if (_solved || _nextStep != _recipe.steps.length) return;
    setState(() => _solved = true);
    widget.onSolved();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Material(
      color: const Color(0xFF0D111B),
      child: Stack(
        children: [
          const _DonerBackdrop(),
          SafeArea(
            child: FadeTransition(
              opacity: _entrance,
              child: ScaleTransition(
                scale: Tween<double>(begin: .96, end: 1).animate(_entrance),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _content(compact),
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

  Widget _content(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF38251E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFB05C)),
            ),
            child: const Icon(
              Icons.restaurant,
              color: Color(0xFFFFB05C),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'МИНИ-ИГРА ДОНЕРА',
                  style: TextStyle(
                    color: Color(0xFFFFB05C),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  _recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Закрыть сборку',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded),
            color: Colors.white70,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _recipe.subtitle,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
            const SizedBox(height: 18),
            _buildStack(compact),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                _feedback ?? 'Выберите первый компонент из подноса.',
                key: ValueKey(_feedback),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _feedback == null
                      ? Colors.white54
                      : _positiveFeedback
                      ? const Color(0xFF7DFFC1)
                      : const Color(0xFFFF8C8C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'КОМПОНЕНТЫ НА ПОДНОСЕ',
              style: TextStyle(
                color: Color(0xFFFFD58E),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [for (final ingredient in _tray) _ingredientButton(ingredient)],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _nextStep == _recipe.steps.length ? _finish : null,
        icon: const Icon(Icons.check_circle_outline),
        label: Text(_solved ? 'Готово' : 'Завершить сборку'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: const Color(0xFFFF9B4A),
          foregroundColor: const Color(0xFF28160D),
        ),
      ),
      if (!compact) const SizedBox(height: 4),
    ],
  );

  Widget _panel({required Widget child}) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE61A2130),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF4E3B34)),
      boxShadow: const [
        BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 8)),
      ],
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _buildStack(bool compact) {
    final slots = <Widget>[];
    for (var index = 0; index < _recipe.steps.length; index++) {
      final placed = index < _nextStep ? _recipe.steps[index] : null;
      slots.add(
        Expanded(
          child: _StackSlot(
            index: index,
            ingredient: placed,
            compact: compact,
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < slots.length; index++) ...[
          if (index > 0)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Icon(Icons.arrow_forward, color: Colors.white24, size: 18),
            ),
          slots[index],
        ],
      ],
    );
  }

  Widget _ingredientButton(_Ingredient ingredient) {
    final expected = _nextStep < _recipe.steps.length
        ? _recipe.steps[_nextStep]
        : null;
    final isExpected = expected?.id == ingredient.id;
    return Semantics(
      button: true,
      label: 'Компонент ${ingredient.label}',
      enabled: !_solved,
      child: InkWell(
        onTap: _solved ? null : () => _choose(ingredient),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 128,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          decoration: BoxDecoration(
            color: isExpected
                ? const Color(0xFF3C3026)
                : const Color(0xFF242A3A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isExpected ? const Color(0xFFFFB05C) : Colors.white12,
              width: isExpected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              CustomPaint(
                size: const Size(84, 54),
                painter: _IngredientPainter(ingredient),
              ),
              Text(
                ingredient.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackSlot extends StatelessWidget {
  const _StackSlot({
    required this.index,
    required this.ingredient,
    required this.compact,
  });

  final int index;
  final _Ingredient? ingredient;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: compact ? 92 : 112),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    decoration: BoxDecoration(
      color: ingredient == null ? Colors.white.withValues(alpha: .04) : const Color(0xFF302821),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: ingredient == null ? Colors.white12 : const Color(0xFFFFB05C),
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (ingredient == null)
          const Icon(Icons.add_circle_outline, color: Colors.white24, size: 32)
        else
          CustomPaint(
            size: const Size(62, 42),
            painter: _IngredientPainter(ingredient!),
          ),
        const SizedBox(height: 4),
        Text(
          ingredient?.label ?? 'Слой ${index + 1}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}

class _IngredientPainter extends CustomPainter {
  const _IngredientPainter(this.ingredient);

  final _Ingredient ingredient;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final center = Offset(size.width / 2, size.height / 2);
    paint.color = const Color(0x44000000);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, size.height - 5), width: 54, height: 9),
      paint,
    );
    paint.color = ingredient.color;
    switch (ingredient.shape) {
      case 0:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - 29, center.dy + 17)
            ..quadraticBezierTo(center.dx - 22, center.dy - 20, center.dx + 25, center.dy - 15)
            ..lineTo(center.dx + 29, center.dy + 17)
            ..close(),
          paint,
        );
        paint.color = const Color(0x66FFF2C2);
        canvas.drawRect(Rect.fromLTWH(center.dx - 15, center.dy - 3, 27, 4), paint);
      case 1:
        canvas.drawRect(Rect.fromCenter(center: center, width: 42, height: 25), paint);
        paint.color = ingredient.color.withValues(alpha: .65);
        for (var index = -1; index <= 1; index++) {
          canvas.drawRect(
            Rect.fromLTWH(center.dx + index * 12 - 3, center.dy - 13, 6, 26),
            paint,
          );
        }
      case 2:
        for (var index = -2; index <= 2; index++) {
          canvas.drawRect(
            Rect.fromLTWH(center.dx + index * 9 - 3, center.dy - 15 + (index.abs() * 2), 6, 28 - index.abs() * 3),
            paint,
          );
        }
      case 3:
        for (var index = -2; index <= 2; index++) {
          canvas.drawRect(
            Rect.fromLTWH(center.dx + index * 9 - 3, center.dy - 14 + (index.abs() * 2), 6, 28 - index.abs() * 3),
            paint,
          );
        }
        paint.color = const Color(0x99FFF0A2);
        canvas.drawRect(Rect.fromLTWH(center.dx - 21, center.dy - 5, 42, 3), paint);
      default:
        canvas.drawCircle(center, 18, paint);
        paint.color = const Color(0x99FFF1C1);
        canvas.drawRect(Rect.fromLTWH(center.dx - 15, center.dy - 2, 30, 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IngredientPainter oldDelegate) =>
      oldDelegate.ingredient != ingredient;
}

class _DonerBackdrop extends StatelessWidget {
  const _DonerBackdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B1514), Color(0xFF0D111B), Color(0xFF111A1C)],
      ),
    ),
    child: SizedBox.expand(),
  );
}
