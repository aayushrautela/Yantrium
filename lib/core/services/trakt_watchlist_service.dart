import 'package:dio/dio.dart';
import '../database/app_database.dart';
import '../models/trakt_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';
import 'trakt_auth_service.dart';

/// Service for Trakt watchlist operations
class TraktWatchlistService {
  final AppDatabase _database;
  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;

  late final Dio _dio;

  TraktWatchlistService(this._database) {
    _dio = Dio(BaseOptions(
      baseUrl: _config.traktBaseUrl,
      headers: {
        'Content-Type': 'application/json',
        'trakt-api-version': _config.traktApiVersion,
        'trakt-api-key': _config.traktClientId,
      },
      connectTimeout: _config.httpTimeout,
      receiveTimeout: _config.httpTimeout,
    ));
  }

  /// Get user's watchlist
  Future<List<TraktWatchlistItem>> getWatchlist({
    String? username,
    String type = 'movies', // 'movies', 'shows', 'seasons', 'episodes'
  }) async {
    if (!['movies', 'shows', 'seasons', 'episodes'].contains(type)) {
      _logger.error('Invalid watchlist type: $type');
      return [];
    }

    try {
      final token = await TraktAuthService(_database).getAccessToken();
      if (token == null) {
        _logger.warning('No access token available for watchlist');
        return [];
      }

      final user = username ?? (await TraktAuthService(_database).getCurrentUser())?['username'];
      if (user == null) {
        _logger.warning('No username available for watchlist');
        return [];
      }

      final response = await _dio.get(
        '/users/$user/watchlist/$type',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final watchlist = (response.data as List<dynamic>? ?? [])
          .map((item) => TraktWatchlistItem.fromJson(item as Map<String, dynamic>))
          .toList();

      _logger.debug('Retrieved ${watchlist.length} watchlist items of type: $type');
      return watchlist;
    } catch (e) {
      _logger.error('Error fetching watchlist', e);
      if (e is DioException) {
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return [];
    }
  }

  /// Add item to watchlist
  Future<bool> addToWatchlist({
    required String type, // 'movie' or 'show'
    required String imdbId,
  }) async {
    if (imdbId.trim().isEmpty) {
      _logger.error('IMDB ID is required for adding to watchlist');
      return false;
    }

    if (type != 'movie' && type != 'show') {
      _logger.error('Type must be either "movie" or "show"');
      return false;
    }

    try {
      final token = await TraktAuthService(_database).getAccessToken();
      if (token == null) {
        _logger.warning('No access token available for adding to watchlist');
        return false;
      }

      final data = <String, dynamic>{};

      if (type == 'movie') {
        data['movies'] = [
          {'ids': {'imdb': imdbId}}
        ];
      } else if (type == 'show') {
        data['shows'] = [
          {'ids': {'imdb': imdbId}}
        ];
      }

      await _dio.post(
        '/sync/watchlist',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      _logger.debug('Successfully added $type to watchlist');
      return true;
    } catch (e) {
      _logger.error('Error adding to watchlist', e);
      if (e is DioException) {
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return false;
    }
  }

  /// Remove item from watchlist
  Future<bool> removeFromWatchlist({
    required String type, // 'movie' or 'show'
    required String imdbId,
  }) async {
    if (imdbId.trim().isEmpty) {
      _logger.error('IMDB ID is required for removing from watchlist');
      return false;
    }

    if (type != 'movie' && type != 'show') {
      _logger.error('Type must be either "movie" or "show"');
      return false;
    }

    try {
      final token = await TraktAuthService(_database).getAccessToken();
      if (token == null) {
        _logger.warning('No access token available for removing from watchlist');
        return false;
      }

      final data = <String, dynamic>{};

      if (type == 'movie') {
        data['movies'] = [
          {'ids': {'imdb': imdbId}}
        ];
      } else if (type == 'show') {
        data['shows'] = [
          {'ids': {'imdb': imdbId}}
        ];
      }

      await _dio.post(
        '/sync/watchlist/remove',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      _logger.debug('Successfully removed $type from watchlist');
      return true;
    } catch (e) {
      _logger.error('Error removing from watchlist', e);
      if (e is DioException) {
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return false;
    }
  }

  /// Get watch history from Trakt
  /// Returns a list of watched items with progress information
  Future<List<Map<String, dynamic>>> getWatchHistory({
    int page = 1,
    int limit = 100,
  }) async {
    if (page < 1) {
      _logger.error('Page number must be >= 1');
      return [];
    }

    if (limit < 1 || limit > 1000) {
      _logger.error('Limit must be between 1 and 1000');
      return [];
    }

    try {
      final token = await TraktAuthService(_database).getAccessToken();
      if (token == null) {
        _logger.warning('No access token available for watch history');
        return [];
      }

      final response = await _dio.get(
        '/sync/history',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final history = (response.data as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      _logger.debug('Retrieved ${history.length} watch history items');
      return history;
    } catch (e) {
      _logger.error('Error fetching watch history', e);
      if (e is DioException) {
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return [];
    }
  }

  /// Get playback progress from Trakt
  /// Returns items that are currently being watched (progress > 0% and < 100%)
  Future<List<Map<String, dynamic>>> getPlaybackProgress({
    String type = 'all', // 'movies', 'episodes', or 'all'
  }) async {
    if (!['movies', 'episodes', 'all'].contains(type)) {
      _logger.error('Type must be one of: movies, episodes, all');
      return [];
    }

    try {
      final token = await TraktAuthService(_database).getAccessToken();
      if (token == null) {
        _logger.warning('No access token available for playback progress');
        return [];
      }

      final endpoint = type == 'all'
          ? '/sync/playback'
          : '/sync/playback/$type';

      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final progress = (response.data as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      _logger.debug('Retrieved ${progress.length} playback progress items');
      return progress;
    } catch (e) {
      _logger.error('Error fetching playback progress', e);
      if (e is DioException) {
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return [];
    }
  }
}