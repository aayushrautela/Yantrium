import '../database/app_database.dart';
import 'configuration_service.dart';
import 'logging_service.dart';
import 'trakt_auth_service.dart';
import 'trakt_scrobble_service.dart';
import 'trakt_watchlist_service.dart';
import 'tmdb_metadata_service.dart';
import 'tmdb_search_service.dart';
import 'tmdb_enrichment_service.dart';
import 'watch_history_service.dart';
import 'library_service.dart';

/// Service Locator for dependency injection
class ServiceLocator {
  static ServiceLocator? _instance;
  static ServiceLocator get instance {
    _instance ??= ServiceLocator._();
    return _instance!;
  }

  ServiceLocator._();

  AppDatabase? _database;
  bool _isInitialized = false;

  // Lazy-loaded services
  TraktAuthService? _traktAuthService;
  TraktScrobbleService? _traktScrobbleService;
  TraktWatchlistService? _traktWatchlistService;
  TmdbMetadataService? _tmdbMetadataService;
  TmdbSearchService? _tmdbSearchService;
  TmdbEnrichmentService? _tmdbEnrichmentService;
  WatchHistoryService? _watchHistoryService;
  LibraryService? _libraryService;

  /// Initialize the service locator with required dependencies
  Future<void> initialize(AppDatabase database) async {
    if (_isInitialized) return;

    _database = database;

    // Check if APIs are configured, but don't throw - allow degraded mode
    final configService = ConfigurationService.instance;
    final isTmdbConfigured = configService.isTmdbConfigured;
    final isTraktConfigured = configService.isTraktConfigured;

    if (!isTmdbConfigured) {
      LoggingService.instance.warning('TMDB API not configured - limited functionality');
    }
    if (!isTraktConfigured) {
      LoggingService.instance.warning('Trakt API not configured - authentication disabled');
    }

    // Initialize services (lazy loading will happen on first access)
    _isInitialized = true;

    LoggingService.instance.info('ServiceLocator initialized');
  }

  /// Get the database instance
  AppDatabase get database {
    if (_database == null) {
      throw StateError('ServiceLocator not initialized. Call initialize() first.');
    }
    return _database!;
  }

  /// Get Trakt authentication service
  TraktAuthService get traktAuthService {
    _traktAuthService ??= TraktAuthService(database);
    return _traktAuthService!;
  }

  /// Get Trakt scrobble service
  TraktScrobbleService get traktScrobbleService {
    _traktScrobbleService ??= TraktScrobbleService(database);
    return _traktScrobbleService!;
  }

  /// Get Trakt watchlist service
  TraktWatchlistService get traktWatchlistService {
    _traktWatchlistService ??= TraktWatchlistService(database);
    return _traktWatchlistService!;
  }

  /// Get TMDB metadata service
  TmdbMetadataService get tmdbMetadataService {
    _tmdbMetadataService ??= TmdbMetadataService();
    return _tmdbMetadataService!;
  }

  /// Get TMDB search service
  TmdbSearchService get tmdbSearchService {
    _tmdbSearchService ??= TmdbSearchService();
    return _tmdbSearchService!;
  }

  /// Get TMDB enrichment service
  TmdbEnrichmentService get tmdbEnrichmentService {
    _tmdbEnrichmentService ??= TmdbEnrichmentService();
    return _tmdbEnrichmentService!;
  }

  /// Get watch history service
  WatchHistoryService get watchHistoryService {
    _watchHistoryService ??= WatchHistoryService(database);
    return _watchHistoryService!;
  }

  /// Get library service
  LibraryService get libraryService {
    _libraryService ??= LibraryService(database);
    return _libraryService!;
  }

  /// Dispose all services for graceful shutdown
  Future<void> dispose() async {
    if (!_isInitialized) return;

    // Dispose services in reverse order of initialization
    try {
      // Dispose library service first as it depends on others
      if (_libraryService != null) {
        // Note: LibraryService doesn't have a dispose method yet
        _libraryService = null;
      }

      // Dispose watch history service
      if (_watchHistoryService != null) {
        // Note: WatchHistoryService doesn't have a dispose method yet
        _watchHistoryService = null;
      }

      // Dispose TMDB services
      _tmdbEnrichmentService = null;
      _tmdbSearchService = null;
      _tmdbMetadataService = null;

      // Dispose Trakt services
      _traktWatchlistService = null;
      _traktScrobbleService = null;
      _traktAuthService = null;

      // Close database last
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      _isInitialized = false;

      LoggingService.instance.info('ServiceLocator disposed gracefully');
    } catch (e) {
      LoggingService.instance.error('Error during ServiceLocator disposal', e);
      // Continue with disposal even if some services fail
      _isInitialized = false;
    }
  }

  /// Reset all services (useful for testing)
  void reset() {
    _traktAuthService = null;
    _traktScrobbleService = null;
    _traktWatchlistService = null;
    _tmdbMetadataService = null;
    _tmdbSearchService = null;
    _tmdbEnrichmentService = null;
    _watchHistoryService = null;
    _libraryService = null;
    _isInitialized = false;
  }
}