import 'package:drift/drift.dart';

/// Table definition for storing addon information
class Addons extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get version => text()();
  TextColumn get description => text().nullable()();
  TextColumn get manifestUrl => text()();
  TextColumn get baseUrl => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get manifestData => text()();
  TextColumn get resources => text()(); // JSON array stored as text
  TextColumn get types => text()(); // JSON array stored as text
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table definition for storing catalog preferences
class CatalogPreferences extends Table {
  TextColumn get addonId => text()();
  TextColumn get catalogType => text()(); // "movie" or "series"
  TextColumn get catalogId => text().nullable()(); // Catalog ID (e.g., "tmdb.top") or null for default
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isHeroSource => boolean().withDefault(const Constant(false))(); // Whether this catalog is used for hero
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {addonId, catalogType, catalogId};
}

/// Table definition for storing Trakt authentication tokens
class TraktAuth extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accessToken => text()();
  TextColumn get refreshToken => text()();
  IntColumn get expiresIn => integer()(); // Seconds until expiration
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()(); // Calculated expiration time
  TextColumn get username => text().nullable()(); // Trakt username
  TextColumn get slug => text().nullable()(); // Trakt slug
}

/// Table definition for storing watch history from Trakt
class WatchHistory extends Table {
  TextColumn get traktId => text()(); // Trakt ID (e.g., "12345" for movie, "12345:1:2" for episode)
  TextColumn get type => text()(); // "movie" or "episode"
  TextColumn get title => text()(); // Title of the movie or episode
  TextColumn get imdbId => text().nullable()(); // IMDb ID for matching with catalog items
  TextColumn get tmdbId => text().nullable()(); // TMDB ID for matching with catalog items
  IntColumn get seasonNumber => integer().nullable()(); // Season number (for episodes)
  IntColumn get episodeNumber => integer().nullable()(); // Episode number (for episodes)
  RealColumn get progress => real()(); // Watch progress percentage (0.0 to 100.0)
  DateTimeColumn get watchedAt => dateTime()(); // When the item was last watched
  DateTimeColumn get pausedAt => dateTime().nullable()(); // When playback was paused
  IntColumn get runtime => integer().nullable()(); // Runtime in seconds
  DateTimeColumn get lastSyncedAt => dateTime()(); // When this record was last synced from Trakt
  DateTimeColumn get createdAt => dateTime()(); // When this record was created locally

  @override
  Set<Column> get primaryKey => {traktId};
}

/// Table definition for storing app settings
class AppSettings extends Table {
  TextColumn get key => text()(); // Setting key (e.g., "accent_color")
  TextColumn get value => text()(); // Setting value (e.g., "#FF5733")
  DateTimeColumn get updatedAt => dateTime()(); // When this setting was last updated

  @override
  Set<Column> get primaryKey => {key};
}

