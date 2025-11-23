import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Addons, CatalogPreferences])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.createTable(catalogPreferences);
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
    // First, unset all hero catalogs
    await (update(catalogPreferences)..where((tbl) => tbl.isHeroSource.equals(true)))
        .write(CatalogPreferencesCompanion(isHeroSource: Value(false)));

    // Then set the new hero catalog
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'yantrium.db'));
    return NativeDatabase(file);
  });
}

