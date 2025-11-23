/// Represents the manifest.json structure from an addon server
class AddonManifest {
  final String id;
  final String version;
  final String name;
  final String? description;
  final List<dynamic> resources; // Can be strings or objects with 'name' field
  final List<String> types;
  final List<CatalogDefinition> catalogs;
  final List<String>? idPrefixes;
  final String? background;
  final String? logo;
  final String? contactEmail;
  final Map<String, dynamic>? behaviorHints;

  AddonManifest({
    required this.id,
    required this.version,
    required this.name,
    this.description,
    required this.resources,
    required this.types,
    required this.catalogs,
    this.idPrefixes,
    this.background,
    this.logo,
    this.contactEmail,
    this.behaviorHints,
  });

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    return AddonManifest(
      id: json['id'] as String,
      version: json['version'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      resources: json['resources'] as List<dynamic>,
      types: (json['types'] as List<dynamic>).cast<String>(),
      catalogs: (json['catalogs'] as List<dynamic>?)
              ?.map((c) => CatalogDefinition.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      idPrefixes: json['idPrefixes'] != null
          ? (json['idPrefixes'] as List<dynamic>).cast<String>()
          : null,
      background: json['background'] as String?,
      logo: json['logo'] as String?,
      contactEmail: json['contactEmail'] as String?,
      behaviorHints: json['behaviorHints'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'name': name,
      if (description != null) 'description': description,
      'resources': resources,
      'types': types,
      'catalogs': catalogs.map((c) => c.toJson()).toList(),
      if (idPrefixes != null) 'idPrefixes': idPrefixes,
      if (background != null) 'background': background,
      if (logo != null) 'logo': logo,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (behaviorHints != null) 'behaviorHints': behaviorHints,
    };
  }
}

/// Defines a catalog available from the addon
class CatalogDefinition {
  final String type; // "movie" or "series"
  final String? id; // Catalog ID (e.g., "tmdb.top", "tmdb.trending")
  final String? name; // Display name
  final int? pageSize;
  final List<Map<String, dynamic>>? extra; // For filtering options

  CatalogDefinition({
    required this.type,
    this.id,
    this.name,
    this.pageSize,
    this.extra,
  });

  factory CatalogDefinition.fromJson(Map<String, dynamic> json) {
    return CatalogDefinition(
      type: json['type'] as String,
      id: json['id'] as String?,
      name: json['name'] as String?,
      pageSize: json['pageSize'] as int?,
      extra: json['extra'] != null
          ? (json['extra'] as List<dynamic>)
              .map((e) => e as Map<String, dynamic>)
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (pageSize != null) 'pageSize': pageSize,
      if (extra != null) 'extra': extra,
    };
  }
}

