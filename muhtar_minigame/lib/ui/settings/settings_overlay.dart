import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game/muhtar_game.dart';
import '../common/animated_overlay.dart';
import 'audio_volume_settings.dart';

/// In-game settings use the same focused card language as the main menu.
/// Each category is a separate submenu so the first screen stays compact.
class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay(this.game, {required this.onMainMenu, super.key});

  final MuhtarGame game;
  final Future<void> Function() onMainMenu;

  @override
  Widget build(BuildContext context) {
    return AnimatedOverlay(
      game: game,
      overlay: MuhtarGame.overlaySettings,
      builder: (context, close) =>
          _SettingsPanel(game: game, close: close, onMainMenu: onMainMenu),
    );
  }
}

enum _SettingsSection { root, gameplay, audio, danger }

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({
    required this.game,
    required this.close,
    required this.onMainMenu,
  });

  final MuhtarGame game;
  final VoidCallback close;
  final Future<void> Function() onMainMenu;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  _SettingsSection _section = _SettingsSection.root;

  String get _sectionTitle => switch (_section) {
    _SettingsSection.root => 'Настройки',
    _SettingsSection.gameplay => 'Игра',
    _SettingsSection.audio => 'Звук',
    _SettingsSection.danger => 'Опасная зона',
  };

  String get _sectionSubtitle => switch (_section) {
    _SettingsSection.root => 'Игра, звук и сохранение прогресса',
    _SettingsSection.gameplay => 'Сохранение и правила прохождения',
    _SettingsSection.audio => 'Общая громкость, музыка и эффекты',
    _SettingsSection.danger => 'Действия, которые нельзя отменить',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .76),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 680),
                  decoration: BoxDecoration(
                    color: const Color(0xE6162338),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0x665BE1D0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        switch (_section) {
                          _SettingsSection.root => _buildRoot(),
                          _SettingsSection.gameplay => _buildGameplay(),
                          _SettingsSection.audio => _buildAudio(),
                          _SettingsSection.danger => _buildDanger(),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(
    children: [
      if (_section == _SettingsSection.root)
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0x334FD1D4),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0x8862E6E8)),
          ),
          child: const Icon(Icons.settings_outlined, color: Color(0xFF9AF4F0)),
        )
      else
        IconButton(
          key: const ValueKey('settings-back'),
          tooltip: 'Назад к категориям настроек',
          onPressed: () => setState(() => _section = _SettingsSection.root),
          icon: const Icon(Icons.arrow_back_rounded),
          color: const Color(0xFFA8B8CC),
        ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sectionTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _sectionSubtitle,
              style: const TextStyle(
                color: Color(0xFFA8B8CC),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Закрыть настройки',
        onPressed: widget.close,
        icon: const Icon(Icons.close_rounded),
        color: const Color(0xFFA8B8CC),
      ),
    ],
  );

  Widget _buildRoot() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _MainMenuAction(
        key: const ValueKey('settings-main-menu'),
        icon: Icons.home_rounded,
        color: const Color(0xFF62E6E8),
        title: 'В главное меню',
        subtitle: 'Сохранить прогресс и вернуться к стартовому экрану.',
        child: FilledButton.icon(
          onPressed: widget.onMainMenu,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Выйти'),
        ),
      ),
      const SizedBox(height: 14),
      _CategoryButton(
        key: const ValueKey('settings-gameplay'),
        icon: Icons.sports_esports_outlined,
        color: const Color(0xFF62E6E8),
        title: 'Игра',
        subtitle: 'Автосохранение и параметры прохождения.',
        onPressed: () => setState(() => _section = _SettingsSection.gameplay),
      ),
      const SizedBox(height: 10),
      _CategoryButton(
        key: const ValueKey('settings-audio'),
        icon: Icons.tune_rounded,
        color: const Color(0xFFFFD166),
        title: 'Звук',
        subtitle: 'Общая громкость, музыка и эффекты.',
        onPressed: () => setState(() => _section = _SettingsSection.audio),
      ),
      const SizedBox(height: 10),
      _CategoryButton(
        key: const ValueKey('settings-danger'),
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF8B9A),
        title: 'Опасная зона',
        subtitle: 'Удаление прогресса нельзя отменить.',
        onPressed: () => setState(() => _section = _SettingsSection.danger),
      ),
    ],
  );

  Widget _buildGameplay() => _SettingsCard(
    icon: Icons.save_outlined,
    color: const Color(0xFF62E6E8),
    title: 'Автосохранение',
    subtitle: 'Прогресс сохраняется после боёв и переходов.',
    trailing: const Icon(
      Icons.check_circle_outline_rounded,
      color: Color(0xFF75D6B0),
    ),
  );

  Widget _buildAudio() => _SettingsCard(
    icon: Icons.tune_rounded,
    color: const Color(0xFFFFD166),
    title: 'Громкость',
    child: AudioVolumeSettings(audio: widget.game.audio),
  );

  Widget _buildDanger() => _SettingsCard(
    icon: Icons.delete_forever_rounded,
    color: const Color(0xFFFF8B9A),
    title: 'Удаление прогресса',
    subtitle: 'Монеты, кости, задания и текущая локация будут удалены.',
    child: Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _confirmReset(context),
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Стереть данные игры'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFA3B0),
          side: const BorderSide(color: Color(0x99FF7185)),
        ),
      ),
    ),
  );

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Стереть данные игры?'),
        content: const Text(
          'Монеты, кости, задания, побеждённые враги и текущий прогресс будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Стереть данные'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.game.resetGame();
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x55111D2F),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _SettingsIcon(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFA8B8CC),
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0x55111D2F),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x334F7388)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SettingsIcon(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Color(0xFFA8B8CC),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        if (child != null) ...[const SizedBox(height: 10), child!],
      ],
    ),
  );
}

class _MainMenuAction extends StatelessWidget {
  const _MainMenuAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0x334FD1D4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x8862E6E8)),
    ),
    child: Row(
      children: [
        _SettingsIcon(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFC4D7E8),
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: child),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Icon(icon, size: 18, color: color),
  );
}
