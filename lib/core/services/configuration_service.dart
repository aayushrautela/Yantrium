import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized configuration service for API keys and settings
class ConfigurationService {
  static ConfigurationService? _instance;
  static ConfigurationService get instance {
    _instance ??= ConfigurationService._();
    return _instance!;
  }

  ConfigurationService._();

  // API Keys - Priority: dart-define (--dart-define) > .env file > empty
  String get traktClientId {
    // Check compile-time constants first (from --dart-define)
    final envKey = String.fromEnvironment('TRAKT_CLIENT_ID');
    if (envKey.isNotEmpty) return envKey;
    
    // Then check .env file
    if (dotenv.isInitialized) {
      final dotEnvKey = dotenv.env['TRAKT_CLIENT_ID'];
      if (dotEnvKey != null && dotEnvKey.isNotEmpty) return dotEnvKey;
    }
    
    return '';
  }

  String get traktClientSecret {
    final envKey = String.fromEnvironment('TRAKT_CLIENT_SECRET');
    if (envKey.isNotEmpty) return envKey;
    
    if (dotenv.isInitialized) {
      final dotEnvKey = dotenv.env['TRAKT_CLIENT_SECRET'];
      if (dotEnvKey != null && dotEnvKey.isNotEmpty) return dotEnvKey;
    }
    
    return '';
  }

  String get traktRedirectUri {
    final envKey = String.fromEnvironment('TRAKT_REDIRECT_URI');
    if (envKey.isNotEmpty) return envKey;
    
    if (dotenv.isInitialized) {
      final dotEnvKey = dotenv.env['TRAKT_REDIRECT_URI'];
      if (dotEnvKey != null && dotEnvKey.isNotEmpty) return dotEnvKey;
    }
    
    return 'yantrium://auth/trakt';
  }

  String get tmdbApiKey {
    final envKey = String.fromEnvironment('TMDB_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    
    if (dotenv.isInitialized) {
      final dotEnvKey = dotenv.env['TMDB_API_KEY'];
      if (dotEnvKey != null && dotEnvKey.isNotEmpty) return dotEnvKey;
    }
    
    return '';
  }

  // TMDB Configuration
  String get tmdbBaseUrl {
    final envKey = String.fromEnvironment('TMDB_BASE_URL');
    if (envKey.isNotEmpty) return envKey;
    
    if (dotenv.isInitialized) {
      final dotEnvKey = dotenv.env['TMDB_BASE_URL'];
      if (dotEnvKey != null && dotEnvKey.isNotEmpty) return dotEnvKey;
    }
    
    return 'https://api.themoviedb.org/3';
  }

  String get tmdbImageBaseUrl {
    final envKey = String.fromEnvironment('TMDB_IMAGE_BASE_URL');
    if (envKey.isNotEmpty) return envKey;
    
    if (dotenv.isInitialized) {
      final dotEnvKey = dotenv.env['TMDB_IMAGE_BASE_URL'];
      if (dotEnvKey != null && dotEnvKey.isNotEmpty) return dotEnvKey;
    }
    
    return 'https://image.tmdb.org/t/p';
  }

  // Cache Configuration
  Duration get tmdbCacheTtl => const Duration(minutes: 5);
  int get maxCacheSize => 100;

  // Trakt API Configuration
  String get traktBaseUrl => 'https://api.trakt.tv';
  String get traktAuthUrl => 'https://trakt.tv/oauth/authorize';
  String get traktTokenUrl => '$traktBaseUrl/oauth/token';
  String get traktDeviceCodeUrl => '$traktBaseUrl/oauth/device/code';
  String get traktDeviceTokenUrl => '$traktBaseUrl/oauth/device/token';
  String get traktApiVersion => '2';

  // Trakt Scrobbling Configuration
  int get defaultTraktCompletionThreshold {
    // Allow override via environment variable, default to 80%
    final envValue = String.fromEnvironment('TRAKT_COMPLETION_THRESHOLD');
    if (envValue.isNotEmpty) {
      final parsed = int.tryParse(envValue);
      if (parsed != null && parsed >= 50 && parsed <= 100) {
        return parsed;
      }
    }
    return 80; // Default 80% completion threshold
  }

  // HTTP Configuration
  Duration get httpTimeout => const Duration(seconds: 30);
  int get maxRetries => 3;

  // Validation
  bool get isTraktConfigured => traktClientId.isNotEmpty && traktClientSecret.isNotEmpty;
  bool get isTmdbConfigured => tmdbApiKey.isNotEmpty;

  /// Validate configuration and throw if required services are not configured
  void validateConfiguration() {
    if (!isTraktConfigured) {
      throw ConfigurationException('Trakt API not configured. Please set TRAKT_CLIENT_ID and TRAKT_CLIENT_SECRET in environment variables.');
    }
    if (!isTmdbConfigured) {
      throw ConfigurationException('TMDB API not configured. Please set TMDB_API_KEY in environment variables.');
    }
  }
}

/// Exception thrown when configuration is invalid
class ConfigurationException implements Exception {
  final String message;
  ConfigurationException(this.message);

  @override
  String toString() => 'ConfigurationException: $message';
}

