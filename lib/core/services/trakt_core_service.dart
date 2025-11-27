import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/trakt_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';

/// Core Trakt service with advanced rate limiting, deduplication, and error handling
/// Based on NuvioStreaming's implementation
class TraktCoreService {
  static TraktCoreService? _instance;
  static TraktCoreService get instance {
    _instance ??= TraktCoreService._();
    return _instance!;
  }

  TraktCoreService._() {
    _initialize();
  }

  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;

  late final Dio _dio;
  AppDatabase? _database;

  // Authentication state
  String? _accessToken;
  String? _refreshToken;
  int _tokenExpiry = 0;
  bool _isInitialized = false;

  // Rate limiting - Optimized for real-time scrobbling
  int _lastApiCall = 0;
  static const int MIN_API_INTERVAL = 500; // Reduced to 500ms for faster updates
  final List<Future<void> Function()> _requestQueue = [];
  bool _isProcessingQueue = false;

  // Track items that have been successfully scrobbled to prevent duplicates
  final Set<String> _scrobbledItems = {};
  static const int SCROBBLE_EXPIRY_MS = 46 * 60 * 1000; // 46 minutes (based on Trakt's expiry window)
  final Map<String, int> _scrobbledTimestamps = {};

  // Track currently watching sessions to avoid duplicate starts
  final Set<String> _currentlyWatching = {};
  final Map<String, int> _lastSyncTimes = {};
  static const int SYNC_DEBOUNCE_MS = 5000; // Reduced from 20000ms to 5000ms for real-time updates

  // Debounce for stop calls - Optimized for responsiveness
  final Map<String, int> _lastStopCalls = {};
  static const int STOP_DEBOUNCE_MS = 1000; // Reduced from 3000ms to 1000ms for better responsiveness

  // Default completion threshold (overridden by user settings)
  static const int DEFAULT_COMPLETION_THRESHOLD = 80; // 80%
  int _completionThreshold = DEFAULT_COMPLETION_THRESHOLD;

  // App lifecycle management
  StreamSubscription? _appLifecycleSubscription;

  Future<void> _initialize() async {
    _setupDio();
    await _loadCompletionThreshold();

    // Set up app lifecycle cleanup to reduce memory pressure
    _appLifecycleSubscription = null; // Will be set up in service locator

    _logger.info('[TraktCoreService] Initialized with rate limiting and deduplication');
  }

  void _setupDio() {
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

    // Add interceptors for logging and error handling
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (kDebugMode) {
          _logger.debug('[TraktCoreService] ${options.method} ${options.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          _logger.debug('[TraktCoreService] Error: ${error.response?.statusCode} ${error.message}');
        }
        handler.next(error);
      },
    ));
  }

  /// Set up database reference (called by service locator)
  void setDatabase(AppDatabase database) {
    // Only set database if not already set (singleton pattern)
    if (_database == null) {
      _database = database;
      _logger.debug('[TraktCoreService] Database initialized');
    } else {
      _logger.debug('[TraktCoreService] Database already initialized, skipping');
    }
  }

  /// Load user-configured completion threshold from database
  Future<void> _loadCompletionThreshold() async {
    if (_database == null) {
      _logger.error('[TraktCoreService] Database not initialized, using default completion threshold');
      _completionThreshold = _config.defaultTraktCompletionThreshold;
      return;
    }

    try {
      final thresholdStr = await _database!.getSettingValue('trakt_completion_threshold');
      if (thresholdStr != null) {
        final threshold = int.tryParse(thresholdStr);
        if (threshold != null && threshold >= 50 && threshold <= 100) {
          _completionThreshold = threshold;
          _logger.info('[TraktCoreService] Loaded user completion threshold: ${_completionThreshold}%');
        }
      } else {
        // Use default from configuration if no user setting
        _completionThreshold = _config.defaultTraktCompletionThreshold;
        _logger.info('[TraktCoreService] Using default completion threshold: ${_completionThreshold}%');
      }
    } catch (error) {
      _logger.error('[TraktCoreService] Error loading completion threshold, using default', error);
      _completionThreshold = _config.defaultTraktCompletionThreshold;
    }
  }

  /// Set completion threshold
  Future<void> setCompletionThreshold(int threshold) async {
    if (threshold >= 50 && threshold <= 100) {
      _completionThreshold = threshold;
      if (_database != null) {
        await _database!.setSetting('trakt_completion_threshold', threshold.toString());
      }
      _logger.info('[TraktCoreService] Updated completion threshold to: ${_completionThreshold}%');
    }
  }

  /// Get current completion threshold
  int get completionThreshold => _completionThreshold;

  /// Clean up old tracking data to prevent memory leaks
  void _cleanupOldData() {
    final now = DateTime.now().millisecondsSinceEpoch;
    int cleanupCount = 0;

    // Remove stop calls older than the debounce window
    _lastStopCalls.removeWhere((key, timestamp) {
      if (now - timestamp > STOP_DEBOUNCE_MS) {
        cleanupCount++;
        return true;
      }
      return false;
    });

    // Also clean up old scrobbled timestamps
    _scrobbledTimestamps.removeWhere((key, timestamp) {
      if (now - timestamp > SCROBBLE_EXPIRY_MS) {
        _scrobbledItems.remove(key);
        cleanupCount++;
        return true;
      }
      return false;
    });

    // Clean up old sync times that haven't been updated in a while
    _lastSyncTimes.removeWhere((key, timestamp) {
      if (now - timestamp > 24 * 60 * 60 * 1000) { // 24 hours
        cleanupCount++;
        return true;
      }
      return false;
    });

    if (cleanupCount > 0 && kDebugMode) {
      _logger.debug('[TraktCoreService] Cleaned up $cleanupCount old tracking entries');
    }
  }

  /// Initialize authentication state
  Future<void> initializeAuth() async {
    if (_isInitialized) return;
    if (_database == null) {
      _logger.error('[TraktCoreService] Cannot initialize auth: database not set');
      return;
    }

    try {
      final auth = await _database!.getTraktAuth();
      if (auth != null) {
        _accessToken = auth.accessToken;
        _refreshToken = auth.refreshToken;
        _tokenExpiry = auth.expiresAt.millisecondsSinceEpoch;
      }
      _isInitialized = true;
      _logger.info('[TraktCoreService] Auth initialized, authenticated: ${_accessToken != null}');
    } catch (error) {
      _logger.error('[TraktCoreService] Auth initialization failed', error);
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    await initializeAuth();

    if (_accessToken == null) return false;

    // Check if token is expired and needs refresh
    if (_tokenExpiry != 0 && _tokenExpiry < DateTime.now().millisecondsSinceEpoch && _refreshToken != null) {
      try {
        await _refreshAccessToken();
        return _accessToken != null;
      } catch (error) {
        _logger.error('[TraktCoreService] Token refresh failed during auth check', error);
        return false;
      }
    }

    return true;
  }

  /// Get current access token, refreshing if necessary
  Future<String?> getAccessToken() async {
    await initializeAuth();

    if (_accessToken == null) return null;

    // Check if token is expired or about to expire (within 5 minutes)
    if (_tokenExpiry != 0 && _tokenExpiry < DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch && _refreshToken != null) {
      try {
        await _refreshAccessToken();
      } catch (error) {
        _logger.error('[TraktCoreService] Token refresh failed', error);
        return null;
      }
    }

    return _accessToken;
  }

  /// Refresh access token using refresh token
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw Exception('No refresh token available');
    }

    try {
      final response = await _dio.post(
        '/oauth/token',
        data: {
          'refresh_token': _refreshToken,
          'client_id': _config.traktClientId,
          'client_secret': _config.traktClientSecret,
          'redirect_uri': _config.traktRedirectUri,
          'grant_type': 'refresh_token',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;
      final expiresIn = data['expires_in'] as int;

      await _saveTokens(accessToken, newRefreshToken, expiresIn);
      _logger.info('[TraktCoreService] Access token refreshed successfully');
    } catch (error) {
      _logger.error('[TraktCoreService] Failed to refresh token', error);
      await _logout(); // Clear tokens if refresh fails
      throw error;
    }
  }

  /// Save authentication tokens
  Future<void> _saveTokens(String accessToken, String refreshToken, int expiresIn) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;

    if (_database != null) {
      await _database!.upsertTraktAuth(
        TraktAuthCompanion.insert(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresIn: expiresIn,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        ),
      );
      _logger.debug('[TraktCoreService] Tokens saved successfully');
    } else {
      _logger.error('[TraktCoreService] Cannot save tokens: database not initialized');
    }
  }

  /// Log out user by clearing tokens
  Future<void> logout() async {
    await _logout();
  }

  Future<void> _logout() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = 0;

    if (_database != null) {
      try {
        await _database!.deleteTraktAuth();
        _logger.info('[TraktCoreService] User logged out successfully');
      } catch (error) {
        _logger.error('[TraktCoreService] Error during logout', error);
      }
    }
  }

  /// Make authenticated API request with rate limiting and error handling
  Future<T> apiRequest<T>(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? data,
    int retryCount = 0,
  }) async {
    // Rate limiting: ensure minimum interval between API calls
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeSinceLastCall = now - _lastApiCall;
    if (timeSinceLastCall < MIN_API_INTERVAL) {
      final delay = MIN_API_INTERVAL - timeSinceLastCall;
      await Future.delayed(Duration(milliseconds: delay));
    }
    _lastApiCall = DateTime.now().millisecondsSinceEpoch;

    // Ensure we have a valid token
    final token = await getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final headers = {
      'Authorization': 'Bearer $token',
    };

    final options = Options(
      method: method,
      headers: headers,
    );

    try {
      final response = await _dio.request(
        endpoint,
        data: data,
        options: options,
      );

      // Handle "No Content" responses (204/205) which have no JSON body
      if (response.statusCode == 204 || response.statusCode == 205) {
        return null as T;
      }

      // Some endpoints may also return empty body with 200. Attempt safe parse.
      try {
        final responseData = response.data;
        if (responseData is T) {
          return responseData;
        }
        // Try to parse as JSON if it's a string
        if (responseData is String && responseData.isNotEmpty) {
          final parsed = json.decode(responseData);
          return parsed as T;
        }
        return responseData as T;
      } catch (parseError) {
        // If body is empty, return null instead of throwing
        _logger.warning('[TraktCoreService] Empty JSON body for $endpoint, returning null');
        return null as T;
      }
    } on DioException catch (error) {
      // Handle rate limiting with exponential backoff
      if (error.response?.statusCode == 429) {
        const maxRetries = 3;
        if (retryCount < maxRetries) {
          final retryAfter = error.response?.headers.value('Retry-After');
          final delay = retryAfter != null
              ? int.parse(retryAfter) * 1000
              : math.min(1000 * math.pow(2, retryCount), 10000); // Exponential backoff, max 10s

          _logger.warning('[TraktCoreService] Rate limited (429), retrying in ${delay}ms (attempt ${retryCount + 1}/$maxRetries)');

          await Future.delayed(Duration(milliseconds: delay.toInt()));
          return apiRequest<T>(endpoint, method: method, data: data, retryCount: retryCount + 1);
        } else {
          _logger.error('[TraktCoreService] Rate limited (429), max retries exceeded for $endpoint');
          throw Exception('API request failed: 429 (Rate Limited)');
        }
      }

      // Handle 409 conflicts gracefully (already watched/scrobbled)
      if (error.response?.statusCode == 409) {
        final errorText = error.response?.data?.toString() ?? '';
        _logger.warning('[TraktCoreService] Content already scrobbled (409) for $endpoint: $errorText');

        // Parse the error response to get expiry info
        try {
          final errorData = error.response?.data is String
              ? json.decode(error.response!.data as String)
              : error.response?.data;

          if (errorData is Map && errorData['watched_at'] != null && errorData['expires_at'] != null) {
            _logger.info('[TraktCoreService] Item was already watched at ${errorData['watched_at']}, expires at ${errorData['expires_at']}');

            // If this is a scrobble endpoint, mark the item as already scrobbled
            if (endpoint.contains('/scrobble/') && data != null) {
              final contentKey = _getContentKeyFromPayload(data);
              if (contentKey != null) {
                _scrobbledItems.add(contentKey);
                _scrobbledTimestamps[contentKey] = DateTime.now().millisecondsSinceEpoch;
                _logger.info('[TraktCoreService] Marked content as already scrobbled: $contentKey');
              }
            }

            // Return a success-like response for 409 conflicts
            return {
              'id': 0,
              'action': endpoint.contains('/stop') ? 'scrobble' : 'start',
              'progress': data?['progress'] ?? 0,
              'alreadyScrobbled': true,
            } as T;
          }
        } catch (parseError) {
          _logger.warning('[TraktCoreService] Could not parse 409 error response: $parseError');
        }

        // Return a graceful response even if we can't parse the error
        return {
          'id': 0,
          'action': 'conflict',
          'progress': 0,
          'alreadyScrobbled': true,
        } as T;
      }

      // Handle 404 errors more gracefully
      if (error.response?.statusCode == 404) {
        _logger.warning('[TraktCoreService] Content not found in Trakt database (404) for $endpoint');
        _logger.warning('[TraktCoreService] This might indicate invalid IMDb ID or content not in Trakt database');

        // Return a graceful response for 404s instead of throwing
        return {
          'id': 0,
          'action': 'not_found',
          'progress': data?['progress'] ?? 0,
          'error': 'Content not found in Trakt database',
        } as T;
      }

      // Enhanced error logging for debugging
      _logger.error('[TraktCoreService] API Error ${error.response?.statusCode} for $endpoint:', {
        'status': error.response?.statusCode,
        'statusText': error.response?.statusMessage,
        'errorText': error.response?.data,
        'requestBody': data != null ? json.encode(data) : 'No body',
        'headers': error.response?.headers.map,
      });

      throw Exception('API request failed: ${error.response?.statusCode ?? 'Unknown error'}');
    }
  }

  /// Helper method to extract content key from scrobble payload for deduplication
  String? _getContentKeyFromPayload(Map<String, dynamic> payload) {
    try {
      if (payload['movie'] != null && payload['movie']['ids'] != null && payload['movie']['ids']['imdb'] != null) {
        return 'movie:${payload['movie']['ids']['imdb']}';
      } else if (payload['episode'] != null && payload['show'] != null && payload['show']['ids'] != null && payload['show']['ids']['imdb'] != null) {
        final season = payload['episode']['season'];
        final episode = payload['episode']['number'];
        return 'episode:${payload['show']['ids']['imdb']}:S$season E$episode';
      }
    } catch (error) {
      _logger.warning('[TraktCoreService] Could not extract content key from payload: $error');
    }
    return null;
  }

  /// Check if content was recently scrobbled to prevent duplicates
  bool _isRecentlyScrobbled(String contentKey) {
    // Clean up expired entries
    _cleanupOldData();

    return _scrobbledItems.contains(contentKey);
  }

  /// Generate unique key for content being watched
  String _getWatchingKey(TraktContentData contentData) {
    return contentData.getContentKey();
  }

  /// Queue request for rate-limited processing
  Future<T> queueRequest<T>(Future<T> Function() requestFn) {
    final completer = Completer<T>();

    _requestQueue.add(() async {
      try {
        final result = await requestFn();
        completer.complete(result);
      } catch (error) {
        completer.completeError(error);
      }
    });

    // Start processing if not already running
    _processQueue();

    return completer.future;
  }

  /// Process the request queue with proper rate limiting
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _requestQueue.isEmpty) {
      return;
    }

    _isProcessingQueue = true;

    while (_requestQueue.isNotEmpty) {
      final request = _requestQueue.removeAt(0);
      try {
        await request();
      } catch (error) {
        _logger.error('[TraktCoreService] Queue request failed', error);
      }

      // Wait minimum interval before next request
      if (_requestQueue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: MIN_API_INTERVAL));
      }
    }

    _isProcessingQueue = false;
  }

  /// Handle app state changes to reduce memory pressure
  void handleAppStateChange(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Clear tracking maps to reduce memory pressure when app goes to background
      _scrobbledItems.clear();
      _scrobbledTimestamps.clear();
      _currentlyWatching.clear();
      _lastSyncTimes.clear();
      _lastStopCalls.clear();
      _requestQueue.clear();
      _isProcessingQueue = false;

      _logger.debug('[TraktCoreService] Cleared tracking data for memory optimization');
    }
  }

  /// Get the user's profile information
  Future<TraktUser> getUserProfile() async {
    final result = await apiRequest<Map<String, dynamic>>('/users/me?extended=full');
    return TraktUser.fromJson(result);
  }

  /// Get the user's watched movies
  Future<List<TraktWatchedItem>> getWatchedMovies() async {
    final result = await apiRequest<List<dynamic>>('/sync/watched/movies');
    return result.map((item) => TraktWatchedItem.fromJson(item)).toList();
  }

  /// Get the user's watched shows
  Future<List<TraktWatchedItem>> getWatchedShows() async {
    final result = await apiRequest<List<dynamic>>('/sync/watched/shows');
    return result.map((item) => TraktWatchedItem.fromJson(item)).toList();
  }

  /// Get the user's watchlist movies with images
  Future<List<TraktWatchlistItemWithImages>> getWatchlistMoviesWithImages() async {
    final result = await apiRequest<List<dynamic>>('/sync/watchlist/movies?extended=images');
    return result.map((item) => TraktWatchlistItemWithImages.fromJson(item)).toList();
  }

  /// Get the user's watchlist shows with images
  Future<List<TraktWatchlistItemWithImages>> getWatchlistShowsWithImages() async {
    final result = await apiRequest<List<dynamic>>('/sync/watchlist/shows?extended=images');
    return result.map((item) => TraktWatchlistItemWithImages.fromJson(item)).toList();
  }

  /// Get the user's collection movies with images
  Future<List<TraktCollectionItemWithImages>> getCollectionMoviesWithImages() async {
    final result = await apiRequest<List<dynamic>>('/sync/collection/movies?extended=images');
    return result.map((item) => TraktCollectionItemWithImages.fromJson(item)).toList();
  }

  /// Get the user's collection shows with images
  Future<List<TraktCollectionItemWithImages>> getCollectionShowsWithImages() async {
    final result = await apiRequest<List<dynamic>>('/sync/collection/shows?extended=images');
    return result.map((item) => TraktCollectionItemWithImages.fromJson(item)).toList();
  }

  /// Get the user's ratings with images
  Future<List<TraktRatingItemWithImages>> getRatingsWithImages({String? type}) async {
    final endpoint = type != null ? '/sync/ratings/$type?extended=images' : '/sync/ratings?extended=images';
    final result = await apiRequest<List<dynamic>>(endpoint);
    return result.map((item) => TraktRatingItemWithImages.fromJson(item)).toList();
  }

  /// Get playback progress with images
  Future<List<TraktPlaybackItem>> getPlaybackProgressWithImages({String? type}) async {
    final endpoint = type != null ? '/sync/playback/$type?extended=images' : '/sync/playback?extended=images';
    final result = await apiRequest<List<dynamic>>(endpoint);
    return result.map((item) => TraktPlaybackItem.fromJson(item)).toList();
  }

  /// Get Trakt ID from IMDb ID with multiple fallback approaches
  Future<int?> getTraktIdFromImdbId(String imdbId, String type) async {
    try {
      // Clean IMDb ID - remove 'tt' prefix if present
      final cleanImdbId = imdbId.startsWith('tt') ? imdbId.substring(2) : imdbId;

      _logger.info('[TraktCoreService] Searching Trakt for $type with IMDb ID: $cleanImdbId');

      // Try multiple search approaches
      final searchUrls = [
        '/search/$type?id_type=imdb&id=$cleanImdbId',
        '/search/$type?query=$cleanImdbId&id_type=imdb',
        // Also try with the full tt-prefixed ID in case the API accepts it
        '/search/$type?id_type=imdb&id=tt$cleanImdbId',
      ];

      for (final searchUrl in searchUrls) {
        try {
          _logger.info('[TraktCoreService] Trying search URL: $searchUrl');

          final data = await apiRequest<List<dynamic>>(searchUrl);
          _logger.debug('[TraktCoreService] Search response data: $data');

          if (data.isNotEmpty) {
            final traktId = data[0][type]?['ids']?['trakt'];
            if (traktId != null) {
              _logger.info('[TraktCoreService] Found Trakt ID: $traktId for IMDb ID: $cleanImdbId');
              return traktId as int;
            }
          }
        } catch (urlError) {
          _logger.warning('[TraktCoreService] URL attempt failed: $urlError');
          continue;
        }
      }

      _logger.warning('[TraktCoreService] No results found for IMDb ID: $cleanImdbId after trying all search methods');
      return null;
    } catch (error) {
      _logger.error('[TraktCoreService] Failed to get Trakt ID from IMDb ID', error);
      return null;
    }
  }

  /// Get Trakt ID from TMDB ID (fallback method)
  Future<int?> getTraktIdFromTmdbId(int tmdbId, String type) async {
    try {
      _logger.info('[TraktCoreService] Searching Trakt for $type with TMDB ID: $tmdbId');

      final data = await apiRequest<List<dynamic>>('/search/$type?id_type=tmdb&id=$tmdbId');
      _logger.debug('[TraktCoreService] TMDB search response: $data');

      if (data.isNotEmpty) {
        final traktId = data[0][type]?['ids']?['trakt'];
        if (traktId != null) {
          _logger.info('[TraktCoreService] Found Trakt ID via TMDB: $traktId for TMDB ID: $tmdbId');
          return traktId as int;
        }
      }

      _logger.warning('[TraktCoreService] No TMDB results found for TMDB ID: $tmdbId');
      return null;
    } catch (error) {
      _logger.error('[TraktCoreService] Failed to get Trakt ID from TMDB ID', error);
      return null;
    }
  }

  /// Clean up resources
  void dispose() {
    _appLifecycleSubscription?.cancel();
    _cleanupOldData();
    _requestQueue.clear();
    _isProcessingQueue = false;
  }
}