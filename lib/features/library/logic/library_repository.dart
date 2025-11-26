import 'package:flutter/foundation.dart';
import '../models/catalog_item.dart';
import '../../addons/logic/addon_client.dart';
import '../../addons/logic/addon_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/service_locator.dart';
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
  final CatalogPreferencesRepository _catalogPreferencesRepository;
  
  // Internal-only catalog IDs that should not be displayed as browseable catalogs
  static const Set<String> _internalCatalogIds = {
    'tmdb.search', 
    'tmdb.language', 
    'tmdb.year'
  };

  /// Check if a catalog is internal-only and should be hidden
  static bool isInternalCatalog(dynamic catalogDef) {
    final id = catalogDef.id?.toLowerCase() ?? '';
    // Exact match on ID only
    return _internalCatalogIds.contains(id);
  }

  LibraryRepository(AppDatabase database)
      : _addonRepository = AddonRepository(database),
        _catalogPreferencesRepository = CatalogPreferencesRepository(database);

  /// Fetch all catalogs from enabled addons grouped by catalog definition
  /// Returns a list of catalog sections, each representing a catalog from an addon
  /// All catalogs are loaded in parallel for better performance
  Future<List<CatalogSection>> getCatalogSections() async {
    final enabledAddons = await _addonRepository.getEnabledAddons();
    final List<Future<CatalogSection?>> catalogFutures = [];

    // Collect all catalog loading futures
    for (final addon in enabledAddons) {
      try {
        final manifest = _addonRepository.getManifest(addon);
        
        // Check if addon supports catalog resource
        if (!AddonRepository.hasResource(addon.resources, 'catalog')) {
          continue;
        }

        final client = AddonClient(addon.baseUrl);

        // Create futures for all catalogs in parallel
        for (final catalogDef in manifest.catalogs) {
          catalogFutures.add(_loadCatalogSection(
            client,
            addon,
            catalogDef,
          ));
        }
      } catch (e) {
        // Continue with other addons if one fails
        debugPrint('Error processing addon ${addon.id}: $e');
      }
    }

    // Wait for all catalogs to load in parallel
    final results = await Future.wait(catalogFutures);
    return results.whereType<CatalogSection>().toList();
  }

  /// Load a single catalog section (helper method for parallel loading)
  Future<CatalogSection?> _loadCatalogSection(
    AddonClient client,
    dynamic addon,
    dynamic catalogDef,
  ) async {
    try {
      // Skip internal-only catalog types that should not be displayed
      if (isInternalCatalog(catalogDef)) {
        return null; // Skip internal catalog types
      }
      
      final catalogId = catalogDef.id?.isEmpty ?? true ? null : catalogDef.id;
      
      // Check if this catalog is enabled
      final isEnabled = await _catalogPreferencesRepository.isCatalogEnabled(
        addon.id,
        catalogDef.type,
        catalogId,
      );
      
      if (!isEnabled) {
        return null; // Skip disabled catalogs
      }
      
      final result = await client.getCatalog(catalogDef.type, catalogId);
      final rawItems = result['metas'] as List<CatalogItem>;
      
      // Use raw items directly - no TMDB enrichment for catalog items
      // Only the hero item will be enriched separately
      if (rawItems.isEmpty) {
        return null;
      }
      
      // Create a section title from catalog name or type
      final title = catalogDef.name ?? 
                  '${catalogDef.type.capitalize()}${catalogDef.id != null && catalogDef.id!.isNotEmpty ? ' - ${catalogDef.id}' : ''}';
      
      return CatalogSection(
        title: title,
        addonName: addon.name,
        items: rawItems, // Use raw items without TMDB enrichment
      );
    } catch (e) {
      // Return null on error (will be filtered out)
      debugPrint('Error loading catalog ${catalogDef.type}/${catalogDef.id}: $e');
      return null;
    }
  }

  /// Get hero items from all hero catalogs (for carousel)
  /// [initialEnrichCount] - number of items to enrich immediately, rest are enriched later
  Future<List<CatalogItem>> getHeroItems({int initialEnrichCount = 1}) async {
    try {
      final heroCatalogs = await _catalogPreferencesRepository.getHeroCatalogs();
      if (heroCatalogs.isEmpty) {
        // Fallback to first section if no hero catalog is set
        final sections = await getCatalogSections();
        if (sections.isNotEmpty && sections[0].items.isNotEmpty) {
          // Enrich only first item initially, rest remain raw
          final items = <CatalogItem>[];
          final rawItems = sections[0].items.take(5);
          
          // Enrich first initialEnrichCount items
          int enrichedCount = 0;
          for (final item in rawItems) {
            if (enrichedCount < initialEnrichCount) {
              final enriched = await enrichItemForHero(item);
              if (enriched != null) {
                items.add(enriched);
                enrichedCount++;
              }
            } else {
              // Add remaining items as raw (will be enriched later)
              items.add(item);
            }
          }
          return items;
        }
        return [];
      }

      // Aggregate items from all hero catalogs
      final allItems = <CatalogItem>[];
      final itemsPerCatalog = (10 / heroCatalogs.length).ceil(); // Distribute items across catalogs
      int totalEnrichedCount = 0;

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

          // Enrich items from this catalog (only first initialEnrichCount total)
          for (final item in rawItems.take(itemsPerCatalog)) {
            if (totalEnrichedCount < initialEnrichCount) {
              final enriched = await enrichItemForHero(item);
              if (enriched != null) {
                allItems.add(enriched);
                totalEnrichedCount++;
              }
            } else {
              // Add remaining as raw
              allItems.add(item);
            }
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
      final enrichedData = await ServiceLocator.instance.tmdbEnrichmentService.enrichCatalogItem(
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

  /// Enrich remaining hero items that were left raw during initial load
  /// Items that already have logos/backgrounds are considered enriched and skipped
  Future<List<CatalogItem>> enrichRemainingHeroItems(List<CatalogItem> items) async {
    final enrichedItems = <CatalogItem>[];
    
    for (final item in items) {
      // Check if item is already enriched (has logo or background from TMDB)
      // Enriched items typically have logos, while raw items from addons don't
      final isEnriched = item.logo != null && item.logo!.isNotEmpty;
      
      if (isEnriched) {
        enrichedItems.add(item);
        continue;
      }
      
      // Enrich the raw item
      final enriched = await enrichItemForHero(item);
      enrichedItems.add(enriched ?? item);
    }
    
    return enrichedItems;
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
          finalTmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(item.id);
        }

        if (finalTmdbId == null) {
          return null;
        }

        // Fetch full metadata which includes credits (will use cache if available)
        if (item.type == 'movie') {
          final metadata = await ServiceLocator.instance.tmdbMetadataService.getMovieMetadata(finalTmdbId);
          tmdbData = metadata?.toJson();
        } else if (item.type == 'series') {
          final metadata = await ServiceLocator.instance.tmdbMetadataService.getTvMetadata(finalTmdbId);
          tmdbData = metadata?.toJson();
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
            // Skip internal-only catalog types that should not be displayed
            if (isInternalCatalog(catalogDef)) {
              continue; // Skip internal catalog types
            }
            
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
          // Skip internal-only catalog types that should not be displayed
          if (isInternalCatalog(catalogDef)) {
            continue; // Skip internal catalog types
          }
          
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

  /// Search for items across TMDB API
  /// Returns items matching the query, sorted by popularity (imdbRating)
  Future<List<CatalogItem>> searchItems(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      // Search both movies and TV shows from TMDB API
      final movieResults = await ServiceLocator.instance.tmdbSearchService.searchMovies(query);
      final tvResults = await ServiceLocator.instance.tmdbSearchService.searchTv(query);

      // Combine and convert to CatalogItem
      final allResults = <CatalogItem>[];
      final enrichmentService = ServiceLocator.instance.tmdbEnrichmentService;

      for (final movieData in movieResults) {
        try {
          final tmdbIdStr = 'tmdb:${movieData.id}';
          allResults.add(CatalogItem.fromJson({
            'id': tmdbIdStr,
            'type': 'movie',
            'name': movieData.title ?? '',
            'poster': enrichmentService.getImageUrl(movieData.posterPath),
            'background': enrichmentService.getImageUrl(movieData.backdropPath, size: 'w1280'),
            'description': movieData.overview,
            'releaseInfo': movieData.releaseDate,
            'imdbRating': movieData.voteAverage.toString(),
          }));
        } catch (e) {
          // Skip invalid items
          continue;
        }
      }

      for (final tvData in tvResults) {
        try {
          final tmdbIdStr = 'tmdb:${tvData.id}';
          allResults.add(CatalogItem.fromJson({
            'id': tmdbIdStr,
            'type': 'series',
            'name': tvData.name ?? '',
            'poster': enrichmentService.getImageUrl(tvData.posterPath),
            'background': enrichmentService.getImageUrl(tvData.backdropPath, size: 'w1280'),
            'description': tvData.overview,
            'releaseInfo': tvData.firstAirDate,
            'imdbRating': tvData.voteAverage.toString(),
          }));
        } catch (e) {
          // Skip invalid items
          continue;
        }
      }

      // Sort by rating (highest first), then by name
      allResults.sort((a, b) {
        final ratingA = double.tryParse(a.imdbRating ?? '0') ?? 0.0;
        final ratingB = double.tryParse(b.imdbRating ?? '0') ?? 0.0;

        if (ratingB != ratingA) {
          return ratingB.compareTo(ratingA);
        }
        return a.name.compareTo(b.name);
      });

      return allResults;
    } catch (e) {
      debugPrint('Error searching TMDB: $e');
      return [];
    }
  }
}
