/// Редкость награды определяет вес выпадения из ящика артефактов.
enum ArtifactRarity { common, rare, epic }

extension ArtifactRarityInfo on ArtifactRarity {
  String get title => switch (this) {
    ArtifactRarity.common => 'Обычный',
    ArtifactRarity.rare => 'Редкий',
    ArtifactRarity.epic => 'Эпический',
  };

  /// Вес выбора без замены. Чем он меньше, тем реже артефакт предлагается.
  int get dropWeight => switch (this) {
    ArtifactRarity.common => 6,
    ArtifactRarity.rare => 3,
    ArtifactRarity.epic => 1,
  };
}

/// Постоянные пассивные эффекты. Большинство артефактов уникальны и не
/// складываются; Железная нить и Точильный камень остаются стакаемыми.
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
          'Артефакт уникален и не складывается.',
    ironThread => '+2 щита каждый раунд. Этот артефакт складывается.',
    whetstone => '+1 урона каждой атакующей кости. Этот артефакт складывается.',
    fieldKit => 'Лечит 2 HP в конце раунда. Артефакт уникален.',
    emberHeart => '+1 горения каждой огненной кости. Артефакт уникален.',
    luckyCharm => '+1 реролл за раунд, суммарно не более 6. Артефакт уникален.',
  };

  ArtifactRarity get rarity => switch (this) {
    Artifact.truceSeal => ArtifactRarity.rare,
    Artifact.ironThread => ArtifactRarity.common,
    Artifact.whetstone => ArtifactRarity.common,
    Artifact.fieldKit => ArtifactRarity.rare,
    Artifact.emberHeart => ArtifactRarity.epic,
    Artifact.luckyCharm => ArtifactRarity.rare,
  };

  bool get stackable => this == Artifact.ironThread || this == Artifact.whetstone;
}

enum CaseType { dice, artifact }

extension CaseTypeInfo on CaseType {
  String get title => this == CaseType.dice ? 'Ящик костей' : 'Ящик артефактов';
  String get description => this == CaseType.dice
      ? 'Случайный тип и уровень 1–3'
      : 'Модификатор и случайные артефакты — выберите один';
}
