import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../addons/models/addon_manifest.dart';
import '../../addons/logic/addon_repository.dart';
import 'library_repository.dart';

/// Repository for managing catalog preferences
class CatalogPreferencesRepository {
  final AppDatabase _database;
  final AddonRepository _addonRepository;
  
  CatalogPreferencesRepository(this._database)
      : _addonRepository = AddonRepository(_database);

  /// Get all catalog preferences
  Future<List<CatalogPreference>> getAllPreferences() async {
    return await _database.getAllCatalogPreferences();
  }

  /// Get preference for a specific catalog
  Future<CatalogPreference?> getPreference(
    String addonId,
    String catalogType,
    String? catalogId,
  ) async {
    return await _database.getCatalogPreference(addonId, catalogType, catalogId);
  }

  /// Check if a catalog is enabled
  Future<bool> isCatalogEnabled(
    String addonId,
    String catalogType,
    String? catalogId,
  ) async {
    final preference = await getPreference(addonId, catalogType, catalogId);
    // Default to enabled if no preference exists
    return preference?.enabled ?? true;
  }

  /// Get all available catalogs from enabled addons
  Future<List<CatalogInfo>> getAvailableCatalogs() async {
    final addons = await _addonRepository.getEnabledAddons();
    final List<CatalogInfo> catalogs = [];

    for (final addon in addons) {
      try {
        final manifest = _addonRepository.getManifest(addon);
        
        if (!AddonRepository.hasResource(addon.resources, 'catalog')) {
          continue;
        }

        for (final catalogDef in manifest.catalogs) {
          // Skip internal-only catalog types that should not be displayed
          if (LibraryRepository.isInternalCatalog(catalogDef)) {
            continue; // Skip internal catalog types
          }
          
          final catalogId = catalogDef.id?.isEmpty ?? true ? null : catalogDef.id;
          final preference = await getPreference(addon.id, catalogDef.type, catalogId);
          
          catalogs.add(CatalogInfo(
            addonId: addon.id,
            addonName: addon.name,
            catalogType: catalogDef.type,
            catalogId: catalogId,
            catalogName: catalogDef.name ?? 
                '${_capitalize(catalogDef.type)}${catalogId != null && catalogId.isNotEmpty ? ' - $catalogId' : ''}',
            enabled: preference?.enabled ?? true,
            isHeroSource: preference?.isHeroSource ?? false,
          ));
        }
      } catch (e) {
        // Continue with other addons if one fails
      }
    }

    return catalogs;
  }

  /// Toggle catalog enabled state
  Future<void> toggleCatalogEnabled(
    String addonId,
    String catalogType,
    String? catalogId,
    bool enabled,
  ) async {
    final now = DateTime.now();
    final preference = await getPreference(addonId, catalogType, catalogId);
    
    if (preference != null) {
      // Update existing preference
      await _database.toggleCatalogEnabled(addonId, catalogType, catalogId, enabled);
    } else {
      // Create new preference
      await _database.upsertCatalogPreference(
        CatalogPreferencesCompanion(
          addonId: Value(addonId),
          catalogType: Value(catalogType),
          catalogId: Value(catalogId),
          enabled: Value(enabled),
          isHeroSource: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Set hero catalog
  Future<void> setHeroCatalog(
    String addonId,
    String catalogType,
    String? catalogId,
  ) async {
    final now = DateTime.now();
    final preference = await getPreference(addonId, catalogType, catalogId);
    
    if (preference != null) {
      // Update existing preference
      await _database.setHeroCatalog(addonId, catalogType, catalogId);
    } else {
      // Create new preference with hero flag
      await _database.upsertCatalogPreference(
        CatalogPreferencesCompanion(
          addonId: Value(addonId),
          catalogType: Value(catalogType),
          catalogId: Value(catalogId),
          enabled: const Value(true),
          isHeroSource: const Value(true),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Unset hero catalog (remove hero status from a specific catalog)
  Future<void> unsetHeroCatalog(
    String addonId,
    String catalogType,
    String? catalogId,
  ) async {
    await _database.unsetHeroCatalog(addonId, catalogType, catalogId);
  }

  /// Get hero catalog info (single, for backward compatibility)
  Future<CatalogInfo?> getHeroCatalog() async {
    final heroPreference = await _database.getHeroCatalog();
    if (heroPreference == null) return null;

    final addon = await _addonRepository.getAddon(heroPreference.addonId);
    if (addon == null) return null;

    final manifest = _addonRepository.getManifest(addon);
    final catalogDef = manifest.catalogs.firstWhere(
      (c) => c.type == heroPreference.catalogType &&
          (c.id?.isEmpty ?? true ? null : c.id) == heroPreference.catalogId,
      orElse: () => CatalogDefinition(type: heroPreference.catalogType),
    );

    return CatalogInfo(
      addonId: heroPreference.addonId,
      addonName: addon.name,
      catalogType: heroPreference.catalogType,
      catalogId: heroPreference.catalogId,
      catalogName: catalogDef.name ?? 
          '${_capitalize(heroPreference.catalogType)}${heroPreference.catalogId != null && heroPreference.catalogId!.isNotEmpty ? ' - ${heroPreference.catalogId}' : ''}',
      enabled: heroPreference.enabled,
      isHeroSource: true,
    );
  }

  /// Get all hero catalog info
  Future<List<CatalogInfo>> getHeroCatalogs() async {
    final heroPreferences = await _database.getHeroCatalogs();
    final List<CatalogInfo> heroCatalogs = [];

    for (final heroPreference in heroPreferences) {
      try {
        final addon = await _addonRepository.getAddon(heroPreference.addonId);
        if (addon == null) continue;

        final manifest = _addonRepository.getManifest(addon);
        final catalogDef = manifest.catalogs.firstWhere(
          (c) => c.type == heroPreference.catalogType &&
              (c.id?.isEmpty ?? true ? null : c.id) == heroPreference.catalogId,
          orElse: () => CatalogDefinition(type: heroPreference.catalogType),
        );

        heroCatalogs.add(CatalogInfo(
          addonId: heroPreference.addonId,
          addonName: addon.name,
          catalogType: heroPreference.catalogType,
          catalogId: heroPreference.catalogId,
          catalogName: catalogDef.name ?? 
              '${_capitalize(heroPreference.catalogType)}${heroPreference.catalogId != null && heroPreference.catalogId!.isNotEmpty ? ' - ${heroPreference.catalogId}' : ''}',
          enabled: heroPreference.enabled,
          isHeroSource: true,
        ));
      } catch (e) {
        // Continue with other catalogs if one fails
        continue;
      }
    }

    return heroCatalogs;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }
}

/// Information about a catalog
class CatalogInfo {
  final String addonId;
  final String addonName;
  final String catalogType;
  final String? catalogId;
  final String catalogName;
  final bool enabled;
  final bool isHeroSource;

  CatalogInfo({
    required this.addonId,
    required this.addonName,
    required this.catalogType,
    this.catalogId,
    required this.catalogName,
    required this.enabled,
    required this.isHeroSource,
  });

  /// Get unique identifier for this catalog
  String get uniqueId => '$addonId|$catalogType|${catalogId ?? ""}';
}

// Removed duplicate capitalize extension - using one from library_repository.dart

