import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for managing torrent downloads via Go sidecar process
class TorrentService {
  Process? _sidecarProcess;
  final int apiPort;
  final int streamPort;
  bool _isRunning = false;

  TorrentService({
    this.apiPort = 8080,
    this.streamPort = 8081,
  });

  bool get isRunning => _isRunning;

  /// Start the torrent sidecar process
  Future<void> start() async {
    if (_isRunning) return;

    try {
      final binaryPath = await _getSidecarBinaryPath();
      final tempDir = await getTemporaryDirectory();

      debugPrint('TorrentService: Starting sidecar from $binaryPath');

      _sidecarProcess = await Process.start(
        binaryPath,
        [],
        environment: {
          'TORRENT_API_PORT': apiPort.toString(),
          'TORRENT_STREAM_PORT': streamPort.toString(),
          'TEMP': tempDir.path,
          'TMPDIR': tempDir.path,
        },
        workingDirectory: tempDir.path,
      );

      _isRunning = true;

      // Listen to output for debugging
      _sidecarProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('TorrentSidecar: $data');
      });

      _sidecarProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('TorrentSidecar ERROR: $data');
      });

      // Monitor for crashes
      _sidecarProcess!.exitCode.then((exitCode) {
        if (exitCode != 0) {
          debugPrint('TorrentService: Sidecar crashed with exit code $exitCode');
          _isRunning = false;
        }
      });

      // Wait a moment for the server to start
      await Future.delayed(const Duration(seconds: 2));

      // Health check - verify the API server is responding
      try {
        final response = await http.get(
          Uri.parse('http://localhost:$apiPort/status'),
        ).timeout(const Duration(seconds: 2));
        
        if (response.statusCode == 200) {
          debugPrint('TorrentService: Sidecar started successfully');
        } else {
          throw Exception('Sidecar health check failed: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('TorrentService: Sidecar health check failed: $e');
        _isRunning = false;
        await stop();
        throw Exception('Sidecar failed to start properly. Check logs for details.');
      }
    } catch (e) {
      debugPrint('TorrentService: Failed to start sidecar: $e');
      _isRunning = false;
      rethrow;
    }
  }

  /// Stop the torrent sidecar process gracefully
  Future<void> stop() async {
    if (!_isRunning || _sidecarProcess == null) return;

    try {
      // First try to terminate gracefully (SIGTERM)
      _sidecarProcess!.kill(ProcessSignal.sigterm);

      // Wait for the process to exit gracefully, but with a timeout
      final exitCode = await _sidecarProcess!.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          // If it doesn't exit gracefully, force kill it
          debugPrint('TorrentService: Sidecar did not exit gracefully, force killing...');
          _sidecarProcess!.kill(ProcessSignal.sigkill);
          return -1; // Force kill exit code
        },
      );

      _isRunning = false;
      debugPrint('TorrentService: Sidecar stopped with exit code $exitCode');
    } catch (e) {
      debugPrint('TorrentService: Error stopping sidecar: $e');
      // Ensure it's marked as not running even on error
      _isRunning = false;
    }
  }

  /// Add a magnet link and return streaming URL
  Future<String> addMagnet(String magnetUrl, {int? fileIndex}) async {
    await _ensureRunning();

    final request = {
      'magnet': magnetUrl,
      if (fileIndex != null) 'fileIndex': fileIndex,
    };

    final response = await http.post(
      Uri.parse('http://localhost:$apiPort/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add magnet: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['streamUrl'] as String;
  }

  /// Get status of all active torrents
  Future<List<Map<String, dynamic>>> getStatus() async {
    await _ensureRunning();

    final response = await http.get(
      Uri.parse('http://localhost:$apiPort/status'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get status: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['torrents'] as List).cast<Map<String, dynamic>>();
  }


  /// Remove a torrent by ID
  Future<void> removeTorrent(String torrentId) async {
    await _ensureRunning();

    final response = await http.delete(
      Uri.parse('http://localhost:$apiPort/remove/$torrentId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove torrent: ${response.body}');
    }
  }

  /// Ensure the sidecar is running
  Future<void> _ensureRunning() async {
    if (!_isRunning) {
      await start();
    }
  }

  /// Get the platform-specific sidecar binary path
  Future<String> _getSidecarBinaryPath() async {
    List<String> binaryNames;

    if (Platform.isWindows) {
      binaryNames = ['torrent-sidecar-windows-x64.exe'];
    } else if (Platform.isMacOS) {
      // Try arm64 first (Apple Silicon), then x64 (Intel)
      binaryNames = ['torrent-sidecar-macos-arm64', 'torrent-sidecar-macos-x64'];
    } else if (Platform.isLinux) {
      binaryNames = ['torrent-sidecar-linux-x64'];
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    // Get temp directory for extracted binary
    final tempDir = await getTemporaryDirectory();

    // Try each binary name
    for (final binaryName in binaryNames) {
      final binaryPath = path.join(tempDir.path, binaryName);

      // Check if binary already exists and is executable
      final binaryFile = File(binaryPath);
      if (await binaryFile.exists()) {
        // Make sure it's executable
        await _makeExecutable(binaryPath);
        return binaryPath;
      }

      try {
        // Load binary from Flutter assets
        final assetPath = 'assets/sidecar/$binaryName';
        if (kDebugMode) {
          debugPrint('TorrentService: Loading binary from asset: $assetPath');
        }

        final binaryData = await rootBundle.load(assetPath);
        final bytes = binaryData.buffer.asUint8List();

        // Write to temp directory
        await binaryFile.writeAsBytes(bytes);

        // Make executable
        await _makeExecutable(binaryPath);

        if (kDebugMode) {
          debugPrint('TorrentService: Binary extracted to: $binaryPath');
        }

        return binaryPath;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('TorrentService: Failed to load $binaryName from assets: $e');
        }
        // Try next binary in list
        continue;
      }
    }

    // If we get here, none of the binaries worked
    // Last resort: try built app directory (for release builds)
    for (final binaryName in binaryNames) {
      final exeDir = path.dirname(Platform.resolvedExecutable);
      final fallbackPath = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'sidecar', binaryName);

      final fallbackFile = File(fallbackPath);
      if (await fallbackFile.exists()) {
        await _makeExecutable(fallbackPath);
        return fallbackPath;
      }
    }

    throw FileSystemException('Sidecar binary not found for any variant', binaryNames.join(', '));
  }

  /// Make a file executable on Unix-like systems
  Future<void> _makeExecutable(String filePath) async {
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', filePath]);
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}



