import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized configuration service for API keys and settings
class ConfigurationService {
  static ConfigurationService? _instance;
  static ConfigurationService get instance {
    _instance ??= ConfigurationService._();
    return _instance!;
  }

  ConfigurationService._();

  // API Keys
  String get traktClientId => dotenv.env['TRAKT_CLIENT_ID'] ?? '';
  String get traktClientSecret => dotenv.env['TRAKT_CLIENT_SECRET'] ?? '';
  String get traktRedirectUri => dotenv.env['TRAKT_REDIRECT_URI'] ?? 'yantrium://auth/trakt';
  String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';

  // TMDB Configuration
  String get tmdbBaseUrl => dotenv.env['TMDB_BASE_URL'] ?? 'https://api.themoviedb.org/3';
  String get tmdbImageBaseUrl => dotenv.env['TMDB_IMAGE_BASE_URL'] ?? 'https://image.tmdb.org/t/p';

  // Cache Configuration
  Duration get tmdbCacheTtl => const Duration(minutes: 5);
  int get maxCacheSize => 100;

  // Trakt API Configuration
  String get traktBaseUrl => 'https://api.trakt.tv';
  String get traktAuthUrl => 'https://trakt.tv/oauth/authorize';
  String get traktTokenUrl => '$traktBaseUrl/oauth/token';
  String get traktApiVersion => '2';

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
