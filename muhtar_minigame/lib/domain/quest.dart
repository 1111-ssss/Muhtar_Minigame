import 'package:flutter/foundation.dart';

/// Задание. Тип цели определяет, как считается прогресс.
enum QuestType { kill, collect, location, deliverItem, purchaseItem, miniGame }

enum QuestState { notStarted, active, completed, claimed }

@immutable
class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.coinReward,
    this.enemyId,
    this.locationId,
    this.itemId,
    this.acceptanceNpcId,
    this.acceptancePropId,
    this.xpReward = 15,
    this.artifactCaseReward = 1,
    this.skinRewardId,
    this.searchPropId,
    this.miniGameId,
  });

  final String id;
  final String title;
  final String description;

  /// Тип цели: убить врагов, собрать монет, посетить локацию.
  final QuestType type;

  /// Сколько единиц надо набрать.
  final int target;

  /// Награда в монетах.
  final int coinReward;

  /// Награда в опыте.
  final int xpReward;
  final int artifactCaseReward;

  /// Для типа kill — id врага.
  final String? enemyId;

  /// Для типа location — id локации.
  final String? locationId;

  /// Для deliverItem — предмет, который нужно принести.
  final String? itemId;

  /// Если задан, задание можно взять только через этого NPC.
  final String? acceptanceNpcId;

  /// Если задан, задание можно взять только через этот интерактивный объект.
  final String? acceptancePropId;

  /// Скин, который выдаётся при получении награды за задание.
  final String? skinRewardId;

  /// Необязательный id объекта, с которым связано поисковое задание.
  final String? searchPropId;

  /// Id мини-игры, которая продвигает задание типа [QuestType.miniGame].
  final String? miniGameId;
}
