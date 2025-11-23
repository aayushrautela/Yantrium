import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Service for fetching metadata from The Movie Database (TMDB) API
class TmdbService {
  late final Dio _dio;
  late final String _apiKey;
  late final String _imageBaseUrl;

  TmdbService() {
    _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
    final baseUrl = dotenv.env['TMDB_BASE_URL'] ?? 'https://api.themoviedb.org/3';
    _imageBaseUrl = dotenv.env['TMDB_IMAGE_BASE_URL'] ?? 'https://image.tmdb.org/t/p';
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      queryParameters: {
        'api_key': _apiKey,
      },
      headers: {
        'Accept': 'application/json',
      },
    ));
  }

  /// Extract TMDB ID from content ID
  /// Supports formats: "tmdb:123", "tt1234567" (IMDB), or numeric string
  int? extractTmdbId(String contentId) {
    // Handle tmdb:123 format
    if (contentId.startsWith('tmdb:')) {
      final id = contentId.substring(5);
      return int.tryParse(id);
    }
    
    // Handle numeric string (assume TMDB ID)
    final numericId = int.tryParse(contentId);
    if (numericId != null) {
      return numericId;
    }
    
    // Handle IMDB ID (tt1234567) - need to search TMDB
    if (contentId.startsWith('tt')) {
      return null; // Will need to search by IMDB ID
    }
    
    return null;
  }

  /// Search for content by IMDB ID and get TMDB ID
  Future<int?> getTmdbIdFromImdb(String imdbId) async {
    try {
      final response = await _dio.get('/find/$imdbId', queryParameters: {
        'external_source': 'imdb_id',
      });
      
      final data = response.data as Map<String, dynamic>;
      
      // Check movie results first
      final movieResults = data['movie_results'] as List<dynamic>?;
      if (movieResults != null && movieResults.isNotEmpty) {
        return movieResults[0]['id'] as int?;
      }
      
      // Check TV results
      final tvResults = data['tv_results'] as List<dynamic>?;
      if (tvResults != null && tvResults.isNotEmpty) {
        return tvResults[0]['id'] as int?;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch movie metadata from TMDB
  Future<Map<String, dynamic>?> getMovieMetadata(int tmdbId) async {
    try {
      debugPrint('[LOGO] Fetching movie metadata for TMDB ID: $tmdbId');
      final response = await _dio.get('/movie/$tmdbId', queryParameters: {
        'append_to_response': 'videos,credits,images',
      });
      final data = response.data as Map<String, dynamic>;
      debugPrint('[LOGO] Movie metadata response keys: ${data.keys.toList()}');
      debugPrint('[LOGO] Has images key: ${data.containsKey('images')}');
      if (data.containsKey('images')) {
        final images = data['images'] as Map<String, dynamic>?;
        debugPrint('[LOGO] Images object type: ${images.runtimeType}');
        debugPrint('[LOGO] Images keys: ${images?.keys.toList()}');
      }
      return data;
    } catch (e) {
      debugPrint('[LOGO] Error fetching movie metadata: $e');
      return null;
    }
  }

  /// Fetch TV series metadata from TMDB
  Future<Map<String, dynamic>?> getTvMetadata(int tmdbId) async {
    try {
      debugPrint('[LOGO] Fetching TV metadata for TMDB ID: $tmdbId');
      final response = await _dio.get('/tv/$tmdbId', queryParameters: {
        'append_to_response': 'videos,credits,images',
      });
      final data = response.data as Map<String, dynamic>;
      debugPrint('[LOGO] TV metadata response keys: ${data.keys.toList()}');
      debugPrint('[LOGO] Has images key: ${data.containsKey('images')}');
      if (data.containsKey('images')) {
        final images = data['images'] as Map<String, dynamic>?;
        debugPrint('[LOGO] Images object type: ${images.runtimeType}');
        debugPrint('[LOGO] Images keys: ${images?.keys.toList()}');
      }
      return data;
    } catch (e) {
      debugPrint('[LOGO] Error fetching TV metadata: $e');
      return null;
    }
  }

  /// Get full image URL from TMDB path
  String getImageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path; // Already full URL
    return '$_imageBaseUrl/$size$path';
  }

  /// Convert TMDB movie data to CatalogItem format
  Map<String, dynamic>? convertMovieToCatalogItem(
    Map<String, dynamic> tmdbData,
    String originalId,
  ) {
    try {
      final credits = tmdbData['credits'] as Map<String, dynamic>?;
      final cast = credits?['cast'] as List<dynamic>?;
      final crew = credits?['crew'] as List<dynamic>?;
      final directors = crew
          ?.where((person) => person['job'] == 'Director')
          .map((person) => person['name'] as String)
          .toList();
      
      final genres = (tmdbData['genres'] as List<dynamic>?)
          ?.map((g) => g['name'] as String)
          .toList();
      
      final videos = tmdbData['videos']?['results'] as List<dynamic>?;
      final trailers = videos
          ?.where((v) => v['type'] == 'Trailer' && v['site'] == 'YouTube')
          .map((v) => {
                'name': v['name'],
                'key': v['key'],
                'site': v['site'],
              })
          .toList();

      // Safely extract logo from images - prefer US/English logos
      String? logoPath;
      try {
        debugPrint('[LOGO] Starting logo extraction for movie: ${tmdbData['title']}');
        final images = tmdbData['images'] as Map<String, dynamic>?;
        debugPrint('[LOGO] Images object: ${images != null ? 'exists' : 'null'}');
        
        final logos = images?['logos'] as List<dynamic>?;
        debugPrint('[LOGO] Logos array: ${logos != null ? 'exists (${logos.length} logos)' : 'null'}');
        
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
              debugPrint('[LOGO] Logo $i: country=$country, language=$language, path=$filePath');
              
              // Priority 1: US + English (best match)
              if (country == 'US' && language == 'en') {
                usEnglishLogo = logoMap;
                debugPrint('[LOGO] Found US/English logo: $filePath');
                break; // Found best match, stop searching
              }
              // Priority 2: Any English logo (language='en', any country)
              else if (language == 'en') {
                englishLogo ??= logoMap; // Keep first English logo found
                debugPrint('[LOGO] Found English logo: $filePath');
              }
              // Fallback: First available logo (keep as last resort)
              preferredLogo ??= logoMap;
            }
          }
          
          // Select in priority order: US/English > English > First available
          preferredLogo = usEnglishLogo ?? englishLogo ?? preferredLogo;
          logoPath = preferredLogo?['file_path'] as String?;
          
          if (usEnglishLogo != null) {
            debugPrint('[LOGO] Selected US/English logo: $logoPath');
          } else if (englishLogo != null) {
            debugPrint('[LOGO] Selected English logo: $logoPath');
          } else {
            debugPrint('[LOGO] Using fallback logo (first available): $logoPath');
          }
        } else {
          debugPrint('[LOGO] No logos found in images');
        }
      } catch (e, stackTrace) {
        debugPrint('[LOGO] Error extracting logo: $e');
        debugPrint('[LOGO] Stack trace: $stackTrace');
      }
      
      final logoUrl = getImageUrl(logoPath, size: 'w500');
      debugPrint('[LOGO] Final logo URL: $logoUrl');

      return {
        'id': originalId,
        'type': 'movie',
        'name': (tmdbData['title'] as String?) ?? '',
        'poster': getImageUrl(tmdbData['poster_path'] as String?),
        'background': getImageUrl(tmdbData['backdrop_path'] as String?, size: 'w1280'),
        'logo': logoUrl,
        'description': tmdbData['overview'] as String?,
        'releaseInfo': tmdbData['release_date'] as String?,
        'genres': genres,
        'imdbRating': tmdbData['vote_average']?.toString(),
        'runtime': tmdbData['runtime']?.toString(),
        'director': directors,
        'cast': cast?.take(10).map((c) => c['name'] as String).toList(),
        'videos': trailers,
      };
    } catch (e) {
      return null;
    }
  }

  /// Convert TMDB TV data to CatalogItem format
  Map<String, dynamic>? convertTvToCatalogItem(
    Map<String, dynamic> tmdbData,
    String originalId,
  ) {
    try {
      final credits = tmdbData['credits'] as Map<String, dynamic>?;
      final cast = credits?['cast'] as List<dynamic>?;
      final crew = credits?['crew'] as List<dynamic>?;
      final creators = crew
          ?.where((person) => person['job'] == 'Creator')
          .map((person) => person['name'] as String)
          .toList();
      
      final genres = (tmdbData['genres'] as List<dynamic>?)
          ?.map((g) => g['name'] as String)
          .toList();
      
      final videos = tmdbData['videos']?['results'] as List<dynamic>?;
      final trailers = videos
          ?.where((v) => v['type'] == 'Trailer' && v['site'] == 'YouTube')
          .map((v) => {
                'name': v['name'],
                'key': v['key'],
                'site': v['site'],
              })
          .toList();

      final firstAirDate = tmdbData['first_air_date'] as String?;
      final lastAirDate = tmdbData['last_air_date'] as String?;
      String? releaseInfo;
      if (firstAirDate != null) {
        releaseInfo = lastAirDate != null && lastAirDate != firstAirDate
            ? '$firstAirDate - $lastAirDate'
            : firstAirDate;
      }

      // Safely extract logo from images - prefer US/English logos
      String? logoPath;
      try {
        debugPrint('[LOGO] Starting logo extraction for TV: ${tmdbData['name']}');
        final images = tmdbData['images'] as Map<String, dynamic>?;
        debugPrint('[LOGO] Images object: ${images != null ? 'exists' : 'null'}');
        
        final logos = images?['logos'] as List<dynamic>?;
        debugPrint('[LOGO] Logos array: ${logos != null ? 'exists (${logos.length} logos)' : 'null'}');
        
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
              debugPrint('[LOGO] Logo $i: country=$country, language=$language, path=$filePath');
              
              // Priority 1: US + English (best match)
              if (country == 'US' && language == 'en') {
                usEnglishLogo = logoMap;
                debugPrint('[LOGO] Found US/English logo: $filePath');
                break; // Found best match, stop searching
              }
              // Priority 2: Any English logo (language='en', any country)
              else if (language == 'en') {
                englishLogo ??= logoMap; // Keep first English logo found
                debugPrint('[LOGO] Found English logo: $filePath');
              }
              // Fallback: First available logo (keep as last resort)
              preferredLogo ??= logoMap;
            }
          }
          
          // Select in priority order: US/English > English > First available
          preferredLogo = usEnglishLogo ?? englishLogo ?? preferredLogo;
          logoPath = preferredLogo?['file_path'] as String?;
          
          if (usEnglishLogo != null) {
            debugPrint('[LOGO] Selected US/English logo: $logoPath');
          } else if (englishLogo != null) {
            debugPrint('[LOGO] Selected English logo: $logoPath');
          } else {
            debugPrint('[LOGO] Using fallback logo (first available): $logoPath');
          }
        } else {
          debugPrint('[LOGO] No logos found in images');
        }
      } catch (e, stackTrace) {
        debugPrint('[LOGO] Error extracting logo: $e');
        debugPrint('[LOGO] Stack trace: $stackTrace');
      }
      
      final logoUrl = getImageUrl(logoPath, size: 'w500');
      debugPrint('[LOGO] Final logo URL: $logoUrl');

      // Safely extract runtime
      String? runtime;
      try {
        final episodeRunTime = tmdbData['episode_run_time'] as List<dynamic>?;
        if (episodeRunTime != null && episodeRunTime.isNotEmpty) {
          runtime = episodeRunTime[0]?.toString();
        }
      } catch (e) {
        // Ignore runtime extraction errors
      }

      return {
        'id': originalId,
        'type': 'series',
        'name': (tmdbData['name'] as String?) ?? '',
        'poster': getImageUrl(tmdbData['poster_path'] as String?),
        'background': getImageUrl(tmdbData['backdrop_path'] as String?, size: 'w1280'),
        'logo': logoUrl,
        'description': tmdbData['overview'] as String?,
        'releaseInfo': releaseInfo,
        'genres': genres,
        'imdbRating': tmdbData['vote_average']?.toString(),
        'runtime': runtime,
        'director': creators,
        'cast': cast?.take(10).map((c) => c['name'] as String).toList(),
        'videos': trailers,
      };
    } catch (e) {
      return null;
    }
  }

  /// Enrich CatalogItem with TMDB metadata
  /// Returns enriched CatalogItem data or null if TMDB fetch fails
  Future<Map<String, dynamic>?> enrichCatalogItem(
    String contentId,
    String type,
  ) async {
    // Try to extract TMDB ID
    int? tmdbId = extractTmdbId(contentId);
    
    // If IMDB ID, search for TMDB ID
    if (tmdbId == null && contentId.startsWith('tt')) {
      tmdbId = await getTmdbIdFromImdb(contentId);
    }
    
    if (tmdbId == null) {
      return null; // Can't find TMDB ID
    }

    // Fetch metadata based on type
    Map<String, dynamic>? tmdbData;
    if (type == 'movie') {
      tmdbData = await getMovieMetadata(tmdbId);
      if (tmdbData != null) {
        return convertMovieToCatalogItem(tmdbData, contentId);
      }
    } else if (type == 'series') {
      tmdbData = await getTvMetadata(tmdbId);
      if (tmdbData != null) {
        return convertTvToCatalogItem(tmdbData, contentId);
      }
    }

    return null;
  }
}

