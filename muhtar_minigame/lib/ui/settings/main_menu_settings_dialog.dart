import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../game_logic/audio_service.dart';
import 'audio_volume_settings.dart';

/// Компактные настройки, доступные до запуска игрового мира.
class MainMenuSettingsDialog extends StatelessWidget {
  const MainMenuSettingsDialog({required this.audio, super.key});

  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0x334FD1D4),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: const Color(0x8862E6E8),
                          ),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: Color(0xFF9AF4F0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Настройки',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Звук и параметры игры',
                              style: TextStyle(
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
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFFA8B8CC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0x55111D2F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x334F7388)),
                    ),
                    child: const Row(
                      children: [
                        _SettingsIcon(
                          icon: Icons.save_outlined,
                          color: Color(0xFF62E6E8),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Автосохранение',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Прогресс сохраняется после боёв и переходов.',
                                style: TextStyle(
                                  color: Color(0xFFA8B8CC),
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Color(0xFF75D6B0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                    decoration: BoxDecoration(
                      color: const Color(0x55111D2F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x334F7388)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            _SettingsIcon(
                              icon: Icons.tune_rounded,
                              color: Color(0xFFFFD166),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Громкость',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AudioVolumeSettings(audio: audio),
                      ],
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
