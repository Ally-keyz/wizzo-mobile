import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/utils/media_utils.dart';

/// Plays a single short video. Only plays while [active] is true, so neighbors
/// in the feed are initialised in advance (preloaded) but stay paused and
/// silent. Shows a loading indicator while the video initialises/buffers.
class ShortsVideoView extends StatefulWidget {
  const ShortsVideoView({
    super.key,
    required this.url,
    required this.active,
  });

  final String url;
  final bool active;

  @override
  State<ShortsVideoView> createState() => _ShortsVideoViewState();
}

class _ShortsVideoViewState extends State<ShortsVideoView> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      // Requested early so a slow network can begin streaming immediately.
      final optimized = optimizeCloudinaryUrl(widget.url);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(optimized),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _controller = controller;
      controller.initialize().then((_) {
        if (!mounted) return;
        controller.setLooping(true);
        setState(() {});
        if (widget.active) controller.play();
      }).catchError((Object _) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
    }
  }

  @override
  void didUpdateWidget(ShortsVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.active) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (initialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          if (_failed)
            const Icon(Icons.videocam_off, color: Colors.white38, size: 64)
          else if (!initialized || controller!.value.isBuffering)
            const CircularProgressIndicator(color: Colors.white70),
        ],
      ),
    );
  }
}