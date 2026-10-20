/// Управляет повторением шага при удержании клавиши направления.
///
/// Первый шаг выполняется сразу при нажатии, а повторная ходьба начинается
/// только после небольшой задержки. Это отличает короткий клик от удержания
/// клавиши и не позволяет случайно пройти второй тайл.
class HeldMovement {
  HeldMovement({required this.onStep});

  static const initialDelay = 0.2;
  static const repeatInterval = 0.06;

  final void Function((int, int) direction) onStep;
  double _timer = 0;
  bool _isRepeating = false;
  bool _enabled = false;

  /// Начинает новое намерение движения и сразу выполняет первый шаг.
  void begin((int, int) direction) {
    _timer = 0;
    _isRepeating = false;
    _enabled = true;
    onStep(direction);
  }

  /// Обрабатывает удержание текущего направления за один кадр.
  void update(double dt, (int, int)? direction) {
    if (direction == null) {
      _timer = 0;
      _isRepeating = false;
      return;
    }

    if (!_enabled) return;

    _timer += dt;
    if (!_isRepeating) {
      if (_timer < initialDelay) return;
      _isRepeating = true;
      // Первый повтор происходит ровно после initialDelay. Остаток времени
      // сохраняем, чтобы интервал после него не начинался заново.
      _timer -= initialDelay;
      onStep(direction);
      return;
    }

    if (_timer < repeatInterval) return;
    _timer -= repeatInterval;
    onStep(direction);
  }

  /// Сбрасывает задержку после отпускания клавиши или блокировки ввода.
  void reset() {
    _timer = 0;
    _isRepeating = false;
    _enabled = false;
  }
}
