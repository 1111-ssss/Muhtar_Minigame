import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Последовательный просмотр трёх роликов. Управляющих кнопок у плеера нет:
/// пользователь может только закрыть окно, после чего последовательность
/// будет начата заново.
class VideoSequenceOverlay extends StatefulWidget {
  const VideoSequenceOverlay({
    required this.onCompleted,
    required this.onClose,
    super.key,
  });

  static const videoAssets = [
    'assets/video/buber_kartofla_1.mp4',
    'assets/video/buber_kartofla_2.mp4',
    'assets/video/buber_kartofla_3.mp4',
  ];

  final VoidCallback onCompleted;
  final VoidCallback onClose;

  @override
  State<VideoSequenceOverlay> createState() => _VideoSequenceOverlayState();
}

class _VideoSequenceOverlayState extends State<VideoSequenceOverlay> {
  VideoPlayerController? _controller;
  int _videoIndex = 0;
  int _loadGeneration = 0;
  Object? _error;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVideo(0));
  }

  @override
  void dispose() {
    final controller = _controller;
    controller?.removeListener(_onVideoTick);
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> _loadVideo(int index) async {
    final generation = ++_loadGeneration;
    _advancing = false;
    final previous = _controller;
    previous?.removeListener(_onVideoTick);
    _controller = null;
    await previous?.dispose();
    if (!mounted || generation != _loadGeneration) return;

    final controller = VideoPlayerController.asset(
      VideoSequenceOverlay.videoAssets[index],
    );
    try {
      await controller.initialize();
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onVideoTick);
      await controller.play();
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _videoIndex = index;
        _error = null;
      });
    } catch (error) {
      await controller.dispose();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = error);
    }
  }

  void _onVideoTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _advancing) {
      return;
    }
    final value = controller.value;
    if (value.isCompleted ||
        (value.duration > Duration.zero && value.position >= value.duration)) {
      _advancing = true;
      if (_videoIndex == VideoSequenceOverlay.videoAssets.length - 1) {
        widget.onCompleted();
      } else {
        unawaited(_loadVideo(_videoIndex + 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Material(
      color: const Color(0xFF070A10),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
              child: Row(
                children: [
                  const Icon(Icons.video_library, color: Color(0xFF62E6E8)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'РАЗДЕВАЛКА ОЗОНА · КАРТОФЛЯ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Text(
                    'РОЛИК ${_videoIndex + 1} / ${VideoSequenceOverlay.videoAssets.length}',
                    style: const TextStyle(
                      color: Color(0xFF62E6E8),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть. Просмотр начнётся сначала',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                    color: Colors.white70,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _error != null
                    ? _ErrorPanel(error: _error!)
                    : controller == null
                    ? const CircularProgressIndicator(color: Color(0xFF62E6E8))
                    : _VideoFrame(controller: controller),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Text(
                'Ролики идут подряд. Пропустить ролик нельзя. Закрытие сбросит просмотр на первый ролик.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 650),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(color: Color(0x6639DDE2), blurRadius: 24),
              ],
            ),
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF171D2B),
          border: Border.all(color: const Color(0xFFFF8C8C)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_filter, color: Color(0xFFFF8C8C), size: 42),
              const SizedBox(height: 12),
              const Text(
                'Не удалось открыть ролик',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Проверьте, что три MP4 лежат в assets/video и что платформа поддерживает video_player.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
