import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../models/trakt_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';
import 'trakt_core_service.dart';

/// Service for Trakt authentication operations
class TraktAuthService {
  final AppDatabase _database;
  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;
  final TraktCoreService _coreService = TraktCoreService.instance;

  TraktAuthService(this._database) {
    // Initialize core service with database
    _coreService.setDatabase(_database);
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
    return await _coreService.isAuthenticated();
  }

  /// Get current access token, refreshing if necessary
  Future<String?> getAccessToken() async {
    return await _coreService.getAccessToken();
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

      // Use Dio directly for token exchange since core service requires auth
      final response = await Dio().post(
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
    return await _coreService.initializeAuth(); // This will handle token refresh
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
    await _coreService.logout();
  }

  /// Get user information from Trakt API
  Future<Map<String, String>?> _getUserInfo(String accessToken) async {
    try {
      // Use Dio directly since this is for initial setup
      final response = await Dio().get(
        '${_config.traktBaseUrl}/users/settings',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
            'trakt-api-version': _config.traktApiVersion,
            'trakt-api-key': _config.traktClientId,
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





