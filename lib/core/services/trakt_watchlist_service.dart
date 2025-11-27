import '../database/app_database.dart';
import '../models/trakt_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';
import 'trakt_core_service.dart';

/// Service for Trakt watchlist and collection operations
/// Based on NuvioStreaming's implementation
class TraktWatchlistService {
  final AppDatabase _database;
  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;
  final TraktCoreService _coreService = TraktCoreService.instance;

  TraktWatchlistService(this._database) {
    // Initialize core service with database
    _coreService.setDatabase(_database);
  }

  /// Get user's watchlist movies with images
  Future<List<TraktWatchlistItemWithImages>> getWatchlistMoviesWithImages() async {
    try {
      return await _coreService.getWatchlistMoviesWithImages();
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error fetching watchlist movies', error);
      return [];
    }
  }

  /// Get user's watchlist shows with images
  Future<List<TraktWatchlistItemWithImages>> getWatchlistShowsWithImages() async {
    try {
      return await _coreService.getWatchlistShowsWithImages();
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error fetching watchlist shows', error);
      return [];
    }
  }

  /// Legacy method for backward compatibility
  Future<List<TraktWatchlistItem>> getWatchlist({
    String? username,
    String type = 'movies',
  }) async {
    if (!['movies', 'shows', 'seasons', 'episodes'].contains(type)) {
      _logger.error('Invalid watchlist type: $type');
      return [];
    }

    try {
      // Use the new methods for movies and shows
      if (type == 'movies') {
        final items = await getWatchlistMoviesWithImages();
        return items.map((item) => TraktWatchlistItem(
          type: item.type,
          movie: item.movie,
          show: item.show,
          listedAt: item.listedAt,
          rank: null, // Not available in new format
        )).toList();
      } else if (type == 'shows') {
        final items = await getWatchlistShowsWithImages();
        return items.map((item) => TraktWatchlistItem(
          type: item.type,
          movie: item.movie,
          show: item.show,
          listedAt: item.listedAt,
          rank: null, // Not available in new format
        )).toList();
      }

      // For seasons and episodes, fall back to basic API
      final result = await _coreService.apiRequest<List<dynamic>>('/sync/watchlist/$type');
      return result.map((item) => TraktWatchlistItem.fromJson(item)).toList();
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error fetching legacy watchlist', error);
      return [];
    }
  }

  /// Add item to watchlist
  Future<bool> addToWatchlist({
    required String type,
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
      // Ensure IMDb ID includes the 'tt' prefix
      final imdbIdWithPrefix = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';

      final payload = type == 'movie'
          ? {'movies': [{'ids': {'imdb': imdbIdWithPrefix}}]}
          : {'shows': [{'ids': {'imdb': imdbIdWithPrefix}}]};

      await _coreService.apiRequest('/sync/watchlist', method: 'POST', data: payload);
      _logger.debug('Successfully added $type to watchlist: $imdbId');
      return true;
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error adding to watchlist', error);
      return false;
    }
  }

  /// Remove item from watchlist
  Future<bool> removeFromWatchlist({
    required String type,
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
      // Ensure IMDb ID includes the 'tt' prefix
      final imdbIdWithPrefix = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';

      final payload = type == 'movie'
          ? {'movies': [{'ids': {'imdb': imdbIdWithPrefix}}]}
          : {'shows': [{'ids': {'imdb': imdbIdWithPrefix}}]};

      await _coreService.apiRequest('/sync/watchlist/remove', method: 'POST', data: payload);
      _logger.debug('Successfully removed $type from watchlist: $imdbId');
      return true;
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error removing from watchlist', error);
      return false;
    }
  }

  /// Check if content is in Trakt watchlist
  Future<bool> isInWatchlist(String imdbId, String type) async {
    if (imdbId.trim().isEmpty || (type != 'movie' && type != 'show')) {
      return false;
    }

    try {
      final items = type == 'movie'
          ? await getWatchlistMoviesWithImages()
          : await getWatchlistShowsWithImages();

      // Ensure IMDb ID includes the 'tt' prefix for comparison
      final imdbIdWithPrefix = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';

      return items.any((item) {
        final itemImdbId = type == 'movie'
            ? item.movie?.ids?.imdb
            : item.show?.ids?.imdb;
        return itemImdbId == imdbIdWithPrefix;
      });
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error checking watchlist status', error);
      return false;
    }
  }

  /// COLLECTION METHODS

  /// Get user's collection movies with images
  Future<List<TraktCollectionItemWithImages>> getCollectionMoviesWithImages() async {
    try {
      return await _coreService.getCollectionMoviesWithImages();
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error fetching collection movies', error);
      return [];
    }
  }

  /// Get user's collection shows with images
  Future<List<TraktCollectionItemWithImages>> getCollectionShowsWithImages() async {
    try {
      return await _coreService.getCollectionShowsWithImages();
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error fetching collection shows', error);
      return [];
    }
  }

  /// Add content to Trakt collection
  Future<bool> addToCollection({
    required String type,
    required String imdbId,
  }) async {
    if (imdbId.trim().isEmpty) {
      _logger.error('IMDB ID is required for adding to collection');
      return false;
    }

    if (type != 'movie' && type != 'show') {
      _logger.error('Type must be either "movie" or "show"');
      return false;
    }

    try {
      // Ensure IMDb ID includes the 'tt' prefix
      final imdbIdWithPrefix = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';

      final payload = type == 'movie'
          ? {'movies': [{'ids': {'imdb': imdbIdWithPrefix}}]}
          : {'shows': [{'ids': {'imdb': imdbIdWithPrefix}}]};

      await _coreService.apiRequest('/sync/collection', method: 'POST', data: payload);
      _logger.debug('Successfully added $type to collection: $imdbId');
      return true;
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error adding to collection', error);
      return false;
    }
  }

  /// Remove content from Trakt collection
  Future<bool> removeFromCollection({
    required String type,
    required String imdbId,
  }) async {
    if (imdbId.trim().isEmpty) {
      _logger.error('IMDB ID is required for removing from collection');
      return false;
    }

    if (type != 'movie' && type != 'show') {
      _logger.error('Type must be either "movie" or "show"');
      return false;
    }

    try {
      // Ensure IMDb ID includes the 'tt' prefix
      final imdbIdWithPrefix = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';

      final payload = type == 'movie'
          ? {'movies': [{'ids': {'imdb': imdbIdWithPrefix}}]}
          : {'shows': [{'ids': {'imdb': imdbIdWithPrefix}}]};

      await _coreService.apiRequest('/sync/collection/remove', method: 'POST', data: payload);
      _logger.debug('Successfully removed $type from collection: $imdbId');
      return true;
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error removing from collection', error);
      return false;
    }
  }

  /// Check if content is in Trakt collection
  Future<bool> isInCollection(String imdbId, String type) async {
    if (imdbId.trim().isEmpty || (type != 'movie' && type != 'show')) {
      return false;
    }

    try {
      final items = type == 'movie'
          ? await getCollectionMoviesWithImages()
          : await getCollectionShowsWithImages();

      // Ensure IMDb ID includes the 'tt' prefix for comparison
      final imdbIdWithPrefix = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';

      return items.any((item) {
        final itemImdbId = type == 'movie'
            ? item.movie?.ids?.imdb
            : item.show?.ids?.imdb;
        return itemImdbId == imdbIdWithPrefix;
      });
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error checking collection status', error);
      return false;
    }
  }

  /// Get playback progress from Trakt (legacy method for compatibility)
  Future<List<Map<String, dynamic>>> getPlaybackProgress({
    String type = 'all',
  }) async {
    if (!['movies', 'episodes', 'all'].contains(type)) {
      _logger.error('Type must be one of: movies, episodes, all');
      return [];
    }

    try {
      final items = await _coreService.getPlaybackProgressWithImages(type: type == 'all' ? null : type);
      return items.map((item) => {
        'progress': item.progress,
        'paused_at': item.pausedAt.toIso8601String(),
        'type': item.type,
        if (item.movie != null) 'movie': item.movie!.toJson(),
        if (item.episode != null) 'episode': item.episode!.toJson(),
        if (item.show != null) 'show': item.show!.toJson(),
      }).toList();
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error fetching playback progress', error);
      return [];
    }
  }

  /// Get watched items from Trakt (legacy method for compatibility)
  Future<List<Map<String, dynamic>>> getWatchedItems({
    String type = 'all',
  }) async {
    if (!['movies', 'episodes', 'all'].contains(type)) {
      _logger.error('Type must be one of: movies, episodes, all');
      return [];
    }

    try {
      final items = type == 'all'
          ? await _coreService.getWatchedMovies() + await _coreService.getWatchedShows()
          : type == 'movies'
              ? await _coreService.getWatchedMovies()
              : await _coreService.getWatchedShows();

      return items.map((item) => item.toJson()).toList();
    } catch (error) {
      _logger.error('[TraktWatchlistService] Error fetching watched items', error);
      return [];
    }
  }

}

