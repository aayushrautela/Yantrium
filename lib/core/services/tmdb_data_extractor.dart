import 'package:flutter/foundation.dart';
import '../../features/library/models/cast_crew_member.dart';

/// Utility class for extracting structured data from TMDB API responses
class TmdbDataExtractor {
  /// Extract maturity rating from TMDB data
  /// For movies: extracts from release_dates.results[US].release_dates[].certification
  /// For TV shows: extracts from content_ratings.results[US].rating
  static String? extractMaturityRating(
    Map<String, dynamic> tmdbData,
    String type,
  ) {
    try {
      if (type == 'movie') {
        final releaseDates = tmdbData['release_dates'] as Map<String, dynamic>?;
        if (releaseDates != null) {
          final results = releaseDates['results'] as List<dynamic>?;
          if (results != null) {
            final usRelease = results.firstWhere(
              (r) => (r['iso_3166_1'] as String?) == 'US',
              orElse: () => null,
            ) as Map<String, dynamic>?;

            if (usRelease != null) {
              final releaseDatesList = usRelease['release_dates'] as List<dynamic>?;
              if (releaseDatesList != null && releaseDatesList.isNotEmpty) {
                // Find first release date with a non-empty certification
                for (final release in releaseDatesList) {
                  final releaseMap = release as Map<String, dynamic>?;
                  final cert = releaseMap?['certification'] as String?;
                  if (cert != null && cert.isNotEmpty) {
                    return cert;
                  }
                }
              }
            }
          }
        }
      } else if (type == 'series') {
        final contentRatings = tmdbData['content_ratings'] as Map<String, dynamic>?;
        if (contentRatings != null) {
          final results = contentRatings['results'] as List<dynamic>?;
          if (results != null) {
            final usRating = results.firstWhere(
              (r) => (r['iso_3166_1'] as String?) == 'US',
              orElse: () => null,
            ) as Map<String, dynamic>?;

            if (usRating != null) {
              final rating = usRating['rating'] as String?;
              if (rating != null && rating.isNotEmpty) {
                return rating;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting maturity rating: $e');
    }
    return null;
  }

  /// Extract maturity rating descriptors from TMDB data
  /// For movies: extracts from release_dates.results[US].release_dates[].descriptors
  /// For TV shows: extracts from content_ratings.results[US].descriptors
  static String? extractMaturityRatingDescriptors(
    Map<String, dynamic> tmdbData,
    String type,
  ) {
    try {
      if (type == 'movie') {
        final releaseDates = tmdbData['release_dates'] as Map<String, dynamic>?;
        if (releaseDates != null) {
          final results = releaseDates['results'] as List<dynamic>?;
          if (results != null) {
            final usRelease = results.firstWhere(
              (r) => (r['iso_3166_1'] as String?) == 'US',
              orElse: () => null,
            ) as Map<String, dynamic>?;

            if (usRelease != null) {
              final releaseDatesList = usRelease['release_dates'] as List<dynamic>?;
              if (releaseDatesList != null && releaseDatesList.isNotEmpty) {
                // Find first release date with descriptors
                for (final release in releaseDatesList) {
                  final releaseMap = release as Map<String, dynamic>?;
                  final descriptors = releaseMap?['descriptors'] as List<dynamic>?;
                  if (descriptors != null && descriptors.isNotEmpty) {
                    // Join descriptors with comma and space
                    return descriptors
                        .whereType<String>()
                        .map((d) => d.trim())
                        .where((d) => d.isNotEmpty)
                        .join(', ');
                  }
                }
              }
            }
          }
        }
      } else if (type == 'series') {
        final contentRatings = tmdbData['content_ratings'] as Map<String, dynamic>?;
        if (contentRatings != null) {
          final results = contentRatings['results'] as List<dynamic>?;
          if (results != null) {
            final usRating = results.firstWhere(
              (r) => (r['iso_3166_1'] as String?) == 'US',
              orElse: () => null,
            ) as Map<String, dynamic>?;

            if (usRating != null) {
              final descriptors = usRating['descriptors'] as List<dynamic>?;
              if (descriptors != null && descriptors.isNotEmpty) {
                // Join descriptors with comma and space
                return descriptors
                    .whereType<String>()
                    .map((d) => d.trim())
                    .where((d) => d.isNotEmpty)
                    .join(', ');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting maturity rating descriptors: $e');
    }
    return null;
  }

  /// Extract cast and crew data from TMDB response
  /// Returns a map with 'cast' and 'crew' keys containing parsed CastCrewMember lists
  static Map<String, List<CastCrewMember>> extractCastAndCrew(
    Map<String, dynamic> tmdbData,
  ) {
    try {
      final credits = tmdbData['credits'] as Map<String, dynamic>?;
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
              debugPrint('Error parsing cast member: $e');
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
              debugPrint('Error parsing crew member: $e');
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
      debugPrint('Error extracting cast and crew: $e');
      return {
        'cast': <CastCrewMember>[],
        'crew': <CastCrewMember>[],
      };
    }
  }

  /// Extract production information (companies, countries, languages)
  static Map<String, dynamic> extractProductionInfo(
    Map<String, dynamic> tmdbData,
    String type,
  ) {
    try {
      final productionCompanies = (tmdbData['production_companies'] as List<dynamic>?)
          ?.map((c) => c['name'] as String?)
          .whereType<String>()
          .toList() ?? [];

      final productionCountries = (tmdbData['production_countries'] as List<dynamic>?)
          ?.map((c) => c['name'] as String?)
          .whereType<String>()
          .toList() ?? [];

      final spokenLanguages = (tmdbData['spoken_languages'] as List<dynamic>?)
          ?.map((l) => l['name'] as String?)
          .whereType<String>()
          .toList() ?? [];

      final originalLanguage = tmdbData['original_language'] as String?;
      final originalTitle = type == 'movie'
          ? (tmdbData['original_title'] as String?)
          : (tmdbData['original_name'] as String?);

      return {
        'productionCompanies': productionCompanies,
        'productionCountries': productionCountries,
        'spokenLanguages': spokenLanguages,
        'originalLanguage': originalLanguage,
        'originalTitle': originalTitle,
      };
    } catch (e) {
      debugPrint('Error extracting production info: $e');
      return {
        'productionCompanies': <String>[],
        'productionCountries': <String>[],
        'spokenLanguages': <String>[],
        'originalLanguage': null,
        'originalTitle': null,
      };
    }
  }

  /// Extract release information (dates, status)
  static Map<String, dynamic> extractReleaseInfo(
    Map<String, dynamic> tmdbData,
    String type,
  ) {
    try {
      String? releaseDate;
      String? status;
      String? releaseYear;

      if (type == 'movie') {
        releaseDate = tmdbData['release_date'] as String?;
        status = tmdbData['status'] as String?;
        if (releaseDate != null && releaseDate.isNotEmpty) {
          releaseYear = releaseDate.split('-')[0];
        }
      } else if (type == 'series') {
        final firstAirDate = tmdbData['first_air_date'] as String?;
        final lastAirDate = tmdbData['last_air_date'] as String?;
        status = tmdbData['status'] as String?;
        
        if (firstAirDate != null && firstAirDate.isNotEmpty) {
          releaseDate = lastAirDate != null && lastAirDate != firstAirDate
              ? '$firstAirDate - $lastAirDate'
              : firstAirDate;
          releaseYear = firstAirDate.split('-')[0];
        }
      }

      return {
        'releaseDate': releaseDate,
        'releaseYear': releaseYear,
        'status': status,
      };
    } catch (e) {
      debugPrint('Error extracting release info: $e');
      return {
        'releaseDate': null,
        'releaseYear': null,
        'status': null,
      };
    }
  }

  /// Extract additional metadata (budget, revenue, tagline, etc.)
  static Map<String, dynamic> extractAdditionalMetadata(
    Map<String, dynamic> tmdbData,
    String type,
  ) {
    try {
      final budget = tmdbData['budget'] as int?;
      final revenue = tmdbData['revenue'] as int?;
      final tagline = tmdbData['tagline'] as String?;
      final voteAverage = tmdbData['vote_average'] as num?;
      final voteCount = tmdbData['vote_count'] as int?;
      final popularity = tmdbData['popularity'] as num?;
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
      debugPrint('Error extracting additional metadata: $e');
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











