import 'package:flutter/foundation.dart';

/// Внешний вид героя, доступный в каталоге игры.
@immutable
class PlayerSkin {
  const PlayerSkin({
    required this.id,
    required this.name,
    required this.portraitKey,
    this.spriteAsset,
  });

  final String id;
  final String name;
  final String portraitKey;

  /// Необязательный спрайт мира. Если его нет, рендерер может использовать
  /// процедурный внешний вид героя.
  final String? spriteAsset;

  String get title => name;

  static const PlayerSkin defaultSkin = PlayerSkin(
    id: 'default',
    name: 'Буберчик',
    portraitKey: 'player',
  );

  static const PlayerSkin ribkaRewardSkin = PlayerSkin(
    id: 'ribka_reward',
    name: 'Рибка',
    portraitKey: 'player_ribka_reward',
  );

  static const PlayerSkin rewardSkin = ribkaRewardSkin;
  static const PlayerSkin ribkaReward = ribkaRewardSkin;

  static const List<PlayerSkin> catalog = [defaultSkin, ribkaRewardSkin];

  static PlayerSkin? byId(String id) {
    for (final skin in catalog) {
      if (skin.id == id) return skin;
    }
    return null;
  }
}
