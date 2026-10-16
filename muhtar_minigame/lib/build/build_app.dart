import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'build_models.dart';
import 'character_editor.dart';
import 'map_editor.dart';

class MuhtarBuildApp extends StatelessWidget {
  const MuhtarBuildApp({super.key, this.projectRoot});

  final String? projectRoot;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MuhtarBuild',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF75D9B5),
          brightness: Brightness.dark,
          surface: const Color(0xFF181D27),
        ),
        scaffoldBackgroundColor: const Color(0xFF10141C),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: _BuildWorkspace(projectRoot: projectRoot),
    );
  }
}

class _BuildWorkspace extends StatefulWidget {
  const _BuildWorkspace({this.projectRoot});
  final String? projectRoot;

  @override
  State<_BuildWorkspace> createState() => _BuildWorkspaceState();
}

class _BuildWorkspaceState extends State<_BuildWorkspace>
    with WidgetsBindingObserver {
  final _mapKey = GlobalKey<MapEditorState>();
  final _portraitKey = GlobalKey<CharacterEditorState>();
  late final String _root;
  late final bool _validProject;
  late final BuildMapRepository _maps;
  late final CharacterRepository _characters;
  int _tab = 0;
  bool _portraitStarted = false;
  bool _closing = false;

  void _selectTab(int tab) {
    setState(() {
      _tab = tab;
      if (tab == 1) _portraitStarted = true;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final current = Directory.current.path;
    _root = p.normalize(
      widget.projectRoot ??
          (File(p.join(current, 'pubspec.yaml')).existsSync()
              ? current
              : p.join(current, 'muhtar_minigame')),
    );
    _validProject =
        File(p.join(_root, 'pubspec.yaml')).existsSync() &&
        File(p.join(_root, 'lib', 'domain', 'locations.dart')).existsSync();
    _maps = BuildMapRepository(projectRoot: _root);
    _characters = CharacterRepository(projectRoot: _root);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    if (_closing) return AppExitResponse.cancel;
    if (!(_mapKey.currentState?.hasUnsavedChanges ?? false) &&
        !(_portraitKey.currentState?.hasUnsavedChanges ?? false)) {
      return AppExitResponse.exit;
    }
    _closing = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Есть несохранённые изменения'),
        content: const Text(
          'Сначала сохраните карты и портреты на соответствующих вкладках. '
          'Закрытие без сохранения удалит только правки в памяти.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Закрыть без сохранения'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Вернуться в редактор'),
          ),
        ],
      ),
    );
    _closing = false;
    return discard == true ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  void _help() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('MuhtarBuild · инструкция'),
        content: SingleChildScrollView(
          child: SelectableText(
            'Карты: выберите локацию, инструмент и тайл. Рисуйте левой кнопкой. '
            'В режиме перемещения можно двигать и масштабировать карту. '
            'Инспектор редактирует сущности выбранной клетки. JSON открывает все поля.\n\n'
            '«Сохранить черновик» сохраняет работу только для редактора. '
            '«Применить к игре» проверяет все карты и записывает assets/maps/locations.json.\n\n'
            'Персонажи: выберите героя, врага или NPC, импортируйте PNG либо создайте '
            'новый холст. Кисть, ластик и пипетка работают по пикселям исходника. '
            '«Сохранить PNG» записывает портрет в assets/portraits/. '
            'Предыдущие версии файлов остаются в muhtar_build/backups/.\n\n'
            'После применения карт или сохранения портретов полностью перезапустите игру '
            '(не hot reload). Ассеты попадут в следующую сборку. '
            'Портреты используются в боях и диалогах; фигуры на карте пока процедурные.\n\n'
            'Проект: $_root\nДокументация: MUHTARBUILD.md в корне репозитория.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MuhtarBuild'),
        actions: [
          IconButton(
            onPressed: _help,
            icon: const Icon(Icons.help_outline),
            tooltip: 'Как работать с редактором',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _selectTab(0),
                icon: Icon(_tab == 0 ? Icons.map : Icons.map_outlined),
                label: Text(_tab == 0 ? 'Карты •' : 'Карты'),
              ),
              TextButton.icon(
                onPressed: () => _selectTab(1),
                icon: Icon(
                  _tab == 1 ? Icons.portrait : Icons.portrait_outlined,
                ),
                label: Text(_tab == 1 ? 'Персонажи •' : 'Персонажи'),
              ),
            ],
          ),
        ),
      ),
      body: !_validProject
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  'Не найден проект muhtar_minigame в $_root.\n'
                  'Запустите ./MuhtarBuild из корня проекта или выполните:\n'
                  'flutter run -d linux -t lib/muhtar_build.dart\n'
                  'из папки muhtar_minigame/. Файлы не изменены.',
                ),
              ),
            )
          : IndexedStack(
              index: _portraitStarted ? _tab : 0,
              children: [
                MapEditor(key: _mapKey, repository: _maps),
                if (_portraitStarted)
                  CharacterEditor(key: _portraitKey, repository: _characters),
              ],
            ),
    );
  }
}
