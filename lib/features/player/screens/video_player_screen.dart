import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../logic/media_kit_player_controller.dart';
import '../../../core/constants/app_constants.dart';

/// Video player screen with MPV integration and custom controls
class VideoPlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String? title;
  final List<String>? subtitles;
  final String? logoUrl; // Movie/show logo
  final String? description; // Episode description (series) or movie description
  final String? episodeName; // Episode name (for series only, null for movies)
  final int? seasonNumber; // Season number (for series only)
  final int? episodeNumber; // Episode number (for series only)
  final bool isMovie; // Whether this is a movie (true) or series (false)

  const VideoPlayerScreen({
    super.key,
    required this.streamUrl,
    this.title,
    this.subtitles,
    this.logoUrl,
    this.description,
    this.episodeName,
    this.seasonNumber,
    this.episodeNumber,
    this.isMovie = false,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final MediaKitPlayerController _controller;
  bool _showControls = false; // Start hidden when playing
  Timer? _controlsTimer;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _controller = MediaKitPlayerController();
    _startPlayback();
    // Listen to playing state to manage auto-hide timer
    _controller.playingStream.listen((isPlaying) {
      if (isPlaying) {
        // When playing starts, start the auto-hide timer
        _startAutoHideTimer();
      } else {
        // When paused, cancel timer and ensure paused overlay is visible
        // (paused overlay is always shown, independent of _showControls)
        _cancelAutoHideTimer();
        // Don't modify _showControls when paused - paused overlay doesn't depend on it
      }
    });
  }

  void _startAutoHideTimer() {
    _cancelAutoHideTimer();
    _controlsTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _controller.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _cancelAutoHideTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
  }

  void _onControlsHoverEnter() {
    // Show controls on hover (works for both playing and paused)
    setState(() => _showControls = true);
    // Only manage timer when playing (paused overlay stays visible)
    if (_controller.isPlaying) {
      _cancelAutoHideTimer();
    }
  }

  void _onControlsHoverExit() {
    // Only start timer when playing (when paused, controls can stay visible)
    if (_controller.isPlaying) {
      _startAutoHideTimer();
    }
    // When paused, keep controls visible even on hover exit (user might want to use them)
    // Or hide them - let's hide them for consistency
    if (!_controller.isPlaying) {
      setState(() => _showControls = false);
    }
  }

  void _onControlInteraction() {
    if (_controller.isPlaying && _showControls) {
      _startAutoHideTimer();
    }
  }

  Future<void> _startPlayback() async {
    try {
      await _controller.start(
        widget.streamUrl,
        subtitles: widget.subtitles,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start playback: $e')),
        );
      }
    }
  }



  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return '0:00';

    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Video player (bottom layer)
            Video(
              controller: _controller.videoController,
              controls: NoVideoControls,
              fit: BoxFit.contain,
            ),

            // 2. Info card / Paused overlay (middle layer - only when paused)
            StreamBuilder<bool>(
              stream: _controller.playingStream,
              initialData: false,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                if (!isPlaying) {
                  return _buildPausedOverlay();
                }
                return const SizedBox.shrink();
              },
            ),

            // 3. Bottom hover detection area (for showing controls when playing)
            StreamBuilder<bool>(
              stream: _controller.playingStream,
              initialData: false,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                // Show hover area when playing and controls are hidden
                // (When paused, controls are always visible, so no hover area needed)
                if (isPlaying && !_showControls) {
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 200,
                    child: MouseRegion(
                      onEnter: (_) => _onControlsHoverEnter(),
                      child: Container(color: Colors.transparent),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // 4. Controls overlay (top layer - always on top when shown)
            // When paused, always show controls on top of info card
            // When playing, show controls based on hover/timer
            StreamBuilder<bool>(
              stream: _controller.playingStream,
              initialData: false,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                // When paused, always show controls (on top of info card)
                // When playing, show controls only if _showControls is true
                if (!isPlaying || _showControls) {
                  return _buildControlsOverlay();
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPausedOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Stack(
        children: [
          // Top left: Back button
          Positioned(
            top: 40,
            left: 40,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.4,
              child: Container(
                margin: const EdgeInsets.only(left: 60),
                constraints: const BoxConstraints(maxWidth: 700),
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    if (widget.logoUrl != null)
                      SizedBox(
                        height: 120,
                        child: Image.network(
                          widget.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    const SizedBox(height: 32),
                    // Season/Episode
                    if (!widget.isMovie && widget.seasonNumber != null && widget.episodeNumber != null)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SEASON ${widget.seasonNumber}',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'EPISODE ${widget.episodeNumber}',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      widget.episodeName ?? widget.title ?? 'Unknown Title',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description
                    if (widget.description != null)
                      Text(
                        widget.description!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    const SizedBox(height: 40),

                    // Resume button
                    ElevatedButton(
                      onPressed: () => _controller.togglePlayPause(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, size: 28),
                          SizedBox(width: 12),
                          Text('RESUME', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return MouseRegion(
      onEnter: (_) => _onControlsHoverEnter(),
      onExit: (_) => _onControlsHoverExit(),
      child: Column(
        children: [
          // Top bar with back button and title
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Bottom controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return StreamBuilder<bool>(
      stream: _controller.playingStream,
      initialData: false,
      builder: (context, playingSnapshot) {
        final isPlaying = playingSnapshot.data ?? false;
        return StreamBuilder<double>(
          stream: _controller.positionStream,
          initialData: 0.0,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? 0.0;
            final duration = _controller.duration;
            return Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  Slider(
                    value: duration > 0 ? position.clamp(0.0, duration) : 0.0,
                    max: duration > 0 ? duration : 1.0,
                    onChanged: (value) {
                      _controller.seek(value);
                      _onControlInteraction();
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.white30,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side: Volume control
                      StreamBuilder<double>(
                        stream: _controller.volumeStream,
                        initialData: 100.0,
                        builder: (context, volumeSnapshot) {
                          final volume = volumeSnapshot.data ?? 100.0;
                          return Row(
                            children: [
                              Icon(
                                volume > 50 ? Icons.volume_up : volume > 0 ? Icons.volume_down : Icons.volume_off,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 120,
                                child: Slider(
                                  value: volume,
                                  max: 100.0,
                                  onChanged: (value) {
                                    _controller.setVolume(value);
                                    _onControlInteraction();
                                  },
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white30,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      // Main controls
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10, color: Colors.white, size: 36),
                            onPressed: () {
                              _controller.seek(position - 10);
                              _onControlInteraction();
                            },
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 48),
                            onPressed: () {
                              _controller.togglePlayPause();
                              _onControlInteraction();
                            },
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.forward_10, color: Colors.white, size: 36),
                            onPressed: () {
                              _controller.seek(position + 10);
                              _onControlInteraction();
                            },
                          ),
                        ],
                      ),
                      // Right side: Subtitles, Stream, Audio, Settings
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              // TODO: Implement stream selection
                            },
                            child: const Text(
                              'Stream: 1',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.audiotrack, color: Colors.white, size: 28),
                            onPressed: () {
                              // TODO: Implement audio stream selection
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.closed_caption, color: Colors.white, size: 28),
                            onPressed: () {
                              // TODO: Implement subtitle selection
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                            onPressed: () {
                              // TODO: Implement settings
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}