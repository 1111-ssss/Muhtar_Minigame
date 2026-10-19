import 'package:flutter/material.dart';

import '../../game_logic/audio_service.dart';

/// Общие ползунки громкости для меню и внутриигровых настроек.
class AudioVolumeSettings extends StatelessWidget {
  const AudioVolumeSettings({required this.audio, super.key});

  final AudioService audio;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: audio,
    builder: (context, _) => Column(
      children: [
        _VolumeSlider(
          sliderKey: const ValueKey('audio-master-slider'),
          icon: Icons.volume_up_outlined,
          label: 'Общая громкость',
          value: audio.masterVolume,
          onChanged: audio.setMasterVolume,
        ),
        _VolumeSlider(
          sliderKey: const ValueKey('audio-music-slider'),
          icon: Icons.music_note_outlined,
          label: 'Музыка',
          value: audio.musicVolume,
          onChanged: audio.setMusicVolume,
        ),
        _VolumeSlider(
          sliderKey: const ValueKey('audio-effects-slider'),
          icon: Icons.graphic_eq_outlined,
          label: 'Эффекты',
          value: audio.effectsVolume,
          onChanged: audio.setEffectsVolume,
        ),
      ],
    ),
  );
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.sliderKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final Key sliderKey;
  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF62E6E8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(
              color: Color(0xFF9EB0C2),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      Slider(
        key: sliderKey,
        value: value,
        min: 0,
        max: 1,
        divisions: 20,
        label: '${(value * 100).round()}%',
        semanticFormatterCallback: (value) =>
            '$label: ${(value * 100).round()}%',
        onChanged: onChanged,
      ),
    ],
  );
}
