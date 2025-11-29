import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../lib/core/database/app_database.dart';
import '../lib/features/library/logic/stream_service.dart';
import '../lib/features/library/models/catalog_item.dart';
import '../lib/features/library/models/stream_info.dart';
import '../lib/features/addons/logic/addon_client.dart';
import '../lib/features/addons/logic/addon_repository.dart';
import '../lib/features/addons/models/addon_config.dart';

/// Custom AddonClient that saves raw responses to files for analysis
class DataSavingAddonClient extends AddonClient {
  final Directory outputDir;
  int requestCount = 0;

  DataSavingAddonClient(super.baseUrl, this.outputDir);

  @override
  Future<Map<String, List<dynamic>>> getStreams(String type, String id) async {
    try {
      final path = '/stream/$type/${Uri.encodeComponent(id)}.json';

      if (kDebugMode) {
        debugPrint('DataSavingAddonClient: Making GET request to: $path');
        debugPrint('DataSavingAddonClient: Full URL: ${_dio.options.baseUrl}$path');
      }

      final response = await _dio.get(path);

      if (kDebugMode) {
        debugPrint('DataSavingAddonClient: Response status: ${response.statusCode}');
        debugPrint('DataSavingAddonClient: Response headers: ${response.headers}');
        debugPrint('DataSavingAddonClient: Raw response data type: ${response.data.runtimeType}');
      }

      // Save raw response data to file
      requestCount++;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'raw_response_${requestCount}_${type}_${id.replaceAll('/', '_')}_${timestamp}.json';

      final rawData = {
        'request': {
          'baseUrl': _dio.options.baseUrl,
          'path': path,
          'fullUrl': '${_dio.options.baseUrl}$path',
          'type': type,
          'id': id,
        },
        'response': {
          'statusCode': response.statusCode,
          'headers': response.headers.map,
          'data': response.data,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      final file = File('${outputDir.path}/$filename');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(rawData),
      );

      if (kDebugMode) {
        debugPrint('DataSavingAddonClient: Saved raw response to ${file.path}');
      }

      // Continue with normal processing
      final data = response.data as Map<String, dynamic>;

      if (kDebugMode) {
        debugPrint('DataSavingAddonClient: Parsed data keys: ${data.keys.toList()}');
        debugPrint('DataSavingAddonClient: Full parsed data: $data');
      }

      // Validate response structure before accessing streams key
      if (!data.containsKey('streams')) {
        if (kDebugMode) {
          debugPrint('DataSavingAddonClient: Response missing streams key');
          debugPrint('DataSavingAddonClient: Available keys: ${data.keys.toList()}');
        }
        return {'streams': <dynamic>[]};
      }

      final streamsData = data['streams'];
      if (streamsData is! List) {
        if (kDebugMode) {
          debugPrint('DataSavingAddonClient: streams is not a list, type: ${streamsData.runtimeType}');
          debugPrint('DataSavingAddonClient: streams value: $streamsData');
        }
        return {'streams': <dynamic>[]};
      }

      final streams = streamsData;

      if (kDebugMode) {
        debugPrint('DataSavingAddonClient: Extracted ${streams.length} stream(s) from response');
      }

      return {'streams': streams};
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('DataSavingAddonClient: DioException - Status: ${e.response?.statusCode}');
        debugPrint('DataSavingAddonClient: DioException - Message: ${e.message}');
        debugPrint('DataSavingAddonClient: DioException - Response data: ${e.response?.data}');
      }

      // Save error data too
      final errorData = {
        'request': {
          'baseUrl': _dio.options.baseUrl,
          'type': type,
          'id': id,
        },
        'error': {
          'type': 'DioException',
          'statusCode': e.response?.statusCode,
          'message': e.message,
          'responseData': e.response?.data,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      requestCount++;
      final filename = 'error_response_${requestCount}_${type}_${id.replaceAll('/', '_')}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${outputDir.path}/$filename');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(errorData),
      );

      // 404 responses for streams return empty lists (not errors)
      if (e.response?.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('DataSavingAddonClient: 404 response, returning empty streams list');
        }
        return {'streams': <dynamic>[]};
      }

      // Re-throw other errors
      rethrow;
    }
  }
}

/// Custom StreamService that uses DataSavingAddonClient
class DataSavingStreamService extends StreamService {
  final Directory outputDir;

  DataSavingStreamService(super.database, this.outputDir);

  @override
  Future<List<StreamInfo>> _fetchStreamsFromAddon(
    AddonConfig addon,
    CatalogItem item, {
    String? imdbId,
    String? episodeId,
  }) async {
    final client = DataSavingAddonClient(addon.baseUrl, outputDir);

    // Use episodeId if provided (for series), otherwise use IMDB ID
    final streamId = episodeId ?? imdbId ?? item.id;

    if (kDebugMode) {
      debugPrint('DataSavingStreamService: Requesting /stream/${item.type}/$streamId.json from ${addon.baseUrl}');
      debugPrint('DataSavingStreamService: Using stream ID: $streamId (episodeId: $episodeId, imdbId: $imdbId, item.id: ${item.id})');
    }

    try {
      final response = await client.getStreams(item.type, streamId);

      if (kDebugMode) {
        debugPrint('DataSavingStreamService: Raw response from addon ${addon.name}:');
        debugPrint('DataSavingStreamService: Response keys: ${response.keys.toList()}');
        debugPrint('DataSavingStreamService: Full response: $response');
      }

      final streamsData = response['streams'] ?? [];

      if (kDebugMode) {
        debugPrint('DataSavingStreamService: Received ${streamsData.length} raw stream(s) from addon ${addon.name}');
        if (streamsData.isNotEmpty) {
          debugPrint('DataSavingStreamService: First stream data: ${streamsData.first}');
        }
      }

      // Process streams using NuvioStreaming approach with pre-filtering and individual error handling
      final parsedStreams = streamsData
          .where((stream) {
            // Pre-filter streams - ensure there's a way to play (URL or infoHash) and identify (title/name)
            if (stream is! Map<String, dynamic>) return false;

            final hasPlayableLink = (stream['url'] != null || stream['infoHash'] != null);
            final hasIdentifier = (stream['title'] != null || stream['name'] != null);

            if (!hasPlayableLink) {
              if (kDebugMode) {
                debugPrint('DataSavingStreamService: Skipping stream without playable link');
              }
            }
            if (!hasIdentifier) {
              if (kDebugMode) {
                debugPrint('DataSavingStreamService: Skipping stream without identifier');
              }
            }

            return hasPlayableLink && hasIdentifier;
          })
          .map((streamData) {
            try {
              final stream = streamData as Map<String, dynamic>;
              final streamUrl = _getStreamUrl(stream);
              final isDirectStreamingUrl = _isDirectStreamingUrl(streamUrl);
              final isMagnetStream = streamUrl.startsWith('magnet:');

              // Handle display title logic (prefer description if longer and contains newlines)
              String displayTitle = stream['title'] ?? stream['name'] ?? 'Unnamed Stream';
              final description = stream['description'] as String?;
              final title = stream['title'] as String?;
              if (description != null &&
                  description.contains('\n') &&
                  description.length > (title?.length ?? 0)) {
                displayTitle = description;
              }

              // Extract size: Prefer behaviorHints.videoSize, fallback to top-level size
              final behaviorHints = stream['behaviorHints'] as Map<String, dynamic>?;
              final sizeInBytes = (behaviorHints?['videoSize'] as int?) ?? (stream['size'] as int?);

              // Memory optimization: Minimize behaviorHints to essential data only
              final minimalBehaviorHints = <String, dynamic>{
                'notWebReady': !isDirectStreamingUrl,
                if (behaviorHints?['cached'] != null) 'cached': behaviorHints!['cached'],
                if (behaviorHints?['bingeGroup'] != null) 'bingeGroup': behaviorHints!['bingeGroup'],
                // Only include essential torrent data for magnet streams
                if (isMagnetStream) ...{
                  'infoHash': stream['infoHash'] ?? (streamUrl.contains('btih:') ? streamUrl.split('btih:')[1].split('&')[0] : null),
                  'fileIdx': stream['fileIdx'],
                  'type': 'torrent',
                },
              };

              // Explicitly construct the final StreamInfo object with all fields
              return StreamInfo(
                id: stream['id'] as String?,
                title: displayTitle,
                name: stream['name'] as String? ?? stream['title'] as String? ?? 'Unnamed Stream',
                description: stream['description'] as String?,
                url: streamUrl,
                quality: stream['quality'] as String?,
                type: stream['type'] as String?,
                subtitles: stream['subtitles'] != null
                    ? (stream['subtitles'] as List<dynamic>)
                        .map((s) => Subtitle.fromJson(s as Map<String, dynamic>))
                        .toList()
                    : null,
                behaviorHints: minimalBehaviorHints,
                addonId: addon.id,
                addonName: addon.name,
                infoHash: stream['infoHash'] as String?,
                fileIdx: stream['fileIdx'] as int?,
                size: sizeInBytes,
                isFree: stream['isFree'] as bool?,
                isDebrid: (behaviorHints?['cached'] as bool?) ?? false,
              );
            } catch (e) {
              if (kDebugMode) {
                debugPrint('DataSavingStreamService: Failed to process individual stream: $e');
                debugPrint('DataSavingStreamService: Stream data: $streamData');
              }
              return null;
            }
          })
          .whereType<StreamInfo>()
          .toList();

      if (kDebugMode) {
        debugPrint('DataSavingStreamService: Successfully parsed ${parsedStreams.length} stream(s) from addon ${addon.name}');
      }

      return parsedStreams;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DataSavingStreamService: Error fetching streams from addon ${addon.id} (${addon.baseUrl}): $e');
      }
      return [];
    }
  }
}

/// Test script to fetch raw stream data from addons and save to files
/// Usage: dart run scripts/test_streams_raw.dart
Future<void> main() async {
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('Error loading .env file: $e');
    print('Make sure .env file exists in the project root');
    exit(1);
  }

  // Initialize database
  final db = AppDatabase(NativeDatabase.memory());

  // Create output directory
  final outputDir = Directory('stream_test_data');
  if (!await outputDir.exists()) {
    await outputDir.create();
  }

  print('Testing Stream Data Collection...\n');

  // Initialize custom StreamService that saves raw data
  final streamService = DataSavingStreamService(db, outputDir);

  // Test data - some popular movies and TV shows with their IMDB IDs
  final testItems = [
    // Movies
    CatalogItem(
      id: 'tt0111161', // The Shawshank Redemption
      name: 'The Shawshank Redemption',
      type: 'movie',
    ),
    CatalogItem(
      id: 'tt0068646', // The Godfather
      name: 'The Godfather',
      type: 'movie',
    ),
    CatalogItem(
      id: 'tt0071562', // The Godfather Part II
      name: 'The Godfather Part II',
      type: 'movie',
    ),
    CatalogItem(
      id: 'tt0468569', // The Dark Knight
      name: 'The Dark Knight',
      type: 'movie',
    ),
    // TV Shows
    CatalogItem(
      id: 'tt0944947', // Game of Thrones
      name: 'Game of Thrones',
      type: 'series',
    ),
    CatalogItem(
      id: 'tt0903747', // Breaking Bad
      name: 'Breaking Bad',
      type: 'series',
    ),
  ];

  int testIndex = 1;
  for (final item in testItems) {
    print('${testIndex}. Testing ${item.type}: ${item.name} (${item.id})');

    try {
      // Fetch streams
      final streams = await streamService.getStreamsForItem(item);

      // Save parsed streams data
      final parsedData = {
        'item': {
          'id': item.id,
          'name': item.name,
          'type': item.type,
        },
        'total_streams': streams.length,
        'streams': streams.map((stream) => {
          'id': stream.id,
          'title': stream.title,
          'name': stream.name,
          'description': stream.description,
          'url': stream.url,
          'quality': stream.quality,
          'type': stream.type,
          'addonId': stream.addonId,
          'addonName': stream.addonName,
          'infoHash': stream.infoHash,
          'fileIdx': stream.fileIdx,
          'size': stream.size,
          'isFree': stream.isFree,
          'isDebrid': stream.isDebrid,
          'behaviorHints': stream.behaviorHints,
          'subtitles': stream.subtitles?.map((sub) => {
            'url': sub.url,
            'lang': sub.lang,
            'id': sub.id,
          }).toList(),
        }).toList(),
      };

      final filename = '${item.type}_${item.id.replaceAll('tt', '')}_${item.name.replaceAll(' ', '_').toLowerCase()}';
      final parsedFile = File('stream_test_data/${filename}_parsed.json');
      await parsedFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(parsedData),
      );
      print('   ✓ Saved parsed data to ${parsedFile.path} (${streams.length} streams)');

    } catch (e) {
      print('   ✗ Error fetching streams for ${item.name}: $e');

      // Save error data
      final errorData = {
        'item': {
          'id': item.id,
          'name': item.name,
          'type': item.type,
        },
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      final filename = '${item.type}_${item.id.replaceAll('tt', '')}_${item.name.replaceAll(' ', '_').toLowerCase()}';
      final errorFile = File('stream_test_data/${filename}_error.json');
      await errorFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(errorData),
      );
      print('   ! Saved error data to ${errorFile.path}');
    }

    testIndex++;
    print('');
  }

  // List all created files
  final files = await outputDir.list().toList();
  final jsonFiles = files.where((f) => f.path.endsWith('.json')).toList();

  print('✓ Stream data collection completed!');
  print('Created ${jsonFiles.length} JSON files in ${outputDir.path}/:');
  print('');

  for (final file in jsonFiles) {
    final stat = await file.stat();
    final sizeKB = (stat.size / 1024).round();
    print('  ${file.path.split('/').last} (${sizeKB}KB)');
  }

  print('');
  print('File types:');
  print('  - *_parsed.json: Parsed StreamInfo objects');
  print('  - *_error.json: Error data when streams failed to load');
  print('  - raw_response_*.json: Raw HTTP responses from addons');
  print('  - error_response_*.json: Raw error responses from addons');
  print('');
  print('Analyze these files to see what additional data is available from addons!');
  print('Look for fields in raw_response_*.json that aren\'t being parsed yet.');

  // Close database
  await db.close();
}
