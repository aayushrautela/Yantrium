import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as fvp;
import '../../../core/services/torrent_service.dart';
import '../../../core/services/service_locator.dart';

/// Information about an audio track
class AudioTrackInfo {
  final int index;
  final String language;
  final String? title;
  final String codec;
  final int channels;
  final int sampleRate;
  final bool isActive;

  AudioTrackInfo({
    required this.index,
    required this.language,
    this.title,
    required this.codec,
    required this.channels,
    required this.sampleRate,
    required this.isActive,
  });

  String get displayName {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    if (language != 'Unknown') {
      return '$language (${codec.toUpperCase()})';
    }
    return 'Track ${index + 1} (${codec.toUpperCase()})';
  }

  String get description {
    final parts = <String>[];
    if (channels > 0) {
      parts.add('${channels}ch');
    }
    if (sampleRate > 0) {
      parts.add('${(sampleRate / 1000).toStringAsFixed(1)}kHz');
    }
    return parts.join(', ');
  }
}

/// Information about a subtitle track
class SubtitleTrackInfo {
  final int index;
  final String language;
  final String? title;
  final String codec;
  final bool isActive;

  SubtitleTrackInfo({
    required this.index,
    required this.language,
    this.title,
    required this.codec,
    required this.isActive,
  });

  String get displayName {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    if (language != 'Unknown') {
      return language;
    }
    return 'Track ${index + 1}';
  }
}

/// Controller for video playback using FVP (FFmpeg-based) with Texture widget
class FvpPlayerController {
  fvp.Player? _player;
  int? _textureId;
  final TorrentService _torrentService;
  Timer? _positionUpdateTimer;
  VoidCallback? _textureIdListener;

  FvpPlayerController({TorrentService? torrentService})
      : _torrentService = torrentService ?? ServiceLocator.instance.torrentService;

  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isInitialized = false;
  bool _isBuffering = false;
  bool _isDisposing = false;
  double _position = 0.0;
  double _duration = 0.0;
  double _volume = 100.0;
  double? _aspectRatio;

  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<double> _positionController = StreamController<double>.broadcast();
  final StreamController<double> _volumeController = StreamController<double>.broadcast();
  final StreamController<bool> _initializedController = StreamController<bool>.broadcast();
  final StreamController<bool> _bufferingController = StreamController<bool>.broadcast();
  final StreamController<double?> _aspectRatioController = StreamController<double?>.broadcast();

  Stream<bool> get playingStream => _playingController.stream;
  Stream<double> get positionStream => _positionController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<bool> get initializedStream => _initializedController.stream;
  Stream<bool> get bufferingStream => _bufferingController.stream;
  Stream<double?> get aspectRatioStream => _aspectRatioController.stream;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isInitialized => _isInitialized;
  bool get isBuffering => _isBuffering;
  double get position => _position;
  double get duration => _duration;
  double get volume => _volume;
  int? get textureId => _textureId;
  double? get aspectRatio => _aspectRatio;

  // Audio and subtitle track information
  List<AudioTrackInfo> getAudioTracks() {
    if (_player == null || !_isInitialized) {
      return [];
    }
    
    final audioStreams = _player!.mediaInfo.audio;
    if (audioStreams == null || audioStreams.isEmpty) {
      return [];
    }

    final activeTracks = _player!.activeAudioTracks;
    final activeIndex = activeTracks.isNotEmpty ? activeTracks.first : -1;

    return audioStreams.map((stream) {
      final metadata = stream.metadata;
      final language = metadata['language'] ?? 
                      metadata['LANGUAGE'] ?? 
                      metadata['lang'] ?? 
                      'Unknown';
      final title = metadata['title'] ?? 
                   metadata['TITLE'] ?? 
                   metadata['handler_name'] ??
                   '';

      return AudioTrackInfo(
        index: stream.index,
        language: language,
        title: title.isNotEmpty ? title : null,
        codec: stream.codec.codec.isNotEmpty ? stream.codec.codec : 'Unknown',
        channels: stream.codec.channels,
        sampleRate: stream.codec.sampleRate,
        isActive: stream.index == activeIndex,
      );
    }).toList();
  }

  List<SubtitleTrackInfo> getSubtitleTracks() {
    if (_player == null || !_isInitialized) {
      return [];
    }
    
    final subtitleStreams = _player!.mediaInfo.subtitle;
    if (subtitleStreams == null || subtitleStreams.isEmpty) {
      return [];
    }

    final activeTracks = _player!.activeSubtitleTracks;
    final activeIndex = activeTracks.isNotEmpty ? activeTracks.first : -1;

    return subtitleStreams.map((stream) {
      final metadata = stream.metadata;
      final language = metadata['language'] ?? 
                      metadata['LANGUAGE'] ?? 
                      metadata['lang'] ?? 
                      'Unknown';
      final title = metadata['title'] ?? 
                   metadata['TITLE'] ?? 
                   metadata['handler_name'] ??
                   '';

      return SubtitleTrackInfo(
        index: stream.index,
        language: language,
        title: title.isNotEmpty ? title : null,
        codec: stream.codec.codec.isNotEmpty ? stream.codec.codec : 'Unknown',
        isActive: stream.index == activeIndex,
      );
    }).toList();
  }

  int? getActiveAudioTrackIndex() {
    if (_player == null || !_isInitialized) {
      return null;
    }
    final activeTracks = _player!.activeAudioTracks;
    return activeTracks.isNotEmpty ? activeTracks.first : null;
  }

  int? getActiveSubtitleTrackIndex() {
    if (_player == null || !_isInitialized) {
      return null;
    }
    final activeTracks = _player!.activeSubtitleTracks;
    return activeTracks.isNotEmpty ? activeTracks.first : null;
  }

  Future<void> setAudioTrack(int trackIndex) async {
    if (_player == null || !_isInitialized) {
      if (kDebugMode) {
        debugPrint('FVP: Cannot set audio track - player not initialized');
      }
      return;
    }

    final audioStreams = _player!.mediaInfo.audio;
    if (audioStreams == null || 
        trackIndex < 0 || 
        trackIndex >= audioStreams.length) {
      if (kDebugMode) {
        debugPrint('FVP: Invalid audio track index: $trackIndex');
      }
      return;
    }

    _player!.activeAudioTracks = [trackIndex];
    if (kDebugMode) {
      debugPrint('FVP: Set active audio track to index: $trackIndex');
    }
  }

  Future<void> setSubtitleTrack(int? trackIndex) async {
    if (_player == null || !_isInitialized) {
      if (kDebugMode) {
        debugPrint('FVP: Cannot set subtitle track - player not initialized');
      }
      return;
    }

    if (trackIndex == null) {
      // Disable subtitles
      _player!.activeSubtitleTracks = [];
      if (kDebugMode) {
        debugPrint('FVP: Disabled subtitles');
      }
      return;
    }

    final subtitleStreams = _player!.mediaInfo.subtitle;
    if (subtitleStreams == null || 
        trackIndex < 0 || 
        trackIndex >= subtitleStreams.length) {
      if (kDebugMode) {
        debugPrint('FVP: Invalid subtitle track index: $trackIndex');
      }
      return;
    }

    _player!.activeSubtitleTracks = [trackIndex];
    if (kDebugMode) {
      debugPrint('FVP: Set active subtitle track to index: $trackIndex');
    }
  }

  // Deprecated - kept for backward compatibility but will be removed
  // The screen should use textureId and StreamBuilders instead
  @Deprecated('Use textureId and StreamBuilders instead')
  dynamic get videoController => null;

  Future<void> start(String url, {List<String>? subtitles}) async {
    try {
      if (kDebugMode) {
        debugPrint('FVP: Starting playback of $url');
      }

      // Dispose previous player if exists
      await _disposePlayer();

      String streamUrl = url;

      // Handle magnet URLs by using torrent service
      if (url.startsWith('magnet:')) {
        if (kDebugMode) {
          debugPrint('FVP: Detected magnet URL, starting torrent download');
        }
        streamUrl = await _torrentService.addMagnet(url);
        if (kDebugMode) {
          debugPrint('FVP: Torrent streaming URL: $streamUrl');
        }
      }

      // Create new player instance
      _player = fvp.Player();

      // Set up state change listener
      _player!.onStateChanged((oldState, newState) {
        _handlePlayerState(newState);
      });

      // Set up media status listener for buffering detection
      _player!.onMediaStatus((oldStatus, newStatus) {
        _handleMediaStatus(oldStatus, newStatus);
        return true; // Allow continuation
      });

      // Set up texture ID listener
      _textureIdListener = () {
        final newTextureId = _player!.textureId.value;
        if (newTextureId != null && newTextureId != _textureId) {
          _textureId = newTextureId;
        }
      };
      _player!.textureId.addListener(_textureIdListener!);

      // Set initial volume
      _player!.volume = _volume / 100.0;

      // Set media URL
      _player!.media = streamUrl;

      // Prepare the media (loads and decodes first frame)
      // prepare() returns the result position, negative means failed
      final prepareResult = await _player!.prepare();
      if (prepareResult < 0) {
        throw Exception('Failed to prepare media (error code: $prepareResult)');
      }
      
      if (kDebugMode) {
        debugPrint('FVP: Media prepared at position: $prepareResult');
      }

      // Wait for initialization (mediaInfo available)
      await _waitForInitialization();

      // Wait for media to be loaded (MediaStatus.loaded)
      await _waitForMediaLoaded();

      // Create/update texture after media is loaded
      // This ensures texture has valid dimensions
      await _player!.updateTexture();
      _textureId = _player!.textureId.value;
      
      // Wait a bit more for texture to be ready if needed
      int textureWaitAttempts = 0;
      while (_textureId == null && textureWaitAttempts < 10) {
        await Future.delayed(const Duration(milliseconds: 50));
        _textureId = _player!.textureId.value;
        textureWaitAttempts++;
      }

      if (kDebugMode) {
        if (_textureId != null) {
          debugPrint('FVP: Texture initialized with ID: $_textureId');
        } else {
          debugPrint('FVP: Warning - Texture ID is still null after waiting');
        }
      }

      // Get aspect ratio from media info
      _updateAspectRatio();

      // Start position updates
      _startPositionUpdates();

      // Start playing
      _player!.state = fvp.PlaybackState.playing;
      _isPlaying = true;
      _isPaused = false;
      if (!_isDisposing && !_playingController.isClosed) {
      _playingController.add(_isPlaying);
    }
      if (!_isDisposing && !_initializedController.isClosed) {
        _initializedController.add(_isInitialized);
      }

      // Give the player a moment to start
      await Future.delayed(const Duration(milliseconds: 100));

      if (kDebugMode) {
        final currentState = _player!.state;
        final currentStatus = _player!.mediaStatus;
        debugPrint('FVP: Playback started with texture ID: $_textureId');
        debugPrint('FVP: Current state: $currentState, status: $currentStatus');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FVP: Error starting playback: $e');
      }
      rethrow;
    }
  }

  Future<void> _waitForInitialization() async {
    // Wait for player to be initialized (media info available)
    int attempts = 0;
    const maxAttempts = 50; // 5 seconds max wait
    while (attempts < maxAttempts) {
      if (_player?.mediaInfo.video != null && _player!.mediaInfo.video!.isNotEmpty) {
        _isInitialized = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!_isInitialized) {
      // If still not initialized, set a default
      _isInitialized = true; // Assume initialized anyway
      if (kDebugMode) {
        debugPrint('FVP: Warning - mediaInfo not available after wait');
      }
    }
  }

  Future<void> _waitForMediaLoaded() async {
    // Wait for media to be loaded (MediaStatus.loaded or MediaStatus.prepared)
    // This ensures the player is ready for playback
    int attempts = 0;
    const maxAttempts = 100; // 10 seconds max wait
    while (attempts < maxAttempts) {
      if (_player != null) {
        final status = _player!.mediaStatus;
        if (status.test(fvp.MediaStatus.loaded) || status.test(fvp.MediaStatus.prepared)) {
          if (kDebugMode) {
            debugPrint('FVP: Media loaded successfully (status: $status)');
          }
          return;
        }
        if (kDebugMode && attempts % 10 == 0) {
          debugPrint('FVP: Waiting for media to load... (attempt $attempts, status: $status)');
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (kDebugMode) {
      final finalStatus = _player?.mediaStatus;
      debugPrint('FVP: Warning - MediaStatus.loaded not reached after wait (final status: $finalStatus)');
    }
  }

  void _handlePlayerState(fvp.PlaybackState state) {
    switch (state) {
      case fvp.PlaybackState.playing:
        _isPlaying = true;
        _isPaused = false;
        break;
      case fvp.PlaybackState.paused:
        _isPlaying = false;
        _isPaused = true;
        break;
      case fvp.PlaybackState.running:
        // Running is like playing
        _isPlaying = true;
        _isPaused = false;
        break;
      case fvp.PlaybackState.stopped:
        _isPlaying = false;
        _isPaused = true;
        break;
      case fvp.PlaybackState.notRunning:
        _isPlaying = false;
        _isPaused = true;
        break;
    }

    if (!_isDisposing && !_playingController.isClosed) {
      _playingController.add(_isPlaying);
    }
  }

  void _handleMediaStatus(fvp.MediaStatus oldStatus, fvp.MediaStatus newStatus) {
    final wasBuffering = _isBuffering;

    // Buffering is detected via MediaStatus, not PlaybackState
    // Check for buffering, stalled, or loading states
    final isCurrentlyBuffering = newStatus.test(fvp.MediaStatus.buffering) ||
        newStatus.test(fvp.MediaStatus.stalled) ||
        (newStatus.test(fvp.MediaStatus.loading) && !newStatus.test(fvp.MediaStatus.loaded));

    _isBuffering = isCurrentlyBuffering;

    if (_isBuffering != wasBuffering) {
      if (!_isDisposing && !_bufferingController.isClosed) {
        _bufferingController.add(_isBuffering);
      }
      if (kDebugMode) {
        debugPrint('FVP: Buffering state changed: $_isBuffering (status: $newStatus)');
      }
    }
  }

  void _updateAspectRatio() {
    final videoInfo = _player?.mediaInfo.video;
    if (videoInfo != null && videoInfo.isNotEmpty) {
      final firstVideo = videoInfo.first;
      if (firstVideo.codec.width > 0 && firstVideo.codec.height > 0) {
        _aspectRatio = firstVideo.codec.width / firstVideo.codec.height;
        if (!_isDisposing && !_aspectRatioController.isClosed) {
          _aspectRatioController.add(_aspectRatio);
        }
        if (kDebugMode) {
          debugPrint('FVP: Aspect ratio updated: $_aspectRatio');
        }
      }
    }
    
    if (_aspectRatio == null) {
      // Default to 16:9 if not available
      _aspectRatio = 16 / 9;
      _aspectRatioController.add(_aspectRatio);
    }
  }

  void _startPositionUpdates() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_player == null || !_isInitialized) {
        timer.cancel();
        return;
      }

      try {
        // Position is in milliseconds
        final currentPosition = _player!.position;
        _position = currentPosition / 1000.0; // Convert to seconds
        if (!_isDisposing && !_positionController.isClosed) {
          _positionController.add(_position);
        }

        // Get duration from mediaInfo if available
        final videoInfo = _player!.mediaInfo.video;
        if (videoInfo != null && videoInfo.isNotEmpty) {
          final firstVideo = videoInfo.first;
          if (firstVideo.duration > 0) {
            final newDuration = firstVideo.duration / 1000.0; // Convert milliseconds to seconds
            if (newDuration != _duration) {
              _duration = newDuration;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('FVP: Error updating position: $e');
        }
      }
    });
  }

  Future<void> pause() async {
    if (_player != null) {
      _player!.state = fvp.PlaybackState.paused;
      _isPaused = true;
      _isPlaying = false;
      if (!_isDisposing && !_playingController.isClosed) {
        _playingController.add(false);
      }
    }
  }

  Future<void> resume() async {
    if (_player != null) {
      _player!.state = fvp.PlaybackState.playing;
      _isPaused = false;
      _isPlaying = true;
      if (!_isDisposing && !_playingController.isClosed) {
        _playingController.add(true);
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPaused) {
      await resume();
    } else {
      await pause();
    }
  }

  Future<void> seek(double seconds) async {
    if (_player != null) {
      final positionMs = (seconds * 1000).toInt();
      await _player!.seek(position: positionMs);
      _position = seconds;
      _positionController.add(_position);
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 100.0);
    if (_player != null) {
      _player!.volume = _volume / 100.0;
    }
    if (!_isDisposing && !_volumeController.isClosed) {
      _volumeController.add(_volume);
    }
  }

  Future<void> stop() async {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;

    if (_player != null) {
      _player!.state = fvp.PlaybackState.stopped;
    }
    
    await _disposePlayer();
    
    _isPlaying = false;
    _isPaused = false;
    _isBuffering = false;
    _isInitialized = false;
    
    // Only add event if not disposing (controllers will be closed)
    if (!_isDisposing && !_playingController.isClosed) {
      _playingController.add(false);
    }
  }

  Future<void> _disposePlayer() async {
    if (_player != null) {
      if (_textureIdListener != null) {
        _player!.textureId.removeListener(_textureIdListener!);
        _textureIdListener = null;
      }
      _player!.onStateChanged(null);
      _player!.onMediaStatus(null);
      _player!.dispose();
      _player = null;
    }
    
    _textureId = null;
    _aspectRatio = null;
    
    // Only add event if not disposing (controllers will be closed)
    if (!_isDisposing && !_aspectRatioController.isClosed) {
      _aspectRatioController.add(null);
    }
  }

  void dispose() {
    // Set disposing flag to prevent event additions during disposal
    _isDisposing = true;
    
    _positionUpdateTimer?.cancel();
    
    // Stop player asynchronously, but close controllers immediately
    // Events in stop() will be skipped due to _isDisposing flag
    stop();
    
    // Close all stream controllers
    if (!_playingController.isClosed) _playingController.close();
    if (!_positionController.isClosed) _positionController.close();
    if (!_volumeController.isClosed) _volumeController.close();
    if (!_initializedController.isClosed) _initializedController.close();
    if (!_bufferingController.isClosed) _bufferingController.close();
    if (!_aspectRatioController.isClosed) _aspectRatioController.close();
  }
}
