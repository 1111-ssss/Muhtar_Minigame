/// Редкость награды определяет вес выпадения из ящика артефактов.
enum ArtifactRarity { common, rare, epic, veryRare }

extension ArtifactRarityInfo on ArtifactRarity {
  String get title => switch (this) {
    ArtifactRarity.common => 'Обычный',
    ArtifactRarity.rare => 'Редкий',
    ArtifactRarity.epic => 'Эпический',
    ArtifactRarity.veryRare => 'Очень редкий',
  };

  /// Вес выбора без замены. Чем он меньше, тем реже артефакт предлагается.
  int get dropWeight => switch (this) {
    ArtifactRarity.common => 6,
    ArtifactRarity.rare => 3,
    ArtifactRarity.epic => 2,
    ArtifactRarity.veryRare => 1,
  };
}

/// Постоянные пассивные эффекты. Артефакты уникальны и не складываются.
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
    ironThread =>
      '+2 щита на этот ход, если в начале хода у героя нет щита. Артефакт уникален.',
    whetstone => '+1 урона каждой атакующей кости. Артефакт уникален.',
    fieldKit => 'Лечит 2 HP в конце раунда. Артефакт уникален.',
    emberHeart => '+1 горения каждой огненной кости. Артефакт уникален.',
    luckyCharm => '+1 реролл за раунд, суммарно не более 6. Артефакт уникален.',
  };

  ArtifactRarity get rarity => switch (this) {
    Artifact.truceSeal => ArtifactRarity.rare,
    Artifact.ironThread => ArtifactRarity.rare,
    Artifact.whetstone => ArtifactRarity.rare,
    Artifact.fieldKit => ArtifactRarity.veryRare,
    Artifact.emberHeart => ArtifactRarity.epic,
    Artifact.luckyCharm => ArtifactRarity.rare,
  };

  bool get stackable => false;
}

enum CaseType { dice, artifact }

extension CaseTypeInfo on CaseType {
  String get title => this == CaseType.dice ? 'Ящик костей' : 'Ящик артефактов';
  String get description => this == CaseType.dice
      ? 'Случайный тип и уровень 1–3'
      : 'Модификатор и случайные артефакты — выберите один';
}
