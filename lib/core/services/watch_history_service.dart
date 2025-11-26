import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import 'service_locator.dart';
import '../../features/library/models/catalog_item.dart';
import '../../features/library/logic/library_repository.dart';

/// Service for managing watch history from Trakt
class WatchHistoryService {
  final AppDatabase _database;
  late final LibraryRepository _libraryRepository;

  WatchHistoryService(this._database) {
    _libraryRepository = LibraryRepository(_database);
  }

  /// Sync watch history from Trakt API and store in local database
  /// Returns the number of items synced
  Future<int> syncWatchHistory({bool forceRefresh = false}) async {
    try {
      // Check if user is authenticated
      if (!await ServiceLocator.instance.traktAuthService.isAuthenticated()) {
        debugPrint('User not authenticated, cannot sync watch history');
        return 0;
      }

      // Get playback progress (items currently being watched)
      final progressItems = await ServiceLocator.instance.traktWatchlistService.getPlaybackProgress();
      
      int syncedCount = 0;
      final now = DateTime.now();

      for (final item in progressItems) {
        try {
          final traktId = _extractTraktId(item);
          final type = item['type'] as String? ?? 'movie';
          final progress = item['progress'] as double? ?? 0.0;
          final pausedAt = item['paused_at'] != null 
              ? DateTime.parse(item['paused_at'] as String)
              : null;
          final watchedAt = item['watched_at'] != null
              ? DateTime.parse(item['watched_at'] as String)
              : now;

          // Extract movie or episode data
          final movie = item['movie'] as Map<String, dynamic>?;
          final episode = item['episode'] as Map<String, dynamic>?;
          final show = item['show'] as Map<String, dynamic>?;

          String title;
          String? imdbId;
          String? tmdbId;
          int? seasonNumber;
          int? episodeNumber;
          int? runtime;

          if (type == 'movie' && movie != null) {
            title = movie['title'] as String? ?? 'Unknown';
            final ids = movie['ids'] as Map<String, dynamic>?;
            imdbId = ids?['imdb'] as String?;
            tmdbId = ids?['tmdb']?.toString();
            runtime = movie['runtime'] as int?;
          } else if (type == 'episode' && episode != null && show != null) {
            title = episode['title'] as String? ?? show['title'] as String? ?? 'Unknown';
            final episodeIds = episode['ids'] as Map<String, dynamic>?;
            final showIds = show['ids'] as Map<String, dynamic>?;
            imdbId = showIds?['imdb'] as String?;
            tmdbId = showIds?['tmdb']?.toString();
            seasonNumber = episode['season'] as int?;
            episodeNumber = episode['number'] as int?;
            runtime = episode['runtime'] as int?;
          } else {
            continue; // Skip invalid items
          }

          // Upsert watch history
          await _database.upsertWatchHistory(
            WatchHistoryCompanion.insert(
              traktId: traktId,
              type: type,
              title: title,
              imdbId: Value(imdbId),
              tmdbId: Value(tmdbId),
              seasonNumber: Value(seasonNumber),
              episodeNumber: Value(episodeNumber),
              progress: progress,
              watchedAt: watchedAt,
              pausedAt: Value(pausedAt),
              runtime: Value(runtime),
              lastSyncedAt: now,
              createdAt: now,
            ),
          );

          syncedCount++;
        } catch (e) {
          debugPrint('Error processing watch history item: $e');
          debugPrint('Item data: $item');
        }
      }

      debugPrint('Synced $syncedCount watch history items from Trakt');
      return syncedCount;
    } catch (e) {
      debugPrint('Error syncing watch history: $e');
      return 0;
    }
  }

  /// Extract Trakt ID from API response
  String _extractTraktId(Map<String, dynamic> item) {
    final type = item['type'] as String? ?? 'movie';
    
    if (type == 'movie') {
      final movie = item['movie'] as Map<String, dynamic>?;
      final ids = movie?['ids'] as Map<String, dynamic>?;
      return ids?['trakt']?.toString() ?? 
             ids?['tmdb']?.toString() ?? 
             ids?['imdb']?.toString() ?? 
             'unknown';
    } else if (type == 'episode') {
      final episode = item['episode'] as Map<String, dynamic>?;
      final show = item['show'] as Map<String, dynamic>?;
      final episodeIds = episode?['ids'] as Map<String, dynamic>?;
      final showIds = show?['ids'] as Map<String, dynamic>?;
      final showTraktId = showIds?['trakt']?.toString() ?? '0';
      final season = episode?['season']?.toString() ?? '0';
      final number = episode?['number']?.toString() ?? '0';
      return '$showTraktId:$season:$number';
    }
    
    return 'unknown';
  }

  /// Get continue watching items (0% to 80% progress)
  /// For series, only returns the latest episode (assumes previous ones are watched)
  Future<List<WatchHistoryData>> getContinueWatching() async {
    final allItems = await _database.getContinueWatching(
      minProgress: 0.0,
      maxProgress: 80.0,
    );
    
    // Separate movies and episodes
    final movies = allItems.where((item) => item.type == 'movie').toList();
    final episodes = allItems.where((item) => item.type == 'episode').toList();
    
    // For episodes, group by TMDB ID (show ID) and only keep the latest episode per show
    final Map<String, WatchHistoryData> latestEpisodes = {};
    final List<WatchHistoryData> episodesWithoutTmdbId = [];
    
    for (final episode in episodes) {
      if (episode.tmdbId == null || episode.tmdbId!.isEmpty) {
        // If no TMDB ID, keep it separately (can't group)
        episodesWithoutTmdbId.add(episode);
        continue;
      }
      
      final showId = episode.tmdbId!;
      final existing = latestEpisodes[showId];
      
      // Keep the episode with the highest season/episode number
      if (existing == null) {
        latestEpisodes[showId] = episode;
      } else {
        // Compare season and episode numbers
        final existingSeason = existing.seasonNumber ?? 0;
        final existingEpisode = existing.episodeNumber ?? 0;
        final currentSeason = episode.seasonNumber ?? 0;
        final currentEpisode = episode.episodeNumber ?? 0;
        
        if (currentSeason > existingSeason || 
            (currentSeason == existingSeason && currentEpisode > existingEpisode)) {
          latestEpisodes[showId] = episode;
        }
      }
    }
    
    // Combine movies with filtered episodes (grouped by show) and episodes without TMDB ID
    return [...movies, ...latestEpisodes.values, ...episodesWithoutTmdbId];
  }

  /// Convert watch history item to CatalogItem for display
  /// Uses TMDB to fetch metadata including posters
  Future<CatalogItem?> watchHistoryToCatalogItem(WatchHistoryData history) async {
    try {
      // Use TMDB to fetch metadata
      String? contentId;
      String type = history.type;
      
      // For episodes, we want to show the series poster, so use the show's TMDB ID
      // For movies, use the movie's TMDB ID
      if (history.tmdbId != null && history.tmdbId!.isNotEmpty) {
        contentId = 'tmdb:${history.tmdbId}';
      } else if (history.imdbId != null && history.imdbId!.isNotEmpty) {
        // If we only have IMDb ID, try to get TMDB ID first
        final tmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(history.imdbId!);
        if (tmdbId != null) {
          contentId = 'tmdb:$tmdbId';
        } else {
          contentId = history.imdbId;
        }
      } else {
        contentId = history.traktId;
      }
      
      // Fetch metadata from TMDB
      Map<String, dynamic>? enrichedData;
      if (history.tmdbId != null && history.tmdbId!.isNotEmpty) {
        // We have TMDB ID, fetch metadata directly
        final tmdbId = int.tryParse(history.tmdbId!);
        if (tmdbId != null) {
          if (type == 'movie') {
            final metadata = await ServiceLocator.instance.tmdbMetadataService.getMovieMetadata(tmdbId);
            if (metadata != null) {
              enrichedData = ServiceLocator.instance.tmdbEnrichmentService.convertMovieToCatalogItem(metadata, contentId ?? history.traktId);
            }
          } else if (type == 'episode') {
            // For episodes, fetch the series metadata (not episode metadata)
            final metadata = await ServiceLocator.instance.tmdbMetadataService.getTvMetadata(tmdbId);
            if (metadata != null) {
              enrichedData = ServiceLocator.instance.tmdbEnrichmentService.convertTvToCatalogItem(metadata, contentId ?? history.traktId);
            }
          }
        }
      } else if (history.imdbId != null && history.imdbId!.isNotEmpty) {
        // Try to get TMDB ID from IMDb ID
        final tmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(history.imdbId!);
        if (tmdbId != null) {
          if (type == 'movie') {
            final metadata = await ServiceLocator.instance.tmdbMetadataService.getMovieMetadata(tmdbId);
            if (metadata != null) {
              enrichedData = ServiceLocator.instance.tmdbEnrichmentService.convertMovieToCatalogItem(metadata, contentId ?? history.traktId);
            }
          } else if (type == 'episode') {
            final metadata = await ServiceLocator.instance.tmdbMetadataService.getTvMetadata(tmdbId);
            if (metadata != null) {
              enrichedData = ServiceLocator.instance.tmdbEnrichmentService.convertTvToCatalogItem(metadata, contentId ?? history.traktId);
            }
          }
        }
      }
      
      // If we got enriched data from TMDB, use it
      if (enrichedData != null) {
        return CatalogItem.fromJson(enrichedData);
      }
      
      // Fallback: create a basic CatalogItem from watch history
      return CatalogItem(
        id: contentId ?? history.traktId,
        type: type,
        name: history.title,
        description: null,
        poster: null,
        background: null,
        logo: null,
        releaseInfo: null,
        genres: null,
        imdbRating: null,
        runtime: history.runtime != null 
            ? '${(history.runtime! / 60).round()} min'
            : null,
      );
    } catch (e) {
      debugPrint('Error converting watch history to catalog item: $e');
      return null;
    }
  }

  /// Update watch progress for an item
  Future<void> updateProgress(String traktId, double progress, {DateTime? pausedAt}) async {
    await _database.updateWatchProgress(traktId, progress, pausedAt: pausedAt);
  }

  /// Get watch progress for an item by IMDb ID
  Future<double?> getProgressByImdbId(String imdbId) async {
    final history = await _database.getWatchHistoryByImdbId(imdbId);
    return history?.progress;
  }

  /// Save local watch progress (works without Trakt authentication)
  /// This is used as a fallback when Trakt is not logged in
  Future<void> saveLocalProgress({
    required String contentId, // Can be tmdb:123, imdb:tt123, or any identifier
    required String type, // 'movie' or 'episode'
    required String title,
    required double progress, // 0.0 to 100.0
    String? imdbId,
    String? tmdbId,
    int? seasonNumber,
    int? episodeNumber,
    int? runtime,
    DateTime? pausedAt,
  }) async {
    try {
      // Generate a local ID if we don't have a Trakt ID
      // Use tmdbId or imdbId or contentId as the identifier
      String localId;
      if (tmdbId != null && tmdbId.isNotEmpty) {
        localId = type == 'episode' && seasonNumber != null && episodeNumber != null
            ? 'local:$tmdbId:$seasonNumber:$episodeNumber'
            : 'local:$tmdbId';
      } else if (imdbId != null && imdbId.isNotEmpty) {
        localId = type == 'episode' && seasonNumber != null && episodeNumber != null
            ? 'local:$imdbId:$seasonNumber:$episodeNumber'
            : 'local:$imdbId';
      } else {
        // Fallback to contentId
        localId = 'local:$contentId';
      }

      final now = DateTime.now();
      
      // Upsert watch history locally
      await _database.upsertWatchHistory(
        WatchHistoryCompanion.insert(
          traktId: localId,
          type: type,
          title: title,
          imdbId: Value(imdbId),
          tmdbId: Value(tmdbId),
          seasonNumber: Value(seasonNumber),
          episodeNumber: Value(episodeNumber),
          progress: progress,
          watchedAt: now,
          pausedAt: Value(pausedAt ?? now),
          runtime: Value(runtime),
          lastSyncedAt: now, // Mark as local-only (not synced from Trakt)
          createdAt: now,
        ),
      );

      debugPrint('Saved local watch progress: $title ($progress%)');
    } catch (e) {
      debugPrint('Error saving local watch progress: $e');
    }
  }
}

