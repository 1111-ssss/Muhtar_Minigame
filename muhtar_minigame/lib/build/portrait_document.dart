import 'dart:async';
import 'dart:io' show ZLibEncoder;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A widget- and repository-independent, straight-RGBA pixel document.
///
/// Coordinates are original image pixels, colors are 0xAARRGGBB. Painting
/// replaces pixels (including alpha), rather than accumulating opacity. A
/// beginStroke/paintLine/endStroke transaction creates one undo entry, however
/// many pointer events it contains. Transforms each create one undo entry.
///
/// PNG decoding and preview creation require a Flutter engine. All pixel edits,
/// history, and PNG encoding are synchronous Dart operations. No file is written
/// by this class. Call [markSaved] only after the repository write succeeds.
class PortraitDocument {
  PortraitDocument._(
    this._width,
    this._height,
    this._rgba, {
    required int historyByteLimit,
    required bool initiallyDirty,
  }) : historyByteLimit = _validateHistoryLimit(historyByteLimit),
       _savedRevision = initiallyDirty ? -1 : 0;

  factory PortraitDocument.blank({
    required int width,
    required int height,
    int color = 0x00000000,
    bool initiallyDirty = true,
    int historyByteLimit = defaultHistoryByteLimit,
  }) {
    _validateSize(width, height);
    final result = PortraitDocument._(
      width,
      height,
      Uint8List(width * height * 4),
      historyByteLimit: historyByteLimit,
      initiallyDirty: initiallyDirty,
    );
    if (color != 0) {
      for (var i = 0; i < result._rgba.length; i += 4) {
        result._writeColor(i, color);
      }
    }
    return result;
  }

  /// Copies the supplied straight (not premultiplied) RGBA bytes.
  factory PortraitDocument.fromRgba({
    required int width,
    required int height,
    required Uint8List rgba,
    bool initiallyDirty = false,
    int historyByteLimit = defaultHistoryByteLimit,
  }) {
    _validateSize(width, height);
    if (rgba.length != width * height * 4) {
      throw ArgumentError('Длина RGBA не соответствует размеру изображения.');
    }
    return PortraitDocument._(
      width,
      height,
      Uint8List.fromList(rgba),
      historyByteLimit: historyByteLimit,
      initiallyDirty: initiallyDirty,
    );
  }

  static const maxDimension = 2048;
  static const maxEncodedBytes = 32 * 1024 * 1024;
  static const defaultHistoryByteLimit = 64 * 1024 * 1024;
  static const maxHistorySteps = 40;
  static const _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

  /// Validates PNG dimensions *before* allocating a decoded image. Oversized
  /// files are rejected, never silently downscaled. The first frame is used.
  static Future<PortraitDocument> decodePng(
    Uint8List bytes, {
    int historyByteLimit = defaultHistoryByteLimit,
  }) async {
    _validateHistoryLimit(historyByteLimit);
    if (bytes.length > maxEncodedBytes) {
      throw const FormatException('PNG превышает ограничение 32 МиБ.');
    }
    if (bytes.length < 33 ||
        !_pngSignature.asMap().entries.every((e) => bytes[e.key] == e.value) ||
        bytes[8] != 0 ||
        bytes[9] != 0 ||
        bytes[10] != 0 ||
        bytes[11] != 13 ||
        bytes[12] != 73 ||
        bytes[13] != 72 ||
        bytes[14] != 68 ||
        bytes[15] != 82) {
      throw const FormatException('Файл не является корректным PNG.');
    }
    final header = ByteData.sublistView(bytes);
    final width = header.getUint32(16);
    final height = header.getUint32(20);
    _validateSize(width, height);

    final codec = await ui.instantiateImageCodec(bytes);
    ui.Image? image;
    try {
      final frame = await codec.getNextFrame();
      image = frame.image;
      if (image.width != width || image.height != height) {
        throw const FormatException('Размер PNG не совпадает с заголовком.');
      }
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) {
        throw const FormatException('Не удалось декодировать PNG.');
      }
      return PortraitDocument.fromRgba(
        width: width,
        height: height,
        rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        historyByteLimit: historyByteLimit,
      );
    } finally {
      image?.dispose();
      codec.dispose();
    }
  }

  int _width;
  int _height;
  Uint8List _rgba;
  final int historyByteLimit;
  final List<_PortraitSnapshot> _undo = [];
  final List<_PortraitSnapshot> _redo = [];
  _PortraitSnapshot? _strokeStart;
  bool _strokeChanged = false;
  bool _disposed = false;
  int _historyBytes = 0;
  int _revision = 0;
  int _nextRevision = 1;
  int _savedRevision;

  int get width => _width;
  int get height => _height;
  int get revision => _revision;
  bool get isDirty => _revision != _savedRevision;
  bool get isStrokeActive => _strokeStart != null;
  bool get canUndo => _undo.isNotEmpty && !isStrokeActive;
  bool get canRedo => _redo.isNotEmpty && !isStrokeActive;
  int get undoCount => _undo.length;
  int get redoCount => _redo.length;

  /// Undo + redo payload only. A live stroke additionally owns one before-image
  /// (at most 16 MiB); the current image is at most another 16 MiB.
  int get historyBytes => _historyBytes;

  Uint8List get rgbaBytes {
    _checkAlive();
    return Uint8List.fromList(_rgba);
  }

  int pixelAt(int x, int y) {
    _checkAlive();
    if (x < 0 || y < 0 || x >= width || y >= height) {
      throw RangeError('Пиксель ($x, $y) вне изображения $width×$height.');
    }
    final i = (y * width + x) * 4;
    return (_rgba[i + 3] << 24) |
        (_rgba[i] << 16) |
        (_rgba[i + 1] << 8) |
        _rgba[i + 2];
  }

  void beginStroke() {
    _checkAlive();
    if (isStrokeActive) throw StateError('Мазок уже начат.');
    _strokeStart = _snapshot();
    _strokeChanged = false;
  }

  /// Circular, hard-edged brush. Integer coordinates address pixel centers.
  /// Bresenham interpolation prevents holes even at high pointer velocity.
  /// Out-of-image centers are ignored; a segment is safely clipped first.
  void paintLine(
    int x0,
    int y0,
    int x1,
    int y1, {
    required int color,
    int brushSize = 1,
    bool erase = false,
  }) {
    _checkAlive();
    if (!isStrokeActive) throw StateError('Сначала вызовите beginStroke().');
    if (brushSize < 1 || brushSize > maxDimension) {
      throw RangeError.range(brushSize, 1, maxDimension, 'brushSize');
    }
    final clipped = _clipLine(x0, y0, x1, y1);
    if (clipped == null) return;
    var x = clipped.$1;
    var y = clipped.$2;
    final endX = clipped.$3;
    final endY = clipped.$4;
    final dx = (endX - x).abs();
    final dy = -(endY - y).abs();
    final sx = x < endX ? 1 : -1;
    final sy = y < endY ? 1 : -1;
    var error = dx + dy;
    var changed = false;
    while (true) {
      changed = _stamp(x, y, brushSize, erase ? 0 : color) || changed;
      if (x == endX && y == endY) break;
      final twice = error * 2;
      if (twice >= dy) {
        error += dy;
        x += sx;
      }
      if (twice <= dx) {
        error += dx;
        y += sy;
      }
    }
    if (changed) {
      _strokeChanged = true;
      _revision = _nextRevision++;
    }
  }

  bool endStroke() {
    _checkAlive();
    final before = _strokeStart;
    if (before == null) return false;
    _strokeStart = null;
    final changed = _strokeChanged;
    _strokeChanged = false;
    if (changed) _record(before);
    return changed;
  }

  void cancelStroke() {
    _checkAlive();
    final before = _strokeStart;
    if (before == null) return;
    _strokeStart = null;
    _strokeChanged = false;
    _restore(before);
  }

  bool undo() {
    _checkIdle();
    if (_undo.isEmpty) return false;
    final previous = _undo.removeLast();
    _historyBytes -= previous.bytes.length;
    final current = _snapshot();
    _redo.add(current);
    _historyBytes += current.bytes.length;
    _restore(previous);
    _trimHistory();
    return true;
  }

  bool redo() {
    _checkIdle();
    if (_redo.isEmpty) return false;
    final next = _redo.removeLast();
    _historyBytes -= next.bytes.length;
    final current = _snapshot();
    _undo.add(current);
    _historyBytes += current.bytes.length;
    _restore(next);
    _trimHistory();
    return true;
  }

  void markSaved({int? revision}) {
    _checkIdle();
    _savedRevision = revision ?? _revision;
  }

  /// Imports a decoded image into this document, retaining one undo step.
  /// The source document is copied and remains owned by the caller.
  void replaceWith(PortraitDocument source) {
    _checkIdle();
    source._checkAlive();
    _replace(source.width, source.height, source.rgbaBytes);
  }

  void clear() {
    _checkIdle();
    _replace(width, height, Uint8List(width * height * 4));
  }

  void flipHorizontal() {
    _checkIdle();
    final bytes = Uint8List(_rgba.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final source = (y * width + x) * 4;
        final target = (y * width + width - 1 - x) * 4;
        bytes.setRange(target, target + 4, _rgba, source);
      }
    }
    _replace(width, height, bytes);
  }

  /// Crops an integer rectangle contained wholly inside the current image.
  void crop({
    required int left,
    required int top,
    required int width,
    required int height,
  }) {
    _checkIdle();
    _validateSize(width, height);
    if (left < 0 ||
        top < 0 ||
        left + width > _width ||
        top + height > _height) {
      throw ArgumentError(
        'Область обрезки должна находиться внутри изображения.',
      );
    }
    final bytes = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      final source = ((top + y) * _width + left) * 4;
      bytes.setRange(y * width * 4, (y + 1) * width * 4, _rgba, source);
    }
    _replace(width, height, bytes);
  }

  /// Nearest-neighbor resampling preserves hard pixel-art edges.
  void resize({required int width, required int height}) {
    _checkIdle();
    _validateSize(width, height);
    if (width == _width && height == _height) return;
    final bytes = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      final sy = y * _height ~/ height;
      for (var x = 0; x < width; x++) {
        final source = (sy * _width + x * _width ~/ width) * 4;
        final target = (y * width + x) * 4;
        bytes.setRange(target, target + 4, _rgba, source);
      }
    }
    _replace(width, height, bytes);
  }

  /// Encodes a snapshot on a worker isolate. Straight RGBA is written directly
  /// to PNG, avoiding a lossy premultiply/unpremultiply roundtrip on saving.
  Future<Uint8List> encodePng() {
    _checkIdle();
    return _encodeOnWorker(width, height, rgbaBytes);
  }

  /// Caller owns and must dispose the returned preview. Flutter's raw image
  /// API expects premultiplied RGBA; the editable backing bytes stay straight.
  Future<ui.Image> createImage() {
    _checkAlive();
    final bytes = rgbaBytes;
    for (var i = 0; i < bytes.length; i += 4) {
      final alpha = bytes[i + 3];
      bytes[i] = (bytes[i] * alpha + 127) ~/ 255;
      bytes[i + 1] = (bytes[i + 1] * alpha + 127) ~/ 255;
      bytes[i + 2] = (bytes[i + 2] * alpha + 127) ~/ 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rgba = Uint8List(0);
    _undo.clear();
    _redo.clear();
    _strokeStart = null;
    _historyBytes = 0;
  }

  bool _stamp(int x, int y, int size, int color) {
    final startX = x - (size - 1) ~/ 2;
    final startY = y - (size - 1) ~/ 2;
    final centerX = startX + (size - 1) / 2;
    final centerY = startY + (size - 1) / 2;
    final radiusSquared = size * size / 4;
    var changed = false;
    for (
      var py = math.max(0, startY);
      py < math.min(height, startY + size);
      py++
    ) {
      for (
        var px = math.max(0, startX);
        px < math.min(width, startX + size);
        px++
      ) {
        final dx = px - centerX;
        final dy = py - centerY;
        if (dx * dx + dy * dy > radiusSquared) continue;
        final i = (py * width + px) * 4;
        final r = (color >> 16) & 255;
        final g = (color >> 8) & 255;
        final b = color & 255;
        final a = (color >> 24) & 255;
        if (_rgba[i] != r ||
            _rgba[i + 1] != g ||
            _rgba[i + 2] != b ||
            _rgba[i + 3] != a) {
          _writeColor(i, color);
          changed = true;
        }
      }
    }
    return changed;
  }

  void _writeColor(int i, int color) {
    _rgba[i] = (color >> 16) & 255;
    _rgba[i + 1] = (color >> 8) & 255;
    _rgba[i + 2] = color & 255;
    _rgba[i + 3] = (color >> 24) & 255;
  }

  (int, int, int, int)? _clipLine(int x0, int y0, int x1, int y1) {
    final dx = (x1 - x0).toDouble();
    final dy = (y1 - y0).toDouble();
    var lo = 0.0;
    var hi = 1.0;
    final p = [-dx, dx, -dy, dy];
    final q = [
      x0.toDouble(),
      width - 1.0 - x0,
      y0.toDouble(),
      height - 1.0 - y0,
    ];
    for (var i = 0; i < 4; i++) {
      if (p[i] == 0) {
        if (q[i] < 0) return null;
      } else {
        final t = q[i] / p[i];
        if (p[i] < 0) {
          lo = math.max(lo, t);
        } else {
          hi = math.min(hi, t);
        }
        if (lo > hi) return null;
      }
    }
    return (
      (x0 + lo * dx).round().clamp(0, width - 1),
      (y0 + lo * dy).round().clamp(0, height - 1),
      (x0 + hi * dx).round().clamp(0, width - 1),
      (y0 + hi * dy).round().clamp(0, height - 1),
    );
  }

  _PortraitSnapshot _snapshot() =>
      _PortraitSnapshot(width, height, rgbaBytes, _revision);

  void _restore(_PortraitSnapshot snapshot) {
    _width = snapshot.width;
    _height = snapshot.height;
    _rgba = snapshot.bytes;
    _revision = snapshot.revision;
  }

  void _replace(int width, int height, Uint8List bytes) {
    var same = width == _width && height == _height;
    if (same) {
      for (var i = 0; i < bytes.length; i++) {
        if (bytes[i] != _rgba[i]) {
          same = false;
          break;
        }
      }
    }
    if (same) return;
    final before = _snapshot();
    _width = width;
    _height = height;
    _rgba = bytes;
    _revision = _nextRevision++;
    _record(before);
  }

  void _record(_PortraitSnapshot before) {
    for (final state in _redo) {
      _historyBytes -= state.bytes.length;
    }
    _redo.clear();
    _undo.add(before);
    _historyBytes += before.bytes.length;
    _trimHistory();
  }

  void _trimHistory() {
    while (_historyBytes > historyByteLimit ||
        _undo.length + _redo.length > maxHistorySteps) {
      final list = _undo.isNotEmpty ? _undo : _redo;
      _historyBytes -= list.removeAt(0).bytes.length;
    }
  }

  void _checkAlive() {
    if (_disposed) throw StateError('Документ уже освобождён.');
  }

  void _checkIdle() {
    _checkAlive();
    if (isStrokeActive) throw StateError('Сначала завершите текущий мазок.');
  }

  static void _validateSize(int width, int height) {
    if (width < 1 ||
        height < 1 ||
        width > maxDimension ||
        height > maxDimension) {
      throw RangeError('Размер изображения: от 1×1 до 2048×2048 пикселей.');
    }
  }

  static int _validateHistoryLimit(int value) {
    if (value < 0 || value > defaultHistoryByteLimit) {
      throw RangeError.range(
        value,
        0,
        defaultHistoryByteLimit,
        'historyByteLimit',
      );
    }
    return value;
  }
}

class _PortraitSnapshot {
  const _PortraitSnapshot(this.width, this.height, this.bytes, this.revision);

  final int width;
  final int height;
  final Uint8List bytes;
  final int revision;
}

// Keep the isolate closure outside the document's instance context so that it
// cannot inadvertently capture and copy the entire undo/redo history.
Future<Uint8List> _encodeOnWorker(int width, int height, Uint8List rgba) =>
    Isolate.run(() => _encodeRgbaPng(width, height, rgba));

Uint8List _encodeRgbaPng(int width, int height, Uint8List rgba) {
  final rows = Uint8List(height * (width * 4 + 1));
  for (var y = 0; y < height; y++) {
    // PNG filter 0 at the start of each row; pixels retain their exact RGBA.
    final target = y * (width * 4 + 1) + 1;
    rows.setRange(target, target + width * 4, rgba, y * width * 4);
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6); // 8-bit RGBA, no interlace.
  final png = BytesBuilder(copy: false)..add(PortraitDocument._pngSignature);
  void chunk(List<int> type, List<int> data) {
    png.add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List());
    png.add(type);
    png.add(data);
    var crc = 0xffffffff;
    for (final bytes in [type, data]) {
      for (final byte in bytes) {
        crc ^= byte;
        for (var bit = 0; bit < 8; bit++) {
          crc = (crc >> 1) ^ ((crc & 1) == 0 ? 0 : 0xedb88320);
        }
      }
    }
    png.add((ByteData(4)..setUint32(0, crc ^ 0xffffffff)).buffer.asUint8List());
  }

  chunk(const [73, 72, 68, 82], header.buffer.asUint8List());
  chunk(const [73, 68, 65, 84], ZLibEncoder().convert(rows));
  chunk(const [73, 69, 78, 68], const []);
  return png.takeBytes();
}
