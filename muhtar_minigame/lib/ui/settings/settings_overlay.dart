import 'package:flutter/material.dart';

import '../../game/muhtar_game.dart';
import '../common/animated_overlay.dart';

/// Настройки сохранены отдельным оверлеем, чтобы опасное действие всегда
/// проходило через явное подтверждение.
class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay(this.game, {super.key});

  final MuhtarGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedOverlay(
      game: game,
      overlay: MuhtarGame.overlaySettings,
      builder: (context, close) => Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        appBar: AppBar(
          title: const Text('Настройки'),
          backgroundColor: const Color(0xFF171923),
          leading: IconButton(
            tooltip: 'Закрыть настройки',
            icon: const Icon(Icons.close),
            onPressed: close,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.save, color: Colors.cyan),
                    title: Text('Автосохранение'),
                    subtitle: Text(
                      'Прогресс сохраняется после боёв и переходов.',
                    ),
                  ),
                  ListenableBuilder(
                    listenable: game.audio,
                    builder: (context, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        game.audio.enabled ? Icons.volume_up : Icons.volume_off,
                        color: Colors.cyan,
                      ),
                      title: const Text('Звуки игры'),
                      subtitle: const Text(
                        'Клики, бой, кости и переходы между локациями.',
                      ),
                      value: game.audio.enabled,
                      onChanged: game.audio.setEnabled,
                    ),
                  ),
                  const Divider(height: 28),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Стереть данные игры',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    subtitle: const Text(
                      'Начать прохождение заново с первой локации.',
                    ),
                    trailing: FilledButton(
                      onPressed: () => _confirmReset(context),
                      child: const Text('Стереть'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
    if (confirmed == true) await game.resetGame();
  }
}
