import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

import 'isometric_map.dart';

enum MapEntityKind {
  character,
  player,
  npc,
  slime,
  goblin,
  gopnik,
  shaurmek,
  viktorKorneplod,
}

/// Базовая сущность на карте: маленький программный пиксель-спрайт с меткой.
///
/// shortcut: плейсхолдер рисуется программно; заменой на SpriteComponent
/// с ассетом получим настоящие спрайты персонажей.
abstract class MapEntity extends PositionComponent {
  MapEntity({
    required this.col,
    required this.row,
    required this.color,
    required this.label,
    this.kind = MapEntityKind.character,
    this.skinId,
    this.skinProvider,
    this.visualVariant,
    super.priority = 1,
  }) : super(anchor: Anchor.center, size: Vector2.all(48));

  int col;
  int row;
  final Color color;
  String label;
  final MapEntityKind kind;

  /// Optional visual skin. The game state does not need to know about this
  /// hook: the world can assign it directly, or provide a callback when the
  /// selected skin is owned by another layer.
  String? skinId;
  String? Function()? skinProvider;

  /// A stable visual id for NPC-specific details. It is separate from the
  /// player skin so that NPCs keep their identity even when the base
  /// humanoid renderer changes.
  final String? visualVariant;

  String? get activeSkinId => skinProvider?.call() ?? skinId;

  void setSkin(String? value) => skinId = value;

  late final TextPaint _labelPaint = TextPaint(
    style: const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 12,
      fontFamily: 'monospace',
      shadows: [Shadow(color: Color(0xDD000000), offset: Offset(1, 1))],
    ),
  );

  void syncPosition() {
    position = IsometricMap.tileToWorld(col, row);
    priority = position.y.round() + 100;
  }

  @override
  Future<void> onLoad() async {
    syncPosition();
  }

  @override
  void render(Canvas canvas) {
    final pixelPaint = Paint()..isAntiAlias = false;

    // PositionComponent с Anchor.center передаёт в render локальную систему,
    // начинающуюся в левом верхнем углу его 48×48 bounds. position при этом
    // является центром bounds. Переводим canvas в anchor перед рисованием,
    // иначе весь спрайт оказывается примерно на полтайла левее/выше, а
    // логическая коллизия остаётся в центре тайла.
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    // Тень под сущностью.
    pixelPaint.color = const Color(0x55000000);
    canvas.drawOval(
      // position — это точка опоры на центре ромба. Раньше тень и ступни
      // рисовались ниже position, из-за чего спрайт визуально стоял на
      // соседнем тайле, хотя логическая коллизия была в правильной клетке.
      Rect.fromCenter(center: Offset.zero, width: 30, height: 12),
      pixelPaint,
    );

    switch (kind) {
      case MapEntityKind.slime:
        canvas.translate(0, -7);
        _renderSlime(canvas, pixelPaint);
      case MapEntityKind.goblin:
        canvas.translate(0, -13);
        _renderGoblin(canvas, pixelPaint);
      case MapEntityKind.gopnik:
        canvas.translate(0, -13);
        _renderGopnik(canvas, pixelPaint);
      case MapEntityKind.shaurmek:
        canvas.translate(0, -12);
        _renderShaurmek(canvas, pixelPaint);
      case MapEntityKind.viktorKorneplod:
        canvas.translate(0, -12);
        _renderViktor(canvas, pixelPaint);
      case MapEntityKind.npc:
        canvas.translate(0, -12);
        _renderNpc(canvas, pixelPaint);
      case MapEntityKind.player:
        canvas.translate(0, -12);
        _renderPlayer(canvas, pixelPaint);
      case MapEntityKind.character:
        canvas.translate(0, -12);
        _renderHumanoid(canvas, pixelPaint);
    }

    // Метка над головой.
    final labelY = kind == MapEntityKind.slime ? -38 : -50;
    _labelPaint.render(
      canvas,
      label,
      Vector2(0, labelY.toDouble()),
      anchor: Anchor.bottomCenter,
    );
    canvas.restore();
  }

  void _renderPlayer(Canvas canvas, Paint paint) {
    final skin = activeSkinId?.toLowerCase();
    switch (skin) {
      case 'red':
      case 'red_hoodie':
      case 'crimson':
        _renderHumanoid(
          canvas,
          paint,
          bodyColor: const Color(0xFFD34A4A),
          accentColor: const Color(0xFFFFC857),
        );
      case 'forest':
      case 'green':
        _renderHumanoid(
          canvas,
          paint,
          bodyColor: const Color(0xFF3E9D70),
          accentColor: const Color(0xFFB9D36A),
        );
      case 'royal':
      case 'gold':
        _renderHumanoid(
          canvas,
          paint,
          bodyColor: const Color(0xFF7658E8),
          accentColor: const Color(0xFFFFD36A),
        );
      case 'ribka_reward':
      case 'player_ribka_reward':
        _renderHumanoid(
          canvas,
          paint,
          bodyColor: const Color(0xFFD14F86),
          accentColor: const Color(0xFFFFC1DA),
        );
      case 'shadow':
      case 'night':
        _renderHumanoid(
          canvas,
          paint,
          bodyColor: const Color(0xFF343A52),
          accentColor: const Color(0xFF78F3D0),
           skinTone: const Color(0xFFE8B89A),
         );
      case 'kartofla':
        _renderKartofla(canvas, paint);
      default:
        _renderHumanoid(canvas, paint);
    }
  }

  void _renderNpc(Canvas canvas, Paint paint) {
    switch (visualVariant?.toLowerCase()) {
      case 'malek':
        _renderMalek(canvas, paint);
      case 'ribka':
        _renderRibka(canvas, paint);
      case 'sofia':
        _renderSofia(canvas, paint);
      case 'shaurmek':
        _renderShaurmek(canvas, paint);
      case 'wb_employee':
        _renderHumanoid(
          canvas,
          paint,
          bodyColor: const Color(0xFF8B4FC8),
          accentColor: const Color(0xFFE0B4FF),
        );
      case 'ilya':
        _renderHumanoid(
          canvas,
          paint,
          bodyColor: const Color(0xFF2D7D9A),
          accentColor: const Color(0xFF7DE0F2),
        );
      case 'ozon_locker':
        _renderHumanoid(
          canvas,
          paint,
          bodyColor: const Color(0xFF147A8A),
          accentColor: const Color(0xFF62E6E8),
        );
      default:
        _renderHumanoid(canvas, paint, hood: true);
    }
  }

  void _renderHumanoid(
    Canvas canvas,
    Paint paint, {
    bool hood = false,
    Color? bodyColor,
    Color? skinTone,
    Color? accentColor,
  }) {
    // Все размеры кратны 3–4 px, а сглаживание отключено: это читаемый
    // пиксельный плейсхолдер, который позже можно заменить спрайт-листом.
    paint.color = const Color(0xFF171923);
    canvas.drawRect(const Rect.fromLTWH(-11, -29, 22, 16), paint);
    canvas.drawRect(const Rect.fromLTWH(-14, -14, 28, 20), paint);
    canvas.drawRect(const Rect.fromLTWH(-11, 5, 8, 7), paint);
    canvas.drawRect(const Rect.fromLTWH(3, 5, 8, 7), paint);

    paint.color = bodyColor ?? color;
    canvas.drawRect(const Rect.fromLTWH(-8, -26, 16, 12), paint);
    canvas.drawRect(const Rect.fromLTWH(-10, -10, 20, 15), paint);
    paint.color = (bodyColor ?? color).withValues(alpha: 0.72);
    canvas.drawRect(const Rect.fromLTWH(-14, -8, 4, 11), paint);
    canvas.drawRect(const Rect.fromLTWH(10, -8, 4, 11), paint);

    paint.color = skinTone ?? const Color(0xFFF7D6B0);
    if (hood) {
      paint.color = accentColor ?? const Color(0xFFFFE082);
      canvas.drawRect(const Rect.fromLTWH(-8, -23, 16, 7), paint);
    } else {
      canvas.drawRect(const Rect.fromLTWH(-5, -22, 3, 3), paint);
      canvas.drawRect(const Rect.fromLTWH(3, -22, 3, 3), paint);
    }
    paint.color = const Color(0xFF202331);
    canvas.drawRect(const Rect.fromLTWH(-6, -17, 12, 3), paint);
  }

  void _renderMalek(Canvas canvas, Paint paint) {
    _renderHumanoid(
      canvas,
      paint,
      bodyColor: const Color(0xFF31536D),
      skinTone: const Color(0xFFC98D69),
      accentColor: const Color(0xFFE8B44D),
    );
    // Кепка, борода и трость делают силуэт Малека узнаваемым даже вдалеке.
    paint.color = const Color(0xFF1C3043);
    canvas.drawRect(const Rect.fromLTWH(-10, -29, 20, 5), paint);
    canvas.drawRect(const Rect.fromLTWH(-13, -26, 8, 3), paint);
    paint.color = const Color(0xFF6E4939);
    canvas.drawRect(const Rect.fromLTWH(-6, -18, 12, 5), paint);
    paint.color = const Color(0xFFD9B36B);
    paint.strokeWidth = 2;
    paint.strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(15, -4), const Offset(17, 10), paint);
    canvas.drawLine(const Offset(14, -4), const Offset(17, -4), paint);
  }

  void _renderRibka(Canvas canvas, Paint paint) {
    _renderHumanoid(
      canvas,
      paint,
      bodyColor: const Color(0xFF2A8D91),
      skinTone: const Color(0xFFE7B18D),
      accentColor: const Color(0xFFFF7B70),
    );
    // Длинные волосы и шарф выступают за базовый прямоугольный силуэт.
    paint.color = const Color(0xFF6B344D);
    canvas.drawRect(const Rect.fromLTWH(-12, -24, 4, 17), paint);
    canvas.drawRect(const Rect.fromLTWH(8, -24, 4, 17), paint);
    paint.color = const Color(0xFFFF7B70);
    canvas.drawRect(const Rect.fromLTWH(-11, -11, 22, 4), paint);
    canvas.drawRect(const Rect.fromLTWH(7, -8, 6, 8), paint);
  }

  void _renderSofia(Canvas canvas, Paint paint) {
    _renderHumanoid(
      canvas,
      paint,
      bodyColor: const Color(0xFFF8F8F4),
      skinTone: const Color(0xFFF1C3A0),
      accentColor: const Color(0xFFFFFFFF),
    );
    // София пока намеренно проработана минимально: полностью белая одежда,
    // чтобы её легко было заменить будущим полноценным спрайтом.
    paint.color = const Color(0xFFFFFFFF);
    canvas.drawRect(const Rect.fromLTWH(-9, -28, 18, 5), paint);
    paint.color = const Color(0xFF25283F);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawRect(const Rect.fromLTWH(-7, -23, 6, 5), paint);
    canvas.drawRect(const Rect.fromLTWH(1, -23, 6, 5), paint);
    canvas.drawLine(const Offset(-1, -21), const Offset(1, -21), paint);
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFFE6A84F);
    canvas.drawRect(const Rect.fromLTWH(12, -4, 7, 8), paint);
  }

  void _renderSlime(Canvas canvas, Paint paint) {
    paint.color = const Color(0xFF17251D);
    canvas.drawRect(const Rect.fromLTWH(-18, -15, 36, 22), paint);
    paint.color = color;
    canvas.drawRect(const Rect.fromLTWH(-14, -19, 28, 23), paint);
    canvas.drawRect(const Rect.fromLTWH(-10, -22, 20, 5), paint);
    paint.color = const Color(0xFFE8F5E9);
    canvas.drawRect(const Rect.fromLTWH(-8, -12, 4, 5), paint);
    canvas.drawRect(const Rect.fromLTWH(4, -12, 4, 5), paint);
    paint.color = const Color(0xFF17251D);
    canvas.drawRect(const Rect.fromLTWH(-7, -11, 2, 3), paint);
    canvas.drawRect(const Rect.fromLTWH(5, -11, 2, 3), paint);
  }

  void _renderGoblin(Canvas canvas, Paint paint) {
    paint.color = const Color(0xFF182019);
    canvas.drawRect(const Rect.fromLTWH(-12, -29, 24, 18), paint);
    canvas.drawRect(const Rect.fromLTWH(-15, -12, 30, 20), paint);
    canvas.drawRect(const Rect.fromLTWH(-11, 7, 8, 6), paint);
    canvas.drawRect(const Rect.fromLTWH(3, 7, 8, 6), paint);
    paint.color = color;
    canvas.drawRect(const Rect.fromLTWH(-8, -24, 16, 13), paint);
    canvas.drawRect(const Rect.fromLTWH(-10, -8, 20, 14), paint);
    paint.color = const Color(0xFFFFE082);
    canvas.drawRect(const Rect.fromLTWH(-6, -20, 4, 4), paint);
    canvas.drawRect(const Rect.fromLTWH(2, -20, 4, 4), paint);
    paint.color = const Color(0xFF7B1FA2);
    canvas.drawRect(const Rect.fromLTWH(-16, -8, 3, 13), paint);
    canvas.drawRect(const Rect.fromLTWH(13, -8, 3, 13), paint);
  }

  void _renderGopnik(Canvas canvas, Paint paint) {
    // Небольшой локальный спрайт в том же пиксельном стиле: кепка, спортивная
    // куртка и сумка курьера. Он читается на зелёном фоне даже без текстур.
    paint.color = const Color(0xFF182019);
    canvas.drawRect(const Rect.fromLTWH(-13, -30, 26, 19), paint);
    canvas.drawRect(const Rect.fromLTWH(-16, -12, 32, 20), paint);
    canvas.drawRect(const Rect.fromLTWH(-11, 7, 8, 6), paint);
    canvas.drawRect(const Rect.fromLTWH(3, 7, 8, 6), paint);
    paint.color = const Color(0xFF3949AB);
    canvas.drawRect(const Rect.fromLTWH(-10, -27, 20, 5), paint);
    canvas.drawRect(const Rect.fromLTWH(-10, -8, 20, 15), paint);
    paint.color = const Color(0xFFF3C6A4);
    canvas.drawRect(const Rect.fromLTWH(-7, -20, 14, 8), paint);
    paint.color = const Color(0xFF202331);
    canvas.drawRect(const Rect.fromLTWH(-4, -17, 3, 3), paint);
    canvas.drawRect(const Rect.fromLTWH(3, -17, 3, 3), paint);
    paint.color = const Color(0xFFB71C1C);
    canvas.drawRect(const Rect.fromLTWH(10, -5, 8, 11), paint);
    paint.color = const Color(0xFFFFD54F);
    canvas.drawRect(const Rect.fromLTWH(12, -2, 4, 3), paint);
  }

  void _renderShaurmek(Canvas canvas, Paint paint) {
    _renderHumanoid(canvas, paint);
    paint.color = const Color(0xFF6D3B24);
    canvas.drawRect(const Rect.fromLTWH(-16, -3, 9, 5), paint);
    paint.color = const Color(0xFFFFD36A);
    canvas.drawRect(const Rect.fromLTWH(-14, -2, 5, 2), paint);
  }

  void _renderViktor(Canvas canvas, Paint paint) {
    _renderHumanoid(canvas, paint);
    paint.color = const Color(0xFF6D4C41);
    canvas.drawRect(const Rect.fromLTWH(-14, -28, 28, 5), paint);
    paint.color = const Color(0xFFB9D36A);
    canvas.drawRect(const Rect.fromLTWH(-17, -1, 4, 11), paint);
  }

  void _renderKartofla(Canvas canvas, Paint paint) {
    _renderHumanoid(
      canvas,
      paint,
      bodyColor: const Color(0xFF9B673C),
      skinTone: const Color(0xFFD69A5D),
      accentColor: const Color(0xFFF1C66B),
    );
    paint.color = const Color(0xFF6F472F);
    canvas.drawRect(const Rect.fromLTWH(-10, -29, 20, 5), paint);
    paint.color = const Color(0xFFF1C66B);
    canvas.drawRect(const Rect.fromLTWH(-9, -12, 18, 4), paint);
    paint.color = const Color(0xFF553522);
    canvas.drawRect(const Rect.fromLTWH(-6, -21, 3, 3), paint);
    canvas.drawRect(const Rect.fromLTWH(3, -21, 3, 3), paint);
  }
}
