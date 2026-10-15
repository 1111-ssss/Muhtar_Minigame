/// Постоянные пассивные эффекты. Повторный выбор увеличивает число копий;
/// числовые бонусы складываются, Печать перемирия действует один раз за бой.
enum Artifact {
  truceSeal,
  ironThread,
  whetstone,
  fieldKit,
  emberHeart,
  luckyCharm;

  String get title => switch (this) {
    truceSeal => 'Печать перемирия',
    ironThread => 'Железная нить',
    whetstone => 'Точильный камень',
    fieldKit => 'Походная аптечка',
    emberHeart => 'Сердце углей',
    luckyCharm => 'Счастливый узел',
  };

  String get description => switch (this) {
    truceSeal =>
      'В первом раунде защищает от урона и поджога, если ваша '
          'атака не пробивает щит врага и на враге ещё нет горения. '
          'Дополнительные копии не усиливают эффект.',
    ironThread => '+2 щита каждый раунд за каждую копию.',
    whetstone => '+1 урона каждой атакующей кости за каждую копию.',
    fieldKit => 'Лечит 2 HP в конце раунда за каждую копию. Не воскрешает.',
    emberHeart => '+1 горения каждой огненной кости за каждую копию.',
    luckyCharm => '+1 реролл за раунд за каждую копию, суммарно не более 6.',
  };
}

enum CaseType { dice, artifact }

extension CaseTypeInfo on CaseType {
  String get title => this == CaseType.dice ? 'Кейс кости' : 'Кейс артефактов';
  String get description => this == CaseType.dice
      ? 'Случайная способность и уровень 1–6'
      : 'Три случайных артефакта — выберите один';
}
