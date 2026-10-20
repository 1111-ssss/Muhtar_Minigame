import 'package:flutter_test/flutter_test.dart';
import 'package:muhtar_minigame/game/held_movement.dart';

void main() {
  test('first step is immediate, then repeats after the hold delay', () {
    final steps = <(int, int)>[];
    final movement = HeldMovement(onStep: steps.add);

    movement.begin((1, 0));
    expect(steps, [(1, 0)]);

    movement.update(0.199, (1, 0));
    expect(steps, [(1, 0)]);

    movement.update(0.002, (1, 0));
    expect(steps, [(1, 0), (1, 0)]);

    movement.update(0.058, (1, 0));
    expect(steps, hasLength(2));

    movement.update(0.002, (1, 0));
    expect(steps, hasLength(3));
  });

  test('releasing the key resets the hold delay', () {
    final steps = <(int, int)>[];
    final movement = HeldMovement(onStep: steps.add);

    movement.begin((0, 1));
    movement.update(0.2, (0, 1));
    expect(steps, hasLength(2));

    movement.update(0.1, null);
    movement.update(0.199, (0, 1));
    expect(steps, hasLength(2));

    movement.update(0.002, (0, 1));
    expect(steps, hasLength(3));
  });

  test('cancelling movement after an interaction prevents repeat steps', () {
    final steps = <(int, int)>[];
    final movement = HeldMovement(onStep: steps.add);

    movement.begin((1, 0));
    movement.reset();
    movement.update(0.5, (1, 0));

    expect(steps, [(1, 0)]);
  });
}
