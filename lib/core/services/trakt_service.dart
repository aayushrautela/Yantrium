import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';

/// Service for interacting with Trakt API
class TraktService {
  late final Dio _dio;
  late final String _clientId;
  late final String _clientSecret;
  late final String _redirectUri;
  late final AppDatabase _database;

  static const String _baseUrl = 'https://api.trakt.tv';
  static const String _authUrl = 'https://trakt.tv/oauth/authorize';
  static const String _tokenUrl = '$_baseUrl/oauth/token';

  TraktService(AppDatabase database) : _database = database {
    _clientId = dotenv.env['TRAKT_CLIENT_ID'] ?? '';
    _clientSecret = dotenv.env['TRAKT_CLIENT_SECRET'] ?? '';
    _redirectUri = dotenv.env['TRAKT_REDIRECT_URI'] ?? 'yantrium://auth/trakt';

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': _clientId,
      },
    ));
  }

  /// Check if Trakt is configured (has client ID and secret)
  bool get isConfigured => _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  /// Get the authorization URL for OAuth login
  String getAuthorizationUrl() {
    final params = Uri(queryParameters: {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
    });
    return '$_authUrl?${params.query}';
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final auth = await _database.getTraktAuth();
    if (auth == null) return false;

    // Check if token is expired
    if (auth.expiresAt.isBefore(DateTime.now())) {
      // Try to refresh token
      return await refreshToken();
    }

    return true;
  }

  /// Get current access token, refreshing if necessary
  Future<String?> getAccessToken() async {
    final auth = await _database.getTraktAuth();
    if (auth == null) return null;

    // Check if token is expired or about to expire (within 5 minutes)
    if (auth.expiresAt.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      final refreshed = await refreshToken();
      if (!refreshed) return null;
      // Get the updated auth after refresh
      final updatedAuth = await _database.getTraktAuth();
      return updatedAuth?.accessToken;
    }

    return auth.accessToken;
  }

  /// Exchange authorization code for access token
  Future<bool> exchangeCodeForToken(String code) async {
    try {
      // Ensure redirect_uri matches exactly what was used in authorization URL
      // and what's registered in Trakt application settings
      final requestData = {
        'code': code,
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'redirect_uri': _redirectUri,
        'grant_type': 'authorization_code',
      };
      
      debugPrint('Exchanging code for token...');
      debugPrint('Redirect URI: $_redirectUri');
      debugPrint('Client ID: ${_clientId.isNotEmpty ? "${_clientId.substring(0, 8)}..." : "EMPTY"}');
      debugPrint('Client Secret: ${_clientSecret.isNotEmpty ? "***" : "EMPTY"}');
      
      final response = await _dio.post(
        _tokenUrl,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'trakt-api-version': '2',
            'trakt-api-key': _clientId,
          },
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;
      final expiresIn = data['expires_in'] as int;

      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      // Fetch user info to get username and slug
      final userInfo = await _getUserInfo(accessToken);

      await _database.upsertTraktAuth(
        TraktAuthCompanion.insert(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresIn: expiresIn,
          createdAt: DateTime.now(),
          expiresAt: expiresAt,
          username: Value(userInfo?['username']),
          slug: Value(userInfo?['slug']),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('Error exchanging code for token: $e');
      if (e is DioException) {
        debugPrint('Dio error status: ${e.response?.statusCode}');
        debugPrint('Dio error response: ${e.response?.data}');
        debugPrint('Dio error headers: ${e.response?.headers}');
        
        // Check if it's a client authentication error
        if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
          final errorData = e.response?.data;
          if (errorData is Map) {
            debugPrint('Trakt API error: ${errorData['error']}');
            debugPrint('Trakt API error description: ${errorData['error_description']}');
          }
        }
      }
      return false;
    }
  }

  /// Refresh the access token using refresh token
  Future<bool> refreshToken() async {
    try {
      final auth = await _database.getTraktAuth();
      if (auth == null || auth.refreshToken.isEmpty) return false;

      final response = await _dio.post(
        _tokenUrl,
        data: {
          'refresh_token': auth.refreshToken,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri': _redirectUri,
          'grant_type': 'refresh_token',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'trakt-api-version': '2',
            'trakt-api-key': _clientId,
          },
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;
      final expiresIn = data['expires_in'] as int;

      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      await _database.upsertTraktAuth(
        TraktAuthCompanion.insert(
          accessToken: accessToken,
          refreshToken: newRefreshToken,
          expiresIn: expiresIn,
          createdAt: DateTime.now(),
          expiresAt: expiresAt,
          username: Value(auth.username),
          slug: Value(auth.slug),
        ),
      );

      return true;
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      if (e is DioException) {
        debugPrint('Dio error response: ${e.response?.data}');
      }
      // If refresh fails, user needs to re-authenticate
      await logout();
      return false;
    }
  }

  /// Get user information from Trakt
  Future<Map<String, String>?> _getUserInfo(String accessToken) async {
    try {
      final response = await _dio.get(
        '/users/settings',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      final user = response.data as Map<String, dynamic>;
      final userData = user['user'] as Map<String, dynamic>?;
      
      if (userData != null) {
        final ids = userData['ids'] as Map<String, dynamic>?;
        return {
          'username': userData['username'] as String? ?? '',
          'slug': ids?['slug'] as String? ?? '',
        };
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching user info: $e');
      if (e is DioException) {
        debugPrint('Dio error response: ${e.response?.data}');
      }
      return null;
    }
  }

  /// Get current authenticated user information
  Future<Map<String, String>?> getCurrentUser() async {
    final auth = await _database.getTraktAuth();
    if (auth == null) return null;

    if (auth.username != null && auth.slug != null) {
      return {
        'username': auth.username!,
        'slug': auth.slug!,
      };
    }

    // If username/slug not in DB, fetch from API
    final token = await getAccessToken();
    if (token == null) return null;

    return await _getUserInfo(token);
  }

  /// Logout user (remove tokens)
  Future<void> logout() async {
    await _database.deleteTraktAuth();
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
    try {
      final token = await getAccessToken();
      if (token == null) return false;

      final data = <String, dynamic>{
        'progress': progress,
      };

      if (type == 'movie') {
        data['movie'] = {'ids': {'imdb': imdbId}};
        if (title != null) {
          data['movie']['title'] = title;
        }
      } else if (type == 'episode') {
        data['episode'] = {
          'ids': {'imdb': imdbId},
        };
        if (season != null) data['episode']['season'] = season;
        if (episode != null) data['episode']['number'] = episode;
        if (title != null) {
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

      return true;
    } catch (e) {
      debugPrint('Error scrobbling: $e');
      if (e is DioException) {
        debugPrint('Dio error response: ${e.response?.data}');
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
    try {
      final token = await getAccessToken();
      if (token == null) return false;

      final data = <String, dynamic>{};

      if (type == 'movie') {
        data['movie'] = {'ids': {'imdb': imdbId}};
        if (title != null) {
          data['movie']['title'] = title;
        }
      } else if (type == 'episode') {
        data['episode'] = {
          'ids': {'imdb': imdbId},
        };
        if (season != null) data['episode']['season'] = season;
        if (episode != null) data['episode']['number'] = episode;
        if (title != null) {
          data['episode']['title'] = title;
        }
      }

      if (message != null) {
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

      return true;
    } catch (e) {
      debugPrint('Error checking in: $e');
      if (e is DioException) {
        debugPrint('Dio error response: ${e.response?.data}');
      }
      return false;
    }
  }

  /// Get user's watchlist
  Future<List<Map<String, dynamic>>> getWatchlist({
    String? username,
    String type = 'movies', // 'movies', 'shows', 'seasons', 'episodes'
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) return [];

      final user = username ?? (await getCurrentUser())?['username'];
      if (user == null) return [];

      final response = await _dio.get(
        '/users/$user/watchlist/$type',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final watchlist = (response.data as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      return watchlist;
    } catch (e) {
      debugPrint('Error fetching watchlist: $e');
      if (e is DioException) {
        debugPrint('Dio error response: ${e.response?.data}');
      }
      return [];
    }
  }

  /// Add item to watchlist
  Future<bool> addToWatchlist({
    required String type, // 'movie' or 'show'
    required String imdbId,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) return false;

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

      return true;
    } catch (e) {
      debugPrint('Error adding to watchlist: $e');
      if (e is DioException) {
        debugPrint('Dio error response: ${e.response?.data}');
      }
      return false;
    }
  }

  /// Remove item from watchlist
  Future<bool> removeFromWatchlist({
    required String type, // 'movie' or 'show'
    required String imdbId,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) return false;

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

      return true;
    } catch (e) {
      debugPrint('Error removing from watchlist: $e');
      if (e is DioException) {
        debugPrint('Dio error response: ${e.response?.data}');
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
    try {
      final token = await getAccessToken();
      if (token == null) return [];

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

      return history;
    } catch (e) {
      debugPrint('Error fetching watch history: $e');
      if (e is DioException) {
        debugPrint('Dio error response: ${e.response?.data}');
      }
      return [];
    }
  }

  /// Get playback progress from Trakt
  /// Returns items that are currently being watched (progress > 0% and < 100%)
  Future<List<Map<String, dynamic>>> getPlaybackProgress({
    String type = 'all', // 'movies', 'episodes', or 'all'
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) return [];

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

      return progress;
    } catch (e) {
      debugPrint('Error fetching playback progress: $e');
      if (e is DioException) {
        debugPrint('Dio error response: ${e.response?.data}');
      }
      return [];
    }
  }
}


