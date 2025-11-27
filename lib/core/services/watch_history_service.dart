import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../models/trakt_models.dart';
import 'service_locator.dart';
import '../../features/library/models/catalog_item.dart';
import '../../features/library/logic/library_repository.dart';

/// Service for managing watch history from Trakt
class WatchHistoryService {
  final AppDatabase _database;
  late final LibraryRepository _libraryRepository;

  static const String _lastSyncKey = 'last_trakt_sync';

  WatchHistoryService(this._database) {
    _libraryRepository = LibraryRepository(_database);
  }

  /// Get the last sync timestamp from database
  Future<DateTime?> getLastSyncTimestamp() async {
    final timestampStr = await _database.getSettingValue(_lastSyncKey);
    if (timestampStr != null) {
      try {
        return DateTime.parse(timestampStr);
      } catch (e) {
        debugPrint('Error parsing last sync timestamp: $e');
        return null;
      }
    }
    return null;
  }

  /// Set the last sync timestamp in database
  Future<void> setLastSyncTimestamp(DateTime timestamp) async {
    await _database.setSetting(_lastSyncKey, timestamp.toIso8601String());
  }

  /// Sync watch history from Trakt API and store in local database
  /// Returns the number of items synced
  /// Uses incremental syncing by default - only fetches items since last sync
  /// Set forceRefresh=true to do a full sync of all history
  Future<int> syncWatchHistory({bool forceRefresh = false}) async {
    try {
      // Check if user is authenticated
      if (!await ServiceLocator.instance.traktAuthService.isAuthenticated()) {
        debugPrint('User not authenticated, cannot sync watch history');
        return 0;
      }

      final now = DateTime.now();
      int syncedCount = 0;

      // Get playback progress (currently watching items) - always fetch these
      final progressItems = await ServiceLocator.instance.traktWatchlistService.getPlaybackProgress();

      // Determine sync strategy
      final lastSyncTimestamp = await getLastSyncTimestamp();
      final shouldDoIncrementalSync = !forceRefresh && lastSyncTimestamp != null;

      List<TraktHistoryItem> allHistoryItems = [];

      if (shouldDoIncrementalSync) {
        // Incremental sync: fetch all items since last sync with pagination
        debugPrint('Performing incremental sync since ${lastSyncTimestamp!.toIso8601String()}');
        
        int page = 1;
        const int limit = 100; // Trakt API limit per page
        bool hasMore = true;
        
        while (hasMore) {
          final pageItems = await ServiceLocator.instance.traktScrobbleService.getHistory(
            startAt: lastSyncTimestamp,
            endAt: now,
            page: page,
            limit: limit,
          );
          
          allHistoryItems.addAll(pageItems);
          debugPrint('Fetched page $page: ${pageItems.length} items (total: ${allHistoryItems.length})');
          
          // If we got fewer items than the limit, we've reached the end
          hasMore = pageItems.length >= limit;
          page++;
        }
        
        debugPrint('Fetched ${allHistoryItems.length} total history items since last sync');
      } else {
        // Full sync: fetch ALL history (no date filter) with pagination
        debugPrint('Performing full sync of all watch history');
        
        int page = 1;
        const int limit = 100; // Trakt API limit per page
        bool hasMore = true;
        
        while (hasMore) {
          final pageItems = await ServiceLocator.instance.traktScrobbleService.getHistory(
            // No startAt/endAt - get all history
            page: page,
            limit: limit,
          );
          
          allHistoryItems.addAll(pageItems);
          debugPrint('Fetched page $page: ${pageItems.length} items (total: ${allHistoryItems.length})');
          
          // If we got fewer items than the limit, we've reached the end
          hasMore = pageItems.length >= limit;
          page++;
        }
        
        debugPrint('Fetched ${allHistoryItems.length} total history items (full sync)');
      }

      // Process playback progress items (0-100% progress)
      int progressItemsSynced = 0;
      int progressItemsUpdated = 0;
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

          // Check if item already exists before upserting
          final existingItem = await _database.getWatchHistoryByTraktId(traktId);
          final isNew = existingItem == null;

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

          if (isNew) {
            progressItemsSynced++;
            syncedCount++;
          } else {
            progressItemsUpdated++;
          }
        } catch (e) {
          debugPrint('Error processing watch history item: $e');
          debugPrint('Item data: $item');
        }
      }
      debugPrint('Synced $progressItemsSynced new playback progress items (updated $progressItemsUpdated items)');

      // Process history items (completed watches from Trakt)
      int historyItemsSynced = 0;
      int historyItemsUpdated = 0;
      for (final item in allHistoryItems) {
        try {
          // History items represent completed watches (scrobbles)
          final traktId = _extractTraktIdFromHistory(item);
          final type = item.type;
          final watchedAt = item.watchedAt;
          final action = item.action;

          // Only process 'watch' or 'scrobble' actions (not 'checkin')
          if (action != 'watch' && action != 'scrobble') {
            continue;
          }

          String title;
          String? imdbId;
          String? tmdbId;
          int? seasonNumber;
          int? episodeNumber;
          int? runtime;
          double progress = 100.0; // History items are completed watches

          if (type == 'movie' && item.movie != null) {
            final movie = item.movie!;
            title = movie.title;
            final ids = movie.ids;
            imdbId = ids.imdb;
            tmdbId = ids.tmdb?.toString();
            // Note: movie runtime not available in history API
          } else if (type == 'episode' && item.episode != null && item.show != null) {
            final episode = item.episode!;
            final show = item.show!;
            title = episode.title;
            final showIds = show.ids;
            imdbId = showIds.imdb;
            tmdbId = showIds.tmdb?.toString();
            seasonNumber = episode.season;
            episodeNumber = episode.number;
          } else {
            continue; // Skip invalid items
          }

          // Check if item already exists before upserting
          final existingItem = await _database.getWatchHistoryByTraktId(traktId);
          final isNew = existingItem == null;

          // Upsert watch history - mark as 100% completed
          await _database.upsertWatchHistory(
            WatchHistoryCompanion.insert(
              traktId: traktId,
              type: type,
              title: title,
              imdbId: Value(imdbId),
              tmdbId: Value(tmdbId),
              seasonNumber: Value(seasonNumber),
              episodeNumber: Value(episodeNumber),
              progress: progress, // 100% for completed watches
              watchedAt: watchedAt,
              pausedAt: const Value.absent(),
              runtime: Value(runtime),
              lastSyncedAt: now,
              createdAt: now,
            ),
          );

          if (isNew) {
            historyItemsSynced++;
            syncedCount++;
          } else {
            historyItemsUpdated++;
          }
        } catch (e) {
          debugPrint('Error processing history item: $e');
          debugPrint('Item data: $item');
        }
      }
      debugPrint('Synced $historyItemsSynced new history items (updated $historyItemsUpdated items)');

      // Update the last sync timestamp if sync was successful
      if (syncedCount > 0 || historyItemsUpdated > 0 || progressItemsUpdated > 0 || shouldDoIncrementalSync) {
        await setLastSyncTimestamp(now);
        debugPrint('Updated last sync timestamp to ${now.toIso8601String()}');
      }

      debugPrint('Total synced: $syncedCount new items ($progressItemsSynced playback + $historyItemsSynced history), Updated: ${progressItemsUpdated + historyItemsUpdated} items');
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

  /// Extract Trakt ID from history item
  String _extractTraktIdFromHistory(TraktHistoryItem item) {
    if (item.type == 'movie' && item.movie != null) {
      final ids = item.movie!.ids;
      return ids.trakt?.toString() ??
             ids.tmdb?.toString() ??
             ids.imdb ??
             'unknown';
    } else if (item.type == 'episode' && item.episode != null && item.show != null) {
      final showIds = item.show!.ids;
      final episode = item.episode!;
      final showTraktId = showIds.trakt?.toString() ?? '0';
      return '$showTraktId:${episode.season}:${episode.number}';
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

