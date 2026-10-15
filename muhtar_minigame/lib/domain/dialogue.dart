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
  });

  final String label;
  final String? nextNodeId;
  final String? questId;
  final String? completeQuestId;
  final String? notification;
  final bool openQuestLog;
  final bool openShop;
  final bool openSongGame;
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
  });

  final String id;
  final String text;
  final List<DialogueChoice> choices;
  final String? textQuestId;
  final Map<QuestState, String> textByQuestState;
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
