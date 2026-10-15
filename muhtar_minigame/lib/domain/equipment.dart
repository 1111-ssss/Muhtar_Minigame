import 'package:flutter/foundation.dart';

/// Тип эффекта, который даёт слот экипировки при помещении в него кости.
enum SlotEffect { damage, shield, heal, burn, poison, upgrade }

/// Слот экипировки: принимает кость по правилу [rule] и применяет эффект.
///
/// Правила как в Dicey Dungeons: одни слоты берут любую кость, другие —
/// только чётные/нечётные/определённое значение и выше.
@immutable
class EquipmentSlot {
  const EquipmentSlot({
    required this.id,
    required this.name,
    required this.effect,
    required this.rule,
    this.minValue = 0,
  });

  final String id;
  final String name;
  final SlotEffect effect;
  final SlotRule rule;

  /// Минимальное значение для правила minValue (и база для кратности multiplier).
  final int minValue;

  bool accepts(int value) => rule.accepts(value, minValue);

  /// Человекочитаемое описание правила.
  String get ruleDescription {
    switch (rule) {
      case SlotRule.any:
        return 'любая кость';
      case SlotRule.even:
        return 'чётное значение';
      case SlotRule.odd:
        return 'нечётное значение';
      case SlotRule.minValue:
        return 'значение ≥ $minValue';
      case SlotRule.multiplier:
        return 'кратно $minValue';
    }
  }
}

/// Правило приёма кости в слот.
enum SlotRule {
  any,
  even,
  odd,
  minValue,
  multiplier;

  bool accepts(int value, int minValue) {
    switch (this) {
      case SlotRule.any:
        return true;
      case SlotRule.even:
        return value % 2 == 0;
      case SlotRule.odd:
        return value % 2 == 1;
      case SlotRule.minValue:
        return value >= minValue;
      case SlotRule.multiplier:
        return minValue > 0 && value % minValue == 0;
    }
  }
}
