import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/torrent_service.dart';
import '../../../core/services/service_locator.dart';

/// Controller for video playback using FVP (FFmpeg-based)
class FvpPlayerController {
  VideoPlayerController? _controller;
  final TorrentService _torrentService;
  Timer? _positionUpdateTimer;

  FvpPlayerController({TorrentService? torrentService})
      : _torrentService = torrentService ?? ServiceLocator.instance.torrentService;
  
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
      }

      _controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      
      await _controller!.initialize();
      
      // Set up listeners
      _controller!.addListener(_updateState);
      
      // Set initial volume
      await _controller!.setVolume(_volume / 100.0);
      
      // Start position updates
      _startPositionUpdates();
      
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

    await _controller?.pause();
    await _controller?.dispose();
    _controller = null;
    _isPlaying = false;
    _isPaused = false;
    _playingController.add(false);
  }


  void dispose() {
    _positionUpdateTimer?.cancel();
    stop();
    _playingController.close();
    _positionController.close();
    _volumeController.close();
  }
}








