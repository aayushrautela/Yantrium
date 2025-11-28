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

// New models from NuvioStreaming's approach

/// Content data for scrobbling operations
class TraktContentData {
  final String type; // 'movie' or 'episode'
  final String imdbId;
  final String title;
  final int year;
  final int? season;
  final int? episode;
  final String? showTitle;
  final int? showYear;
  final String? showImdbId;

  const TraktContentData({
    required this.type,
    required this.imdbId,
    required this.title,
    required this.year,
    this.season,
    this.episode,
    this.showTitle,
    this.showYear,
    this.showImdbId,
  });

  /// Generate unique key for this content
  String getContentKey() {
    if (type == 'movie') {
      return 'movie:$imdbId';
    } else {
      return 'episode:${showImdbId ?? imdbId}:S${season}E${episode}';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'imdbId': imdbId,
      'title': title,
      'year': year,
      'season': season,
      'episode': episode,
      'showTitle': showTitle,
      'showYear': showYear,
      'showImdbId': showImdbId,
    };
  }
}

/// Scrobble response with conflict handling
class TraktScrobbleResponse {
  final int id;
  final String action; // 'start' | 'pause' | 'scrobble' | 'conflict'
  final double progress;
  final Map<String, dynamic>? sharing;
  final TraktMovie? movie;
  final TraktEpisode? episode;
  final TraktShow? show;
  final bool alreadyScrobbled;

  const TraktScrobbleResponse({
    required this.id,
    required this.action,
    required this.progress,
    this.sharing,
    this.movie,
    this.episode,
    this.show,
    this.alreadyScrobbled = false,
  });

  factory TraktScrobbleResponse.fromJson(Map<String, dynamic> json) {
    return TraktScrobbleResponse(
      id: json['id'] as int? ?? 0,
      action: json['action'] as String? ?? 'scrobble',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      sharing: json['sharing'] as Map<String, dynamic>?,
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      episode: json['episode'] != null ? TraktEpisode.fromJson(json['episode']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
      alreadyScrobbled: json['alreadyScrobbled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'progress': progress,
      if (sharing != null) 'sharing': sharing,
      if (movie != null) 'movie': movie!.toJson(),
      if (episode != null) 'episode': episode!.toJson(),
      if (show != null) 'show': show!.toJson(),
      if (alreadyScrobbled) 'alreadyScrobbled': alreadyScrobbled,
    };
  }
}

/// Playback progress item
class TraktPlaybackItem {
  final double progress;
  final DateTime pausedAt;
  final int id;
  final String type; // 'movie' | 'episode'
  final TraktMovie? movie;
  final TraktEpisode? episode;
  final TraktShow? show;

  const TraktPlaybackItem({
    required this.progress,
    required this.pausedAt,
    required this.id,
    required this.type,
    this.movie,
    this.episode,
    this.show,
  });

  factory TraktPlaybackItem.fromJson(Map<String, dynamic> json) {
    return TraktPlaybackItem(
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      pausedAt: DateTime.parse(json['paused_at'] as String),
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      episode: json['episode'] != null ? TraktEpisode.fromJson(json['episode']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'progress': progress,
      'paused_at': pausedAt.toIso8601String(),
      'id': id,
      'type': type,
      if (movie != null) 'movie': movie!.toJson(),
      if (episode != null) 'episode': episode!.toJson(),
      if (show != null) 'show': show!.toJson(),
    };
  }
}

/// Watchlist item with images
class TraktWatchlistItemWithImages {
  final String type;
  final TraktMovie? movie;
  final TraktShow? show;
  final DateTime listedAt;
  final TraktImages? images;

  const TraktWatchlistItemWithImages({
    required this.type,
    this.movie,
    this.show,
    required this.listedAt,
    this.images,
  });

  factory TraktWatchlistItemWithImages.fromJson(Map<String, dynamic> json) {
    return TraktWatchlistItemWithImages(
      type: json['type'] as String? ?? '',
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
      listedAt: DateTime.parse(json['listed_at'] as String),
      images: json['images'] != null ? TraktImages.fromJson(json['images']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (movie != null) 'movie': movie!.toJson(),
      if (show != null) 'show': show!.toJson(),
      'listed_at': listedAt.toIso8601String(),
      if (images != null) 'images': images!.toJson(),
    };
  }
}

/// Collection item with images
class TraktCollectionItemWithImages {
  final String type;
  final TraktMovie? movie;
  final TraktShow? show;
  final DateTime collectedAt;
  final TraktImages? images;

  const TraktCollectionItemWithImages({
    required this.type,
    this.movie,
    this.show,
    required this.collectedAt,
    this.images,
  });

  factory TraktCollectionItemWithImages.fromJson(Map<String, dynamic> json) {
    return TraktCollectionItemWithImages(
      type: json['type'] as String? ?? '',
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
      collectedAt: DateTime.parse(json['collected_at'] as String),
      images: json['images'] != null ? TraktImages.fromJson(json['images']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (movie != null) 'movie': movie!.toJson(),
      if (show != null) 'show': show!.toJson(),
      'collected_at': collectedAt.toIso8601String(),
      if (images != null) 'images': images!.toJson(),
    };
  }
}

/// Rating item with images
class TraktRatingItemWithImages {
  final String type;
  final TraktMovie? movie;
  final TraktShow? show;
  final int rating;
  final DateTime ratedAt;
  final TraktImages? images;

  const TraktRatingItemWithImages({
    required this.type,
    this.movie,
    this.show,
    required this.rating,
    required this.ratedAt,
    this.images,
  });

  factory TraktRatingItemWithImages.fromJson(Map<String, dynamic> json) {
    return TraktRatingItemWithImages(
      type: json['type'] as String? ?? '',
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
      rating: json['rating'] as int? ?? 0,
      ratedAt: DateTime.parse(json['rated_at'] as String),
      images: json['images'] != null ? TraktImages.fromJson(json['images']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (movie != null) 'movie': movie!.toJson(),
      if (show != null) 'show': show!.toJson(),
      'rating': rating,
      'rated_at': ratedAt.toIso8601String(),
      if (images != null) 'images': images!.toJson(),
    };
  }
}

/// Trakt watched item (for watched history)
class TraktWatchedItem {
  final TraktMovie? movie;
  final TraktShow? show;
  final int plays;
  final DateTime lastWatchedAt;
  final List<Map<String, dynamic>>? seasons;

  const TraktWatchedItem({
    this.movie,
    this.show,
    required this.plays,
    required this.lastWatchedAt,
    this.seasons,
  });

  factory TraktWatchedItem.fromJson(Map<String, dynamic> json) {
    // Helper to deeply convert seasons/episodes data
    List<Map<String, dynamic>>? parseSeasons(List<dynamic>? seasonsList) {
      if (seasonsList == null) return null;
      return seasonsList.map((s) => Map<String, dynamic>.from(s)).toList();
    }

    return TraktWatchedItem(
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
      plays: json['plays'] as int? ?? 0,
      lastWatchedAt: DateTime.parse(json['last_watched_at'] as String),
      seasons: parseSeasons(json['seasons'] as List<dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (movie != null) 'movie': movie!.toJson(),
      if (show != null) 'show': show!.toJson(),
      'plays': plays,
      'last_watched_at': lastWatchedAt.toIso8601String(),
      if (seasons != null) 'seasons': seasons,
    };
  }
}

/// Trakt images
class TraktImages {
  final List<String>? fanart;
  final List<String>? poster;
  final List<String>? logo;
  final List<String>? clearart;
  final List<String>? banner;
  final List<String>? thumb;

  const TraktImages({
    this.fanart,
    this.poster,
    this.logo,
    this.clearart,
    this.banner,
    this.thumb,
  });

  factory TraktImages.fromJson(Map<String, dynamic> json) {
    return TraktImages(
      fanart: (json['fanart'] as List<dynamic>?)?.cast<String>(),
      poster: (json['poster'] as List<dynamic>?)?.cast<String>(),
      logo: (json['logo'] as List<dynamic>?)?.cast<String>(),
      clearart: (json['clearart'] as List<dynamic>?)?.cast<String>(),
      banner: (json['banner'] as List<dynamic>?)?.cast<String>(),
      thumb: (json['thumb'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (fanart != null) 'fanart': fanart,
      if (poster != null) 'poster': poster,
      if (logo != null) 'logo': logo,
      if (clearart != null) 'clearart': clearart,
      if (banner != null) 'banner': banner,
      if (thumb != null) 'thumb': thumb,
    };
  }

  /// Get the first poster URL with https prefix
  String? getPosterUrl() {
    if (poster == null || poster!.isEmpty) return null;
    final posterPath = poster![0];
    return posterPath.startsWith('http') ? posterPath : 'https://${posterPath}';
  }

  /// Get the first fanart URL with https prefix
  String? getFanartUrl() {
    if (fanart == null || fanart!.isEmpty) return null;
    final fanartPath = fanart![0];
    return fanartPath.startsWith('http') ? fanartPath : 'https://${fanartPath}';
  }
}

/// History item for watch history
class TraktHistoryItem {
  final int id;
  final DateTime watchedAt;
  final String action; // 'scrobble' | 'checkin' | 'watch'
  final String type; // 'movie' | 'episode'
  final TraktMovie? movie;
  final TraktEpisode? episode;
  final TraktShow? show;

  const TraktHistoryItem({
    required this.id,
    required this.watchedAt,
    required this.action,
    required this.type,
    this.movie,
    this.episode,
    this.show,
  });

  factory TraktHistoryItem.fromJson(Map<String, dynamic> json) {
    return TraktHistoryItem(
      id: json['id'] as int? ?? 0,
      watchedAt: DateTime.parse(json['watched_at'] as String),
      action: json['action'] as String? ?? 'watch',
      type: json['type'] as String? ?? '',
      movie: json['movie'] != null ? TraktMovie.fromJson(json['movie']) : null,
      episode: json['episode'] != null ? TraktEpisode.fromJson(json['episode']) : null,
      show: json['show'] != null ? TraktShow.fromJson(json['show']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'watched_at': watchedAt.toIso8601String(),
      'action': action,
      'type': type,
      if (movie != null) 'movie': movie!.toJson(),
      if (episode != null) 'episode': episode!.toJson(),
      if (show != null) 'show': show!.toJson(),
    };
  }
}

/// Payload for removing items from history
class TraktHistoryRemovePayload {
  final List<Map<String, dynamic>>? movies;
  final List<Map<String, dynamic>>? shows;
  final List<Map<String, dynamic>>? seasons;
  final List<Map<String, dynamic>>? episodes;
  final List<int>? ids;

  const TraktHistoryRemovePayload({
    this.movies,
    this.shows,
    this.seasons,
    this.episodes,
    this.ids,
  });

  Map<String, dynamic> toJson() {
    return {
      if (movies != null) 'movies': movies,
      if (shows != null) 'shows': shows,
      if (seasons != null) 'seasons': seasons,
      if (episodes != null) 'episodes': episodes,
      if (ids != null) 'ids': ids,
    };
  }
}

/// Response for history removal
class TraktHistoryRemoveResponse {
  final Map<String, int> deleted;
  final Map<String, List<Map<String, dynamic>>> notFound;

  const TraktHistoryRemoveResponse({
    required this.deleted,
    required this.notFound,
  });

  factory TraktHistoryRemoveResponse.fromJson(Map<String, dynamic> json) {
    final deletedJson = json['deleted'] as Map<String, dynamic>? ?? {};
    final notFoundJson = json['not_found'] as Map<String, dynamic>? ?? {};

    return TraktHistoryRemoveResponse(
      deleted: Map<String, int>.from(deletedJson),
      notFound: Map<String, List<Map<String, dynamic>>>.from(notFoundJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deleted': deleted,
      'not_found': notFound,
    };
  }
}

/// Comment types for content
class TraktComment {
  final int id;
  final String comment;
  final bool spoiler;
  final bool review;
  final int parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int replies;
  final int likes;
  final Map<String, dynamic>? userStats;
  final TraktUser user;

  const TraktComment({
    required this.id,
    required this.comment,
    required this.spoiler,
    required this.review,
    required this.parentId,
    required this.createdAt,
    required this.updatedAt,
    required this.replies,
    required this.likes,
    this.userStats,
    required this.user,
  });

  factory TraktComment.fromJson(Map<String, dynamic> json) {
    return TraktComment(
      id: json['id'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      spoiler: json['spoiler'] as bool? ?? false,
      review: json['review'] as bool? ?? false,
      parentId: json['parent_id'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      replies: json['replies'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      userStats: json['user_stats'] as Map<String, dynamic>?,
      user: TraktUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comment': comment,
      'spoiler': spoiler,
      'review': review,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'replies': replies,
      'likes': likes,
      if (userStats != null) 'user_stats': userStats,
      'user': user.toJson(),
    };
  }
}

/// Simplified comment type for content
class TraktContentComment {
  final int id;
  final String comment;
  final bool spoiler;
  final bool review;
  final int parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int replies;
  final int likes;
  final String language;
  final int? userRating;
  final Map<String, dynamic>? userStats;
  final TraktUser user;

  const TraktContentComment({
    required this.id,
    required this.comment,
    required this.spoiler,
    required this.review,
    required this.parentId,
    required this.createdAt,
    required this.updatedAt,
    required this.replies,
    required this.likes,
    required this.language,
    this.userRating,
    this.userStats,
    required this.user,
  });

  factory TraktContentComment.fromJson(Map<String, dynamic> json) {
    return TraktContentComment(
      id: json['id'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      spoiler: json['spoiler'] as bool? ?? false,
      review: json['review'] as bool? ?? false,
      parentId: json['parent_id'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      replies: json['replies'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      language: json['language'] as String? ?? 'en',
      userRating: json['user_rating'] as int?,
      userStats: json['user_stats'] as Map<String, dynamic>?,
      user: TraktUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'comment': comment,
      'spoiler': spoiler,
      'review': review,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'replies': replies,
      'likes': likes,
      'language': language,
      if (userRating != null) 'user_rating': userRating,
      if (userStats != null) 'user_stats': userStats,
      'user': user.toJson(),
    };
  }
}

// Add toJson methods to existing models that need them
extension TraktMovieExtension on TraktMovie {
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (year != null) 'year': year,
      'ids': ids.toJson(),
    };
  }
}

extension TraktShowExtension on TraktShow {
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (year != null) 'year': year,
      'ids': ids.toJson(),
    };
  }
}

extension TraktEpisodeExtension on TraktEpisode {
  Map<String, dynamic> toJson() {
    return {
      'season': season,
      'number': number,
      'title': title,
      'ids': ids.toJson(),
      if (runtime != null) 'runtime': runtime,
    };
  }
}

extension TraktUserExtension on TraktUser {
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      if (slug != null) 'slug': slug,
      'private': private,
      if (name != null) 'name': name,
      'vip': vip,
      'vip_ep': vipEp,
      'ids': ids.toJson(),
    };
  }
}

