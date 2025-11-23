import 'dart:convert';
import '../models/addon_config.dart';
import 'addon_client.dart';

/// Handles addon installation logic
class AddonInstaller {
  /// Install addon from manifest URL
  /// Returns AddonConfig ready to be saved to database
  static Future<AddonConfig> installAddon(String manifestUrl) async {
    // Fetch manifest
    final manifest = await AddonClient.getManifest(manifestUrl);

    // Validate manifest
    if (!AddonClient.validateManifest(manifest)) {
      throw Exception('Invalid manifest: missing required fields');
    }

    // Extract base URL
    final baseUrl = AddonClient.extractBaseUrl(manifestUrl);

    // Create AddonConfig
    final now = DateTime.now();
    return AddonConfig(
      id: manifest.id,
      name: manifest.name,
      version: manifest.version,
      description: manifest.description,
      manifestUrl: manifestUrl,
      baseUrl: baseUrl,
      enabled: true,
      manifestData: jsonEncode(manifest.toJson()),
      resources: manifest.resources,
      types: manifest.types,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Update addon manifest (refresh from URL)
  static Future<AddonConfig> updateAddon(AddonConfig existingAddon) async {
    // Fetch fresh manifest
    final manifest = await AddonClient.getManifest(existingAddon.manifestUrl);

    // Validate manifest
    if (!AddonClient.validateManifest(manifest)) {
      throw Exception('Invalid manifest: missing required fields');
    }

    // Update AddonConfig (preserve enabled state and creation date)
    return AddonConfig(
      id: existingAddon.id,
      name: manifest.name,
      version: manifest.version,
      description: manifest.description,
      manifestUrl: existingAddon.manifestUrl,
      baseUrl: existingAddon.baseUrl,
      enabled: existingAddon.enabled, // Preserve enabled state
      manifestData: jsonEncode(manifest.toJson()),
      resources: manifest.resources,
      types: manifest.types,
      createdAt: existingAddon.createdAt, // Preserve creation date
      updatedAt: DateTime.now(),
    );
  }
}

