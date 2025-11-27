import 'package:dio/dio.dart';
import '../models/tmdb_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';

/// Cached metadata entry with timestamp
class _CachedMetadata {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Duration ttl;

  _CachedMetadata(this.data, this.ttl) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

/// Service for TMDB metadata operations
class TmdbMetadataService {
  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;

  late final Dio _dio;

  // Cache for TMDB metadata
  final Map<String, _CachedMetadata> _cache = {};

  TmdbMetadataService() {
    _dio = Dio(BaseOptions(
      baseUrl: _config.tmdbBaseUrl,
      queryParameters: {
        'api_key': _config.tmdbApiKey,
      },
      headers: {
        'Accept': 'application/json',
      },
      connectTimeout: _config.httpTimeout,
      receiveTimeout: _config.httpTimeout,
    ));
  }

  /// Search for content by IMDB ID and get TMDB ID
  Future<int?> getTmdbIdFromImdb(String imdbId) async {
    if (imdbId.trim().isEmpty) {
      _logger.error('IMDB ID is required');
      return null;
    }

    try {
      final response = await _dio.get('/find/$imdbId', queryParameters: {
        'external_source': 'imdb_id',
      });

      final data = response.data as Map<String, dynamic>;

      // Check movie results first
      final movieResults = data['movie_results'] as List<dynamic>?;
      if (movieResults != null && movieResults.isNotEmpty) {
        return movieResults[0]['id'] as int?;
      }

      // Check TV results
      final tvResults = data['tv_results'] as List<dynamic>?;
      if (tvResults != null && tvResults.isNotEmpty) {
        return tvResults[0]['id'] as int?;
      }

      return null;
    } catch (e) {
      _logger.error('Error finding TMDB ID from IMDB ID: $imdbId', e);
      return null;
    }
  }

  /// Fetch movie metadata from TMDB (with caching)
  Future<TmdbMovie?> getMovieMetadata(int tmdbId) async {
    if (tmdbId <= 0) {
      _logger.error('Invalid TMDB ID: $tmdbId');
      return null;
    }

    final cacheKey = 'movie_$tmdbId';

    // Check cache first
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      // Check if cached data has external_ids (added in recent update)
      final hasExternalIds = cached.data.containsKey('external_ids') &&
                            (cached.data['external_ids'] as Map<String, dynamic>?)?.containsKey('imdb_id') == true;

      if (hasExternalIds) {
        _logger.debug('Using cached movie metadata for TMDB ID: $tmdbId');
        return TmdbMovie.fromJson(cached.data);
      } else {
        _logger.debug('Cached movie metadata missing external_ids, forcing refresh for TMDB ID: $tmdbId');
        _cache.remove(cacheKey);
      }
    }

    try {
      _logger.debug('Fetching movie metadata for TMDB ID: $tmdbId');
      final response = await _dio.get('/movie/$tmdbId', queryParameters: {
        'append_to_response': 'videos,credits,images,release_dates,external_ids',
      });
      final data = response.data as Map<String, dynamic>;

      // Store in cache
      _cache[cacheKey] = _CachedMetadata(data, _config.tmdbCacheTtl);

      // Remove old cache entries if cache is getting too large
      if (_cache.length > _config.maxCacheSize) {
        _cleanupCache();
      }

      return TmdbMovie.fromJson(data);
    } catch (e) {
      _logger.error('Error fetching movie metadata for ID: $tmdbId', e);
      return null;
    }
  }

  /// Fetch TV series metadata from TMDB (with caching)
  Future<TmdbTvShow?> getTvMetadata(int tmdbId) async {
    if (tmdbId <= 0) {
      _logger.error('Invalid TMDB ID: $tmdbId');
      return null;
    }

    final cacheKey = 'tv_$tmdbId';

    // Check cache first
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      // Check if cached data has external_ids
      final hasExternalIds = cached.data.containsKey('external_ids') &&
                            (cached.data['external_ids'] as Map<String, dynamic>?)?.containsKey('imdb_id') == true;

      if (hasExternalIds) {
        _logger.debug('Using cached TV metadata for TMDB ID: $tmdbId');
        return TmdbTvShow.fromJson(cached.data);
      } else {
        _logger.debug('Cached TV metadata missing external_ids, forcing refresh for TMDB ID: $tmdbId');
        _cache.remove(cacheKey);
      }
    }

    try {
      _logger.debug('Fetching TV metadata for TMDB ID: $tmdbId');
      final response = await _dio.get('/tv/$tmdbId', queryParameters: {
        'append_to_response': 'videos,credits,images,content_ratings,external_ids',
      });
      final data = response.data as Map<String, dynamic>;

      // Store in cache
      _cache[cacheKey] = _CachedMetadata(data, _config.tmdbCacheTtl);

      // Remove old cache entries if cache is getting too large
      if (_cache.length > _config.maxCacheSize) {
        _cleanupCache();
      }

      return TmdbTvShow.fromJson(data);
    } catch (e) {
      _logger.error('Error fetching TV metadata for ID: $tmdbId', e);
      return null;
    }
  }

  /// Clear the metadata cache
  void clearCache() {
    _cache.clear();
    _logger.debug('Cleared TMDB metadata cache');
  }

  /// Clear cache for a specific TMDB ID (useful for forcing refresh)
  void clearCacheForId(int tmdbId, String type) {
    if (tmdbId <= 0) {
      _logger.error('Invalid TMDB ID: $tmdbId');
      return;
    }

    final cacheKey = '${type}_$tmdbId';
    _cache.remove(cacheKey);
    _logger.debug('Cleared cache for $type ID: $tmdbId');
  }

  /// Get current cache size
  int getCacheSize() {
    return _cache.length;
  }

  /// Clean up expired cache entries and oldest entries if cache is too large
  void _cleanupCache() {
    // Remove expired entries
    _cache.removeWhere((key, value) => value.isExpired);

    // If still too large, remove oldest entries
    if (_cache.length > _config.maxCacheSize) {
      final entries = _cache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

      final toRemove = entries.take(_cache.length - _config.maxCacheSize);
      for (final entry in toRemove) {
        _cache.remove(entry.key);
      }
    }
  }
}





