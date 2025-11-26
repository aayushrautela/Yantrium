import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Addons, CatalogPreferences, TraktAuth, WatchHistory, AppSettings, LibraryItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(catalogPreferences);
        }
        if (from < 3) {
          await migrator.createTable(traktAuth);
        }
        if (from < 4) {
          await migrator.createTable(watchHistory);
        }
        if (from < 5) {
          await migrator.createTable(appSettings);
        }
        if (from < 6) {
          await migrator.createTable(libraryItems);
        }
      },
    );
  }

  // Addon DAO methods
  Future<List<Addon>> getAllAddons() => select(addons).get();
  
  Future<Addon?> getAddonById(String id) => 
      (select(addons)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  
  Future<List<Addon>> getEnabledAddons() => 
      (select(addons)..where((tbl) => tbl.enabled.equals(true))).get();
  
  Future<int> insertAddon(AddonsCompanion addon) => into(addons).insert(addon);
  
  Future<int> updateAddon(AddonsCompanion addon) async {
    return await (update(addons)..where((tbl) => tbl.id.equals(addon.id.value)))
        .write(addon);
  }
  
  Future<int> deleteAddon(String id) async {
    return await (delete(addons)..where((tbl) => tbl.id.equals(id))).go();
  }
  
  Future<int> toggleAddonEnabled(String id, bool enabled) async {
    return await (update(addons)..where((tbl) => tbl.id.equals(id)))
        .write(AddonsCompanion(enabled: Value(enabled)));
  }

  // Catalog Preferences DAO methods
  Future<List<CatalogPreference>> getAllCatalogPreferences() => 
      select(catalogPreferences).get();

  Future<CatalogPreference?> getCatalogPreference(
    String addonId,
    String catalogType,
    String? catalogId,
  ) {
    final query = select(catalogPreferences)
      ..where((tbl) => tbl.addonId.equals(addonId))
      ..where((tbl) => tbl.catalogType.equals(catalogType));
    
    if (catalogId == null || catalogId.isEmpty) {
      query.where((tbl) => tbl.catalogId.isNull());
    } else {
      query.where((tbl) => tbl.catalogId.equals(catalogId));
    }
    
    return query.getSingleOrNull();
  }

  Future<List<CatalogPreference>> getEnabledCatalogs() =>
      (select(catalogPreferences)..where((tbl) => tbl.enabled.equals(true))).get();

  Future<CatalogPreference?> getHeroCatalog() =>
      (select(catalogPreferences)..where((tbl) => tbl.isHeroSource.equals(true))).getSingleOrNull();

  Future<List<CatalogPreference>> getHeroCatalogs() =>
      (select(catalogPreferences)..where((tbl) => tbl.isHeroSource.equals(true))).get();

  Future<int> upsertCatalogPreference(CatalogPreferencesCompanion preference) =>
      into(catalogPreferences).insertOnConflictUpdate(preference);

  Future<int> toggleCatalogEnabled(
    String addonId,
    String catalogType,
    String? catalogId,
    bool enabled,
  ) async {
    final query = update(catalogPreferences)
      ..where((tbl) => tbl.addonId.equals(addonId))
      ..where((tbl) => tbl.catalogType.equals(catalogType));
    
    if (catalogId == null || catalogId.isEmpty) {
      query.where((tbl) => tbl.catalogId.isNull());
    } else {
      query.where((tbl) => tbl.catalogId.equals(catalogId));
    }
    
    return await query.write(CatalogPreferencesCompanion(enabled: Value(enabled)));
  }

  Future<int> setHeroCatalog(
    String addonId,
    String catalogType,
    String? catalogId,
  ) async {
    // Set the specific catalog as hero (allow multiple hero catalogs)
    final query = update(catalogPreferences)
      ..where((tbl) => tbl.addonId.equals(addonId))
      ..where((tbl) => tbl.catalogType.equals(catalogType));
    
    if (catalogId == null || catalogId.isEmpty) {
      query.where((tbl) => tbl.catalogId.isNull());
    } else {
      query.where((tbl) => tbl.catalogId.equals(catalogId));
    }
    
    return await query.write(CatalogPreferencesCompanion(isHeroSource: Value(true)));
  }

  Future<int> unsetHeroCatalog(
    String addonId,
    String catalogType,
    String? catalogId,
  ) async {
    // Unset the specific catalog's hero status
    final query = update(catalogPreferences)
      ..where((tbl) => tbl.addonId.equals(addonId))
      ..where((tbl) => tbl.catalogType.equals(catalogType));
    
    if (catalogId == null || catalogId.isEmpty) {
      query.where((tbl) => tbl.catalogId.isNull());
    } else {
      query.where((tbl) => tbl.catalogId.equals(catalogId));
    }
    
    return await query.write(CatalogPreferencesCompanion(isHeroSource: Value(false)));
  }

  // Trakt Auth DAO methods
  Future<TraktAuthData?> getTraktAuth() => 
      (select(traktAuth)..orderBy([(t) => OrderingTerm.desc(t.id)]))
          .getSingleOrNull();
  
  Future<int> upsertTraktAuth(TraktAuthCompanion auth) async {
    // Since we only store one auth, delete existing and insert new
    await deleteTraktAuth();
    return await into(traktAuth).insert(auth);
  }
  
  Future<int> deleteTraktAuth() => delete(traktAuth).go();

  // Watch History DAO methods
  Future<List<WatchHistoryData>> getAllWatchHistory() => 
      (select(watchHistory)..orderBy([(t) => OrderingTerm.desc(t.watchedAt)])).get();
  
  Future<List<WatchHistoryData>> getContinueWatching({double minProgress = 0.0, double maxProgress = 80.0}) =>
      (select(watchHistory)
        ..where((t) => t.progress.isBiggerOrEqualValue(minProgress))
        ..where((t) => t.progress.isSmallerOrEqualValue(maxProgress))
        ..orderBy([(t) => OrderingTerm.desc(t.watchedAt)]))
      .get();
  
  Future<WatchHistoryData?> getWatchHistoryByTraktId(String traktId) =>
      (select(watchHistory)..where((t) => t.traktId.equals(traktId))).getSingleOrNull();
  
  Future<WatchHistoryData?> getWatchHistoryByImdbId(String imdbId) =>
      (select(watchHistory)..where((t) => t.imdbId.equals(imdbId))).getSingleOrNull();
  
  /// Check if an episode is watched (progress >= 80%)
  Future<bool> isEpisodeWatched(String? tmdbId, int seasonNumber, int episodeNumber) async {
    if (tmdbId == null || tmdbId.isEmpty) {
      if (kDebugMode) {
        debugPrint('isEpisodeWatched: tmdbId is null or empty');
      }
      return false;
    }
    
    if (kDebugMode) {
      debugPrint('isEpisodeWatched: Querying for tmdbId=$tmdbId, season=$seasonNumber, episode=$episodeNumber');
    }
    
    final history = await (select(watchHistory)
      ..where((t) => t.type.equals('episode'))
      ..where((t) => t.tmdbId.equals(tmdbId))
      ..where((t) => t.seasonNumber.equals(seasonNumber))
      ..where((t) => t.episodeNumber.equals(episodeNumber)))
      .getSingleOrNull();
    
    if (history == null) {
      if (kDebugMode) {
        debugPrint('isEpisodeWatched: No history found for this episode');
      }
      return false;
    }
    
    if (kDebugMode) {
      debugPrint('isEpisodeWatched: Found history - progress=${history.progress}, watched=${history.progress >= 80.0}');
    }
    
    return history.progress >= 80.0;
  }
  
  Future<int> upsertWatchHistory(WatchHistoryCompanion history) async {
    return await into(watchHistory).insertOnConflictUpdate(history);
  }
  
  Future<int> updateWatchProgress(String traktId, double progress, {DateTime? pausedAt}) async {
    return await (update(watchHistory)..where((t) => t.traktId.equals(traktId)))
        .write(WatchHistoryCompanion(
          progress: Value(progress),
          pausedAt: pausedAt != null ? Value(pausedAt) : const Value.absent(),
          watchedAt: Value(DateTime.now()),
        ));
  }
  
  Future<int> deleteWatchHistory(String traktId) =>
      (delete(watchHistory)..where((t) => t.traktId.equals(traktId))).go();
  
  Future<int> clearWatchHistory() => delete(watchHistory).go();

  // App Settings DAO methods
  Future<AppSetting?> getSetting(String key) =>
      (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
  
  Future<String?> getSettingValue(String key) async {
    final setting = await getSetting(key);
    return setting?.value;
  }
  
  Future<int> setSetting(String key, String value) async {
    return await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: key,
        value: value,
        updatedAt: DateTime.now(),
      ),
    );
  }
  
  Future<int> deleteSetting(String key) =>
      (delete(appSettings)..where((t) => t.key.equals(key))).go();

  // Library Items DAO methods
  Future<List<LibraryItem>> getAllLibraryItems() =>
      (select(libraryItems)..orderBy([(t) => OrderingTerm.desc(t.addedAt)])).get();
  
  Future<LibraryItem?> getLibraryItemByContentId(String contentId) =>
      (select(libraryItems)..where((t) => t.contentId.equals(contentId))).getSingleOrNull();
  
  Future<int> addLibraryItem(LibraryItemsCompanion item) =>
      into(libraryItems).insertOnConflictUpdate(item);
  
  Future<int> removeLibraryItem(String contentId) =>
      (delete(libraryItems)..where((t) => t.contentId.equals(contentId))).go();
  
  Future<bool> isInLibrary(String contentId) async {
    final item = await getLibraryItemByContentId(contentId);
    return item != null;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'yantrium.db'));
    return NativeDatabase(file);
  });
}

