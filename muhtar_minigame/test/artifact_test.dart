import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/domain/artifact.dart';

void main() {
  test('artifact rarity exposes titles and weighted drop chances', () {
    expect(ArtifactRarity.values.map((rarity) => rarity.title), [
      'Обычный',
      'Редкий',
      'Эпический',
      'Очень редкий',
    ]);
    expect(ArtifactRarity.values.map((rarity) => rarity.dropWeight), [
      6,
      3,
      2,
      1,
    ]);
  });

  test('artifact catalog has stable descriptions and unique rewards', () {
    expect(Artifact.values, hasLength(6));
    expect(
      Artifact.values.map((artifact) => artifact.title),
      everyElement(isNotEmpty),
    );
    expect(
      Artifact.values.map((artifact) => artifact.description),
      everyElement(contains('Артефакт уникален')),
    );
    expect(
      Artifact.values,
      everyElement(predicate<Artifact>((artifact) => !artifact.stackable)),
    );
    expect(Artifact.fieldKit.rarity, ArtifactRarity.veryRare);
    expect(Artifact.emberHeart.rarity, ArtifactRarity.epic);
  });

  test('case types explain both inventory containers', () {
    expect(CaseType.dice.title, 'Ящик костей');
    expect(CaseType.dice.description, contains('уровень 1–3'));
    expect(CaseType.artifact.title, 'Ящик артефактов');
    expect(CaseType.artifact.description, contains('выберите один'));
  });
}
