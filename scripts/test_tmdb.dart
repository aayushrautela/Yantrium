import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Test script to call TMDB API and save responses to files
/// Usage: dart run scripts/test_tmdb.dart
Future<void> main() async {
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('Error loading .env file: $e');
    print('Make sure .env file exists in the project root');
    exit(1);
  }

  final apiKey = dotenv.env['TMDB_API_KEY'];
  if (apiKey == null || apiKey.isEmpty || apiKey == 'your_tmdb_api_key_here') {
    print('Error: TMDB_API_KEY not set in .env file');
    print('Please set your TMDB API key in the .env file');
    exit(1);
  }

  final baseUrl = dotenv.env['TMDB_BASE_URL'] ?? 'https://api.themoviedb.org/3';
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    queryParameters: {
      'api_key': apiKey,
    },
    headers: {
      'Accept': 'application/json',
    },
  ));

  // Create output directory
  final outputDir = Directory('test_responses');
  if (!await outputDir.exists()) {
    await outputDir.create();
  }

  print('Testing TMDB API calls...\n');

  // Test 1: Get popular movies
  print('1. Fetching popular movies...');
  try {
    final response = await dio.get('/movie/popular');
    final file = File('test_responses/popular_movies.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 2: Get a specific movie (The Matrix - TMDB ID: 603)
  print('\n2. Fetching movie details (The Matrix - ID: 603)...');
  try {
    final response = await dio.get('/movie/603', queryParameters: {
      'append_to_response': 'videos,credits,images',
    });
    final file = File('test_responses/movie_603_matrix.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 3: Get popular TV shows
  print('\n3. Fetching popular TV shows...');
  try {
    final response = await dio.get('/tv/popular');
    final file = File('test_responses/popular_tv.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 4: Get a specific TV show (Breaking Bad - TMDB ID: 1396)
  print('\n4. Fetching TV show details (Breaking Bad - ID: 1396)...');
  try {
    final response = await dio.get('/tv/1396', queryParameters: {
      'append_to_response': 'videos,credits,images',
    });
    final file = File('test_responses/tv_1396_breaking_bad.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 5: Search by IMDB ID (The Matrix - tt0133093)
  print('\n5. Finding TMDB ID from IMDB ID (tt0133093 - The Matrix)...');
  try {
    final response = await dio.get('/find/tt0133093', queryParameters: {
      'external_source': 'imdb_id',
    });
    final file = File('test_responses/find_imdb_tt0133093.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 6: Search by IMDB ID (Breaking Bad - tt0903747)
  print('\n6. Finding TMDB ID from IMDB ID (tt0903747 - Breaking Bad)...');
  try {
    final response = await dio.get('/find/tt0903747', queryParameters: {
      'external_source': 'imdb_id',
    });
    final file = File('test_responses/find_imdb_tt0903747.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 7: Search movies by query
  print('\n7. Searching movies by query (Matrix)...');
  try {
    final response = await dio.get('/search/movie', queryParameters: {
      'query': 'Matrix',
    });
    final file = File('test_responses/search_movie_matrix.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 8: Search TV by query
  print('\n8. Searching TV shows by query (Breaking Bad)...');
  try {
    final response = await dio.get('/search/tv', queryParameters: {
      'query': 'Breaking Bad',
    });
    final file = File('test_responses/search_tv_breaking_bad.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  print('\n✓ All tests completed!');
  print('Check the test_responses/ directory for JSON files.');
}


