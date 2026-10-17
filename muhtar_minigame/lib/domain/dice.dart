import 'package:flutter/foundation.dart';

/// Особый эффект боевой кости.
enum DiceAbility { none, warrior, doctor, ember, guardian, upgrade }

/// Одноразовый модификатор, который можно наложить на кость из инвентаря.
enum DiceModifier { none, light, heavy, glass }

extension DiceModifierInfo on DiceModifier {
  String get title => switch (this) {
    DiceModifier.none => 'Без модификатора',
    DiceModifier.light => 'Легкий',
    DiceModifier.heavy => 'Тяжелый',
    DiceModifier.glass => 'Стекло',
  };

  String get description => switch (this) {
    DiceModifier.none => 'Обычная кость.',
    DiceModifier.light => 'Не тратит энергию при размещении.',
    DiceModifier.heavy =>
      'После хода остается на доске и теряет уровень. Нельзя перемещать или снять.',
    DiceModifier.glass =>
      'Срабатывает при размещении с учетом клетки и разбивается.',
  };
}

extension DiceAbilityInfo on DiceAbility {
  String get description => switch (this) {
    DiceAbility.none => 'Атакующая кость.',
    DiceAbility.warrior => 'Наносит урон по выпавшей грани.',
    DiceAbility.doctor => 'Лечит героя на уровень этой кости.',
    DiceAbility.ember => 'Накладывает горение по выпавшей грани.',
    DiceAbility.guardian => 'Даёт щит по выпавшей грани.',
    DiceAbility.upgrade =>
      'Поставь на доску: усиливает выпавшее значение занятых клеток '
          'в фиксированной зоне. Уровень 1 затрагивает 8 клеток, уровень 6 — одну.',
  };
}

/// Одна кость в инвентаре: способность и уровень определяют её силу.
@immutable
class Dice {
  const Dice({
    required this.id,
    required this.name,
    required this.baseFaces,
    this.level = 1,
    this.ability = DiceAbility.none,
    this.modifier = DiceModifier.none,
    this.visualKey = 'blade',
  });

  final String id;
  final String name;

  /// Базовые грани кости (для d6 — [1,2,3,4,5,6]).
  final List<int> baseFaces;

  /// Уровень кости. Максимум — 6.
  final int level;

  /// Эффект, который срабатывает, когда эта кость использована в слоте.
  final DiceAbility ability;

  /// Модификатор, полученный из ящика артефактов.
  final DiceModifier modifier;

  /// Ключ визуального оформления в Flutter-оверлеях.
  final String visualKey;

  /// Старое представление для экрана контента; бой использует [rollFaces].
  List<int> get faces => baseFaces.map((face) => face + level - 1).toList();

  /// Максимальное значение на кости.
  int get maxFace => baseFaces.reduce((a, b) => a > b ? a : b) + level - 1;

  @Deprecated('Улучшение происходит объединением двух одинаковых костей')
  int get upgradeCost => 25 * level;

  /// Диапазон броска. Фактическое равномерное значение выбирает движок.
  List<int> get rollFaces {
    return [for (var face = level.clamp(1, 6).toInt(); face <= 6; face++) face];
  }

  static const int maxLevel = 6;

  bool get canUpgrade => level < maxLevel;

  Dice copyWith({
    int? level,
    DiceAbility? ability,
    DiceModifier? modifier,
    String? visualKey,
  }) => Dice(
    id: id,
    name: name,
    baseFaces: baseFaces,
    level: level ?? this.level,
    ability: ability ?? this.ability,
    modifier: modifier ?? this.modifier,
    visualKey: visualKey ?? this.visualKey,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dice &&
          other.id == id &&
          other.level == level &&
          other.modifier == modifier;

  @override
  int get hashCode => Object.hash(id, level, modifier);
}
