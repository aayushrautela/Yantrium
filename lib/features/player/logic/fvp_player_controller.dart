import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/torrent_service.dart';

/// Controller for video playback using FVP (FFmpeg-based)
class FvpPlayerController {
  VideoPlayerController? _controller;
  final TorrentService _torrentService;

  // Torrent streaming state
  String? _currentTorrentId;
  int? _currentFileIndex;
  Timer? _positionUpdateTimer;
  Timer? _torrentPositionUpdateTimer;

  FvpPlayerController({TorrentService? torrentService})
      : _torrentService = torrentService ?? TorrentService();

  bool _isPlaying = false;
  bool _isPaused = false;
  double _position = 0.0;
  double _duration = 0.0;
  double _volume = 100.0;

  final StreamController<bool> _playingController = StreamController<bool>.broadcast();
  final StreamController<double> _positionController = StreamController<double>.broadcast();
  final StreamController<double> _volumeController = StreamController<double>.broadcast();
  
  Stream<bool> get playingStream => _playingController.stream;
  Stream<double> get positionStream => _positionController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  double get position => _position;
  double get duration => _duration;
  double get volume => _volume;
  
  VideoPlayerController? get videoController => _controller;

  Future<void> start(String url, {List<String>? subtitles}) async {
    try {
      if (kDebugMode) {
        debugPrint('FVP: Starting playback of $url');
      }

      // Dispose previous controller if exists
      await _controller?.dispose();

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

        // Parse torrent info from streaming URL for position updates
        _parseTorrentInfoFromUrl(streamUrl);
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));

      await _controller!.initialize();
      
      // Set up listeners
      _controller!.addListener(_updateState);
      
      // Set initial volume
      await _controller!.setVolume(_volume / 100.0);

      // Start position updates
      _startPositionUpdates();

      // Start torrent position updates if streaming
      if (_currentTorrentId != null) {
        _startTorrentPositionUpdates();
      }

      // Start playing
      await _controller!.play();

      _isPlaying = true;
      _isPaused = false;
      _playingController.add(_isPlaying);
      
      if (kDebugMode) {
        debugPrint('FVP: Playback started');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FVP: Error starting playback: $e');
      }
      rethrow;
    }
  }

  void _updateState() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    final value = _controller!.value;
    _duration = value.duration.inSeconds.toDouble();
    _position = value.position.inSeconds.toDouble();
    _isPlaying = value.isPlaying;
    _isPaused = !value.isPlaying;
    
    _positionController.add(_position);
    _playingController.add(_isPlaying);
  }

  void _startPositionUpdates() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_controller == null || !_controller!.value.isInitialized) {
        timer.cancel();
        return;
      }
      _updateState();
    });
  }

  Future<void> pause() async {
    await _controller?.pause();
    _isPaused = true;
    _playingController.add(false);
  }

  Future<void> resume() async {
    await _controller?.play();
    _isPaused = false;
    _playingController.add(true);
  }

  Future<void> togglePlayPause() async {
    if (_isPaused) {
      await resume();
    } else {
      await pause();
    }
  }

  Future<void> seek(double seconds) async {
    await _controller?.seekTo(Duration(seconds: seconds.toInt()));
    _position = seconds;
    _positionController.add(_position);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 100.0);
    await _controller?.setVolume(_volume / 100.0);
    _volumeController.add(_volume);
  }

  Future<void> stop() async {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;

    _torrentPositionUpdateTimer?.cancel();
    _torrentPositionUpdateTimer = null;

    await _controller?.pause();
    await _controller?.dispose();
    _controller = null;
    _isPlaying = false;
    _isPaused = false;
    _playingController.add(false);

    // Clear torrent state
    _currentTorrentId = null;
    _currentFileIndex = null;
  }

  /// Parse torrent information from streaming URL
  void _parseTorrentInfoFromUrl(String url) {
    try {
      // URL format: http://localhost:8081/stream/{torrentId}/{fileIndex}
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 3 && pathSegments[0] == 'stream') {
        _currentTorrentId = pathSegments[1];
        _currentFileIndex = int.tryParse(pathSegments[2]);

        if (kDebugMode) {
          debugPrint('FVP: Parsed torrent info - ID: $_currentTorrentId, File: $_currentFileIndex');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FVP: Failed to parse torrent URL: $e');
      }
    }
  }

  /// Start periodic position updates to torrent service for streaming optimization
  void _startTorrentPositionUpdates() {
    _torrentPositionUpdateTimer?.cancel();

    _torrentPositionUpdateTimer = Timer.periodic(
      const Duration(seconds: 2), // Update every 2 seconds
      (timer) {
        if (_controller != null &&
            _currentTorrentId != null &&
            _currentFileIndex != null &&
            _controller!.value.isInitialized) {

          // Estimate bytes based on bitrate (assume ~2MB/s for 1080p video)
          const int estimatedBytesPerSecond = 2000000; // 2MB/s
          final positionBytes = (_controller!.value.position.inSeconds * estimatedBytesPerSecond).round();
          _torrentService.updatePosition(_currentTorrentId!, _currentFileIndex!, positionBytes);
        }
      },
    );
  }

  void dispose() {
    _positionUpdateTimer?.cancel();
    _torrentPositionUpdateTimer?.cancel();
    stop();
    _playingController.close();
    _positionController.close();
    _volumeController.close();
  }
}








