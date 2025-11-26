/// Represents an episode in a TV series
class Episode {
  final int episodeNumber;
  final String name;
  final String? overview;
  final String? stillPath; // Episode image
  final String? airDate;
  final int? runtime; // Duration in minutes
  final double? voteAverage;

  Episode({
    required this.episodeNumber,
    required this.name,
    this.overview,
    this.stillPath,
    this.airDate,
    this.runtime,
    this.voteAverage,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      episodeNumber: json['episode_number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      overview: json['overview'] as String?,
      stillPath: json['still_path'] as String?,
      airDate: json['air_date'] as String?,
      runtime: json['runtime'] as int?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
    );
  }
}

/// Represents a season with its episodes
class Season {
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? posterPath;
  final int episodeCount;
  final String? airDate;
  final List<Episode> episodes;

  Season({
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.posterPath,
    required this.episodeCount,
    this.airDate,
    required this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    final episodesJson = json['episodes'] as List<dynamic>? ?? [];
    return Season(
      seasonNumber: json['season_number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      episodeCount: json['episode_count'] as int? ?? 0,
      airDate: json['air_date'] as String?,
      episodes: episodesJson
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}









