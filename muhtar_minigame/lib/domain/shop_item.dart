import 'package:flutter/foundation.dart';

enum ShopEffect { heal, increaseMaxHp, addItem, damage }

@immutable
class ShopItem {
  const ShopItem({
    required this.id,
    required this.npcId,
    required this.title,
    required this.description,
    required this.price,
    required this.effect,
    this.amount = 0,
    this.itemId,
    this.requiredQuestId,
  });

  final String id;
  final String npcId;
  final String title;
  final String description;
  final int price;
  final ShopEffect effect;
  final int amount;
  final String? itemId;
  final String? requiredQuestId;
}
