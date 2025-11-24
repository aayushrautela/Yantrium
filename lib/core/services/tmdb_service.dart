import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'id_parser.dart';
import 'tmdb_data_extractor.dart';

/// Cached metadata entry with timestamp
class _CachedMetadata {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Duration ttl;

  _CachedMetadata(this.data, this.ttl) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

/// Service for fetching metadata from The Movie Database (TMDB) API
class TmdbService {
  late final Dio _dio;
  late final String _apiKey;
  late final String _imageBaseUrl;
  
  // Cache for TMDB metadata (5 minute TTL)
  final Map<String, _CachedMetadata> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

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

  /// Fetch movie metadata from TMDB (with caching)
  Future<Map<String, dynamic>?> getMovieMetadata(int tmdbId) async {
    final cacheKey = 'movie_$tmdbId';
    
    // Check cache first
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[CACHE] Using cached movie metadata for TMDB ID: $tmdbId');
      return Map<String, dynamic>.from(cached.data);
    }
    
    try {
      debugPrint('[LOGO] Fetching movie metadata for TMDB ID: $tmdbId');
      final response = await _dio.get('/movie/$tmdbId', queryParameters: {
        'append_to_response': 'videos,credits,images,release_dates',
      });
      final data = response.data as Map<String, dynamic>;
      debugPrint('[LOGO] Movie metadata response keys: ${data.keys.toList()}');
      debugPrint('[LOGO] Has images key: ${data.containsKey('images')}');
      if (data.containsKey('images')) {
        final images = data['images'] as Map<String, dynamic>?;
        debugPrint('[LOGO] Images object type: ${images.runtimeType}');
        debugPrint('[LOGO] Images keys: ${images?.keys.toList()}');
      }
      
      // Store in cache
      _cache[cacheKey] = _CachedMetadata(data, _cacheTtl);
      
      return data;
    } catch (e) {
      debugPrint('[LOGO] Error fetching movie metadata: $e');
      return null;
    }
  }

  /// Fetch TV series metadata from TMDB (with caching)
  Future<Map<String, dynamic>?> getTvMetadata(int tmdbId) async {
    final cacheKey = 'tv_$tmdbId';
    
    // Check cache first
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[CACHE] Using cached TV metadata for TMDB ID: $tmdbId');
      return Map<String, dynamic>.from(cached.data);
    }
    
    try {
      debugPrint('[LOGO] Fetching TV metadata for TMDB ID: $tmdbId');
      final response = await _dio.get('/tv/$tmdbId', queryParameters: {
        'append_to_response': 'videos,credits,images,content_ratings',
      });
      final data = response.data as Map<String, dynamic>;
      debugPrint('[LOGO] TV metadata response keys: ${data.keys.toList()}');
      debugPrint('[LOGO] Has images key: ${data.containsKey('images')}');
      if (data.containsKey('images')) {
        final images = data['images'] as Map<String, dynamic>?;
        debugPrint('[LOGO] Images object type: ${images.runtimeType}');
        debugPrint('[LOGO] Images keys: ${images?.keys.toList()}');
      }
      
      // Store in cache
      _cache[cacheKey] = _CachedMetadata(data, _cacheTtl);
      
      return data;
    } catch (e) {
      debugPrint('[LOGO] Error fetching TV metadata: $e');
      return null;
    }
  }
  
  /// Clear the metadata cache
  void clearCache() {
    _cache.clear();
  }
  
  /// Get current cache size
  int getCacheSize() {
    return _cache.length;
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
      // Use centralized extractor for cast and crew
      final castAndCrew = TmdbDataExtractor.extractCastAndCrew(tmdbData);
      final cast = castAndCrew['cast']!;
      final crew = castAndCrew['crew']!;
      
      final directors = crew
          .where((person) => person.character?.toLowerCase() == 'director')
          .map((person) => person.name)
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

      // Use centralized extractor for additional metadata
      final additionalMetadata = TmdbDataExtractor.extractAdditionalMetadata(tmdbData, 'movie');
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
        'name': (tmdbData['title'] as String?) ?? '',
        'poster': getImageUrl(tmdbData['poster_path'] as String?),
        'background': getImageUrl(tmdbData['backdrop_path'] as String?, size: 'w1280'),
        'logo': logoUrl,
        'description': tmdbData['overview'] as String?,
        'releaseInfo': tmdbData['release_date'] as String?,
        'genres': genres,
        'imdbRating': tmdbData['vote_average']?.toString(),
        'runtime': runtime?.toString(),
        'director': directors,
        'cast': cast.take(10).map((c) => c.name).toList(),
        'castFull': fullCast,
        'crewFull': fullCrew,
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
      // Use centralized extractor for cast and crew
      final castAndCrew = TmdbDataExtractor.extractCastAndCrew(tmdbData);
      final cast = castAndCrew['cast']!;
      final crew = castAndCrew['crew']!;
      
      final creators = crew
          .where((person) => person.character?.toLowerCase() == 'creator')
          .map((person) => person.name)
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

      // Use centralized extractor for additional metadata
      final additionalMetadata = TmdbDataExtractor.extractAdditionalMetadata(tmdbData, 'series');
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
        'name': (tmdbData['name'] as String?) ?? '',
        'poster': getImageUrl(tmdbData['poster_path'] as String?),
        'background': getImageUrl(tmdbData['backdrop_path'] as String?, size: 'w1280'),
        'logo': logoUrl,
        'description': tmdbData['overview'] as String?,
        'releaseInfo': releaseInfo,
        'genres': genres,
        'imdbRating': tmdbData['vote_average']?.toString(),
        'runtime': runtime?.toString(),
        'director': creators,
        'cast': cast.take(10).map((c) => c.name).toList(),
        'castFull': fullCast,
        'crewFull': fullCrew,
        'videos': trailers,
      };
    } catch (e) {
      return null;
    }
  }

  /// Enrich CatalogItem with TMDB metadata
  /// Returns enriched CatalogItem data or null if TMDB fetch fails
  /// If cachedTmdbData is provided, uses it instead of fetching (avoids duplicate API calls)
  Future<Map<String, dynamic>?> enrichCatalogItem(
    String contentId,
    String type, {
    Map<String, dynamic>? cachedTmdbData,
  }) async {
    // Use cached data if provided
    Map<String, dynamic>? tmdbData = cachedTmdbData;
    
    // Only fetch if no cached data provided
    if (tmdbData == null) {
      // Try to extract TMDB ID
      int? tmdbId = IdParser.extractTmdbId(contentId);
      
      // If IMDB ID, search for TMDB ID
      if (tmdbId == null && contentId.startsWith('tt')) {
        tmdbId = await getTmdbIdFromImdb(contentId);
      }
      
      if (tmdbId == null) {
        return null; // Can't find TMDB ID
      }

      // Fetch metadata based on type (will use cache if available)
      if (type == 'movie') {
        tmdbData = await getMovieMetadata(tmdbId);
      } else if (type == 'series') {
        tmdbData = await getTvMetadata(tmdbId);
      }
    }

    if (tmdbData != null) {
      if (type == 'movie') {
        return convertMovieToCatalogItem(tmdbData, contentId);
      } else if (type == 'series') {
        return convertTvToCatalogItem(tmdbData, contentId);
      }
    }

    return null;
  }

  /// Get cast and crew for a movie or TV show
  Future<Map<String, dynamic>?> getCastAndCrew(int tmdbId, String type) async {
    try {
      final endpoint = type == 'movie' ? '/movie/$tmdbId/credits' : '/tv/$tmdbId/credits';
      final response = await _dio.get(endpoint);
      final data = response.data as Map<String, dynamic>;

      final cast = (data['cast'] as List<dynamic>?)
          ?.map((c) => {
                'name': c['name'],
                'character': c['character'],
                'profile_path': c['profile_path'],
                'order': c['order'],
              })
          .toList();

      final crew = (data['crew'] as List<dynamic>?)
          ?.map((c) => {
                'name': c['name'],
                'job': c['job'],
                'profile_path': c['profile_path'],
              })
          .toList();

      return {
        'cast': cast ?? [],
        'crew': crew ?? [],
      };
    } catch (e) {
      return null;
    }
  }

  /// Get movie recommendations sorted by popularity
  Future<List<Map<String, dynamic>>> getMovieRecommendations(int tmdbId) async {
    try {
      final response = await _dio.get('/movie/$tmdbId/recommendations');
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      // Sort by popularity (highest first) and take top 15
      results.sort((a, b) => (b['popularity'] as num).compareTo(a['popularity'] as num));
      return results.take(15).toList();
    } catch (e) {
      debugPrint('Error fetching movie recommendations: $e');
      return [];
    }
  }

  /// Get TV show recommendations sorted by popularity
  Future<List<Map<String, dynamic>>> getTvRecommendations(int tmdbId) async {
    try {
      final response = await _dio.get('/tv/$tmdbId/recommendations');
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      // Sort by popularity (highest first) and take top 15
      results.sort((a, b) => (b['popularity'] as num).compareTo(a['popularity'] as num));
      return results.take(15).toList();
    } catch (e) {
      debugPrint('Error fetching TV recommendations: $e');
      return [];
    }
  }

  /// Get similar/recommended movies or TV shows
  Future<List<Map<String, dynamic>>> getSimilar(int tmdbId, String type) async {
    try {
      final endpoint = type == 'movie' ? '/movie/$tmdbId/similar' : '/tv/$tmdbId/similar';
      final response = await _dio.get(endpoint);
      final data = response.data as Map<String, dynamic>;

      final results = data['results'] as List<dynamic>? ?? [];

      // Sort by popularity (highest first) and take top 15
      results.sort((a, b) => (b['popularity'] as num?)?.compareTo(a['popularity'] as num? ?? 0) ?? 0);
      final topResults = results.take(15);

      return topResults.map((item) {
        final id = item['id']?.toString() ?? '';
        final tmdbIdStr = 'tmdb:$id';

        return {
          'id': tmdbIdStr,
          'type': type,
          'name': type == 'movie' ? (item['title'] as String?) : (item['name'] as String?),
          'poster': getImageUrl(item['poster_path'] as String?),
          'background': getImageUrl(item['backdrop_path'] as String?, size: 'w1280'),
          'description': item['overview'] as String?,
          'releaseInfo': type == 'movie'
              ? (item['release_date'] as String?)
              : (item['first_air_date'] as String?),
          'imdbRating': item['vote_average']?.toString(),
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get episodes for a specific season of a TV series
  Future<Map<String, dynamic>?> getSeasonEpisodes(int tmdbId, int seasonNumber) async {
    try {
      final response = await _dio.get('/tv/$tmdbId/season/$seasonNumber');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Get all seasons for a TV series
  Future<List<Map<String, dynamic>>> getSeasons(int tmdbId) async {
    try {
      final response = await _dio.get('/tv/$tmdbId');
      final data = response.data as Map<String, dynamic>;
      final seasons = data['seasons'] as List<dynamic>? ?? [];
      return seasons.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Search for movies using TMDB search API
  Future<List<Map<String, dynamic>>> searchMovies(String query) async {
    try {
      final response = await _dio.get('/search/movie', queryParameters: {
        'query': query,
        'page': 1,
      });
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      // Sort by popularity (highest first)
      results.sort((a, b) => (b['popularity'] as num?)?.compareTo(a['popularity'] as num? ?? 0) ?? 0);

      return results.map((item) {
        final id = item['id']?.toString() ?? '';
        final tmdbIdStr = 'tmdb:$id';

        return {
          'id': tmdbIdStr,
          'type': 'movie',
          'name': item['title'] as String? ?? '',
          'poster': getImageUrl(item['poster_path'] as String?),
          'background': getImageUrl(item['backdrop_path'] as String?, size: 'w1280'),
          'description': item['overview'] as String?,
          'releaseInfo': item['release_date'] as String?,
          'imdbRating': item['vote_average']?.toString(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error searching movies: $e');
      return [];
    }
  }

  /// Search for TV shows using TMDB search API
  Future<List<Map<String, dynamic>>> searchTv(String query) async {
    try {
      final response = await _dio.get('/search/tv', queryParameters: {
        'query': query,
        'page': 1,
      });
      final data = response.data as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      // Sort by popularity (highest first)
      results.sort((a, b) => (b['popularity'] as num?)?.compareTo(a['popularity'] as num? ?? 0) ?? 0);

      return results.map((item) {
        final id = item['id']?.toString() ?? '';
        final tmdbIdStr = 'tmdb:$id';

        return {
          'id': tmdbIdStr,
          'type': 'series',
          'name': item['name'] as String? ?? '',
          'poster': getImageUrl(item['poster_path'] as String?),
          'background': getImageUrl(item['backdrop_path'] as String?, size: 'w1280'),
          'description': item['overview'] as String?,
          'releaseInfo': item['first_air_date'] as String?,
          'imdbRating': item['vote_average']?.toString(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error searching TV shows: $e');
      return [];
    }
  }
}
