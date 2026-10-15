import 'dart:ui';

import 'map_entity.dart';

/// NPC на карте. При тапе открывается диалоговое окно.
class NpcEntity extends MapEntity {
  NpcEntity({
    required this.npcId,
    required super.col,
    required super.row,
    required super.label,
    super.color = const Color(0xFFFFCA28),
    String? visualVariant,
  }) : super(kind: MapEntityKind.npc, visualVariant: visualVariant ?? npcId);

  final String npcId;
}
