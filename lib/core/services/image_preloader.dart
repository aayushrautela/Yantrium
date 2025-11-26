import 'package:flutter/material.dart';
import '../../features/library/models/catalog_item.dart';

class ImagePreloader {
  static final Map<String, bool> _preloadCache = {};

  /// Preload hero background images for immediate display
  static void preloadHeroImages(List<CatalogItem> items, {int count = 3}) {
    for (final item in items.take(count)) {
      if (item.background != null && !_preloadCache.containsKey(item.background)) {
        _preloadCache[item.background!] = true;
        // Preload image into cache
        NetworkImage(item.background!).resolve(ImageConfiguration.empty);
      }
    }
  }

  /// Preload poster images for catalog display
  static void preloadPosters(List<CatalogItem> items, {int count = 20}) {
    for (final item in items.take(count)) {
      if (item.poster != null && !_preloadCache.containsKey(item.poster)) {
        _preloadCache[item.poster!] = true;
        // Preload image into cache
        NetworkImage(item.poster!).resolve(ImageConfiguration.empty);
      }
    }
  }

  /// Check if image is already preloaded
  static bool isPreloaded(String? url) {
    return url != null && _preloadCache.containsKey(url);
  }

  /// Clear preload cache (useful for memory management)
  static void clearCache() {
    _preloadCache.clear();
  }

  /// Get cache size for debugging
  static int get cacheSize => _preloadCache.length;
}

