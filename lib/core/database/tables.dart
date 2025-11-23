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

