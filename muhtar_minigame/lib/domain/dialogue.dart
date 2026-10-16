import 'package:flutter/foundation.dart';

import 'quest.dart';

/// Один вариант ответа в дереве диалога.
///
/// Сюжет можно расширять данными: UI не знает, что именно происходит после
/// выбора — переход к следующей реплике, активация задания или закрытие.
@immutable
class DialogueChoice {
  const DialogueChoice({
    required this.label,
    this.nextNodeId,
    this.questId,
    this.completeQuestId,
    this.notification,
    this.openQuestLog = false,
    this.openShop = false,
    this.openSongGame = false,
    this.openDonerGame = false,
    this.donerQuestId,
    this.donerRecipeId,
    this.openVideoSequence = false,
    this.requiredQuestId,
    this.requiredQuestStates = const {},
    this.requiredEnemyId,
    this.requiredLocationId,
  });

  final String label;
  final String? nextNodeId;
  final String? questId;
  final String? completeQuestId;
  final String? notification;
  final bool openQuestLog;
  final bool openShop;
  final bool openSongGame;
  final bool openDonerGame;
  final String? donerQuestId;
  final String? donerRecipeId;
  final bool openVideoSequence;

  /// Дополнительные условия показа варианта. Они позволяют одному диалогу
  /// вести несколько последовательных заданий без копирования дерева.
  final String? requiredQuestId;
  final Set<QuestState> requiredQuestStates;
  final String? requiredEnemyId;
  final String? requiredLocationId;
}

/// Реплика персонажа и доступные ответы.
@immutable
class DialogueNode {
  const DialogueNode({
    required this.id,
    required this.text,
    this.choices = const [],
    this.textQuestId,
    this.textByQuestState = const {},
    this.textByShawarmaOutcome = const {},
  });

  final String id;
  final String text;
  final List<DialogueChoice> choices;
  final String? textQuestId;
  final Map<QuestState, String> textByQuestState;

  /// Ветвление для Ильи после выбора «съесть»/«отнести» шаурму.
  final Map<String, String> textByShawarmaOutcome;
}

/// Дерево диалога одного NPC.
@immutable
class DialogueTree {
  const DialogueTree({required this.startNodeId, required this.nodes});

  final String startNodeId;
  final List<DialogueNode> nodes;

  DialogueNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }
}
