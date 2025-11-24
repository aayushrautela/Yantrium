import 'package:flutter/foundation.dart';
import '../../addons/logic/addon_client.dart';
import '../../addons/logic/addon_repository.dart';
import '../../addons/models/addon_config.dart';
import '../models/stream_info.dart';
import '../models/catalog_item.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/id_parser.dart';
import '../../../core/services/tmdb_service.dart';

/// Service to fetch streams from addons
class StreamService {
  final AppDatabase _database;
  final AddonRepository _addonRepository;
  final TmdbService _tmdbService;

  StreamService(this._database) 
      : _addonRepository = AddonRepository(_database),
        _tmdbService = TmdbService();

  /// Get IMDB ID from catalog item (fetches from TMDB if needed)
  Future<String?> _getImdbId(CatalogItem item, {Map<String, dynamic>? cachedTmdbData}) async {
    // If already an IMDB ID, use it directly
    if (IdParser.isImdbId(item.id)) {
      if (kDebugMode) {
        debugPrint('StreamService: Item already has IMDB ID: ${item.id}');
      }
      return item.id;
    }

    // Try to extract TMDB ID
    final tmdbId = IdParser.extractTmdbId(item.id);
    if (tmdbId == null) {
      if (kDebugMode) {
        debugPrint('StreamService: Could not extract TMDB ID from ${item.id}');
      }
      return null;
    }

    // Use cached TMDB data if provided, otherwise fetch from TMDB
    try {
      Map<String, dynamic>? tmdbData = cachedTmdbData;

      // Only fetch if no cached data provided
      if (tmdbData == null) {
        if (item.type == 'movie') {
          tmdbData = await _tmdbService.getMovieMetadata(tmdbId);
        } else if (item.type == 'series') {
          tmdbData = await _tmdbService.getTvMetadata(tmdbId);
        }
      }

      if (tmdbData != null) {
        final externalIds = tmdbData['external_ids'] as Map<String, dynamic>?;
        final imdbId = externalIds?['imdb_id'] as String?;
        if (kDebugMode) {
          debugPrint('StreamService: Extracted IMDB ID from TMDB: $imdbId');
        }
        return imdbId;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StreamService: Error fetching IMDB ID from TMDB: $e');
      }
    }

    return null;
  }

  /// Fetch streams from all enabled addons for a catalog item
  /// Returns a list of streams with their source addon information
  Future<List<StreamInfo>> getStreamsForItem(
    CatalogItem item, {
    String? episodeId,
    Map<String, dynamic>? cachedTmdbData,
  }) async {
    if (kDebugMode) {
      debugPrint('StreamService: Getting streams for ${item.name} (${item.id}, type: ${item.type})');
    }
    
    // Get IMDB ID for the item
    final imdbId = await _getImdbId(item, cachedTmdbData: cachedTmdbData);
    if (imdbId == null) {
      if (kDebugMode) {
        debugPrint('StreamService: Could not get IMDB ID, cannot fetch streams');
      }
      return [];
    }

    if (kDebugMode) {
      debugPrint('StreamService: Using IMDB ID: $imdbId for stream requests');
    }
    
    // Get all enabled addons
    final enabledAddons = await _addonRepository.getEnabledAddons();

    if (kDebugMode) {
      debugPrint('StreamService: Found ${enabledAddons.length} enabled addon(s)');
    }

    // Filter addons that support streaming and the item type
    final streamingAddons = enabledAddons.where((addon) {
      final manifest = _addonRepository.getManifest(addon);
      final hasStreamResource = AddonRepository.hasResource(addon.resources, 'stream');
      final supportsType = manifest.types.contains(item.type);
      
      if (kDebugMode) {
        debugPrint('StreamService: Addon ${addon.name} (${addon.id}): hasStream=$hasStreamResource, supportsType=$supportsType, types=${manifest.types}');
      }
      
      return hasStreamResource && supportsType;
    }).toList();

    if (kDebugMode) {
      debugPrint('StreamService: ${streamingAddons.length} addon(s) support streaming for ${item.type}');
    }

    if (streamingAddons.isEmpty) {
      if (kDebugMode) {
        debugPrint('StreamService: No addons support streaming for ${item.type}');
      }
      return [];
    }

    // Fetch streams from all addons in parallel
    final streamFutures = streamingAddons.map((addon) async {
      try {
        if (kDebugMode) {
          debugPrint('StreamService: Fetching streams from addon ${addon.name} (${addon.id})');
        }
        final streams = await _fetchStreamsFromAddon(addon, item, imdbId: imdbId, episodeId: episodeId);
        if (kDebugMode) {
          debugPrint('StreamService: Addon ${addon.name} returned ${streams.length} stream(s)');
        }
        return streams;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('StreamService: Failed to fetch streams from addon ${addon.id}: $e');
        }
        return <StreamInfo>[];
      }
    });

    final streamLists = await Future.wait(streamFutures);
    
    // Flatten and return all streams
    final allStreams = streamLists.expand((streams) => streams).toList();
    
    if (kDebugMode) {
      debugPrint('StreamService: Total streams found: ${allStreams.length}');
    }
    
    return allStreams;
  }

  /// Fetch streams from a single addon
  Future<List<StreamInfo>> _fetchStreamsFromAddon(
    AddonConfig addon,
    CatalogItem item, {
    String? imdbId,
    String? episodeId,
  }) async {
    final client = AddonClient(addon.baseUrl);
    
    // Use episodeId if provided (for series), otherwise use IMDB ID
    final streamId = episodeId ?? imdbId ?? item.id;
    
    if (kDebugMode) {
      debugPrint('StreamService: Requesting /stream/${item.type}/${streamId}.json from ${addon.baseUrl}');
      debugPrint('StreamService: Using stream ID: $streamId (episodeId: $episodeId, imdbId: $imdbId, item.id: ${item.id})');
    }
    
    try {
      final response = await client.getStreams(item.type, streamId);
      
      if (kDebugMode) {
        debugPrint('StreamService: Raw response from addon ${addon.name}:');
        debugPrint('StreamService: Response keys: ${response.keys.toList()}');
        debugPrint('StreamService: Full response: $response');
      }
      
      final streamsData = response['streams'] as List<dynamic>? ?? [];

      if (kDebugMode) {
        debugPrint('StreamService: Received ${streamsData.length} raw stream(s) from addon ${addon.name}');
        if (streamsData.isNotEmpty) {
          debugPrint('StreamService: First stream data: ${streamsData.first}');
        }
      }

      final parsedStreams = streamsData
          .map((streamData) {
            try {
              if (streamData is! Map<String, dynamic>) {
                if (kDebugMode) {
                  debugPrint('StreamService: Skipping invalid stream data (not a map)');
                }
                return null;
              }

              // Parse stream info and add addon metadata
              final streamInfo = StreamInfo.fromJson(streamData);
              
              if (kDebugMode) {
                debugPrint('StreamService: Parsed stream: url=${streamInfo.url}, quality=${streamInfo.quality}');
              }
              
              // Add addon information to the stream
              return StreamInfo(
                id: streamInfo.id,
                title: streamInfo.title,
                name: streamInfo.name,
                description: streamInfo.description,
                url: streamInfo.url,
                quality: streamInfo.quality,
                type: streamInfo.type,
                subtitles: streamInfo.subtitles,
                behaviorHints: streamInfo.behaviorHints,
                addonId: addon.id,
                addonName: addon.name,
              );
            } catch (e) {
              if (kDebugMode) {
                debugPrint('StreamService: Failed to parse stream: $e');
                debugPrint('StreamService: Stream data: $streamData');
              }
              return null;
            }
          })
          .whereType<StreamInfo>()
          .toList();
      
      if (kDebugMode) {
        debugPrint('StreamService: Successfully parsed ${parsedStreams.length} stream(s) from addon ${addon.name}');
      }
      
      return parsedStreams;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StreamService: Error fetching streams from addon ${addon.id} (${addon.baseUrl}): $e');
      }
      return [];
    }
  }
}
