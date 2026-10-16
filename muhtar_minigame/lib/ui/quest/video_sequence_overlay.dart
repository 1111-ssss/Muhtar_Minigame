import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  Player? _player;
  VideoController? _controller;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<VideoParams>? _videoParamsSubscription;
  int _videoIndex = 0;
  int _loadGeneration = 0;
  Object? _error;
  bool _videoReady = false;
  bool _advancing = false;
  double _aspectRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVideo(0));
  }

  @override
  void dispose() {
    _loadGeneration++;
    unawaited(_disposeCurrentPlayer());
    super.dispose();
  }

  Future<void> _disposeCurrentPlayer() async {
    final player = _player;
    _player = null;
    _controller = null;

    final completedSubscription = _completedSubscription;
    final errorSubscription = _errorSubscription;
    final videoParamsSubscription = _videoParamsSubscription;
    _completedSubscription = null;
    _errorSubscription = null;
    _videoParamsSubscription = null;

    await completedSubscription?.cancel();
    await errorSubscription?.cancel();
    await videoParamsSubscription?.cancel();
    await player?.dispose();
  }

  Future<void> _disposePlayerIfCurrent(Player player) async {
    if (!identical(_player, player)) return;
    await _disposeCurrentPlayer();
  }

  Future<void> _loadVideo(int index) async {
    final generation = ++_loadGeneration;
    _advancing = false;
    await _disposeCurrentPlayer();
    if (!mounted || generation != _loadGeneration) return;

    setState(() {
      _videoIndex = index;
      _error = null;
      _videoReady = false;
      _aspectRatio = 16 / 9;
    });

    final player = Player();
    final controller = VideoController(player);
    var errorReported = false;
    _player = player;
    _completedSubscription = player.stream.completed.listen((completed) {
      if (completed) {
        _onVideoCompleted(player, generation);
      }
    });
    _errorSubscription = player.stream.error.listen((error) {
      errorReported = true;
      _onVideoError(error, player, generation);
    });
    _videoParamsSubscription = player.stream.videoParams.listen((params) {
      _onVideoParams(params, player, generation);
    });

    try {
      // media_kit resolves asset:// URIs to the bundled Flutter asset path.
      await player.open(
        Media('asset:///${VideoSequenceOverlay.videoAssets[index]}'),
      );
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(_player, player) ||
          errorReported) {
        await _disposePlayerIfCurrent(player);
        return;
      }

      final params = player.state.videoParams;
      final aspectRatio = _videoAspectRatio(params);
      setState(() {
        _controller = controller;
        _videoReady = _videoReady || _hasVideoDimensions(params);
        if (aspectRatio != null) _aspectRatio = aspectRatio;
      });
    } catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(_player, player)) {
        await _disposePlayerIfCurrent(player);
        return;
      }
      setState(() {
        _error = error;
        _videoReady = false;
      });
      await _disposePlayerIfCurrent(player);
    }
  }

  void _onVideoCompleted(Player player, int generation) {
    if (!mounted ||
        generation != _loadGeneration ||
        !identical(_player, player) ||
        _advancing) {
      return;
    }
    _advancing = true;
    if (_videoIndex == VideoSequenceOverlay.videoAssets.length - 1) {
      widget.onCompleted();
    } else {
      unawaited(_loadVideo(_videoIndex + 1));
    }
  }

  void _onVideoError(String playerError, Player player, int generation) {
    if (!mounted ||
        generation != _loadGeneration ||
        !identical(_player, player)) {
      return;
    }
    setState(() {
      _error = playerError;
      _videoReady = false;
    });
    unawaited(_disposePlayerIfCurrent(player));
  }

  void _onVideoParams(VideoParams params, Player player, int generation) {
    if (!mounted ||
        generation != _loadGeneration ||
        !identical(_player, player)) {
      return;
    }
    final aspectRatio = _videoAspectRatio(params);
    final videoReady = _hasVideoDimensions(params);
    if (aspectRatio == null && _videoReady == videoReady) return;
    setState(() {
      _videoReady = videoReady;
      if (aspectRatio != null) _aspectRatio = aspectRatio;
    });
  }

  static bool _hasVideoDimensions(VideoParams params) {
    final width = params.w ?? params.dw;
    final height = params.h ?? params.dh;
    return (width ?? 0) > 0 && (height ?? 0) > 0;
  }

  static double? _videoAspectRatio(VideoParams params) {
    final aspect = params.aspect;
    if (aspect != null && aspect.isFinite && aspect > 0) return aspect;
    final width = params.dw ?? params.w;
    final height = params.dh ?? params.h;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
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
                    : controller == null || !_videoReady
                    ? const CircularProgressIndicator(color: Color(0xFF62E6E8))
                    : _VideoFrame(
                        controller: controller,
                        aspectRatio: _aspectRatio,
                      ),
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
  const _VideoFrame({required this.controller, required this.aspectRatio});

  final VideoController controller;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 650),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.black,
              boxShadow: [BoxShadow(color: Color(0x6639DDE2), blurRadius: 24)],
            ),
            child: Video(
              controller: controller,
              aspectRatio: aspectRatio,
              controls: NoVideoControls,
            ),
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
              const Icon(
                Icons.movie_filter,
                color: Color(0xFFFF8C8C),
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'Не удалось открыть ролик',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Проверьте, что в assets/video есть файлы buber_kartofla_1.mp4, buber_kartofla_2.mp4 и buber_kartofla_3.mp4. Для Linux/Windows используется media_kit.',
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
