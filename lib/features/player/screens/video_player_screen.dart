import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../logic/fvp_player_controller.dart';
import '../../../core/widgets/back_button_overlay.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/watch_history_service.dart';
import '../../../core/services/trakt_scrobble_service.dart';
import '../../../core/models/trakt_models.dart';

/// Video player screen with FVP integration and custom controls
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
  final String? contentId; // Content ID (e.g., "tmdb:123" or "imdb:tt123")
  final String? imdbId; // IMDb ID for tracking
  final String? tmdbId; // TMDB ID for tracking
  final int? runtime; // Runtime in seconds

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
    this.contentId,
    this.imdbId,
    this.tmdbId,
    this.runtime,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final FvpPlayerController _controller;
  bool _showControls = false; // Start hidden when playing
  Timer? _controlsTimer;
  Timer? _progressSaveTimer;
  bool _isFullscreen = false;
  late final WatchHistoryService _watchHistoryService;
  late final TraktScrobbleService _traktScrobbleService;
  late final TraktContentData _traktContentData;
  Timer? _traktScrobbleTimer;
  bool _hasStartedTraktScrobble = false;

  @override
  void initState() {
    super.initState();
    _watchHistoryService = ServiceLocator.instance.watchHistoryService;
    _traktScrobbleService = ServiceLocator.instance.traktScrobbleService;

    // Create Trakt content data for scrobbling
    _traktContentData = TraktContentData(
      type: widget.isMovie ? 'movie' : 'episode',
      imdbId: widget.imdbId ?? '',
      title: widget.title ?? 'Unknown',
      year: 0, // We don't have year information, could be added later
      season: widget.seasonNumber,
      episode: widget.episodeNumber,
      showTitle: widget.isMovie ? null : widget.title,
      showYear: widget.isMovie ? null : 0,
      showImdbId: widget.isMovie ? null : widget.imdbId,
    );

    _controller = FvpPlayerController();
    _startPlayback();
    // Listen to playing state to manage auto-hide timer and Trakt scrobbling
    _controller.playingStream.listen((isPlaying) {
      if (isPlaying) {
        // When playing starts, start the auto-hide timer
        _startAutoHideTimer();
        _startProgressTracking();
        _startTraktScrobbling();
      } else {
        // When paused, cancel timer and ensure paused overlay is visible
        // (paused overlay is always shown, independent of _showControls)
        _cancelAutoHideTimer();
        _stopProgressTracking();
        _pauseTraktScrobbling();
        // Save progress when paused
        _saveProgress();
        // Don't modify _showControls when paused - paused overlay doesn't depend on it
      }
    });
  }

  @override
  void dispose() {
    _saveProgress(); // Save progress when closing
    _stopProgressTracking();
    _stopTraktScrobbling(); // Stop Trakt scrobbling when closing
    _cancelAutoHideTimer();
    _controlsTimer?.cancel();
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startProgressTracking() {
    _stopProgressTracking();
    // Save progress every 30 seconds while playing
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveProgress();
    });
  }

  void _stopProgressTracking() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
  }

  /// Start Trakt scrobbling when playback begins
  void _startTraktScrobbling() {
    // Only start if we have valid IMDb ID and haven't started yet
    if (_traktContentData.imdbId.isEmpty || _hasStartedTraktScrobble) {
      return;
    }

    // Start Trakt scrobbling
    _traktScrobbleService.scrobbleStart(_traktContentData, 0.1); // Start with minimal progress
    _hasStartedTraktScrobble = true;

    // Set up periodic scrobble updates every 5 minutes (300 seconds)
    _traktScrobbleTimer?.cancel();
    _traktScrobbleTimer = Timer.periodic(const Duration(seconds: 300), (_) {
      _updateTraktProgress();
    });
  }

  /// Pause Trakt scrobbling when playback is paused
  void _pauseTraktScrobbling() {
    if (!_hasStartedTraktScrobble) return;

    _updateTraktProgress(); // Update progress before pausing
    _traktScrobbleTimer?.cancel();
    _traktScrobbleTimer = null;
  }

  /// Stop Trakt scrobbling when closing the player
  void _stopTraktScrobbling() {
    if (!_hasStartedTraktScrobble) return;

    _traktScrobbleTimer?.cancel();
    _traktScrobbleTimer = null;

    // Calculate final progress and stop scrobbling
    final progress = _controller.duration > 0
        ? _controller.position / _controller.duration
        : 0.0;

    _traktScrobbleService.scrobbleStop(_traktContentData, progress * 100);
    _hasStartedTraktScrobble = false;
  }

  /// Update Trakt progress during playback
  void _updateTraktProgress() {
    if (!_hasStartedTraktScrobble || !_controller.isPlaying) return;

    final progress = _controller.duration > 0
        ? (_controller.position / _controller.duration) * 100
        : 0.0;

    _traktScrobbleService.scrobblePause(_traktContentData, progress);
  }

  Future<void> _saveProgress() async {
    if (widget.title == null || widget.title!.isEmpty) return;

    try {
      final duration = _controller.duration;
      final position = _controller.position;

      if (duration <= 0 || position < 0) return;

      final progress = (position / duration * 100.0).clamp(0.0, 100.0);

      // Only save if progress is meaningful (at least 1% and less than 100%)
      if (progress < 1.0 || progress >= 100.0) return;

      // Extract TMDB ID from contentId if available
      String? tmdbId = widget.tmdbId;
      String? imdbId = widget.imdbId;

      if (tmdbId == null && widget.contentId != null) {
        // Try to extract from contentId (e.g., "tmdb:123")
        if (widget.contentId!.startsWith('tmdb:')) {
          tmdbId = widget.contentId!.substring(5);
        } else if (widget.contentId!.startsWith('imdb:')) {
          imdbId = widget.contentId!.substring(5);
        }
      }

      final title = widget.isMovie
          ? widget.title!
          : (widget.episodeName ?? widget.title!);

      await _watchHistoryService.saveLocalProgress(
        contentId: widget.contentId ?? widget.title ?? 'unknown',
        type: widget.isMovie ? 'movie' : 'episode',
        title: title,
        progress: progress,
        imdbId: imdbId,
        tmdbId: tmdbId,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
        runtime: widget.runtime,
        pausedAt: DateTime.now(),
      );
    } catch (e) {
      // Silently fail - progress saving shouldn't interrupt playback
      debugPrint('Error saving progress: $e');
    }
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
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to start playback: $e'),
            ),
          ),
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Video player (bottom layer)
            StreamBuilder<bool>(
              stream: _controller.initializedStream,
              initialData: false,
              builder: (context, initializedSnapshot) {
                final isInitialized = initializedSnapshot.data ?? false;
                final textureId = _controller.textureId;
                
                if (!isInitialized || textureId == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                return StreamBuilder<double?>(
                  stream: _controller.aspectRatioStream,
                  initialData: _controller.aspectRatio,
                  builder: (context, aspectRatioSnapshot) {
                    final aspectRatio = aspectRatioSnapshot.data ?? 16 / 9;
                    return Center(
                      child: AspectRatio(
                        aspectRatio: aspectRatio,
                        child: Texture(
                          textureId: textureId,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    );
                  },
                );
              },
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
    );
  }

  Widget _buildStreamSelectionPopover(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Solid dark background - Zinc 900
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Stream Selection',
            style: TextStyle(
              color: colorScheme.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(16),
          Text(
            'Stream selection will be available here.',
            style: TextStyle(
              color: colorScheme.foreground.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioSelectionPopover(BuildContext parentContext) {
    final colorScheme = Theme.of(parentContext).colorScheme;
    
    // Use StatefulBuilder to allow the popover to rebuild when tracks change
    return StatefulBuilder(
      builder: (popoverContext, setState) {
        final audioTracks = _getAudioTracks();
        
        return Container(
          width: 400,
          height: 450,
          decoration: BoxDecoration(
            color: const Color(0xFF18181B), // Solid dark background - Zinc 900
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.border,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'AUDIO TRACK',
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Audio tracks list - scrollable section
              if (audioTracks.isEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No audio tracks available.',
                      style: TextStyle(
                        color: colorScheme.foreground.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    itemCount: audioTracks.length,
                    itemBuilder: (context, index) {
                      final track = audioTracks[index];
                      return _AudioTrackItem(
                        track: track,
                        onTap: () {
                          _controller.setAudioTrack(track.index);
                          // Rebuild the popover to update selection indicators
                          setState(() {});
                          // Don't close the popover - let user close it manually or click outside
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<AudioTrackInfo> _getAudioTracks() {
    return _controller.getAudioTracks();
  }

  List<SubtitleTrackInfo> _getSubtitleTracks() {
    return _controller.getSubtitleTracks();
  }

  Widget _buildSubtitleSelectionPopover(BuildContext parentContext) {
    final colorScheme = Theme.of(parentContext).colorScheme;
    
    // Use Builder to capture the popover's context
    return Builder(
      builder: (popoverContext) {
        final subtitleTracks = _getSubtitleTracks();
        
        return Container(
          width: 300,
          decoration: BoxDecoration(
            color: const Color(0xFF18181B), // Solid dark background - Zinc 900
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.border,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Subtitles',
                style: TextStyle(
                  color: colorScheme.foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(16),
              // Option to disable subtitles
              VideoSafeShadcnItem(
                label: 'Off',
                isSelected: _controller.getActiveSubtitleTrackIndex() == null,
                onTap: () {
                  _controller.setSubtitleTrack(null);
                  Navigator.of(popoverContext).pop();
                },
              ),
          if (subtitleTracks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No subtitle tracks available.',
                style: TextStyle(
                  color: colorScheme.foreground.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: subtitleTracks.length,
                itemBuilder: (context, index) {
                  final track = subtitleTracks[index];
                  final isSelected = track.isActive;
                  
                  // Build label with codec info if available
                  String label = track.displayName;
                  if (track.codec.isNotEmpty && track.codec != 'Unknown') {
                    label += ' • ${track.codec.toUpperCase()}';
                  }
                  
                  return VideoSafeShadcnItem(
                    label: label,
                    isSelected: isSelected,
                    onTap: () {
                      _controller.setSubtitleTrack(track.index);
                      Navigator.of(popoverContext).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
    );
  }

  Widget _buildSettingsPopover(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Solid dark background - Zinc 900
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Player Settings',
            style: TextStyle(
              color: colorScheme.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(16),
          Text(
            'Player settings will be available here.',
            style: TextStyle(
              color: colorScheme.foreground.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPausedOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.background.withValues(alpha: 0.8),
      child: Stack(
        children: [
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
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    const SizedBox(height: 32),
                    // Season/Episode
                    if (!widget.isMovie &&
                        widget.seasonNumber != null &&
                        widget.episodeNumber != null)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SEASON ${widget.seasonNumber}',
                              style: TextStyle(
                                  color: colorScheme.foreground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'EPISODE ${widget.episodeNumber}',
                            style: TextStyle(
                                color: colorScheme.foreground.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Title - Hide for movies when logo is visible, but always show for episodes
                    if (!widget.isMovie || widget.logoUrl == null)
                      Text(
                        widget.episodeName ?? widget.title ?? 'Unknown Title',
                        style: TextStyle(
                          color: colorScheme.foreground,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (!widget.isMovie || widget.logoUrl == null)
                      const SizedBox(height: 20),

                    // Description
                    if (widget.description != null)
                      Text(
                        widget.description!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.foreground.withValues(alpha: 0.75),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Back button overlay
          BackButtonOverlay(
            onBack: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              }
            },
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
            child: Stack(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      const SizedBox(width: 48), // Space for back button
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.title ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.foreground,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Back button overlay
                BackButtonOverlay(
                  padding: const EdgeInsets.only(top: 10, left: 10),
                  onBack: () {
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.pop();
                    }
                  },
                ),
              ],
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
    final colorScheme = Theme.of(context).colorScheme;
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
                  colors: [Colors.transparent, colorScheme.background.withValues(alpha: 0.8)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  material.Slider(
                    value: duration > 0 ? position.clamp(0.0, duration) : 0.0,
                    max: duration > 0 ? duration : 1.0,
                    onChanged: (value) {
                      _controller.seek(value);
                      _onControlInteraction();
                    },
                    activeColor: colorScheme.foreground,
                    inactiveColor: colorScheme.foreground.withValues(alpha: 0.3),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(position),
                          style: TextStyle(
                              color: colorScheme.foreground.withValues(alpha: 0.7), fontSize: 12)),
                      Text(_formatDuration(duration),
                          style: TextStyle(
                              color: colorScheme.foreground.withValues(alpha: 0.7), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Buttons Row
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
                                volume > 50
                                    ? Icons.volume_up
                                    : volume > 0
                                        ? Icons.volume_down
                                        : Icons.volume_off,
                                color: colorScheme.foreground,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 120,
                                child: material.Slider(
                                  value: volume,
                                  max: 100.0,
                                  onChanged: (value) {
                                    _controller.setVolume(value);
                                    _onControlInteraction();
                                  },
                                  activeColor: colorScheme.foreground,
                                  inactiveColor: colorScheme.foreground.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // Main controls (Rewind, Play, Forward)
                      Row(
                        children: [
                          IconButton(
                            variance: ButtonVariance.ghost,
                            icon: Icon(Icons.replay_10,
                                color: colorScheme.foreground, size: 36),
                            onPressed: () {
                              _controller.seek(position - 10);
                              _onControlInteraction();
                            },
                          ),
                          const SizedBox(width: 20),
                          // Show loading indicator when buffering or not initialized, otherwise show play/pause button
                          StreamBuilder<bool>(
                            stream: _controller.bufferingStream,
                            initialData: _controller.isBuffering,
                            builder: (context, bufferingSnapshot) {
                              final isBuffering = bufferingSnapshot.data ?? false;
                              final isInitialized = _controller.isInitialized;
                              // Show loading indicator when buffering or not initialized
                              if (isBuffering || !isInitialized) {
                                return IconButton(
                                  variance: ButtonVariance.ghost,
                                  icon: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      colorScheme.foreground,
                                      BlendMode.srcIn,
                                    ),
                                    child: CircularProgressIndicator(
                                      size: 48,
                                    ),
                                  ),
                                  onPressed: null,
                                );
                              }
                              return IconButton(
                                variance: ButtonVariance.ghost,
                                icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: colorScheme.foreground,
                                    size: 48),
                                onPressed: () {
                                  _controller.togglePlayPause();
                                  _onControlInteraction();
                                },
                              );
                            },
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            variance: ButtonVariance.ghost,
                            icon: Icon(Icons.forward_10,
                                color: colorScheme.foreground, size: 36),
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
                          GhostButton(
                            onPressed: () {
                              showPopover(
                                context: context,
                                alignment: Alignment.topRight,
                                offset: const Offset(20, 8),
                                overlayBarrier: OverlayBarrier(
                                  borderRadius: Theme.of(context).borderRadiusLg,
                                ),
                                builder: (context) => _buildStreamSelectionPopover(context),
                              );
                            },
                            child: Text(
                              'Stream: 1',
                              style:
                                  TextStyle(color: colorScheme.foreground, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            variance: ButtonVariance.ghost,
                            icon: Icon(Icons.audiotrack,
                                color: colorScheme.foreground, size: 28),
                            onPressed: () {
                              showPopover(
                                context: context,
                                alignment: Alignment.topRight,
                                offset: const Offset(20, 8),
                                overlayBarrier: OverlayBarrier(
                                  borderRadius: Theme.of(context).borderRadiusLg,
                                ),
                                builder: (context) => _buildAudioSelectionPopover(context),
                              );
                            },
                          ),
                          IconButton(
                            variance: ButtonVariance.ghost,
                            icon: Icon(Icons.closed_caption,
                                color: colorScheme.foreground, size: 28),
                            onPressed: () {
                              showPopover(
                                context: context,
                                alignment: Alignment.topRight,
                                offset: const Offset(20, 8),
                                overlayBarrier: OverlayBarrier(
                                  borderRadius: Theme.of(context).borderRadiusLg,
                                ),
                                builder: (context) => _buildSubtitleSelectionPopover(context),
                              );
                            },
                          ),
                          IconButton(
                            variance: ButtonVariance.ghost,
                            icon: Icon(Icons.settings,
                                color: colorScheme.foreground, size: 28),
                            onPressed: () {
                              showPopover(
                                context: context,
                                alignment: Alignment.topRight,
                                offset: const Offset(20, 8),
                                overlayBarrier: OverlayBarrier(
                                  borderRadius: Theme.of(context).borderRadiusLg,
                                ),
                                builder: (context) => _buildSettingsPopover(context),
                              );
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

/// Audio track item widget matching the design spec
class _AudioTrackItem extends StatefulWidget {
  final AudioTrackInfo track;
  final VoidCallback onTap;

  const _AudioTrackItem({
    required this.track,
    required this.onTap,
  });

  @override
  State<_AudioTrackItem> createState() => _AudioTrackItemState();
}

class _AudioTrackItemState extends State<_AudioTrackItem> {
  bool _isHovered = false;

  String _getChannelConfig(int channels) {
    switch (channels) {
      case 1:
        return 'Mono';
      case 2:
        return 'Stereo';
      case 6:
        return '5.1';
      case 8:
        return '7.1';
      default:
        return '${channels}ch';
    }
  }

  String _getFormattedSampleRate(int sampleRate) {
    if (sampleRate >= 1000) {
      return '${(sampleRate / 1000).toStringAsFixed(0)}kHz';
    }
    return '${sampleRate}Hz';
  }

  String _formatCodec(String codec) {
    // Format codec names to match common formats
    final upper = codec.toUpperCase();
    if (upper.contains('E-AC3') || upper.contains('EAC3')) {
      return 'E-AC3';
    }
    if (upper.contains('AC3')) {
      return 'AC3';
    }
    if (upper.contains('AAC')) {
      return 'AAC';
    }
    if (upper.contains('MP3') || upper.contains('MPEG')) {
      return 'MP3';
    }
    return upper;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = widget.track.isActive;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF27272A) // Slightly darker background for selected
                : (_isHovered ? const Color(0xFF27272A) : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Language name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.track.language != 'Unknown' 
                          ? widget.track.language 
                          : 'Track ${widget.track.index + 1}',
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Technical details: "48kHz • 6ch"
                    Text(
                      '${_getFormattedSampleRate(widget.track.sampleRate)} • ${widget.track.channels}ch',
                      style: TextStyle(
                        color: colorScheme.foreground.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Codec badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  _formatCodec(widget.track.codec),
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Channel configuration badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getChannelConfig(widget.track.channels),
                  style: TextStyle(
                    color: colorScheme.foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Checkmark for selected track
              if (isSelected)
                Icon(
                  Icons.check,
                  color: colorScheme.primary,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Video-safe Shadcn-style item widget that renders perfectly over video textures
/// Avoids any blur or transparency that can cause glitches
class VideoSafeShadcnItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const VideoSafeShadcnItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<VideoSafeShadcnItem> createState() => _VideoSafeShadcnItemState();
}

class _VideoSafeShadcnItemState extends State<VideoSafeShadcnItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // 1. GET YOUR ACCENT COLOR
    // This grabs the specific color (Blue, Violet, Orange) from your ThemeService
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    const zinc50 = Color(0xFFFAFAFA); 
    
    // SAFE BACKGROUND:
    // Keep it dark grey (Zinc 800) on hover. 
    // We DO NOT use the accent color for the background because 
    // vibrant/transparent backgrounds can glitch over video textures.
    final backgroundColor = _isHovered 
        ? const Color(0xFF27272A) 
        : Colors.transparent;

    // ACCENT FOREGROUND:
    // We apply the accent color to the Text and Icon instead.
    // This looks premium (like Shadcn) and renders perfectly over video.
    final foregroundColor = widget.isSelected 
        ? primaryColor 
        : zinc50;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            
            // OPTIONAL: Add a thin border of your accent color when selected
            // This reinforces the selection without filling the card
            border: widget.isSelected 
                ? Border.all(color: primaryColor.withValues(alpha: 0.5), width: 1) 
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: foregroundColor, // <--- Accent Color Applied Here
                    fontSize: 13,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (widget.isSelected)
                Icon(
                  Icons.check, 
                  color: foregroundColor, // <--- And Here
                  size: 16
                ),
            ],
          ),
        ),
      ),
    );
  }
}