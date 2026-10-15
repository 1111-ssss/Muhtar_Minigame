import 'package:flutter/foundation.dart';

import 'equipment.dart';

/// Архетип врага: характеристики и поведение в бою (данные, не код).
///
/// TODO(сюжет): имена, реплики и награды будут наполнены сюжетным контентом.
@immutable
class EnemyArchetype {
  const EnemyArchetype({
    required this.id,
    required this.name,
    required this.maxHp,
    required this.diceFaces,
    required this.equipment,
    this.coins = 10,
    this.xp = 8,
    this.actsFirst = false,
    this.appliesBurn = false,
    this.burnDamage = 0,
    this.startingShield = 0,
    this.attackPhrases = const [],
    this.rootCells = 0,
    this.coinStealChance = 0,
  });

  final String id;
  final String name;
  final int maxHp;

  /// Грани боевой кости врага.
  final List<int> diceFaces;

  /// Слоты экипировки врага (то же, что и у игрока).
  final List<EquipmentSlot> equipment;

  /// Монеты за победу.
  final int coins;

  /// Опыт за победу.
  final int xp;

  /// Особенности архетипа, которые читаются боевым движком.
  final bool actsFirst;
  final bool appliesBurn;
  final int burnDamage;
  final int startingShield;

  /// Реплики, которые враг произносит по очереди в начале раундов.
  final List<String> attackPhrases;

  /// Количество корневых клеток для особой механики Виктора.
  final int rootCells;

  /// Вероятность кражи монет при атаке, если механика врага её использует.
  final double coinStealChance;
}
