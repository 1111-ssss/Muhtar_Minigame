import 'dart:ui';

import 'map_entity.dart';

/// Враг на карте. При тапе по нему начинается бой (если игрок рядом).
class EnemyEntity extends MapEntity {
  EnemyEntity({
    required this.enemyId,
    required super.col,
    required super.row,
    required super.label,
    required this.spawnKey,
    Color? color,
  }) : super(
         color:
             color ??
             switch (enemyId) {
               'shaurmek' => const Color(0xFFE07A42),
               'viktor_korneplod' => const Color(0xFF7B8F43),
               'gopnik' => const Color(0xFF3949AB),
               _ => const Color(0xFFEF5350),
             },
         kind: switch (enemyId) {
           'slime' => MapEntityKind.slime,
           'goblin' => MapEntityKind.goblin,
           'gopnik' => MapEntityKind.gopnik,
           'shaurmek' => MapEntityKind.shaurmek,
           'viktor_korneplod' => MapEntityKind.viktorKorneplod,
           _ => MapEntityKind.character,
         },
       );

  final String enemyId;
  final String spawnKey;
}
