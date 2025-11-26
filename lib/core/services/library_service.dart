import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/app_database.dart';
import '../../features/library/models/catalog_item.dart';

/// Service for managing library items (saved content)
class LibraryService {
  final AppDatabase _database;

  LibraryService(this._database);

  /// Add an item to the library
  Future<bool> addToLibrary(CatalogItem item) async {
    try {
      final jsonData = jsonEncode(item.toJson());
      await _database.addLibraryItem(
        LibraryItemsCompanion.insert(
          contentId: item.id,
          type: item.type,
          title: item.name,
          data: jsonData,
          addedAt: DateTime.now(),
        ),
      );
      debugPrint('Added ${item.name} to library');
      return true;
    } catch (e) {
      debugPrint('Error adding item to library: $e');
      return false;
    }
  }

  /// Remove an item from the library
  Future<bool> removeFromLibrary(String contentId) async {
    try {
      await _database.removeLibraryItem(contentId);
      debugPrint('Removed item from library: $contentId');
      return true;
    } catch (e) {
      debugPrint('Error removing item from library: $e');
      return false;
    }
  }

  /// Check if an item is in the library
  Future<bool> isInLibrary(String contentId) async {
    return await _database.isInLibrary(contentId);
  }

  /// Get all library items as CatalogItems
  Future<List<CatalogItem>> getLibraryItems() async {
    try {
      final libraryItems = await _database.getAllLibraryItems();
      final catalogItems = <CatalogItem>[];

      for (final item in libraryItems) {
        try {
          final jsonData = jsonDecode(item.data) as Map<String, dynamic>;
          final catalogItem = CatalogItem.fromJson(jsonData);
          catalogItems.add(catalogItem);
        } catch (e) {
          debugPrint('Error parsing library item ${item.contentId}: $e');
          // Skip invalid items
        }
      }

      return catalogItems;
    } catch (e) {
      debugPrint('Error getting library items: $e');
      return [];
    }
  }

  /// Toggle library status (add if not in library, remove if in library)
  Future<bool> toggleLibraryStatus(CatalogItem item) async {
    final isInLib = await isInLibrary(item.id);
    if (isInLib) {
      return await removeFromLibrary(item.id);
    } else {
      return await addToLibrary(item);
    }
  }
}


