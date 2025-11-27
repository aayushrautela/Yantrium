/// Model classes for Trakt API responses
class TraktIds {
  final String? trakt;
  final String? slug;
  final String? imdb;
  final String? tmdb;

  const TraktIds({
    this.trakt,
    this.slug,
    this.imdb,
    this.tmdb,
  });

  factory TraktIds.fromJson(Map<String, dynamic> json) {
    return TraktIds(
      trakt: json['trakt']?.toString(),
      slug: json['slug']?.toString(),
      imdb: json['imdb']?.toString(),
      tmdb: json['tmdb']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (trakt != null) 'trakt': trakt,
      if (slug != null) 'slug': slug,
      if (imdb != null) 'imdb': imdb,
      if (tmdb != null) 'tmdb': tmdb,
    };
  }
}

class TraktMovie {
  final String title;
  final int? year;
  final TraktIds ids;

  const TraktMovie({
    required this.title,
    this.year,
    required this.ids,
  });

  factory TraktMovie.fromJson(Map<String, dynamic> json) {
    return TraktMovie(
      title: json['title'] as String? ?? '',
      year: json['year'] as int?,
      ids: TraktIds.fromJson(json['ids'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class TraktShow {
  final String title;
  final int? year;
  final TraktIds ids;

  const TraktShow({
    required this.title,
    this.year,
    required this.ids,
  });

  factory TraktShow.fromJson(Map<String, dynamic> json) {
    return TraktShow(
      title: json['title'] as String? ?? '',
      year: json['year'] as int?,
      ids: TraktIds.fromJson(json['ids'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class TraktEpisode {
  final int season;
  final int number;
  final String title;
  final TraktIds ids;
  final int? runtime;

  const TraktEpisode({
    required this.season,
    required this.number,
    required this.title,
    required this.ids,
    this.runtime,
  });

  factory TraktEpisode.fromJson(Map<String, dynamic> json) {
    return TraktEpisode(
      season: json['season'] as int? ?? 0,
      number: json['number'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      ids: TraktIds.fromJson(json['ids'] as Map<String, dynamic>? ?? {}),
      runtime: json['runtime'] as int?,
    );
  }
}

class TraktWatchlistItem {
  final String type;
  final TraktMovie? movie;
  final TraktShow? show;
  final DateTime? listedAt;
  final int? rank;

  const TraktWatchlistItem({
    required this.type,
    this.movie,
    this.show,
    this.listedAt,
    this.rank,
  });

  factory TraktWatchlistItem.fromJson(Map<String, dynamic> json) {
    return TraktWatchlistItem(
      type: json['type'] as String? ?? '',
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
      listedAt: json['listed_at'] != null ? DateTime.parse(json['listed_at']) : null,
      rank: json['rank'] as int?,
    );
  }
}

class TraktWatchHistoryItem {
  final int? id;
  final DateTime watchedAt;
  final String action;
  final String type;
  final TraktMovie? movie;
  final TraktShow? show;
  final TraktEpisode? episode;

  const TraktWatchHistoryItem({
    this.id,
    required this.watchedAt,
    required this.action,
    required this.type,
    this.movie,
    this.show,
    this.episode,
  });

  factory TraktWatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return TraktWatchHistoryItem(
      id: json['id'] as int?,
      watchedAt: DateTime.parse(json['watched_at'] as String),
      action: json['action'] as String? ?? '',
      type: json['type'] as String? ?? '',
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
      episode: json['episode'] != null ? TraktEpisode.fromJson(json['episode']) : null,
    );
  }
}

class TraktPlaybackProgressItem {
  final double progress;
  final DateTime pausedAt;
  final String type;
  final TraktMovie? movie;
  final TraktShow? show;
  final TraktEpisode? episode;

  const TraktPlaybackProgressItem({
    required this.progress,
    required this.pausedAt,
    required this.type,
    this.movie,
    this.show,
    this.episode,
  });

  factory TraktPlaybackProgressItem.fromJson(Map<String, dynamic> json) {
    return TraktPlaybackProgressItem(
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      pausedAt: DateTime.parse(json['paused_at'] as String),
      type: json['type'] as String? ?? '',
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
      episode: json['episode'] != null ? TraktEpisode.fromJson(json['episode']) : null,
    );
  }
}

class TraktUser {
  final String username;
  final String? slug;
  final bool private;
  final String? name;
  final bool vip;
  final bool vipEp;
  final TraktIds ids;

  const TraktUser({
    required this.username,
    this.slug,
    required this.private,
    this.name,
    required this.vip,
    required this.vipEp,
    required this.ids,
  });

  factory TraktUser.fromJson(Map<String, dynamic> json) {
    return TraktUser(
      username: json['username'] as String? ?? '',
      slug: json['slug'] as String?,
      private: json['private'] as bool? ?? false,
      name: json['name'] as String?,
      vip: json['vip'] as bool? ?? false,
      vipEp: json['vip_ep'] as bool? ?? false,
      ids: TraktIds.fromJson(json['ids'] as Map<String, dynamic>? ?? {}),
    );
  }
}


