import '../../features/library/models/cast_crew_member.dart';
import '../models/tmdb_models.dart';
import 'configuration_service.dart';
import 'logging_service.dart';
import 'tmdb_metadata_service.dart';

/// Service for TMDB data enrichment operations
class TmdbEnrichmentService {
  final LoggingService _logger = LoggingService.instance;
  final ConfigurationService _config = ConfigurationService.instance;

  /// Get full image URL from TMDB path
  String getImageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path; // Already full URL
    return '${_config.tmdbImageBaseUrl}/$size$path';
  }

  /// Convert TMDB movie data to CatalogItem format
  Map<String, dynamic>? convertMovieToCatalogItem(
    TmdbMovie tmdbData,
    String originalId,
  ) {
    try {
      // Use centralized extractor for cast and crew
      final castAndCrew = _extractCastAndCrew(tmdbData);
      final cast = castAndCrew['cast']!;
      final crew = castAndCrew['crew']!;

      final directors = crew
          .where((person) => person.character?.toLowerCase() == 'director')
          .map((person) => person.name)
          .toList();

      final genres = tmdbData.genres.map((g) => g.name).toList();

      final videos = tmdbData.videos?['results'] as List<dynamic>?;
      final trailers = videos
          ?.where((v) => v['type'] == 'Trailer' && v['site'] == 'YouTube')
          .map((v) => {
                'name': v['name'],
                'key': v['key'],
                'site': v['site'],
              })
          .toList();

      // Safely extract logo from images
      final logoUrl = _extractLogoUrl(tmdbData);

      // Use centralized extractor for additional metadata
      final additionalMetadata = _extractAdditionalMetadata(tmdbData, 'movie');
      final runtime = additionalMetadata['runtime'] as int?;

      // Convert cast/crew to JSON format for CatalogItem
      final fullCast = cast.map((c) => {
            'name': c.name,
            'character': c.character,
            'profile_path': c.profileImageUrl,
            'order': c.order,
          }).toList();

      final fullCrew = crew.map((c) => {
            'name': c.name,
            'job': c.character,
            'profile_path': c.profileImageUrl,
          }).toList();

      return {
        'id': originalId,
        'type': 'movie',
        'name': tmdbData.title,
        'poster': getImageUrl(tmdbData.posterPath),
        'background': getImageUrl(tmdbData.backdropPath, size: 'w1280'),
        'logo': logoUrl,
        'description': tmdbData.overview,
        'releaseInfo': tmdbData.releaseDate,
        'genres': genres,
        'imdbRating': tmdbData.voteAverage.toString(),
        'runtime': runtime?.toString(),
        'director': directors,
        'cast': cast.take(10).map((c) => c.name).toList(),
        'castFull': fullCast,
        'crewFull': fullCrew,
        'videos': trailers,
      };
    } catch (e) {
      _logger.error('Error converting movie to catalog item', e);
      return null;
    }
  }

  /// Convert TMDB TV data to CatalogItem format
  Map<String, dynamic>? convertTvToCatalogItem(
    TmdbTvShow tmdbData,
    String originalId,
  ) {
    try {
      // Use centralized extractor for cast and crew
      final castAndCrew = _extractCastAndCrew(tmdbData);
      final cast = castAndCrew['cast']!;
      final crew = castAndCrew['crew']!;

      final creators = crew
          .where((person) => person.character?.toLowerCase() == 'creator')
          .map((person) => person.name)
          .toList();

      final genres = tmdbData.genres.map((g) => g.name).toList();

      final videos = tmdbData.videos?['results'] as List<dynamic>?;
      final trailers = videos
          ?.where((v) => v['type'] == 'Trailer' && v['site'] == 'YouTube')
          .map((v) => {
                'name': v['name'],
                'key': v['key'],
                'site': v['site'],
              })
          .toList();

      final firstAirDate = tmdbData.firstAirDate;
      final lastAirDate = tmdbData.lastAirDate;
      String? releaseInfo;
      if (firstAirDate != null) {
        releaseInfo = lastAirDate != null && lastAirDate != firstAirDate
            ? '$firstAirDate - $lastAirDate'
            : firstAirDate;
      }

      // Safely extract logo from images
      final logoUrl = _extractLogoUrl(tmdbData);

      // Use centralized extractor for additional metadata
      final additionalMetadata = _extractAdditionalMetadata(tmdbData, 'series');
      final runtime = additionalMetadata['runtime'] as int?;

      // Convert cast/crew to JSON format for CatalogItem
      final fullCast = cast.map((c) => {
            'name': c.name,
            'character': c.character,
            'profile_path': c.profileImageUrl,
            'order': c.order,
          }).toList();

      final fullCrew = crew.map((c) => {
            'name': c.name,
            'job': c.character,
            'profile_path': c.profileImageUrl,
          }).toList();

      return {
        'id': originalId,
        'type': 'series',
        'name': tmdbData.name,
        'poster': getImageUrl(tmdbData.posterPath),
        'background': getImageUrl(tmdbData.backdropPath, size: 'w1280'),
        'logo': logoUrl,
        'description': tmdbData.overview,
        'releaseInfo': releaseInfo,
        'genres': genres,
        'imdbRating': tmdbData.voteAverage.toString(),
        'runtime': runtime?.toString(),
        'director': creators,
        'cast': cast.take(10).map((c) => c.name).toList(),
        'castFull': fullCast,
        'crewFull': fullCrew,
        'videos': trailers,
      };
    } catch (e) {
      _logger.error('Error converting TV show to catalog item', e);
      return null;
    }
  }

  /// Enrich CatalogItem with TMDB metadata
  Future<Map<String, dynamic>?> enrichCatalogItem(
    String contentId,
    String type, {
    Map<String, dynamic>? cachedTmdbData,
    TmdbMetadataService? metadataService,
  }) async {
    final tmdbService = metadataService ?? TmdbMetadataService();

    // Use cached data if provided
    Map<String, dynamic>? tmdbData = cachedTmdbData;

    // Only fetch if no cached data provided
    if (tmdbData == null) {
      // Try to extract TMDB ID
      int? tmdbId;

      // If contentId is already a TMDB ID format
      if (contentId.startsWith('tmdb:')) {
        tmdbId = int.tryParse(contentId.substring(5));
      }

      // If IMDB ID, search for TMDB ID
      if (tmdbId == null && contentId.startsWith('tt')) {
        tmdbId = await tmdbService.getTmdbIdFromImdb(contentId);
      }

      if (tmdbId == null) {
        _logger.debug('Could not find TMDB ID for content: $contentId');
        return null; // Can't find TMDB ID
      }

      // Fetch metadata based on type (will use cache if available)
      if (type == 'movie') {
        final metadata = await tmdbService.getMovieMetadata(tmdbId);
        tmdbData = metadata?.toJson();
      } else if (type == 'series') {
        final metadata = await tmdbService.getTvMetadata(tmdbId);
        tmdbData = metadata?.toJson();
      }
    }

    if (tmdbData != null) {
      if (type == 'movie') {
        final movie = TmdbMovie.fromJson(tmdbData);
        return convertMovieToCatalogItem(movie, contentId);
      } else if (type == 'series') {
        final tv = TmdbTvShow.fromJson(tmdbData);
        return convertTvToCatalogItem(tv, contentId);
      }
    }

    return null;
  }

  /// Extract cast and crew data from TMDB response
  Map<String, List<CastCrewMember>> _extractCastAndCrew(dynamic tmdbData) {
    try {
      Map<String, dynamic>? credits;
      if (tmdbData is TmdbMovie) {
        credits = tmdbData.credits;
      } else if (tmdbData is TmdbTvShow) {
        credits = tmdbData.credits;
      }

      final cast = credits?['cast'] as List<dynamic>?;
      final crew = credits?['crew'] as List<dynamic>?;

      final parsedCast = (cast ?? [])
          .map((c) {
            try {
              if (c is Map<String, dynamic>) {
                return CastCrewMember.fromJson(c);
              }
              return null;
            } catch (e) {
              _logger.debug('Error parsing cast member', e);
              return null;
            }
          })
          .whereType<CastCrewMember>()
          .toList();

      final parsedCrew = (crew ?? [])
          .map((c) {
            try {
              if (c is Map<String, dynamic>) {
                return CastCrewMember.fromJson(c);
              }
              return null;
            } catch (e) {
              _logger.debug('Error parsing crew member', e);
              return null;
            }
          })
          .whereType<CastCrewMember>()
          .toList();

      return {
        'cast': parsedCast,
        'crew': parsedCrew,
      };
    } catch (e) {
      _logger.error('Error extracting cast and crew', e);
      return {
        'cast': <CastCrewMember>[],
        'crew': <CastCrewMember>[],
      };
    }
  }

  /// Extract logo URL from TMDB images data
  String _extractLogoUrl(dynamic tmdbData) {
    try {
      final images = (tmdbData is TmdbMovie || tmdbData is TmdbTvShow)
          ? tmdbData.images
          : tmdbData['images'] as Map<String, dynamic>?;

      final logos = images?['logos'] as List<dynamic>?;

      if (logos != null && logos.isNotEmpty) {
        // Smart logo selection: prioritize English logos
        Map<String, dynamic>? preferredLogo;
        Map<String, dynamic>? englishLogo;
        Map<String, dynamic>? usEnglishLogo;

        for (int i = 0; i < logos.length; i++) {
          final logo = logos[i];
          final logoMap = logo as Map<String, dynamic>?;
          if (logoMap != null) {
            final country = logoMap['iso_3166_1'] as String?;
            final language = logoMap['iso_639_1'] as String?;
            final filePath = logoMap['file_path'] as String?;

            // Priority 1: US + English (best match)
            if (country == 'US' && language == 'en') {
              usEnglishLogo = logoMap;
              break; // Found best match, stop searching
            }
            // Priority 2: Any English logo (language='en', any country)
            else if (language == 'en') {
              englishLogo ??= logoMap; // Keep first English logo found
            }
            // Fallback: First available logo (keep as last resort)
            preferredLogo ??= logoMap;
          }
        }

        // Select in priority order: US/English > English > First available
        preferredLogo = usEnglishLogo ?? englishLogo ?? preferredLogo;
        final logoPath = preferredLogo?['file_path'] as String?;

        return getImageUrl(logoPath, size: 'w500');
      }
    } catch (e) {
      _logger.error('Error extracting logo', e);
    }
    return '';
  }

  /// Extract additional metadata (budget, revenue, tagline, etc.)
  Map<String, dynamic> _extractAdditionalMetadata(dynamic tmdbData, String type) {
    try {
      if (tmdbData is TmdbMovie) {
        return {
          'budget': tmdbData.budget,
          'revenue': tmdbData.revenue,
          'tagline': tmdbData.tagline,
          'voteAverage': tmdbData.voteAverage,
          'voteCount': tmdbData.voteCount,
          'popularity': tmdbData.popularity,
          'runtime': tmdbData.runtime,
        };
      } else if (tmdbData is TmdbTvShow) {
        return {
          'budget': null,
          'revenue': null,
          'tagline': tmdbData.tagline,
          'voteAverage': tmdbData.voteAverage,
          'voteCount': tmdbData.voteCount,
          'popularity': tmdbData.popularity,
          'runtime': tmdbData.episodeRunTime.isNotEmpty ? tmdbData.episodeRunTime.first : null,
          'numberOfSeasons': tmdbData.numberOfSeasons,
          'numberOfEpisodes': tmdbData.numberOfEpisodes,
        };
      }

      // Fallback for raw Map data
      final budget = tmdbData['budget'] as int?;
      final revenue = tmdbData['revenue'] as int?;
      final tagline = tmdbData['tagline'] as String?;
      final voteAverage = (tmdbData['vote_average'] as num?)?.toDouble();
      final voteCount = tmdbData['vote_count'] as int?;
      final popularity = (tmdbData['popularity'] as num?)?.toDouble();
      final runtime = type == 'movie'
          ? (tmdbData['runtime'] as int?)
          : ((tmdbData['episode_run_time'] as List<dynamic>?)?.firstOrNull as int?);

      // Series-specific fields
      int? numberOfSeasons;
      int? numberOfEpisodes;
      if (type == 'series') {
        numberOfSeasons = tmdbData['number_of_seasons'] as int?;
        numberOfEpisodes = tmdbData['number_of_episodes'] as int?;
      }

      return {
        'budget': budget,
        'revenue': revenue,
        'tagline': tagline,
        'voteAverage': voteAverage,
        'voteCount': voteCount,
        'popularity': popularity,
        'runtime': runtime,
        'numberOfSeasons': numberOfSeasons,
        'numberOfEpisodes': numberOfEpisodes,
      };
    } catch (e) {
      _logger.error('Error extracting additional metadata', e);
      return {
        'budget': null,
        'revenue': null,
        'tagline': null,
        'voteAverage': null,
        'voteCount': null,
        'popularity': null,
        'runtime': null,
        'numberOfSeasons': null,
        'numberOfEpisodes': null,
      };
    }
  }
}

