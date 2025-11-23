/// Represents a single item in a catalog response
class CatalogItem {
  final String id; // Content ID (e.g., "tt1234567" or "tmdb:123")
  final String type; // "movie" or "series"
  final String name; // Title
  final String? poster; // Poster image URL
  final String? background; // Background image URL
  final String? logo;
  final String? description;
  final String? releaseInfo;
  final List<String>? genres;
  final String? imdbRating;
  final String? runtime;

  CatalogItem({
    required this.id,
    required this.type,
    required this.name,
    this.poster,
    this.background,
    this.logo,
    this.description,
    this.releaseInfo,
    this.genres,
    this.imdbRating,
    this.runtime,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    // Safely extract required fields with null checks
    final id = json['id'];
    final type = json['type'];
    final name = json['name'];
    
    // Validate required fields
    if (id == null || type == null || name == null) {
      throw FormatException(
        'CatalogItem missing required fields: id=$id, type=$type, name=$name',
      );
    }
    
    // Safely extract optional fields
    String? safeString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      return value.toString();
    }
    
    List<String>? safeStringList(dynamic value) {
      if (value == null) return null;
      if (value is! List) return null;
      return value
          .map((e) => e?.toString())
          .whereType<String>()
          .toList();
    }
    
    return CatalogItem(
      id: id.toString(),
      type: type.toString(),
      name: name.toString(),
      poster: safeString(json['poster']),
      background: safeString(json['background']),
      logo: safeString(json['logo']),
      description: safeString(json['description']),
      releaseInfo: safeString(json['releaseInfo']),
      genres: safeStringList(json['genres']),
      imdbRating: safeString(json['imdbRating']),
      runtime: safeString(json['runtime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      if (poster != null) 'poster': poster,
      if (background != null) 'background': background,
      if (logo != null) 'logo': logo,
      if (description != null) 'description': description,
      if (releaseInfo != null) 'releaseInfo': releaseInfo,
      if (genres != null) 'genres': genres,
      if (imdbRating != null) 'imdbRating': imdbRating,
      if (runtime != null) 'runtime': runtime,
    };
  }

  /// Create a copy of this CatalogItem with updated fields
  CatalogItem copyWith({
    String? id,
    String? type,
    String? name,
    String? poster,
    String? background,
    String? logo,
    String? description,
    String? releaseInfo,
    List<String>? genres,
    String? imdbRating,
    String? runtime,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      poster: poster ?? this.poster,
      background: background ?? this.background,
      logo: logo ?? this.logo,
      description: description ?? this.description,
      releaseInfo: releaseInfo ?? this.releaseInfo,
      genres: genres ?? this.genres,
      imdbRating: imdbRating ?? this.imdbRating,
      runtime: runtime ?? this.runtime,
    );
  }
}

