import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../models/trakt_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';
import 'trakt_core_service.dart';

/// Device authentication response model
class DeviceCodeResponse {
  final String deviceCode;
  final String userCode;
  final String verificationUrl;
  final int interval; // Polling interval in seconds
  final int expiresIn; // Expiration time in seconds

  DeviceCodeResponse({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUrl,
    required this.interval,
    required this.expiresIn,
  });

  factory DeviceCodeResponse.fromJson(Map<String, dynamic> json) {
    return DeviceCodeResponse(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUrl: json['verification_url'] as String,
      interval: json['interval'] as int,
      expiresIn: json['expires_in'] as int,
    );
  }
}

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

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await _coreService.isAuthenticated();
  }

  /// Get current access token, refreshing if necessary
  Future<String?> getAccessToken() async {
    return await _coreService.getAccessToken();
  }

  /// Generate device codes for device authentication
  Future<DeviceCodeResponse?> generateDeviceCode() async {
    try {
      _logger.debug('Generating device code for authentication');

      final requestData = {
        'client_id': _config.traktClientId,
      };

      final response = await Dio().post(
        _config.traktDeviceCodeUrl,
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
      final deviceCodeResponse = DeviceCodeResponse.fromJson(data);

      _logger.info('Successfully generated device code');
      return deviceCodeResponse;
    } catch (e) {
      _logger.error('Error generating device code', e);
      if (e is DioException) {
        _logger.debug('Dio error status: ${e.response?.statusCode}');
        _logger.debug('Dio error response: ${e.response?.data}');
      }
      return null;
    }
  }

  /// Poll for access token using device code
  /// Returns true if successful, false if failed, null if still pending
  Future<bool?> pollForAccessToken(String deviceCode, int intervalSeconds) async {
    try {
      final requestData = {
        'code': deviceCode,
        'client_id': _config.traktClientId,
        'client_secret': _config.traktClientSecret,
      };

      final response = await Dio().post(
        _config.traktDeviceTokenUrl,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'trakt-api-version': _config.traktApiVersion,
            'trakt-api-key': _config.traktClientId,
          },
        ),
      );

      // Success - save tokens
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

      // Reload auth state in core service so it picks up the new tokens immediately
      await _coreService.reloadAuth();

      _logger.info('Successfully obtained access token via device authentication');
      return true;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      
      // Handle different status codes according to Trakt API docs
      switch (statusCode) {
        case 200:
          // Should not reach here as this is handled above, but just in case
          return true;
        case 400:
          // Pending - waiting for user to authorize
          _logger.debug('Device authentication pending - waiting for user authorization');
          return null;
        case 404:
          // Not Found - invalid device_code
          _logger.error('Invalid device code');
          return false;
        case 409:
          // Already Used - user already approved this code
          _logger.error('Device code already used');
          return false;
        case 410:
          // Expired - the tokens have expired
          _logger.error('Device code expired');
          return false;
        case 418:
          // Denied - user explicitly denied this code
          _logger.error('User denied device authentication');
          return false;
        case 429:
          // Slow Down - polling too quickly
          _logger.warning('Polling too quickly - should slow down');
          return null;
        default:
          _logger.error('Error polling for access token', e);
          _logger.debug('Dio error status: $statusCode');
          _logger.debug('Dio error response: ${e.response?.data}');
          return false;
      }
    } catch (e) {
      _logger.error('Unexpected error polling for access token', e);
      return false;
    }
  }

  /// Refresh the access token using refresh token
  Future<bool> refreshToken() async {
    await _coreService.initializeAuth(); // This will handle token refresh
    return await _coreService.isAuthenticated();
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





