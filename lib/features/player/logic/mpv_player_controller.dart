import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Controller for MPV video playback using JSON IPC
class MpvPlayerController {
  Process? _mpvProcess;
  Socket? _ipcSocket;
  int? _ipcPort;
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

  /// Start MPV playback with the given URL
  Future<void> start(String url, {List<String>? subtitles}) async {
    try {
      // Use a random TCP port for IPC
      _ipcPort = 50000 + (DateTime.now().millisecondsSinceEpoch % 10000);
      
      if (kDebugMode) {
        debugPrint('MPV: Starting playback of $url');
        debugPrint('MPV: IPC port: $_ipcPort');
      }

      // Build MPV command
      final List<String> args = [
        '--no-terminal',
        '--vo=gpu',
        '--hwdec=auto',
        '--input-ipc-server=tcp://127.0.0.1:$_ipcPort',
        '--keep-open=yes',
        '--no-border',
        url,
      ];

      // Add subtitles if provided
      if (subtitles != null && subtitles.isNotEmpty) {
        for (final subtitle in subtitles) {
          args.addAll(['--sub-file', subtitle]);
        }
      }

      // Spawn MPV process
      _mpvProcess = await Process.start('mpv', args);
      
      if (kDebugMode) {
        debugPrint('MPV: Process started with PID ${_mpvProcess!.pid}');
      }

      // Wait a bit for MPV to start and create socket
      await Future.delayed(const Duration(milliseconds: 1000));

      // Connect to IPC socket
      await _connectToSocket();
      
      // Start listening for events
      _listenToEvents();
      
      _isPlaying = true;
      _isPaused = false;
      _playingController.add(_isPlaying);
      
      // Get initial properties
      await Future.delayed(const Duration(milliseconds: 500));
      await _updateProperties();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MPV: Error starting playback: $e');
      }
      rethrow;
    }
  }

  /// Connect to MPV IPC socket (TCP)
  Future<void> _connectToSocket() async {
    if (_ipcPort == null) return;
    
    int retries = 0;
    while (retries < 20) {
      try {
        _ipcSocket = await Socket.connect(
          InternetAddress('127.0.0.1'),
          _ipcPort!,
        );
        
        if (kDebugMode) {
          debugPrint('MPV: Connected to IPC socket on port $_ipcPort');
        }
        return;
      } catch (e) {
        if (kDebugMode && retries % 5 == 0) {
          debugPrint('MPV: Waiting for socket... (attempt ${retries + 1}): $e');
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }
    
    throw Exception('Failed to connect to MPV IPC socket on port $_ipcPort');
  }

  /// Listen for MPV events
  void _listenToEvents() {
    if (_ipcSocket == null) return;
    
    _ipcSocket!.listen(
      (data) {
        final lines = utf8.decode(data).split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            
            if (json.containsKey('event')) {
              _handleEvent(json);
            } else if (json.containsKey('data')) {
              _handleResponse(json);
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('MPV: Error parsing event: $e, line: $line');
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('MPV: Socket error: $error');
        }
      },
      onDone: () {
        if (kDebugMode) {
          debugPrint('MPV: Socket closed');
        }
        _isPlaying = false;
        _playingController.add(_isPlaying);
      },
    );
    
    // Also poll for properties periodically
    Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (_mpvProcess == null) {
        timer.cancel();
        return;
      }
      
      // Check if process is still running (non-blocking)
      try {
        final exitCode = await _mpvProcess!.exitCode.timeout(
          const Duration(milliseconds: 100),
          onTimeout: () => -1, // Return -1 to indicate timeout (process still running)
        );
        if (exitCode != -1) {
          _isPlaying = false;
          _playingController.add(_isPlaying);
          timer.cancel();
          return;
        }
      } catch (e) {
        // Process still running
      }
      
      // Update properties periodically
      await _updateProperties();
    });
  }

  /// Handle MPV events
  void _handleEvent(Map<String, dynamic> event) {
    final eventName = event['event'] as String?;
    
    if (kDebugMode) {
      debugPrint('MPV: Event: $eventName');
    }
    
    switch (eventName) {
      case 'playback-restart':
      case 'file-loaded':
        _isPlaying = true;
        _isPaused = false;
        _playingController.add(_isPlaying);
        _updateProperties();
        break;
      case 'pause':
        _isPaused = true;
        _playingController.add(false);
        break;
      case 'unpause':
        _isPaused = false;
        _playingController.add(true);
        break;
      case 'playback-restart':
        _updateProperties();
        break;
    }
  }

  /// Handle MPV responses
  void _handleResponse(Map<String, dynamic> response) {
    if (response.containsKey('data')) {
      final data = response['data'];
      final requestId = response['request_id'] as int?;
      
      if (requestId != null && _requestIdMap.containsKey(requestId)) {
        final property = _requestIdMap[requestId]!;
        _requestIdMap.remove(requestId);
        
        if (data is num) {
          switch (property) {
            case 'time-pos':
              _position = data.toDouble();
              _positionController.add(_position);
              break;
            case 'duration':
              _duration = data.toDouble();
              break;
            case 'volume':
              _volume = data.toDouble();
              _volumeController.add(_volume);
              break;
          }
        }
      }
    }
  }

  /// Send command to MPV via IPC socket
  Future<void> _sendCommand(Map<String, dynamic> command) async {
    if (_ipcSocket == null) return;
    
    try {
      final json = jsonEncode(command);
      _ipcSocket!.add(utf8.encode('$json\n'));
      
      if (kDebugMode) {
        debugPrint('MPV: Sent command: $json');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MPV: Error sending command: $e');
      }
    }
  }

  /// Update playback properties
  Future<void> _updateProperties() async {
    await Future.wait([
      _getProperty('time-pos'),
      _getProperty('duration'),
      _getProperty('volume'),
    ]);
  }

  int _requestIdCounter = 0;
  final Map<int, String> _requestIdMap = {};
  
  /// Get property from MPV
  Future<void> _getProperty(String property) async {
    final requestId = _requestIdCounter++;
    _requestIdMap[requestId] = property;
    await _sendCommand({
      'command': ['get_property', property],
      'request_id': requestId,
    });
  }

  /// Pause playback
  Future<void> pause() async {
    await _sendCommand({'command': ['set_property', 'pause', true]});
    _isPaused = true;
    _playingController.add(false);
  }

  /// Resume playback
  Future<void> resume() async {
    await _sendCommand({'command': ['set_property', 'pause', false]});
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
    await _sendCommand({'command': ['seek', seconds, 'absolute']});
    _position = seconds;
    _positionController.add(_position);
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 100.0);
    await _sendCommand({'command': ['set_property', 'volume', _volume]});
    _volumeController.add(_volume);
  }

  /// Stop playback
  Future<void> stop() async {
    if (_mpvProcess != null) {
      await _sendCommand({'command': ['quit']});
      await _mpvProcess!.exitCode;
      _mpvProcess = null;
    }
    
    if (_ipcSocket != null) {
      await _ipcSocket!.close();
      _ipcSocket = null;
    }
    
    _ipcPort = null;
    
    _isPlaying = false;
    _isPaused = false;
    _playingController.add(false);
  }

  /// Dispose resources
  void dispose() {
    stop();
    _playingController.close();
    _positionController.close();
    _volumeController.close();
  }
}
