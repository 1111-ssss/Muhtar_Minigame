import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'build_models.dart';
import 'portrait_document.dart';

/// Native MuhtarBuild portrait editor. Embed inside the build shell; it owns
/// neither a MaterialApp nor any character metadata. Imports remain in memory
/// until the explicit Save action calls CharacterRepository.savePng.
class CharacterEditor extends StatefulWidget {
  const CharacterEditor({super.key, required this.repository});

  final CharacterRepository repository;

  @override
  CharacterEditorState createState() => CharacterEditorState();
}

enum _PortraitTool { brush, eraser, eyedropper, pan }

enum _UnsavedChoice { save, discard }

class CharacterEditorState extends State<CharacterEditor> {
  bool get hasUnsavedChanges => _document?.isDirty ?? false;
  final _transform = TransformationController();
  final _hex = TextEditingController(text: '#F2C7A5');
  final _focus = FocusNode();
  List<CharacterDocument> _characters = [];
  CharacterDocument? _selected;
  PortraitDocument? _document;
  ui.Image? _preview;
  _PortraitTool _tool = _PortraitTool.brush;
  int _color = 0xfff2c7a5;
  int _brushSize = 1;
  int? _pointer;
  Offset? _lastPixel;
  Offset? _hoverPixel;
  bool _busy = true;
  bool _missing = false;
  bool _previewRunning = false;
  bool _previewAgain = false;
  bool _allowPop = false;
  String? _error;
  String? _message;
  String? _hexError;
  Size _viewport = Size.zero;

  static const _palette = <int>[
    0xff161b22,
    0xff374151,
    0xff6b7280,
    0xffd1d5db,
    0xffffffff,
    0xfff2c7a5,
    0xffcb997e,
    0xff8b5e3c,
    0xffef4444,
    0xfff59e0b,
    0xfffacc15,
    0xff84cc16,
    0xff22c55e,
    0xff14b8a6,
    0xff38bdf8,
    0xff3b82f6,
    0xff8b5cf6,
    0xffd946ef,
    0xffec4899,
    0x00000000,
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
  }

  @override
  void dispose() {
    _document?.dispose();
    _preview?.dispose();
    _transform.dispose();
    _hex.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _finishStroke();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorText(Object error) => switch (error) {
    FileSystemException e =>
      'Ошибка файла: ${e.message}${e.path == null ? '' : '\n${e.path}'}',
    FormatException e => 'Ошибка PNG: ${e.message}',
    ArgumentError e => '${e.message}',
    _ => 'Не удалось выполнить операцию: $error',
  };

  Future<PortraitDocument?> _readPortrait(CharacterDocument character) async {
    final file = widget.repository.portraitFile(character);
    if (!file.existsSync()) return null;
    if (file.lengthSync() > PortraitDocument.maxEncodedBytes) {
      throw const FormatException('PNG превышает ограничение 32 МиБ.');
    }
    return PortraitDocument.decodePng(file.readAsBytesSync());
  }

  Future<void> _loadCatalog() async {
    try {
      final characters = await widget.repository.loadAll();
      if (!mounted) return;
      setState(() {
        _characters = characters;
        _selected = characters.firstOrNull;
      });
      if (_selected != null) {
        final image = await _readPortrait(_selected!);
        if (!mounted) {
          image?.dispose();
          return;
        }
        _installDocument(image, fileMissing: image == null);
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _installDocument(PortraitDocument? image, {bool? fileMissing}) {
    final previous = _document;
    final preview = _preview;
    setState(() {
      _document = image;
      _preview = null;
      if (fileMissing != null) _missing = fileMissing;
      _hoverPixel = null;
      _pointer = null;
      _lastPixel = null;
    });
    previous?.dispose();
    preview?.dispose();
    _fitImage();
    _requestPreview();
  }

  Future<void> _selectCharacter(CharacterDocument character) => _run(() async {
    if (!await _resolveUnsaved()) return;
    final image = await _readPortrait(character);
    if (!mounted) {
      image?.dispose();
      return;
    }
    setState(() => _selected = character);
    _installDocument(image, fileMissing: image == null);
  });

  Future<bool> _resolveUnsaved() async {
    if (!(_document?.isDirty ?? false)) return true;
    final choice = await showDialog<_UnsavedChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сохранить изменения?'),
        content: Text(
          'Портрет «${_selected?.name ?? ''}» изменён. Перед продолжением сохраните правки или отбросьте их.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _UnsavedChoice.discard),
            child: const Text('Не сохранять'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _UnsavedChoice.save),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return false;
    if (choice == _UnsavedChoice.save) return _saveCurrent();
    return true;
  }

  Future<bool> _confirm(String title, String message, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: SelectableText(message)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _saveCurrent() async {
    final document = _document;
    final character = _selected;
    if (document == null || character == null) return false;
    final target = widget.repository.portraitFile(character);
    if (await target.exists()) {
      if (!mounted) return false;
      if (!await _confirm(
        'Перезаписать портрет?',
        'Будет заменён файл:\n${target.path}\n\nРепозиторий сохранит предыдущую версию в резервной копии.',
        'Перезаписать',
      )) {
        return false;
      }
    }
    if (!mounted) return false;
    final revision = document.revision;
    final bytes = await document.encodePng();
    if (!mounted) return false;
    final saved = await widget.repository.savePng(character, bytes);
    if (!mounted) return true;
    document.markSaved(revision: revision);
    setState(() {
      _missing = false;
      _message = 'PNG сохранён: ${saved.path}';
    });
    return true;
  }

  Future<void> _importPng() => _run(() async {
    final path = await _showPathDialog();
    if (path == null || !mounted) return;
    final source = File(path);
    if (!await source.exists()) {
      throw FileSystemException('Файл не найден', path);
    }
    if (await source.length() > PortraitDocument.maxEncodedBytes) {
      throw const FormatException('PNG превышает ограничение 32 МиБ.');
    }
    final imported = await PortraitDocument.decodePng(
      await source.readAsBytes(),
    );
    if (!mounted) {
      imported.dispose();
      return;
    }
    if (_document == null) {
      // Decoding is clean by default. Replacing a fresh blank makes the import
      // unsaved, even for a missing portrait whose PNG happens to be transparent.
      final blank = PortraitDocument.blank(
        width: imported.width,
        height: imported.height,
      );
      blank.replaceWith(imported);
      imported.dispose();
      _installDocument(blank);
    } else {
      try {
        _document!.replaceWith(imported);
      } finally {
        imported.dispose();
      }
      _afterEdit(fit: true);
    }
    setState(
      () => _message =
          'Импортирован $path. Нажмите «Сохранить PNG», чтобы записать портрет.',
    );
  });

  Future<String?> _showPathDialog() => showDialog<String>(
    context: context,
    builder: (_) => const _ImportPathDialog(),
  );

  Future<void> _newPortrait() => _run(() async {
    final size = await showDialog<_ImageGeometry>(
      context: context,
      builder: (_) => const _GeometryDialog(
        mode: _GeometryMode.create,
        width: 128,
        height: 128,
      ),
    );
    if (size == null || !mounted) return;
    final blank = PortraitDocument.blank(
      width: size.width,
      height: size.height,
    );
    if (_document == null) {
      _installDocument(blank);
    } else {
      try {
        _document!.replaceWith(blank);
      } finally {
        blank.dispose();
      }
      _afterEdit(fit: true);
    }
  });

  Future<void> _geometry(_GeometryMode mode) => _run(() async {
    final document = _document!;
    final result = await showDialog<_ImageGeometry>(
      context: context,
      builder: (_) => _GeometryDialog(
        mode: mode,
        width: document.width,
        height: document.height,
      ),
    );
    if (result == null || !mounted) return;
    if (mode == _GeometryMode.crop) {
      document.crop(
        left: result.left,
        top: result.top,
        width: result.width,
        height: result.height,
      );
    } else {
      document.resize(width: result.width, height: result.height);
    }
    _afterEdit(fit: true);
  });

  Future<void> _reset() => _run(() async {
    final character = _selected!;
    final file = widget.repository.portraitFile(character);
    final exists = await file.exists();
    if (!mounted) return;
    if (!await _confirm(
      exists ? 'Вернуться к сохранённому PNG?' : 'Очистить изображение?',
      exists
          ? 'Несохранённые изменения и история будут сброшены. Загрузится файл:\n${file.path}'
          : 'Файла портрета пока нет. Холст станет прозрачным; очистку можно отменить кнопкой «Назад».',
      exists ? 'Загрузить из файла' : 'Очистить',
    )) {
      return;
    }
    if (exists) {
      final image = await _readPortrait(character);
      if (!mounted) {
        image?.dispose();
        return;
      }
      if (image == null) {
        throw FileSystemException(
          'Файл был удалён; рабочий документ сохранён в памяти',
          file.path,
        );
      }
      _installDocument(image, fileMissing: false);
    } else if (mounted) {
      _document?.clear();
      setState(() => _missing = true);
      _afterEdit();
    }
  });

  void _afterEdit({bool fit = false}) {
    setState(() {
      _error = null;
      _message = null;
    });
    if (fit) _fitImage();
    _requestPreview();
  }

  void _edit(void Function(PortraitDocument) edit, {bool fit = false}) {
    if (_busy || _document == null) return;
    _finishStroke();
    try {
      edit(_document!);
      _afterEdit(fit: fit);
    } on Object catch (error) {
      setState(() => _error = _errorText(error));
    }
  }

  void _requestPreview() {
    _previewAgain = true;
    if (!_previewRunning) unawaited(_refreshPreview());
  }

  Future<void> _refreshPreview() async {
    _previewRunning = true;
    try {
      while (mounted && _previewAgain) {
        _previewAgain = false;
        final document = _document;
        if (document == null) continue;
        final revision = document.revision;
        final image = await document.createImage();
        if (!mounted ||
            !identical(_document, document) ||
            document.revision != revision) {
          image.dispose();
          continue;
        }
        final old = _preview;
        setState(() => _preview = image);
        old?.dispose();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () =>
              _error = 'Не удалось обновить предпросмотр: ${_errorText(error)}',
        );
      }
    } finally {
      _previewRunning = false;
    }
  }

  void _fitImage() {
    final document = _document;
    if (document == null || _viewport.isEmpty) return;
    final scale = math
        .min(
          math.max(1, _viewport.width - 40) / document.width,
          math.max(1, _viewport.height - 40) / document.height,
        )
        .clamp(0.02, 16.0);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        (_viewport.width - document.width * scale) / 2,
        (_viewport.height - document.height * scale) / 2,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoom(double factor, {Offset? anchor}) {
    if (_busy || _document == null) return;
    final matrix = _transform.value;
    final oldScale = matrix.getMaxScaleOnAxis();
    final newScale = (oldScale * factor).clamp(0.02, 64.0);
    final point = anchor ?? Offset(_viewport.width / 2, _viewport.height / 2);
    final scene = _transform.toScene(point);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        point.dx - scene.dx * newScale,
        point.dy - scene.dy * newScale,
        0,
        1,
      )
      ..scaleByDouble(newScale, newScale, 1, 1);
  }

  Offset? _pixelAt(Offset local) {
    final document = _document;
    if (document == null) return null;
    final scene = _transform.toScene(local);
    if (scene.dx < 0 ||
        scene.dy < 0 ||
        scene.dx >= document.width ||
        scene.dy >= document.height) {
      return null;
    }
    return Offset(scene.dx.floorToDouble(), scene.dy.floorToDouble());
  }

  void _pointerDown(PointerDownEvent event) {
    if (_busy ||
        _tool == _PortraitTool.pan ||
        _pointer != null ||
        event.buttons != kPrimaryButton) {
      return;
    }
    _focus.requestFocus();
    final pixel = _pixelAt(event.localPosition);
    if (pixel == null) return;
    if (_tool == _PortraitTool.eyedropper) {
      _setColor(_document!.pixelAt(pixel.dx.toInt(), pixel.dy.toInt()));
      setState(() => _hoverPixel = pixel);
      return;
    }
    _pointer = event.pointer;
    _lastPixel = pixel;
    _document!.beginStroke();
    _paint(pixel, pixel);
  }

  void _pointerMove(PointerMoveEvent event) {
    final pixel = _pixelAt(event.localPosition);
    if (_busy || event.pointer != _pointer) return;
    if (pixel == null) {
      _lastPixel = null;
      return;
    }
    _paint(_lastPixel ?? pixel, pixel);
    _lastPixel = pixel;
  }

  void _paint(Offset from, Offset to) {
    _document!.paintLine(
      from.dx.toInt(),
      from.dy.toInt(),
      to.dx.toInt(),
      to.dy.toInt(),
      color: _color,
      brushSize: _brushSize,
      erase: _tool == _PortraitTool.eraser,
    );
    setState(() {
      _hoverPixel = to;
      _message = null;
    });
    _requestPreview();
  }

  void _finishStroke({bool cancel = false}) {
    if (!(_document?.isStrokeActive ?? false)) return;
    if (cancel) {
      _document!.cancelStroke();
    } else {
      _document!.endStroke();
    }
    _pointer = null;
    _lastPixel = null;
    if (mounted) setState(() {});
    if (cancel) _requestPreview();
  }

  void _setColor(int color) {
    _finishStroke();
    setState(() {
      _color = color;
      _hex.text = _formatColor(color);
      _hexError = null;
    });
  }

  String _formatColor(int color) => (color >> 24) == 255
      ? '#${(color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}'
      : '#${color.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  void _applyHex() {
    final text = _hex.text.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(text)) {
      setState(() => _hexError = 'Введите RRGGBB или AARRGGBB.');
      return;
    }
    _setColor(int.parse(text, radix: 16) | (text.length == 6 ? 0xff000000 : 0));
  }

  Future<void> _onPop(bool didPop) async {
    if (didPop || _busy) return;
    await _run(() async {
      if (!await _resolveUnsaved() || !mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    return PopScope(
      canPop: _allowPop || (!_busy && !(document?.isDirty ?? false)),
      onPopInvokedWithResult: (didPop, _) => unawaited(_onPop(didPop)),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
              unawaited(
                _run(() async {
                  await _saveCurrent();
                }),
              ),
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
              unawaited(
                _run(() async {
                  await _saveCurrent();
                }),
              ),
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
              _edit((d) => d.undo(), fit: true),
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: true,
            shift: true,
          ): () =>
              _edit((d) => d.redo(), fit: true),
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
              _edit((d) => d.redo(), fit: true),
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () =>
              _edit((d) => d.undo(), fit: true),
          const SingleActivator(
            LogicalKeyboardKey.keyZ,
            meta: true,
            shift: true,
          ): () =>
              _edit((d) => d.redo(), fit: true),
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              _finishStroke(cancel: true),
        },
        child: Focus(
          focusNode: _focus,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxControlsHeight = constraints.hasBoundedHeight
                    ? math.max(100.0, constraints.maxHeight * 0.54)
                    : 360.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 3,
                      child: _busy
                          ? const LinearProgressIndicator(minHeight: 3)
                          : null,
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxControlsHeight),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(constraints.maxWidth),
                            if (_selected != null) ...[
                              const SizedBox(height: 12),
                              SelectableText(
                                widget.repository.portraitFile(_selected!).path,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              _buildActions(),
                            ],
                            if (document != null) ...[
                              const SizedBox(height: 12),
                              _buildTools(),
                            ],
                            if (_missing)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Файл портрета отсутствует. Создайте холст или импортируйте PNG; запись произойдёт только при сохранении.',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.tertiary,
                                  ),
                                ),
                              ),
                            if (_error != null) _notice(_error!, error: true),
                            if (_message != null) _notice(_message!),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildCanvas()),
                    if (document != null) _buildStatus(document),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double width) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Портреты персонажей',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'PNG · пиксельное редактирование',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        SizedBox(
          width: math.min(360, math.max(100, width - 32)),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Персонаж',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CharacterDocument>(
                value: _selected,
                isExpanded: true,
                isDense: true,
                items: [
                  for (final c in _characters)
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                        '${c.name} · ${c.portraitKey}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null && !identical(value, _selected)) {
                          unawaited(_selectCharacter(value));
                        }
                      },
              ),
            ),
          ),
        ),
        if (_document != null)
          Chip(
            avatar: Icon(
              _document!.isDirty
                  ? Icons.edit_outlined
                  : Icons.check_circle_outline,
              size: 18,
            ),
            label: Text(
              _document!.isDirty
                  ? 'Есть несохранённые правки'
                  : 'Совпадает с файлом',
            ),
          ),
        if (_characters.isEmpty && !_busy)
          OutlinedButton.icon(
            onPressed: () => unawaited(_run(_loadCatalog)),
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить список'),
          ),
      ],
    );
  }

  Widget _buildActions() {
    final available = !_busy && _document != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          key: const ValueKey('save-portrait'),
          onPressed: available && _document!.isDirty
              ? () => unawaited(
                  _run(() async {
                    await _saveCurrent();
                  }),
                )
              : null,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Сохранить PNG'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => unawaited(_importPng()),
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Импорт PNG…'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => unawaited(_newPortrait()),
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Новый холст…'),
        ),
        OutlinedButton.icon(
          onPressed: available && _document!.canUndo
              ? () => _edit((d) => d.undo(), fit: true)
              : null,
          icon: const Icon(Icons.undo),
          label: const Text('Назад'),
        ),
        OutlinedButton.icon(
          onPressed: available && _document!.canRedo
              ? () => _edit((d) => d.redo(), fit: true)
              : null,
          icon: const Icon(Icons.redo),
          label: const Text('Вперёд'),
        ),
        OutlinedButton.icon(
          onPressed: available ? () => _edit((d) => d.flipHorizontal()) : null,
          icon: const Icon(Icons.flip),
          label: const Text('Отразить'),
        ),
        OutlinedButton.icon(
          onPressed: available
              ? () => unawaited(_geometry(_GeometryMode.crop))
              : null,
          icon: const Icon(Icons.crop),
          label: const Text('Обрезать…'),
        ),
        OutlinedButton.icon(
          onPressed: available
              ? () => unawaited(_geometry(_GeometryMode.resize))
              : null,
          icon: const Icon(Icons.photo_size_select_large),
          label: const Text('Размер…'),
        ),
        TextButton.icon(
          onPressed: !_busy ? () => unawaited(_reset()) : null,
          icon: const Icon(Icons.restore),
          label: const Text('Сбросить…'),
        ),
      ],
    );
  }

  Widget _buildTools() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final entry in const [
              (_PortraitTool.brush, Icons.brush_outlined, 'Кисть'),
              (_PortraitTool.eraser, Icons.auto_fix_normal, 'Ластик'),
              (_PortraitTool.eyedropper, Icons.colorize, 'Пипетка'),
              (_PortraitTool.pan, Icons.pan_tool_outlined, 'Масштаб / сдвиг'),
            ])
              ChoiceChip(
                avatar: Icon(entry.$2, size: 18),
                label: Text(entry.$3),
                selected: _tool == entry.$1,
                onSelected: _busy
                    ? null
                    : (_) {
                        _finishStroke();
                        setState(() => _tool = entry.$1);
                      },
              ),
            SizedBox(
              width: 240,
              child: Row(
                children: [
                  Text('Кисть: $_brushSize px'),
                  Expanded(
                    child: Slider(
                      // Recreate the slider's overlay/focus subtree when a
                      // modal operation disables it (Flutter semantics safety).
                      key: ValueKey(_busy),
                      value: _brushSize.toDouble(),
                      min: 1,
                      max: 64,
                      divisions: 63,
                      label: '$_brushSize px',
                      onChanged: _busy
                          ? null
                          : (value) {
                              _finishStroke();
                              setState(() => _brushSize = value.round());
                            },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final color in _palette)
                  Tooltip(
                    message: color == 0 ? 'Прозрачный' : _formatColor(color),
                    child: Semantics(
                      label: 'Цвет ${_formatColor(color)}',
                      selected: _color == color,
                      button: true,
                      child: InkWell(
                        onTap: _busy ? null : () => _setColor(color),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _color == color
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                              width: _color == color ? 2 : 1,
                            ),
                          ),
                          child: CustomPaint(
                            painter: _ColorSwatchPainter(Color(color)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _hex,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: 'Цвет HEX',
                  helperText: 'RRGGBB или AARRGGBB (с альфа)',
                  errorText: _hexError,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'Применить цвет',
                    onPressed: _busy ? null : _applyHex,
                    icon: const Icon(Icons.check),
                  ),
                ),
                onSubmitted: (_) => _applyHex(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _notice(String text, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? colors.errorContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Semantics(
        liveRegion: true,
        child: SelectableText(
          text,
          style: TextStyle(
            color: error
                ? colors.onErrorContainer
                : colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    final document = _document;
    if (document == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.portrait_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                _selected == null
                    ? 'Нет персонажей в репозитории'
                    : _missing
                    ? 'Портрет ещё не создан'
                    : 'Портрет не удалось открыть',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _selected == null
                    ? 'Загрузите каталог персонажей.'
                    : 'Создайте прозрачный холст или импортируйте PNG по пути к файлу.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (_viewport != size) {
          final firstLayout = _viewport.isEmpty;
          _viewport = size;
          if (firstLayout) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitImage();
            });
          }
        }
        return ClipRect(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: MouseRegion(
              cursor: _busy
                  ? SystemMouseCursors.wait
                  : switch (_tool) {
                      _PortraitTool.pan => SystemMouseCursors.grab,
                      _PortraitTool.eyedropper => SystemMouseCursors.precise,
                      _ => SystemMouseCursors.precise,
                    },
              onHover: (event) {
                final pixel = _pixelAt(event.localPosition);
                if (pixel != _hoverPixel) setState(() => _hoverPixel = pixel);
              },
              onExit: (_) => setState(() => _hoverPixel = null),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _pointerDown,
                onPointerMove: _pointerMove,
                onPointerUp: (event) {
                  if (event.pointer == _pointer) _finishStroke();
                },
                onPointerCancel: (event) {
                  if (event.pointer == _pointer) _finishStroke(cancel: true);
                },
                onPointerSignal: (event) {
                  if (_busy ||
                      _tool == _PortraitTool.pan ||
                      event is! PointerScrollEvent) {
                    return;
                  }
                  GestureBinding.instance.pointerSignalResolver.register(
                    event,
                    (event) {
                      final scroll = event as PointerScrollEvent;
                      _finishStroke();
                      _zoom(
                        math.exp(-scroll.scrollDelta.dy / 300),
                        anchor: scroll.localPosition,
                      );
                    },
                  );
                },
                child: Semantics(
                  label:
                      'Холст портрета ${document.width} на ${document.height} пикселей. Выберите кисть, ластик, пипетку или режим сдвига.',
                  image: true,
                  child: InteractiveViewer(
                    key: const ValueKey('portrait-canvas'),
                    transformationController: _transform,
                    alignment: Alignment.topLeft,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(100000),
                    minScale: 0.02,
                    maxScale: 64,
                    panEnabled: !_busy && _tool == _PortraitTool.pan,
                    scaleEnabled: !_busy && _tool == _PortraitTool.pan,
                    child: CustomPaint(
                      size: Size(
                        document.width.toDouble(),
                        document.height.toDouble(),
                      ),
                      painter: _PortraitPainter(
                        image: _preview,
                        width: document.width,
                        height: document.height,
                        outline: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatus(PortraitDocument document) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${document.width} × ${document.height} px'),
          if (_hoverPixel != null)
            Text('X ${_hoverPixel!.dx.toInt()} · Y ${_hoverPixel!.dy.toInt()}'),
          Text(
            'История: ${document.undoCount} / ${document.redoCount} · ${(document.historyBytes / 1048576).toStringAsFixed(1)} МиБ',
          ),
          ValueListenableBuilder<Matrix4>(
            valueListenable: _transform,
            builder: (_, matrix, _) =>
                Text('${(matrix.getMaxScaleOnAxis() * 100).round()} %'),
          ),
          IconButton(
            tooltip: 'Уменьшить',
            onPressed: _busy ? null : () => _zoom(1 / 1.25),
            icon: const Icon(Icons.zoom_out),
          ),
          IconButton(
            tooltip: 'Увеличить',
            onPressed: _busy ? null : () => _zoom(1.25),
            icon: const Icon(Icons.zoom_in),
          ),
          TextButton(
            onPressed: _busy ? null : _fitImage,
            child: const Text('Вписать'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () {
                    final scale = _transform.value.getMaxScaleOnAxis();
                    _zoom(1 / scale);
                  },
            child: const Text('1:1'),
          ),
          Text(
            _tool == _PortraitTool.pan
                ? 'Перетаскивание — сдвиг · колесо / жест — масштаб'
                : 'ЛКМ — инструмент · колесо — масштаб · Ctrl+S — сохранить',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  const _PortraitPainter({
    required this.image,
    required this.width,
    required this.height,
    required this.outline,
  });

  final ui.Image? image;
  final int width;
  final int height;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    _paintCheckerboard(canvas, bounds, cellSize: 8);
    final current = image;
    if (current != null && current.width == width && current.height == height) {
      canvas.drawImage(
        current,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.none,
      );
    }
    canvas.drawRect(
      bounds,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0,
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter oldDelegate) =>
      image != oldDelegate.image ||
      width != oldDelegate.width ||
      height != oldDelegate.height ||
      outline != oldDelegate.outline;
}

class _ColorSwatchPainter extends CustomPainter {
  const _ColorSwatchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    _paintCheckerboard(canvas, bounds, cellSize: 5);
    canvas.drawRect(bounds, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ColorSwatchPainter oldDelegate) =>
      color != oldDelegate.color;
}

void _paintCheckerboard(
  Canvas canvas,
  Rect bounds, {
  required double cellSize,
}) {
  canvas.drawRect(bounds, Paint()..color = const Color(0xff414750));
  final paint = Paint()..color = const Color(0xff2c3139);
  final path = Path();
  final rows = (bounds.height / cellSize).ceil();
  final cols = (bounds.width / cellSize).ceil();
  for (var y = 0; y < rows; y++) {
    for (var x = y % 2; x < cols; x += 2) {
      path.addRect(
        Rect.fromLTWH(
          bounds.left + x * cellSize,
          bounds.top + y * cellSize,
          math.min(cellSize, bounds.width - x * cellSize),
          math.min(cellSize, bounds.height - y * cellSize),
        ),
      );
    }
  }
  canvas.drawPath(path, paint);
}

enum _GeometryMode { create, resize, crop }

class _ImportPathDialog extends StatefulWidget {
  const _ImportPathDialog();

  @override
  State<_ImportPathDialog> createState() => _ImportPathDialogState();
}

class _ImportPathDialogState extends State<_ImportPathDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Импорт PNG'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _form,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Путь к PNG-файлу',
            hintText: '/home/user/portraits/player.png',
            helperText:
                'Оригинальный размер, до 2048×2048 и 32 МиБ.\nФайл загрузится без записи в assets.',
            helperMaxLines: 3,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Укажите путь к файлу.'
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Загрузить')),
    ],
  );
}

class _ImageGeometry {
  const _ImageGeometry({
    required this.width,
    required this.height,
    this.left = 0,
    this.top = 0,
  });
  final int width;
  final int height;
  final int left;
  final int top;
}

class _GeometryDialog extends StatefulWidget {
  const _GeometryDialog({
    required this.mode,
    required this.width,
    required this.height,
  });
  final _GeometryMode mode;
  final int width;
  final int height;

  @override
  State<_GeometryDialog> createState() => _GeometryDialogState();
}

class _GeometryDialogState extends State<_GeometryDialog> {
  final _form = GlobalKey<FormState>();
  late final _width = TextEditingController(text: '${widget.width}');
  late final _height = TextEditingController(text: '${widget.height}');
  final _left = TextEditingController(text: '0');
  final _top = TextEditingController(text: '0');
  String? _error;

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _left.dispose();
    _top.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final result = _ImageGeometry(
      width: int.parse(_width.text),
      height: int.parse(_height.text),
      left: int.parse(_left.text),
      top: int.parse(_top.text),
    );
    if (widget.mode == _GeometryMode.crop &&
        (result.left + result.width > widget.width ||
            result.top + result.height > widget.height)) {
      setState(
        () => _error =
            'Прямоугольник должен помещаться в ${widget.width}×${widget.height} px.',
      );
      return;
    }
    Navigator.pop(context, result);
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int minimum = 1,
  }) {
    return SizedBox(
      width: 168,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        validator: (value) {
          final number = int.tryParse(value ?? '');
          return number == null ||
                  number < minimum ||
                  number > PortraitDocument.maxDimension
              ? 'От $minimum до 2048.'
              : null;
        },
        onFieldSubmitted: (_) => _submit(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.mode) {
      _GeometryMode.create => 'Новый прозрачный холст',
      _GeometryMode.resize => 'Изменить размер',
      _GeometryMode.crop => 'Обрезать портрет',
    };
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (widget.mode) {
                  _GeometryMode.create =>
                    'От 1 до 2048 пикселей по каждой стороне. Текущий портрет можно вернуть через историю.',
                  _GeometryMode.resize =>
                    'Масштабирование методом ближайшего соседа, без размытия пикселей. Пропорции задаются вручную.',
                  _GeometryMode.crop =>
                    'Координаты от левого верхнего угла исходного изображения, начиная с 0.',
                }),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (widget.mode == _GeometryMode.crop) ...[
                      _field('Слева, px', _left, minimum: 0),
                      _field('Сверху, px', _top, minimum: 0),
                    ],
                    _field('Ширина, px', _width),
                    _field('Высота, px', _height),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.mode == _GeometryMode.create ? 'Создать' : 'Применить',
          ),
        ),
      ],
    );
  }
}
