import 'dart:convert';
import '../models/addon_config.dart';
import '../models/addon_manifest.dart';
import '../logic/addon_installer.dart';
import '../../../core/database/app_database.dart';

/// Repository pattern for addon operations
class AddonRepository {
  final AppDatabase _database;

  AddonRepository(this._database);

  /// Check if addon supports a resource
  /// Resources can be strings or objects with 'name' field
  static bool hasResource(List<dynamic> resources, String resourceName) {
    for (final resource in resources) {
      if (resource is String) {
        if (resource == resourceName) return true;
      } else if (resource is Map<String, dynamic>) {
        if (resource['name'] == resourceName) return true;
      }
    }
    return false;
  }

  /// Install addon from manifest URL
  Future<AddonConfig> installAddon(String manifestUrl) async {
    final addonConfig = await AddonInstaller.installAddon(manifestUrl);
    
    // Check if addon already exists
    final existing = await _database.getAddonById(addonConfig.id);
    if (existing != null) {
      // Update existing addon
      await _database.updateAddon(addonConfig.toCompanion());
    } else {
      // Insert new addon
      await _database.insertAddon(addonConfig.toCompanion());
    }
    
    return addonConfig;
  }

  /// List all installed addons
  Future<List<AddonConfig>> listAddons() async {
    final addons = await _database.getAllAddons();
    return addons.map((addon) => AddonConfig.fromDatabase(addon)).toList();
  }

  /// Get specific addon by ID
  Future<AddonConfig?> getAddon(String id) async {
    final addon = await _database.getAddonById(id);
    if (addon == null) return null;
    return AddonConfig.fromDatabase(addon);
  }

  /// Enable addon
  Future<bool> enableAddon(String id) async {
    final result = await _database.toggleAddonEnabled(id, true);
    return result > 0;
  }

  /// Disable addon
  Future<bool> disableAddon(String id) async {
    final result = await _database.toggleAddonEnabled(id, false);
    return result > 0;
  }

  /// Remove addon
  Future<bool> removeAddon(String id) async {
    final result = await _database.deleteAddon(id);
    return result > 0;
  }

  /// Update addon manifest (refresh from URL)
  Future<AddonConfig> updateAddon(String id) async {
    final existing = await getAddon(id);
    if (existing == null) {
      throw Exception('Addon not found: $id');
    }

    final updated = await AddonInstaller.updateAddon(existing);
    final rowsAffected = await _database.updateAddon(updated.toCompanion());
    if (rowsAffected == 0) {
      throw Exception('Failed to update addon: no rows affected');
    }
    return updated;
  }

  /// Get only enabled addons
  Future<List<AddonConfig>> getEnabledAddons() async {
    final addons = await _database.getEnabledAddons();
    return addons.map((addon) => AddonConfig.fromDatabase(addon)).toList();
  }

  /// Get manifest from addon config
  AddonManifest getManifest(AddonConfig addon) {
    final json = jsonDecode(addon.manifestData) as Map<String, dynamic>;
    return AddonManifest.fromJson(json);
  }
}

