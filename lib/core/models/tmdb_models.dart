/// Model classes for TMDB API responses
class TmdbIds {
  final String? imdb;
  final int? tmdb;

  const TmdbIds({
    this.imdb,
    this.tmdb,
  });

  factory TmdbIds.fromJson(Map<String, dynamic> json) {
    return TmdbIds(
      imdb: json['imdb_id'] as String?,
      tmdb: json['id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (imdb != null) 'imdb_id': imdb,
      if (tmdb != null) 'id': tmdb,
    };
  }
}

class TmdbGenre {
  final int id;
  final String name;

  const TmdbGenre({
    required this.id,
    required this.name,
  });

  factory TmdbGenre.fromJson(Map<String, dynamic> json) {
    return TmdbGenre(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class TmdbProductionCompany {
  final int id;
  final String name;
  final String? logoPath;
  final String? originCountry;

  const TmdbProductionCompany({
    required this.id,
    required this.name,
    this.logoPath,
    this.originCountry,
  });

  factory TmdbProductionCompany.fromJson(Map<String, dynamic> json) {
    return TmdbProductionCompany(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      logoPath: json['logo_path'] as String?,
      originCountry: json['origin_country'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (logoPath != null) 'logo_path': logoPath,
      if (originCountry != null) 'origin_country': originCountry,
    };
  }
}

class TmdbSpokenLanguage {
  final String iso6391;
  final String name;

  const TmdbSpokenLanguage({
    required this.iso6391,
    required this.name,
  });

  factory TmdbSpokenLanguage.fromJson(Map<String, dynamic> json) {
    return TmdbSpokenLanguage(
      iso6391: json['iso_639_1'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'iso_639_1': iso6391, 'name': name};
}

class TmdbMovie {
  final bool adult;
  final String? backdropPath;
  final int? budget;
  final List<TmdbGenre> genres;
  final int id;
  final String? imdbId;
  final String originalLanguage;
  final String originalTitle;
  final String overview;
  final double popularity;
  final String? posterPath;
  final List<TmdbProductionCompany> productionCompanies;
  final String? releaseDate;
  final int? revenue;
  final int? runtime;
  final List<TmdbSpokenLanguage> spokenLanguages;
  final String status;
  final String tagline;
  final String title;
  final bool video;
  final double voteAverage;
  final int voteCount;
  
  // Raw JSON data for append_to_response fields (credits, images, videos, external_ids)
  final Map<String, dynamic>? credits;
  final Map<String, dynamic>? images;
  final Map<String, dynamic>? videos;
  final Map<String, dynamic>? externalIds;

  const TmdbMovie({
    required this.adult,
    this.backdropPath,
    this.budget,
    required this.genres,
    required this.id,
    this.imdbId,
    required this.originalLanguage,
    required this.originalTitle,
    required this.overview,
    required this.popularity,
    this.posterPath,
    required this.productionCompanies,
    this.releaseDate,
    this.revenue,
    this.runtime,
    required this.spokenLanguages,
    required this.status,
    required this.tagline,
    required this.title,
    required this.video,
    required this.voteAverage,
    required this.voteCount,
    this.credits,
    this.images,
    this.videos,
    this.externalIds,
  });

  factory TmdbMovie.fromJson(Map<String, dynamic> json) {
    return TmdbMovie(
      adult: json['adult'] as bool? ?? false,
      backdropPath: json['backdrop_path'] as String?,
      budget: json['budget'] as int?,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((g) => TmdbGenre.fromJson(g))
          .toList() ?? [],
      id: json['id'] as int? ?? 0,
      imdbId: json['imdb_id'] as String? ?? json['external_ids']?['imdb_id'] as String?,
      originalLanguage: json['original_language'] as String? ?? '',
      originalTitle: json['original_title'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
      posterPath: json['poster_path'] as String?,
      productionCompanies: (json['production_companies'] as List<dynamic>?)
          ?.map((c) => TmdbProductionCompany.fromJson(c))
          .toList() ?? [],
      releaseDate: json['release_date'] as String?,
      revenue: json['revenue'] as int?,
      runtime: json['runtime'] as int?,
      spokenLanguages: (json['spoken_languages'] as List<dynamic>?)
          ?.map((l) => TmdbSpokenLanguage.fromJson(l))
          .toList() ?? [],
      status: json['status'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      title: json['title'] as String? ?? '',
      video: json['video'] as bool? ?? false,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] as int? ?? 0,
      credits: json['credits'] as Map<String, dynamic>?,
      images: json['images'] as Map<String, dynamic>?,
      videos: json['videos'] as Map<String, dynamic>?,
      externalIds: json['external_ids'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'adult': adult,
      if (backdropPath != null) 'backdrop_path': backdropPath,
      if (budget != null) 'budget': budget,
      'genres': genres.map((g) => {'id': g.id, 'name': g.name}).toList(),
      'id': id,
      if (imdbId != null) 'imdb_id': imdbId,
      'original_language': originalLanguage,
      'original_title': originalTitle,
      'overview': overview,
      'popularity': popularity,
      if (posterPath != null) 'poster_path': posterPath,
      'production_companies': productionCompanies.map((c) => c.toJson()).toList(),
      if (releaseDate != null) 'release_date': releaseDate,
      if (revenue != null) 'revenue': revenue,
      if (runtime != null) 'runtime': runtime,
      'spoken_languages': spokenLanguages.map((l) => l.toJson()).toList(),
      'status': status,
      'tagline': tagline,
      'title': title,
      'video': video,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      if (credits != null) 'credits': credits,
      if (images != null) 'images': images,
      if (videos != null) 'videos': videos,
      if (externalIds != null) 'external_ids': externalIds,
    };
  }
}

class TmdbTvShow {
  final String? backdropPath;
  final List<int> episodeRunTime;
  final String? firstAirDate;
  final List<TmdbGenre> genres;
  final String homepage;
  final int id;
  final bool inProduction;
  final List<String> languages;
  final String? lastAirDate;
  final String name;
  final int numberOfEpisodes;
  final int numberOfSeasons;
  final List<String> originCountry;
  final String originalLanguage;
  final String originalName;
  final String overview;
  final double popularity;
  final String? posterPath;
  final List<TmdbProductionCompany> productionCompanies;
  final String status;
  final String tagline;
  final String type;
  final double voteAverage;
  final int voteCount;
  
  // Raw JSON data for append_to_response fields (credits, images, videos, external_ids)
  final Map<String, dynamic>? credits;
  final Map<String, dynamic>? images;
  final Map<String, dynamic>? videos;
  final Map<String, dynamic>? externalIds;

  const TmdbTvShow({
    this.backdropPath,
    required this.episodeRunTime,
    this.firstAirDate,
    required this.genres,
    required this.homepage,
    required this.id,
    required this.inProduction,
    required this.languages,
    this.lastAirDate,
    required this.name,
    required this.numberOfEpisodes,
    required this.numberOfSeasons,
    required this.originCountry,
    required this.originalLanguage,
    required this.originalName,
    required this.overview,
    required this.popularity,
    this.posterPath,
    required this.productionCompanies,
    required this.status,
    required this.tagline,
    required this.type,
    required this.voteAverage,
    required this.voteCount,
    this.credits,
    this.images,
    this.videos,
    this.externalIds,
  });

  factory TmdbTvShow.fromJson(Map<String, dynamic> json) {
    return TmdbTvShow(
      backdropPath: json['backdrop_path'] as String?,
      episodeRunTime: (json['episode_run_time'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
      firstAirDate: json['first_air_date'] as String?,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((g) => TmdbGenre.fromJson(g))
          .toList() ?? [],
      homepage: json['homepage'] as String? ?? '',
      id: json['id'] as int? ?? 0,
      inProduction: json['in_production'] as bool? ?? false,
      languages: (json['languages'] as List<dynamic>?)
          ?.map((l) => l as String)
          .toList() ?? [],
      lastAirDate: json['last_air_date'] as String?,
      name: json['name'] as String? ?? '',
      numberOfEpisodes: json['number_of_episodes'] as int? ?? 0,
      numberOfSeasons: json['number_of_seasons'] as int? ?? 0,
      originCountry: (json['origin_country'] as List<dynamic>?)
          ?.map((c) => c as String)
          .toList() ?? [],
      originalLanguage: json['original_language'] as String? ?? '',
      originalName: json['original_name'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
      posterPath: json['poster_path'] as String?,
      productionCompanies: (json['production_companies'] as List<dynamic>?)
          ?.map((c) => TmdbProductionCompany.fromJson(c))
          .toList() ?? [],
      status: json['status'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      type: json['type'] as String? ?? '',
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] as int? ?? 0,
      credits: json['credits'] as Map<String, dynamic>?,
      images: json['images'] as Map<String, dynamic>?,
      videos: json['videos'] as Map<String, dynamic>?,
      externalIds: json['external_ids'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (backdropPath != null) 'backdrop_path': backdropPath,
      'episode_run_time': episodeRunTime,
      if (firstAirDate != null) 'first_air_date': firstAirDate,
      'genres': genres.map((g) => g.toJson()).toList(),
      'homepage': homepage,
      'id': id,
      'in_production': inProduction,
      'languages': languages,
      if (lastAirDate != null) 'last_air_date': lastAirDate,
      'name': name,
      'number_of_episodes': numberOfEpisodes,
      'number_of_seasons': numberOfSeasons,
      'origin_country': originCountry,
      'original_language': originalLanguage,
      'original_name': originalName,
      'overview': overview,
      'popularity': popularity,
      if (posterPath != null) 'poster_path': posterPath,
      'production_companies': productionCompanies.map((c) => c.toJson()).toList(),
      'status': status,
      'tagline': tagline,
      'type': type,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      if (credits != null) 'credits': credits,
      if (images != null) 'images': images,
      if (videos != null) 'videos': videos,
      if (externalIds != null) 'external_ids': externalIds,
    };
  }
}

class TmdbSearchResult {
  final int id;
  final String? title;
  final String? name;
  final String? overview;
  final String? releaseDate;
  final String? firstAirDate;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final double popularity;
  final bool adult;
  final String? mediaType;

  const TmdbSearchResult({
    required this.id,
    this.title,
    this.name,
    this.overview,
    this.releaseDate,
    this.firstAirDate,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    required this.voteCount,
    required this.popularity,
    required this.adult,
    this.mediaType,
  });

  factory TmdbSearchResult.fromJson(Map<String, dynamic> json) {
    return TmdbSearchResult(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String?,
      name: json['name'] as String?,
      overview: json['overview'] as String?,
      releaseDate: json['release_date'] as String?,
      firstAirDate: json['first_air_date'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: json['vote_count'] as int? ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
      adult: json['adult'] as bool? ?? false,
      mediaType: json['media_type'] as String?,
    );
  }
}

class TmdbFindResult {
  final List<TmdbSearchResult> movieResults;
  final List<TmdbSearchResult> tvResults;

  const TmdbFindResult({
    required this.movieResults,
    required this.tvResults,
  });

  factory TmdbFindResult.fromJson(Map<String, dynamic> json) {
    return TmdbFindResult(
      movieResults: (json['movie_results'] as List<dynamic>?)
          ?.map((m) => TmdbSearchResult.fromJson(m))
          .toList() ?? [],
      tvResults: (json['tv_results'] as List<dynamic>?)
          ?.map((t) => TmdbSearchResult.fromJson(t))
          .toList() ?? [],
    );
  }
}


