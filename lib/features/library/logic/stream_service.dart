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

  /// Check if URL is a direct streaming URL (HTTP/HTTPS)
  bool _isDirectStreamingUrl(String? url) {
    if (url == null) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Extract stream URL from various formats returned by addons
  String _getStreamUrl(Map<String, dynamic> stream) {
    // Prefer plain string URLs; guard against objects or unexpected types
    if (stream['url'] is String) {
      return stream['url'] as String;
    }

    // Some addons might nest the URL inside an object; try common shape
    if (stream['url'] is Map<String, dynamic> &&
        stream['url']['url'] is String) {
      return stream['url']['url'] as String;
    }

    // Handle magnet links from infoHash
    if (stream['infoHash'] is String) {
      final infoHash = stream['infoHash'] as String;
      final trackers = [
        'udp://tracker.opentrackr.org:1337/announce',
        'udp://9.rarbg.com:2810/announce',
        'udp://tracker.openbittorrent.com:6969/announce',
        'udp://tracker.torrent.eu.org:451/announce',
        'udp://open.stealth.si:80/announce',
        'udp://tracker.leechers-paradise.org:6969/announce',
        'udp://tracker.coppersurfer.tk:6969/announce',
        'udp://tracker.internetwarriors.net:1337/announce'
      ];
      final trackersString = trackers.map((t) => '&tr=${Uri.encodeComponent(t)}').join('');
      final encodedTitle = Uri.encodeComponent(
        stream['title'] ?? stream['name'] ?? 'Unknown'
      );
      return 'magnet:?xt=urn:btih:$infoHash&dn=$encodedTitle$trackersString';
    }

    return '';
  }

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
      debugPrint('StreamService: Requesting /stream/${item.type}/$streamId.json from ${addon.baseUrl}');
      debugPrint('StreamService: Using stream ID: $streamId (episodeId: $episodeId, imdbId: $imdbId, item.id: ${item.id})');
    }
    
    try {
      final response = await client.getStreams(item.type, streamId);
      
      if (kDebugMode) {
        debugPrint('StreamService: Raw response from addon ${addon.name}:');
        debugPrint('StreamService: Response keys: ${response.keys.toList()}');
        debugPrint('StreamService: Full response: $response');
      }
      
      final streamsData = response['streams'] ?? [];

      if (kDebugMode) {
        debugPrint('StreamService: Received ${streamsData.length} raw stream(s) from addon ${addon.name}');
        if (streamsData.isNotEmpty) {
          debugPrint('StreamService: First stream data: ${streamsData.first}');
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
                debugPrint('StreamService: Skipping stream without playable link');
              }
            }
            if (!hasIdentifier) {
              if (kDebugMode) {
                debugPrint('StreamService: Skipping stream without identifier');
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
                debugPrint('StreamService: Failed to process individual stream: $e');
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
