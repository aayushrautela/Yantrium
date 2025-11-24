import 'package:flutter/foundation.dart';
import '../models/catalog_item.dart';
import '../../addons/logic/addon_client.dart';
import '../../addons/logic/addon_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/tmdb_service.dart';
import '../../../core/services/id_parser.dart';
import '../../../core/services/tmdb_data_extractor.dart';
import 'catalog_preferences_repository.dart';

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

/// Catalog section with title and items
class CatalogSection {
  final String title;
  final String addonName;
  final List<CatalogItem> items;

  CatalogSection({
    required this.title,
    required this.addonName,
    required this.items,
  });
}

/// Repository for fetching catalogs from addons
class LibraryRepository {
  final AddonRepository _addonRepository;
  final TmdbService _tmdbService;
  final CatalogPreferencesRepository _catalogPreferencesRepository;

  LibraryRepository(AppDatabase database)
      : _addonRepository = AddonRepository(database),
        _tmdbService = TmdbService(),
        _catalogPreferencesRepository = CatalogPreferencesRepository(database);

  /// Fetch all catalogs from enabled addons grouped by catalog definition
  /// Returns a list of catalog sections, each representing a catalog from an addon
  Future<List<CatalogSection>> getCatalogSections() async {
    final enabledAddons = await _addonRepository.getEnabledAddons();
    final List<CatalogSection> sections = [];

    for (final addon in enabledAddons) {
      try {
        final manifest = _addonRepository.getManifest(addon);
        
        // Check if addon supports catalog resource
        if (!AddonRepository.hasResource(addon.resources, 'catalog')) {
          continue;
        }

        final client = AddonClient(addon.baseUrl);

        // Fetch catalogs for each catalog definition in manifest
        for (final catalogDef in manifest.catalogs) {
          try {
            final catalogId = catalogDef.id?.isEmpty ?? true ? null : catalogDef.id;
            
            // Check if this catalog is enabled
            final isEnabled = await _catalogPreferencesRepository.isCatalogEnabled(
              addon.id,
              catalogDef.type,
              catalogId,
            );
            
            if (!isEnabled) {
              continue; // Skip disabled catalogs
            }
            
            final result = await client.getCatalog(catalogDef.type, catalogId);
            final rawItems = result['metas'] as List<CatalogItem>;
            
            // Use raw items directly - no TMDB enrichment for catalog items
            // Only the hero item will be enriched separately
            if (rawItems.isNotEmpty) {
              // Create a section title from catalog name or type
              final title = catalogDef.name ?? 
                          '${catalogDef.type.capitalize()}${catalogDef.id != null && catalogDef.id!.isNotEmpty ? ' - ${catalogDef.id}' : ''}';
              
              sections.add(CatalogSection(
                title: title,
                addonName: addon.name,
                items: rawItems, // Use raw items without TMDB enrichment
              ));
            }
          } catch (e) {
            // Continue with other catalogs if one fails
          }
        }
      } catch (e) {
        // Continue with other addons if one fails
      }
    }

    return sections;
  }

  /// Get hero items from all hero catalogs (for carousel)
  Future<List<CatalogItem>> getHeroItems() async {
    try {
      final heroCatalogs = await _catalogPreferencesRepository.getHeroCatalogs();
      if (heroCatalogs.isEmpty) {
        // Fallback to first section if no hero catalog is set
        final sections = await getCatalogSections();
        if (sections.isNotEmpty && sections[0].items.isNotEmpty) {
          // Enrich first few items for hero
          final items = <CatalogItem>[];
          for (final item in sections[0].items.take(5)) {
            final enriched = await enrichItemForHero(item);
            if (enriched != null) items.add(enriched);
          }
          return items;
        }
        return [];
      }

      // Aggregate items from all hero catalogs
      final allItems = <CatalogItem>[];
      final itemsPerCatalog = (10 / heroCatalogs.length).ceil(); // Distribute items across catalogs

      for (final heroCatalog in heroCatalogs) {
        try {
          // Get the addon
          final addon = await _addonRepository.getAddon(heroCatalog.addonId);
          if (addon == null) continue;

          // Get the catalog
          final client = AddonClient(addon.baseUrl);
          final result = await client.getCatalog(
            heroCatalog.catalogType,
            heroCatalog.catalogId,
          );
          
          final rawItems = result['metas'] as List<CatalogItem>;
          if (rawItems.isEmpty) continue;

          // Enrich items from this catalog
          for (final item in rawItems.take(itemsPerCatalog)) {
            final enriched = await enrichItemForHero(item);
            if (enriched != null) allItems.add(enriched);
          }
        } catch (e) {
          // Continue with other catalogs if one fails
          continue;
        }
      }

      // Limit total items to 10 for the hero carousel
      return allItems.take(10).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get hero item from the selected hero catalog (single item, for backward compatibility)
  Future<CatalogItem?> getHeroItem() async {
    final items = await getHeroItems();
    return items.isNotEmpty ? items[0] : null;
  }

  /// Enrich a single catalog item with full TMDB metadata (for hero section)
  /// This makes a full API call including images/logos
  Future<CatalogItem?> enrichItemForHero(
    CatalogItem item, {
    Map<String, dynamic>? cachedTmdbData,
  }) async {
    try {
      final enrichedData = await _tmdbService.enrichCatalogItem(
        item.id,
        item.type,
        cachedTmdbData: cachedTmdbData,
      );
      
      if (enrichedData != null) {
        return CatalogItem.fromJson(enrichedData);
      }
      return item; // Return original if enrichment fails
    } catch (e) {
      return item; // Return original on error
    }
  }

  /// Get cast and crew data for an item (extracts from TMDB enrichment)
  /// If cachedTmdbData is provided, uses it instead of fetching (avoids duplicate API calls)
  Future<Map<String, dynamic>?> getCastAndCrewForItem(
    CatalogItem item, {
    Map<String, dynamic>? cachedTmdbData,
  }) async {
    try {
      Map<String, dynamic>? tmdbData = cachedTmdbData;
      
      // Only fetch if no cached data provided
      if (tmdbData == null) {
        final tmdbId = IdParser.extractTmdbId(item.id);
        int? finalTmdbId = tmdbId;
        
        if (finalTmdbId == null && IdParser.isImdbId(item.id)) {
          finalTmdbId = await _tmdbService.getTmdbIdFromImdb(item.id);
        }
        
        if (finalTmdbId == null) {
          return null;
        }
        
        // Fetch full metadata which includes credits (will use cache if available)
        if (item.type == 'movie') {
          tmdbData = await _tmdbService.getMovieMetadata(finalTmdbId);
        } else if (item.type == 'series') {
          tmdbData = await _tmdbService.getTvMetadata(finalTmdbId);
        }
      }
      
      if (tmdbData == null) {
        return null;
      }
      
      // Use centralized extractor
      final castAndCrew = TmdbDataExtractor.extractCastAndCrew(tmdbData);
      
      // Convert CastCrewMember lists back to JSON format for compatibility
      return {
        'cast': castAndCrew['cast']!.map((m) => {
          'name': m.name,
          'character': m.character,
          'profile_path': m.profileImageUrl,
          'order': m.order,
        }).toList(),
        'crew': castAndCrew['crew']!.map((m) => {
          'name': m.name,
          'job': m.character,
          'profile_path': m.profileImageUrl,
        }).toList(),
      };
    } catch (e) {
      return null;
    }
  }

  /// Fetch all catalogs from enabled addons
  /// Returns a map of addon ID to list of catalog items
  Future<Map<String, List<CatalogItem>>> getAllCatalogs() async {
    final enabledAddons = await _addonRepository.getEnabledAddons();
    final Map<String, List<CatalogItem>> catalogs = {};

    for (final addon in enabledAddons) {
      try {
        final manifest = _addonRepository.getManifest(addon);
        
        // Check if addon supports catalog resource
        if (!AddonRepository.hasResource(addon.resources, 'catalog')) {
          continue;
        }

        final client = AddonClient(addon.baseUrl);
        final addonCatalogs = <CatalogItem>[];

        // Fetch catalogs for each catalog definition in manifest
        for (final catalogDef in manifest.catalogs) {
          try {
            final catalogId = catalogDef.id?.isEmpty ?? true ? null : catalogDef.id;
            final result = await client.getCatalog(catalogDef.type, catalogId);
            final rawItems = result['metas'] as List<CatalogItem>;
            
            // Use raw items directly - no TMDB enrichment
            addonCatalogs.addAll(rawItems);
          } catch (e) {
            // Continue with other catalogs if one fails
          }
        }

        if (addonCatalogs.isNotEmpty) {
          catalogs[addon.id] = addonCatalogs;
        }
      } catch (e) {
        // Continue with other addons if one fails
      }
    }

    return catalogs;
  }

  /// Get catalogs grouped by type (movie/series)
  Future<Map<String, List<CatalogItem>>> getCatalogsByType() async {
    final allCatalogs = await getAllCatalogs();
    final Map<String, List<CatalogItem>> byType = {
      'movie': <CatalogItem>[],
      'series': <CatalogItem>[],
    };

    for (final catalogList in allCatalogs.values) {
      for (final item in catalogList) {
        if (item.type == 'movie' || item.type == 'series') {
          byType[item.type]!.add(item);
        }
      }
    }

    return byType;
  }

  /// Get catalogs for a specific addon
  Future<List<CatalogItem>> getCatalogsForAddon(String addonId) async {
    final addon = await _addonRepository.getAddon(addonId);
    if (addon == null || !addon.enabled) {
      return [];
    }

    try {
      final manifest = _addonRepository.getManifest(addon);
      
      if (!AddonRepository.hasResource(addon.resources, 'catalog')) {
        return [];
      }

      final client = AddonClient(addon.baseUrl);
      final catalogs = <CatalogItem>[];

      for (final catalogDef in manifest.catalogs) {
        try {
          final catalogId = catalogDef.id?.isEmpty ?? true ? null : catalogDef.id;
          final result = await client.getCatalog(catalogDef.type, catalogId);
          final rawItems = result['metas'] as List<CatalogItem>;
          
          // Use raw items directly - no TMDB enrichment
          catalogs.addAll(rawItems);
        } catch (e) {
          // Continue with other catalogs if one fails
        }
      }

      return catalogs;
    } catch (e) {
      return [];
    }
  }

  /// Search for items across all enabled catalogs
  /// Returns items matching the query, sorted by popularity (imdbRating)
  Future<List<CatalogItem>> searchItems(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final queryLower = query.toLowerCase().trim();
    final allCatalogs = await getAllCatalogs();
    final List<CatalogItem> results = [];

    // Search through all catalog items
    for (final catalogList in allCatalogs.values) {
      for (final item in catalogList) {
        // Search in name, description, and genres
        final nameMatch = item.name.toLowerCase().contains(queryLower);
        final descriptionMatch = item.description?.toLowerCase().contains(queryLower) ?? false;
        final genreMatch = item.genres?.any((genre) => genre.toLowerCase().contains(queryLower)) ?? false;

        if (nameMatch || descriptionMatch || genreMatch) {
          results.add(item);
        }
      }
    }

    // Remove duplicates (same id)
    final uniqueResults = <String, CatalogItem>{};
    for (final item in results) {
      if (!uniqueResults.containsKey(item.id)) {
        uniqueResults[item.id] = item;
      }
    }

    // Sort by popularity (imdbRating) - higher rating first
    final sortedResults = uniqueResults.values.toList();
    sortedResults.sort((a, b) {
      final ratingA = double.tryParse(a.imdbRating ?? '0') ?? 0.0;
      final ratingB = double.tryParse(b.imdbRating ?? '0') ?? 0.0;
      
      // Sort by rating descending, then by name ascending
      if (ratingB != ratingA) {
        return ratingB.compareTo(ratingA);
      }
      return a.name.compareTo(b.name);
    });

    return sortedResults;
  }
}
