import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../models/trakt_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';

/// Service for Trakt authentication operations
class TraktAuthService {
  final AppDatabase _database;
  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;

  late final Dio _dio;

  TraktAuthService(this._database) {
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

  /// Check if Trakt is configured (has client ID and secret)
  bool get isConfigured => _config.isTraktConfigured;

  /// Get the authorization URL for OAuth login
  String getAuthorizationUrl() {
    final params = Uri(queryParameters: {
      'response_type': 'code',
      'client_id': _config.traktClientId,
      'redirect_uri': _config.traktRedirectUri,
    });
    return '${_config.traktAuthUrl}?${params.query}';
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final auth = await _database.getTraktAuth();
    if (auth == null) {
      _logger.debug('No Trakt auth found in database');
      return false;
    }

    // Check if token is expired
    if (auth.expiresAt.isBefore(DateTime.now())) {
      _logger.debug('Trakt token expired, attempting refresh');
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
      _logger.debug('Trakt token expiring soon, refreshing');
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
    if (code.trim().isEmpty) {
      _logger.error('Authorization code is empty');
      return false;
    }

    try {
      _logger.debug('Exchanging authorization code for access token');

      final requestData = {
        'code': code,
        'client_id': _config.traktClientId,
        'client_secret': _config.traktClientSecret,
        'redirect_uri': _config.traktRedirectUri,
        'grant_type': 'authorization_code',
      };

      final response = await _dio.post(
        _config.traktTokenUrl,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'trakt-api-version': _config.traktApiVersion,
            'trakt-api-key': _config.traktClientId,
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

      _logger.info('Successfully exchanged code for token');
      return true;
    } catch (e) {
      _logger.error('Error exchanging code for token', e);
      if (e is DioException) {
        _logger.debug('Dio error status: ${e.response?.statusCode}');
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return false;
    }
  }

  /// Refresh the access token using refresh token
  Future<bool> refreshToken() async {
    try {
      final auth = await _database.getTraktAuth();
      if (auth == null || auth.refreshToken.isEmpty) {
        _logger.debug('No refresh token available');
        return false;
      }

      _logger.debug('Refreshing Trakt access token');

      final response = await _dio.post(
        _config.traktTokenUrl,
        data: {
          'refresh_token': auth.refreshToken,
          'client_id': _config.traktClientId,
          'client_secret': _config.traktClientSecret,
          'redirect_uri': _config.traktRedirectUri,
          'grant_type': 'refresh_token',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'trakt-api-version': _config.traktApiVersion,
            'trakt-api-key': _config.traktClientId,
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

      _logger.info('Successfully refreshed Trakt token');
      return true;
    } catch (e) {
      _logger.error('Error refreshing token', e);
      if (e is DioException) {
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      // If refresh fails, user needs to re-authenticate
      await logout();
      return false;
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
    _logger.debug('Logging out Trakt user');
    await _database.deleteTraktAuth();
  }

  /// Get user information from Trakt API
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
      _logger.error('Error fetching user info', e);
      if (e is DioException) {
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return null;
    }
  }
}


