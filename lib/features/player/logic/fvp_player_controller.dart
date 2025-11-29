import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fvp/mdk.dart' as fvp;
import '../../../core/services/torrent_service.dart';
import '../../../core/services/service_locator.dart';

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
      _playingController.add(_isPlaying);
      _initializedController.add(_isInitialized);

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

    _playingController.add(_isPlaying);
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
      _bufferingController.add(_isBuffering);
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
        _aspectRatioController.add(_aspectRatio);
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
        _positionController.add(_position);

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
      _playingController.add(false);
    }
  }

  Future<void> resume() async {
    if (_player != null) {
      _player!.state = fvp.PlaybackState.playing;
      _isPaused = false;
      _isPlaying = true;
      _playingController.add(true);
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
    _volumeController.add(_volume);
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
    _playingController.add(false);
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
    _aspectRatioController.add(null);
  }

  void dispose() {
    _positionUpdateTimer?.cancel();
    stop();
    _playingController.close();
    _positionController.close();
    _volumeController.close();
    _initializedController.close();
    _bufferingController.close();
    _aspectRatioController.close();
  }
}
