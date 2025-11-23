import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

/// Represents an installed addon in the system
class AddonConfig {
  final String id;
  final String name;
  final String version;
  final String? description;
  final String manifestUrl;
  final String baseUrl;
  final bool enabled;
  final String manifestData;
  final List<dynamic> resources;
  final List<String> types;
  final DateTime createdAt;
  final DateTime updatedAt;

  AddonConfig({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    required this.manifestUrl,
    required this.baseUrl,
    required this.enabled,
    required this.manifestData,
    required this.resources,
    required this.types,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert from database entity
  factory AddonConfig.fromDatabase(Addon addon) {
    return AddonConfig(
      id: addon.id,
      name: addon.name,
      version: addon.version,
      description: addon.description,
      manifestUrl: addon.manifestUrl,
      baseUrl: addon.baseUrl,
      enabled: addon.enabled,
      manifestData: addon.manifestData,
      resources: jsonDecode(addon.resources) as List<dynamic>,
      types: (jsonDecode(addon.types) as List<dynamic>).cast<String>(),
      createdAt: addon.createdAt,
      updatedAt: addon.updatedAt,
    );
  }

  /// Convert to database companion for insert/update
  AddonsCompanion toCompanion() {
    return AddonsCompanion(
      id: Value(id),
      name: Value(name),
      version: Value(version),
      description: Value(description),
      manifestUrl: Value(manifestUrl),
      baseUrl: Value(baseUrl),
      enabled: Value(enabled),
      manifestData: Value(manifestData),
      resources: Value(jsonEncode(resources)),
      types: Value(jsonEncode(types)),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}


