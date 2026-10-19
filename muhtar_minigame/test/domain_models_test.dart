import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/equipment.dart';
import 'package:muhtar_minigame/domain/player_skin.dart';

void main() {
  test('equipment slot rules accept only their advertised values', () {
    const cases = <SlotRule, List<Object>>{
      SlotRule.any: [1, 6, true],
      SlotRule.even: [2, 6, false, 3],
      SlotRule.odd: [1, 5, false, 4],
      SlotRule.minValue: [4, 5, false, 3],
      SlotRule.multiplier: [6, 12, false, 5],
    };

    expect(SlotRule.multiplier.accepts(6, 0), isFalse);
    for (final entry in cases.entries) {
      final values = entry.value;
      final accepted = values.take(2).cast<int>();
      final rejected = values.skip(2).cast<Object>();

      for (final value in accepted) {
        final minValue = entry.key == SlotRule.minValue
            ? 4
            : entry.key == SlotRule.multiplier
            ? 3
            : 0;
        expect(
          entry.key.accepts(value, minValue),
          isTrue,
          reason: '${entry.key} should accept $value',
        );
      }
      for (final value in rejected.whereType<int>()) {
        final minValue = entry.key == SlotRule.minValue
            ? 4
            : entry.key == SlotRule.multiplier
            ? 3
            : 0;
        expect(
          entry.key.accepts(value, minValue),
          isFalse,
          reason: '${entry.key} should reject $value',
        );
      }
    }
  });

  test('equipment metadata has readable text for every variant', () {
    expect(SlotEffect.values.map((effect) => effect.title), [
      'Урон',
      'Щит',
      'Лечение',
      'Горение',
      'Яд',
      'Улучшение',
    ]);
    expect(AbilityRarity.values.map((rarity) => rarity.title), [
      'Обычная',
      'Редкая',
      'Эпическая',
      'Легендарная',
    ]);

    const slots = [
      EquipmentSlot(
        id: 'any',
        name: 'Любая',
        effect: SlotEffect.damage,
        rule: SlotRule.any,
      ),
      EquipmentSlot(
        id: 'even',
        name: 'Чётная',
        effect: SlotEffect.shield,
        rule: SlotRule.even,
      ),
      EquipmentSlot(
        id: 'odd',
        name: 'Нечётная',
        effect: SlotEffect.heal,
        rule: SlotRule.odd,
      ),
      EquipmentSlot(
        id: 'min',
        name: 'Порог',
        effect: SlotEffect.burn,
        rule: SlotRule.minValue,
        minValue: 4,
      ),
      EquipmentSlot(
        id: 'multiple',
        name: 'Кратно',
        effect: SlotEffect.poison,
        rule: SlotRule.multiplier,
        minValue: 3,
        rarity: AbilityRarity.legendary,
      ),
    ];

    expect(slots.map((slot) => slot.ruleDescription), [
      'любая кость',
      'чётное значение',
      'нечётное значение',
      'значение ≥ 4',
      'кратно 3',
    ]);
    expect(slots.last.rarity, AbilityRarity.legendary);
  });

  test('player skin catalog resolves known and unknown ids', () {
    expect(PlayerSkin.defaultSkin.title, 'Буберчик');
    expect(PlayerSkin.defaultSkin.spriteAsset, isNull);
    expect(PlayerSkin.byId('default'), PlayerSkin.defaultSkin);
    expect(PlayerSkin.byId('ribka_reward'), PlayerSkin.ribkaRewardSkin);
    expect(PlayerSkin.byId('kartofla'), PlayerSkin.kartoflaSkin);
    expect(PlayerSkin.byId('missing-skin'), isNull);
    expect(PlayerSkin.catalog, hasLength(3));
  });
}
