import 'package:dio/dio.dart';
import '../database/app_database.dart';
import 'configuration_service.dart';
import 'logging_service.dart';
import 'trakt_auth_service.dart';

/// Service for Trakt scrobbling operations (watching progress tracking)
class TraktScrobbleService {
  final AppDatabase _database;
  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;

  late final Dio _dio;

  TraktScrobbleService(this._database) {
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

  /// Scrobble watching progress
  Future<bool> scrobble({
    required String type, // 'movie' or 'episode'
    required String imdbId,
    required double progress, // 0.0 to 100.0
    String? title,
    int? season,
    int? episode,
  }) async {
    if (imdbId.trim().isEmpty) {
      _logger.error('IMDB ID is required for scrobbling');
      return false;
    }

    if (progress < 0.0 || progress > 100.0) {
      _logger.error('Progress must be between 0.0 and 100.0');
      return false;
    }

    if (type != 'movie' && type != 'episode') {
      _logger.error('Type must be either "movie" or "episode"');
      return false;
    }

    try {
      final token = await TraktAuthService(_database).getAccessToken();
      if (token == null) {
        _logger.warning('No access token available for scrobbling');
        return false;
      }

      final data = <String, dynamic>{
        'progress': progress,
      };

      if (type == 'movie') {
        data['movie'] = {'ids': {'imdb': imdbId}};
        if (title != null && title.isNotEmpty) {
          data['movie']['title'] = title;
        }
      } else if (type == 'episode') {
        data['episode'] = {
          'ids': {'imdb': imdbId},
        };
        if (season != null) data['episode']['season'] = season;
        if (episode != null) data['episode']['number'] = episode;
        if (title != null && title.isNotEmpty) {
          data['episode']['title'] = title;
        }
      }

      await _dio.post(
        '/scrobble/stop',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      _logger.debug('Successfully scrobbled $type progress: ${progress.toStringAsFixed(1)}%');
      return true;
    } catch (e) {
      _logger.error('Error scrobbling', e);
      if (e is DioException) {
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return false;
    }
  }

  /// Check in (mark as watching now)
  Future<bool> checkin({
    required String type, // 'movie' or 'episode'
    required String imdbId,
    String? title,
    int? season,
    int? episode,
    String? message,
  }) async {
    if (imdbId.trim().isEmpty) {
      _logger.error('IMDB ID is required for checkin');
      return false;
    }

    if (type != 'movie' && type != 'episode') {
      _logger.error('Type must be either "movie" or "episode"');
      return false;
    }

    try {
      final token = await TraktAuthService(_database).getAccessToken();
      if (token == null) {
        _logger.warning('No access token available for checkin');
        return false;
      }

      final data = <String, dynamic>{};

      if (type == 'movie') {
        data['movie'] = {'ids': {'imdb': imdbId}};
        if (title != null && title.isNotEmpty) {
          data['movie']['title'] = title;
        }
      } else if (type == 'episode') {
        data['episode'] = {
          'ids': {'imdb': imdbId},
        };
        if (season != null) data['episode']['season'] = season;
        if (episode != null) data['episode']['number'] = episode;
        if (title != null && title.isNotEmpty) {
          data['episode']['title'] = title;
        }
      }

      if (message != null && message.isNotEmpty) {
        data['message'] = message;
      }

      await _dio.post(
        '/checkin',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      _logger.debug('Successfully checked in $type');
      return true;
    } catch (e) {
      _logger.error('Error checking in', e);
      if (e is DioException) {
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return false;
    }
  }
}





