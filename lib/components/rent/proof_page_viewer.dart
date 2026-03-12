import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// ── Fullscreen proof viewer ────────────────────────────────────────────────
class ProofViewerPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const ProofViewerPage({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<ProofViewerPage> createState() => _ProofViewerPageState();
}

class _ProofViewerPageState extends State<ProofViewerPage> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideoUrl(String url) {
    final ext = url.split('?').first.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.urls.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final url = widget.urls[i];
          if (_isVideoUrl(url)) {
            // Only mount the player for the current page to save memory
            return _VideoPlayerTile(
              url: url,
              isActive: i == _current,
            );
          }
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      ),
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Video player tile ──────────────────────────────────────────────────────
class _VideoPlayerTile extends StatefulWidget {
  final String url;
  final bool isActive;

  const _VideoPlayerTile({required this.url, required this.isActive});

  @override
  State<_VideoPlayerTile> createState() => _VideoPlayerTileState();
}

class _VideoPlayerTileState extends State<_VideoPlayerTile> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _controller.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        // Auto-play when page is active
        if (widget.isActive) _controller.play();
      }
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void didUpdateWidget(_VideoPlayerTile old) {
    super.didUpdateWidget(old);
    // Pause when user swipes away, play when they come back
    if (_initialized) {
      widget.isActive ? _controller.play() : _controller.pause();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white38, size: 48),
            SizedBox(height: 12),
            Text(
              'Hindi ma-load ang video.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Video ──────────────────────────────────────────
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),

          // ── Play/pause overlay ─────────────────────────────
          AnimatedOpacity(
            opacity: _controller.value.isPlaying ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(16),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),

          // ── Progress bar at bottom ─────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _VideoProgressBar(controller: _controller),
          ),
        ],
      ),
    );
  }
}

// ── Thin progress bar ──────────────────────────────────────────────────────
class _VideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoProgressBar({required this.controller});

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      color: Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrub bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 2,
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                final target = Duration(
                  milliseconds: (v * duration.inMilliseconds).toInt(),
                );
                widget.controller.seekTo(target);
              },
            ),
          ),
          // Time labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(position),
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 11)),
              Text(_format(duration),
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}