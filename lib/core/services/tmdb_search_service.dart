import 'package:dio/dio.dart';
import '../models/tmdb_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';

/// Service for TMDB search operations
class TmdbSearchService {
  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;

  late final Dio _dio;

  TmdbSearchService() {
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

  /// Search for movies using TMDB search API
  Future<List<TmdbSearchResult>> searchMovies(String query, {int page = 1}) async {
    if (query.trim().isEmpty) {
      _logger.error('Search query cannot be empty');
      return [];
    }

    if (page < 1) {
      _logger.error('Page number must be >= 1');
      return [];
    }

    try {
      final response = await _dio.get('/search/movie', queryParameters: {
        'query': query,
        'page': page,
      });
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>? ?? [])
          .map((item) => TmdbSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort by popularity (highest first)
      results.sort((a, b) => b.popularity.compareTo(a.popularity));

      _logger.debug('Found ${results.length} movies for query: "$query"');
      return results;
    } catch (e) {
      _logger.error('Error searching movies for query: "$query"', e);
      return [];
    }
  }

  /// Search for TV shows using TMDB search API
  Future<List<TmdbSearchResult>> searchTv(String query, {int page = 1}) async {
    if (query.trim().isEmpty) {
      _logger.error('Search query cannot be empty');
      return [];
    }

    if (page < 1) {
      _logger.error('Page number must be >= 1');
      return [];
    }

    try {
      final response = await _dio.get('/search/tv', queryParameters: {
        'query': query,
        'page': page,
      });
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>? ?? [])
          .map((item) => TmdbSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort by popularity (highest first)
      results.sort((a, b) => b.popularity.compareTo(a.popularity));

      _logger.debug('Found ${results.length} TV shows for query: "$query"');
      return results;
    } catch (e) {
      _logger.error('Error searching TV shows for query: "$query"', e);
      return [];
    }
  }

  /// Get movie recommendations sorted by popularity
  Future<List<TmdbSearchResult>> getMovieRecommendations(int tmdbId, {int limit = 15}) async {
    if (tmdbId <= 0) {
      _logger.error('Invalid TMDB ID: $tmdbId');
      return [];
    }

    if (limit <= 0) {
      _logger.error('Limit must be > 0');
      return [];
    }

    try {
      final response = await _dio.get('/movie/$tmdbId/recommendations');
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>? ?? [])
          .map((item) => TmdbSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort by popularity (highest first) and take top results
      results.sort((a, b) => b.popularity.compareTo(a.popularity));
      final topResults = results.take(limit).toList();

      _logger.debug('Found ${topResults.length} movie recommendations for TMDB ID: $tmdbId');
      return topResults;
    } catch (e) {
      _logger.error('Error fetching movie recommendations for ID: $tmdbId', e);
      return [];
    }
  }

  /// Get TV show recommendations sorted by popularity
  Future<List<TmdbSearchResult>> getTvRecommendations(int tmdbId, {int limit = 15}) async {
    if (tmdbId <= 0) {
      _logger.error('Invalid TMDB ID: $tmdbId');
      return [];
    }

    if (limit <= 0) {
      _logger.error('Limit must be > 0');
      return [];
    }

    try {
      final response = await _dio.get('/tv/$tmdbId/recommendations');
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>? ?? [])
          .map((item) => TmdbSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort by popularity (highest first) and take top results
      results.sort((a, b) => b.popularity.compareTo(a.popularity));
      final topResults = results.take(limit).toList();

      _logger.debug('Found ${topResults.length} TV recommendations for TMDB ID: $tmdbId');
      return topResults;
    } catch (e) {
      _logger.error('Error fetching TV recommendations for ID: $tmdbId', e);
      return [];
    }
  }

  /// Get similar/recommended movies or TV shows
  Future<List<TmdbSearchResult>> getSimilar(int tmdbId, String type, {int limit = 15}) async {
    if (tmdbId <= 0) {
      _logger.error('Invalid TMDB ID: $tmdbId');
      return [];
    }

    if (type != 'movie' && type != 'tv') {
      _logger.error('Type must be either "movie" or "tv"');
      return [];
    }

    if (limit <= 0) {
      _logger.error('Limit must be > 0');
      return [];
    }

    try {
      final endpoint = type == 'movie' ? '/movie/$tmdbId/similar' : '/tv/$tmdbId/similar';
      final response = await _dio.get(endpoint);
      final data = response.data as Map<String, dynamic>;

      final results = (data['results'] as List<dynamic>? ?? [])
          .map((item) => TmdbSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort by popularity (highest first) and take top results
      results.sort((a, b) => b.popularity.compareTo(a.popularity));
      final topResults = results.take(limit).toList();

      _logger.debug('Found ${topResults.length} similar $type for TMDB ID: $tmdbId');
      return topResults;
    } catch (e) {
      _logger.error('Error fetching similar content for $type ID: $tmdbId', e);
      return [];
    }
  }

  /// Get episodes for a specific season of a TV series
  Future<Map<String, dynamic>?> getSeasonEpisodes(int tmdbId, int seasonNumber) async {
    if (tmdbId <= 0) {
      _logger.error('Invalid TMDB ID: $tmdbId');
      return null;
    }

    if (seasonNumber < 0) {
      _logger.error('Season number must be >= 0');
      return null;
    }

    try {
      final response = await _dio.get('/tv/$tmdbId/season/$seasonNumber');
      _logger.debug('Fetched season $seasonNumber episodes for TV show ID: $tmdbId');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _logger.error('Error fetching season episodes for TV ID: $tmdbId, season: $seasonNumber', e);
      return null;
    }
  }

  /// Get all seasons for a TV series
  Future<List<Map<String, dynamic>>> getSeasons(int tmdbId) async {
    if (tmdbId <= 0) {
      _logger.error('Invalid TMDB ID: $tmdbId');
      return [];
    }

    try {
      final response = await _dio.get('/tv/$tmdbId');
      final data = response.data as Map<String, dynamic>;
      final seasons = (data['seasons'] as List<dynamic>? ?? [])
          .map((season) => season as Map<String, dynamic>)
          .toList();

      _logger.debug('Found ${seasons.length} seasons for TV show ID: $tmdbId');
      return seasons;
    } catch (e) {
      _logger.error('Error fetching seasons for TV ID: $tmdbId', e);
      return [];
    }
  }
}

