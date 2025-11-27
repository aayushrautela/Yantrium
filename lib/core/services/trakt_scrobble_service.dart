import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../models/trakt_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';
import 'trakt_core_service.dart';

/// Service for Trakt scrobbling operations with advanced rate limiting and deduplication
/// Based on NuvioStreaming's implementation
class TraktScrobbleService {
  final AppDatabase _database;
  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;
  final TraktCoreService _coreService = TraktCoreService.instance;

  TraktScrobbleService(this._database) {
    // Initialize core service with database
    _coreService.setDatabase(_database);
  }

  /// Validate content data before making API calls
  bool _validateContentData(TraktContentData contentData) {
    if (contentData.type != 'movie' && contentData.type != 'episode') {
      _logger.error('Invalid content type: ${contentData.type}');
      return false;
    }

    if (contentData.title.trim().isEmpty) {
      _logger.error('Missing or empty title');
      return false;
    }

    if (contentData.imdbId.trim().isEmpty) {
      _logger.error('Missing or empty IMDb ID');
      return false;
    }

    if (contentData.type == 'episode') {
      if (contentData.season == null || contentData.season! < 1) {
        _logger.error('Invalid season number');
        return false;
      }
      if (contentData.episode == null || contentData.episode! < 1) {
        _logger.error('Invalid episode number');
        return false;
      }
      if (contentData.showTitle?.trim().isEmpty ?? true) {
        _logger.error('Missing or empty show title');
        return false;
      }
      if (contentData.showYear == null || contentData.showYear! < 1900) {
        _logger.error('Invalid show year');
        return false;
      }
    }

    return true;
  }

  /// Build scrobble payload for API requests
  Map<String, dynamic> _buildScrobblePayload(TraktContentData contentData, double progress) {
    // Clamp progress between 0 and 100 and round to 2 decimals for API
    final clampedProgress = (progress < 0 ? 0 : progress > 100 ? 100 : progress).roundToDouble();

    if (contentData.type == 'movie') {
      if (contentData.imdbId.isEmpty || contentData.title.isEmpty) {
        throw Exception('Missing movie data for scrobbling');
      }

      // Ensure IMDb ID includes the 'tt' prefix for Trakt scrobble payloads
      final imdbIdWithPrefix = contentData.imdbId.startsWith('tt')
          ? contentData.imdbId
          : 'tt${contentData.imdbId}';

      return {
        'movie': {
          'title': contentData.title,
          'year': contentData.year,
          'ids': {
            'imdb': imdbIdWithPrefix
          }
        },
        'progress': clampedProgress
      };
    } else if (contentData.type == 'episode') {
      if (contentData.season == null || contentData.episode == null || contentData.showTitle == null || contentData.showYear == null) {
        throw Exception('Missing episode data for scrobbling');
      }

      final payload = {
        'show': {
          'title': contentData.showTitle,
          'year': contentData.showYear,
          'ids': <String, dynamic>{}
        },
        'episode': {
          'season': contentData.season,
          'number': contentData.episode
        },
        'progress': clampedProgress
      };

      // Add show IMDB ID if available
      if (contentData.showImdbId != null) {
        final showImdbWithPrefix = contentData.showImdbId!.startsWith('tt')
            ? contentData.showImdbId
            : 'tt${contentData.showImdbId}';
        (payload['show'] as Map<String, dynamic>)['ids'] = {'imdb': showImdbWithPrefix};
      }

      // Add episode IMDB ID if available (for specific episode IDs)
      if (contentData.imdbId.isNotEmpty && contentData.imdbId != contentData.showImdbId) {
        final episodeImdbWithPrefix = contentData.imdbId.startsWith('tt')
            ? contentData.imdbId
            : 'tt${contentData.imdbId}';

        (payload['episode'] as Map<String, dynamic>)['ids'] = {
          'imdb': episodeImdbWithPrefix
        };
      }

      return payload;
    }

    throw Exception('Invalid content type: ${contentData.type}');
  }

  /// Start watching content (scrobble start)
  Future<bool> scrobbleStart(TraktContentData contentData, double progress) async {
    try {
      // Validate content data before making API call
      if (!_validateContentData(contentData)) {
        return false;
      }

      final payload = _buildScrobblePayload(contentData, progress);
      final response = await _coreService.apiRequest<TraktScrobbleResponse>('/scrobble/start', data: payload);

      if (response != null) {
        _logger.debug('Started watching ${contentData.type}: ${contentData.title}');
        return true;
      }

      return false;
    } catch (error) {
      _logger.error('[TraktScrobbleService] Failed to start watching', error);
      return false;
    }
  }

  /// Pause watching content (scrobble pause) - with debouncing
  Future<bool> scrobblePause(TraktContentData contentData, double progress, {bool force = false}) async {
    try {
      // Validate content data before making API call
      if (!_validateContentData(contentData)) {
        return false;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final watchingKey = contentData.getContentKey();

      // Debouncing - prevent truly rapid calls (< 100ms)
      if (!force && (_coreService as dynamic)._lastSyncTimes[watchingKey] != null) {
        final lastSync = (_coreService as dynamic)._lastSyncTimes[watchingKey];
        if (now - lastSync < 100) {
          return true; // Skip this sync, but return success
        }
      }

      (_coreService as dynamic)._lastSyncTimes[watchingKey] = now;

      final payload = _buildScrobblePayload(contentData, progress);
      final response = await _coreService.queueRequest(() async {
        return await _coreService.apiRequest<TraktScrobbleResponse>('/scrobble/pause', data: payload);
      });

      if (response != null) {
        _logger.debug('Updated progress ${progress.toStringAsFixed(1)}% for ${contentData.type}: ${contentData.title}');
        return true;
      }

      return false;
    } catch (error) {
      // Handle rate limiting errors more gracefully
      if (error.toString().contains('429')) {
        _logger.warning('[TraktScrobbleService] Rate limited, will retry later');
        return true; // Return success to avoid error spam
      }

      _logger.error('[TraktScrobbleService] Failed to update progress', error);
      return false;
    }
  }

  /// Stop watching content (scrobble stop) - handles completion infoic
  Future<bool> scrobbleStop(TraktContentData contentData, double progress) async {
    try {
      // Validate content data before making API call
      if (!_validateContentData(contentData)) {
        return false;
      }

      final watchingKey = contentData.getContentKey();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Debouncing - prevent truly duplicate calls (< 1 second)
      final lastStopTime = (_coreService as dynamic)._lastStopCalls[watchingKey];
      if (lastStopTime != null && (now - lastStopTime) < 1000) {
        _logger.debug('[TraktScrobbleService] Ignoring duplicate stop call for ${contentData.title}');
        return true; // Return success to avoid error handling
      }

      // Record this stop attempt
      (_coreService as dynamic)._lastStopCalls[watchingKey] = now;

      // Use pause if below user threshold, stop only when ready to scrobble
      final useStop = progress >= _coreService.completionThreshold;
      final endpoint = useStop ? '/scrobble/stop' : '/scrobble/pause';

      final payload = _buildScrobblePayload(contentData, progress);
      final response = await _coreService.queueRequest(() async {
        return await _coreService.apiRequest<TraktScrobbleResponse>(endpoint, data: payload);
      });

      if (response != null) {
        // Mark as scrobbled if >= user threshold to prevent future duplicates and restarts
        if (progress >= _coreService.completionThreshold) {
          (_coreService as dynamic)._scrobbledItems.add(watchingKey);
          (_coreService as dynamic)._scrobbledTimestamps[watchingKey] = DateTime.now().millisecondsSinceEpoch;
        }

        // Action reflects actual endpoint used based on user threshold
        final action = progress >= _coreService.completionThreshold ? 'scrobbled' : 'paused';
        _logger.debug('Stopped watching ${contentData.type}: ${contentData.title} (${progress.toStringAsFixed(1)}% - $action)');

        return true;
      } else {
        // If failed, remove from lastStopCalls so we can try again
        (_coreService as dynamic)._lastStopCalls.remove(watchingKey);
      }

      return false;
    } catch (error) {
      // Handle rate limiting errors more gracefully
      if (error.toString().contains('429')) {
        _logger.warning('[TraktScrobbleService] Rate limited, will retry later');
        return true;
      }

      _logger.error('[TraktScrobbleService] Failed to stop scrobbling', error);
      return false;
    }
  }

  /// IMMEDIATE SCROBBLE METHODS - Bypass rate limiting queue for critical user actions

  /// Immediate scrobble pause - bypasses queue for instant user feedback
  Future<bool> scrobblePauseImmediate(TraktContentData contentData, double progress) async {
    try {
      // Validate content data before making API call
      if (!_validateContentData(contentData)) {
        return false;
      }

      final watchingKey = contentData.getContentKey();

      // Minimal deduplication: Only prevent calls within 50ms for immediate actions
      final lastSync = (_coreService as dynamic)._lastSyncTimes[watchingKey];
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lastSync != null && (now - lastSync) < 50) {
        return true; // Skip this sync, but return success
      }

      (_coreService as dynamic)._lastSyncTimes[watchingKey] = now;

      // BYPASS QUEUE: Call API directly for immediate response
      final payload = _buildScrobblePayload(contentData, progress);
      final response = await _coreService.apiRequest<TraktScrobbleResponse>('/scrobble/pause', data: payload);

      if (response != null) {
        _logger.debug('[IMMEDIATE] Updated progress ${progress.toStringAsFixed(1)}% for ${contentData.type}: ${contentData.title}');
        return true;
      }

      return false;
    } catch (error) {
      _logger.error('[TraktScrobbleService] Failed to pause scrobbling immediately', error);
      return false;
    }
  }

  /// Immediate scrobble stop - bypasses queue for instant user feedback
  Future<bool> scrobbleStopImmediate(TraktContentData contentData, double progress) async {
    try {
      // Validate content data before making API call
      if (!_validateContentData(contentData)) {
        return false;
      }

      final watchingKey = contentData.getContentKey();

      // Minimal deduplication: Only prevent calls within 200ms for immediate actions
      final lastStopTime = (_coreService as dynamic)._lastStopCalls[watchingKey];
      final now = DateTime.now().millisecondsSinceEpoch;
      if (lastStopTime != null && (now - lastStopTime) < 200) {
        return true;
      }

      (_coreService as dynamic)._lastStopCalls[watchingKey] = now;

      // BYPASS QUEUE: Use pause if below user threshold, stop only when ready to scrobble
      final useStop = progress >= _coreService.completionThreshold;
      final endpoint = useStop ? '/scrobble/stop' : '/scrobble/pause';

      final payload = _buildScrobblePayload(contentData, progress);
      final response = await _coreService.apiRequest<TraktScrobbleResponse>(endpoint, data: payload);

      if (response != null) {
        // Mark as scrobbled if >= user threshold to prevent future duplicates and restarts
        if (progress >= _coreService.completionThreshold) {
          (_coreService as dynamic)._scrobbledItems.add(watchingKey);
          (_coreService as dynamic)._scrobbledTimestamps[watchingKey] = DateTime.now().millisecondsSinceEpoch;
        }

        // Action reflects actual endpoint used based on user threshold
        final action = progress >= _coreService.completionThreshold ? 'scrobbled' : 'paused';
        _logger.debug('[IMMEDIATE] Stopped watching ${contentData.type}: ${contentData.title} (${progress.toStringAsFixed(1)}% - $action)');

        return true;
      }

      return false;
    } catch (error) {
      _logger.error('[TraktScrobbleService] Failed to stop scrobbling immediately', error);
      return false;
    }
  }

  /// Legacy scrobble method for backward compatibility
  /// @deprecated Use scrobbleStop instead
  Future<bool> scrobble({
    required String type,
    required String imdbId,
    required double progress,
    String? title,
    int? season,
    int? episode,
  }) async {
    final contentData = TraktContentData(
      type: type,
      imdbId: imdbId,
      title: title ?? 'Unknown',
      year: 0, // Not used in legacy method
      season: season,
      episode: episode,
      showTitle: type == 'episode' ? title : null,
      showYear: type == 'episode' ? 0 : null,
    );

    return await scrobbleStop(contentData, progress);
  }

  /// Legacy checkin method for backward compatibility
  /// @deprecated Use scrobbleStart instead
  Future<bool> checkin({
    required String type,
    required String imdbId,
    String? title,
    int? season,
    int? episode,
    String? message,
  }) async {
    final contentData = TraktContentData(
      type: type,
      imdbId: imdbId,
      title: title ?? 'Unknown',
      year: 0,
      season: season,
      episode: episode,
      showTitle: type == 'episode' ? title : null,
      showYear: type == 'episode' ? 0 : null,
    );

    return await scrobbleStart(contentData, 1.0); // Start with minimal progress
  }

  /// HISTORY MANAGEMENT METHODS

  /// Get user's watch history with optional filtering
  Future<List<TraktHistoryItem>> getHistory({
    String? type, // 'movies', 'shows', 'episodes'
    int? id,
    DateTime? startAt,
    DateTime? endAt,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final result = await _coreService.apiRequest<List<dynamic>>(
        _buildHistoryEndpoint(type, id),
        data: _buildHistoryQueryParams(startAt, endAt, page, limit),
      );
      return result.map((item) => TraktHistoryItem.fromJson(item)).toList();
    } catch (error) {
      _logger.error('[TraktScrobbleService] Error fetching history', error);
      return [];
    }
  }

  /// Build history endpoint URL
  String _buildHistoryEndpoint(String? type, int? id) {
    String endpoint = '/sync/history';
    if (type != null) {
      endpoint += '/$type';
      if (id != null) {
        endpoint += '/$id';
      }
    }
    return endpoint;
  }

  /// Build query parameters for history requests
  Map<String, dynamic>? _buildHistoryQueryParams(DateTime? startAt, DateTime? endAt, int page, int limit) {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (startAt != null) {
      params['start_at'] = startAt.toIso8601String();
    }
    if (endAt != null) {
      params['end_at'] = endAt.toIso8601String();
    }

    return params.isNotEmpty ? params : null;
  }

  /// Remove items from user's watched history
  Future<TraktHistoryRemoveResponse?> removeFromHistory(TraktHistoryRemovePayload payload) async {
    try {
      _logger.info('[TraktScrobbleService] removeFromHistory called with payload: ${payload.toJson()}');

      final result = await _coreService.apiRequest<Map<String, dynamic>>(
        '/sync/history/remove',
        method: 'POST',
        data: payload.toJson(),
      );

      final response = TraktHistoryRemoveResponse.fromJson(result);
      _logger.info('[TraktScrobbleService] removeFromHistory API response: ${response.toJson()}');

      return response;
    } catch (error) {
      _logger.error('[TraktScrobbleService] Failed to remove from history', error);
      return null;
    }
  }

  /// Get user's movie watch history
  Future<List<TraktHistoryItem>> getHistoryMovies({
    DateTime? startAt,
    DateTime? endAt,
    int page = 1,
    int limit = 100,
  }) async {
    return getHistory(type: 'movies', startAt: startAt, endAt: endAt, page: page, limit: limit);
  }

  /// Get user's episode watch history
  Future<List<TraktHistoryItem>> getHistoryEpisodes({
    DateTime? startAt,
    DateTime? endAt,
    int page = 1,
    int limit = 100,
  }) async {
    return getHistory(type: 'episodes', startAt: startAt, endAt: endAt, page: page, limit: limit);
  }

  /// Get user's show watch history
  Future<List<TraktHistoryItem>> getHistoryShows({
    DateTime? startAt,
    DateTime? endAt,
    int page = 1,
    int limit = 100,
  }) async {
    return getHistory(type: 'shows', startAt: startAt, endAt: endAt, page: page, limit: limit);
  }

  /// Remove a movie from watched history by IMDB ID
  Future<bool> removeMovieFromHistory(String imdbId) async {
    try {
      final payload = TraktHistoryRemovePayload(
        movies: [
          {
            'ids': {
              'imdb': imdbId.startsWith('tt') ? imdbId : 'tt$imdbId',
            },
          },
        ],
      );

      final result = await removeFromHistory(payload);
      return result != null && (result.deleted['movies'] ?? 0) > 0;
    } catch (error) {
      _logger.error('[TraktScrobbleService] Failed to remove movie from history', error);
      return false;
    }
  }

  /// Remove an episode from watched history by IMDB IDs
  Future<bool> removeEpisodeFromHistory(String showImdbId, int season, int episode) async {
    try {
      _logger.info('[TraktScrobbleService] removeEpisodeFromHistory called for $showImdbId S${season}E${episode}');

      final payload = TraktHistoryRemovePayload(
        shows: [
          {
            'ids': {
              'imdb': showImdbId.startsWith('tt') ? showImdbId : 'tt$showImdbId',
            },
            'seasons': [
              {
                'number': season,
                'episodes': [
                  {'number': episode},
                ],
              },
            ],
          },
        ],
      );

      _logger.info('[TraktScrobbleService] Sending removeEpisodeFromHistory payload: ${payload.toJson()}');

      final result = await removeFromHistory(payload);

      if (result != null) {
        final success = (result.deleted['episodes'] ?? 0) > 0;
        _logger.info('[TraktScrobbleService] Episode removal success: $success (${result.deleted['episodes'] ?? 0} episodes deleted)');
        return success;
      }

      _logger.info('[TraktScrobbleService] No result from removeEpisodeFromHistory');
      return false;
    } catch (error) {
      _logger.error('[TraktScrobbleService] Failed to remove episode from history', error);
      return false;
    }
  }

  /// Remove entire show from watched history by IMDB ID
  Future<bool> removeShowFromHistory(String imdbId) async {
    try {
      _logger.info('[TraktScrobbleService] removeShowFromHistory called for $imdbId');

      // First, let's check if this show exists in history
      _logger.info('[TraktScrobbleService] Checking if $imdbId exists in watch history...');
      final history = await getHistoryEpisodes(limit: 200); // Get recent episode history
      final fullImdbId = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';
      final showInHistory = history.any((item) => item.show?.ids?.imdb == fullImdbId);

      _logger.info('[TraktScrobbleService] Show $imdbId found in history: $showInHistory');

      if (!showInHistory) {
        _logger.info('[TraktScrobbleService] Show $imdbId not found in watch history - nothing to remove');
        return true; // Consider this a success since there's nothing to remove
      }

      final payload = TraktHistoryRemovePayload(
        shows: [
          {
            'ids': {
              'imdb': imdbId.startsWith('tt') ? imdbId : 'tt$imdbId',
            },
          },
        ],
      );

      _logger.info('[TraktScrobbleService] Sending removeFromHistory payload: ${payload.toJson()}');

      final result = await removeFromHistory(payload);

      _logger.info('[TraktScrobbleService] removeFromHistory response: ${result?.toJson()}');

      if (result != null) {
        final success = (result.deleted['episodes'] ?? 0) > 0;
        _logger.info('[TraktScrobbleService] Show removal success: $success (${result.deleted['episodes'] ?? 0} episodes deleted)');
        return success;
      }

      _logger.info('[TraktScrobbleService] No response from removeFromHistory API');
      return false;
    } catch (error) {
      _logger.error('[TraktScrobbleService] Failed to remove show from history', error);
      return false;
    }
  }

  /// Remove items from history by history IDs
  Future<bool> removeHistoryByIds(List<int> historyIds) async {
    try {
      final payload = TraktHistoryRemovePayload(ids: historyIds);

      final result = await removeFromHistory(payload);
      return result != null && ((result.deleted['movies'] ?? 0) > 0 || (result.deleted['episodes'] ?? 0) > 0);
    } catch (error) {
      _logger.error('[TraktScrobbleService] Failed to remove history by IDs', error);
      return false;
    }
  }
}





