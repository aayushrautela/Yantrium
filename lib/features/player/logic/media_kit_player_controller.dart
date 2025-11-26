import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Controller for MPV video playback using media_kit
class MediaKitPlayerController {
  late final Player _player;
  late final VideoController _videoController;
  
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
  
  VideoController get videoController => _videoController;

  MediaKitPlayerController() {
    _player = Player();
    _videoController = VideoController(_player);
    
    // Listen to player state changes
    _player.stream.playing.listen((playing) {
      _isPlaying = playing;
      _isPaused = !playing;
      _playingController.add(_isPlaying);
    });
    
    _player.stream.position.listen((position) {
      _position = position.inSeconds.toDouble();
      _positionController.add(_position);
    });
    
    _player.stream.duration.listen((duration) {
      _duration = duration.inSeconds.toDouble();
    });
    
    _player.stream.volume.listen((volume) {
      _volume = volume * 100.0;
      _volumeController.add(_volume);
    });
  }

  /// Start MPV playback with the given URL
  Future<void> start(String url, {List<String>? subtitles}) async {
    try {
      if (kDebugMode) {
        debugPrint('MediaKit: Starting playback of $url');
      }

      // Prepare media with subtitles if provided
      final media = Media(url);
      
      // Add subtitles if provided
      if (subtitles != null && subtitles.isNotEmpty) {
        // media_kit handles subtitles through the Media object
        // For now, we'll just play the main URL
        // Subtitles can be added later if needed
      }

      await _player.open(media);
      
      _isPlaying = true;
      _isPaused = false;
      _playingController.add(_isPlaying);
      
      if (kDebugMode) {
        debugPrint('MediaKit: Playback started');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MediaKit: Error starting playback: $e');
      }
      rethrow;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _player.pause();
    _isPaused = true;
    _playingController.add(false);
  }

  /// Resume playback
  Future<void> resume() async {
    await _player.play();
    _isPaused = false;
    _playingController.add(true);
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPaused) {
      await resume();
    } else {
      await pause();
    }
  }

  /// Seek to position
  Future<void> seek(double seconds) async {
    await _player.seek(Duration(seconds: seconds.toInt()));
    _position = seconds;
    _positionController.add(_position);
  }

  /// Set volume (0.0 to 100.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 100.0);
    await _player.setVolume(_volume / 100.0);
    _volumeController.add(_volume);
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _isPaused = false;
    _playingController.add(false);
  }

  /// Dispose resources
  void dispose() {
    stop();
    _player.dispose();
    _playingController.close();
    _positionController.close();
    _volumeController.close();
  }
}






