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

  /// Extract or generate stream URL from stream data
  String? _getStreamUrl(Map<String, dynamic> streamData) {
    // Direct URL (string)
    if (streamData['url'] is String) {
      return streamData['url'] as String;
    }

    // Nested URL object
    if (streamData['url'] is Map && streamData['url']['url'] is String) {
      return streamData['url']['url'] as String;
    }

    // Generate magnet URL from infoHash
    if (streamData['infoHash'] is String) {
      final infoHash = streamData['infoHash'] as String;
      final trackers = [
        'udp://tracker.opentrackr.org:1337/announce',
        'udp://9.rarbg.com:2810/announce',
        'udp://tracker.openbittorrent.com:6969/announce',
        'udp://tracker.torrent.eu.org:451/announce',
        'udp://open.stealth.si:80/announce',
        'udp://tracker.leechers-paradise.org:6969/announce',
        'udp://tracker.coppersurfer.tk:6969/announce',
        'udp://tracker.internetwarriors.net:1337/announce',
      ];
      final trackersString = trackers.map((t) => '&tr=${Uri.encodeComponent(t)}').join('');
      final title = streamData['title'] ?? streamData['name'] ?? 'Unknown';
      return 'magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(title)}$trackersString';
    }

    return null;
  }

  /// Check if URL is a direct streaming URL (HTTP/HTTPS)
  bool _isDirectStreamingUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Extract quality from stream name/title using regex patterns
  String? _extractQuality(Map<String, dynamic> streamData) {
    final text = streamData['name'] as String? ?? streamData['title'] as String?;
    if (text == null) return null;

    // Quality patterns to look for
    final qualityPatterns = [
      RegExp(r'\b4K\b', caseSensitive: false),
      RegExp(r'\b2160p\b', caseSensitive: false),
      RegExp(r'\b1440p\b', caseSensitive: false),
      RegExp(r'\b1080p\b', caseSensitive: false),
      RegExp(r'\b720p\b', caseSensitive: false),
      RegExp(r'\b480p\b', caseSensitive: false),
      RegExp(r'\b360p\b', caseSensitive: false),
    ];

    for (final pattern in qualityPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }

    return null;
  }

  /// Extract subtitle data from stream object
  List<Subtitle>? _extractSubtitles(Map<String, dynamic> streamData) {
    final subsData = streamData['subtitles'];
    if (subsData is! List) return null;

    return subsData.map((sub) {
      if (sub is Map<String, dynamic>) {
        return Subtitle(
          url: sub['url'] as String,
          lang: sub['lang'] as String,
          id: sub['id'] as String?,
        );
      }
      return null;
    }).whereType<Subtitle>().toList();
  }

  /// Process streams robustly - filter and convert to StreamInfo objects
  List<StreamInfo> _processStreams(List<dynamic> streamsData, AddonConfig addon) {
    return streamsData
      .where((stream) {
        if (stream is! Map<String, dynamic>) return false;
        final hasPlayableLink = stream['url'] != null || stream['infoHash'] != null;
        final hasIdentifier = stream['title'] != null || stream['name'] != null;
        return hasPlayableLink && hasIdentifier;
      })
      .map((streamData) {
        final streamUrl = _getStreamUrl(streamData);
        if (streamUrl == null) return null;

        // Extract quality from name/title
        final quality = _extractQuality(streamData);

        // Build behavior hints
        final behaviorHints = <String, dynamic>{};
        if (streamData['behaviorHints'] is Map) {
          behaviorHints.addAll(streamData['behaviorHints'] as Map<String, dynamic>);
        }
        if (streamData['fileIdx'] != null) {
          behaviorHints['fileIdx'] = streamData['fileIdx'];
        }

        return StreamInfo(
          id: streamData['id'] as String?,
          title: streamData['title'] as String? ?? streamData['name'] as String?,
          name: streamData['name'] as String? ?? streamData['title'] as String?,
          description: streamData['description'] as String?,
          url: streamUrl,
          quality: quality,
          type: streamData['type'] as String?,
          subtitles: _extractSubtitles(streamData),
          behaviorHints: behaviorHints.isNotEmpty ? behaviorHints : null,
          addonId: addon.id,
          addonName: addon.name,
        );
      })
      .whereType<StreamInfo>()
      .toList();
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

      final parsedStreams = _processStreams(streamsData, addon);
      
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
