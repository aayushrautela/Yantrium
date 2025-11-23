import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Test script to call TMDB API and save detailed responses to files
/// Usage: dart run scripts/test_tmdb_detailed.dart
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
  final imageBaseUrl = dotenv.env['TMDB_IMAGE_BASE_URL'] ?? 'https://image.tmdb.org/t/p';
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

  print('Testing TMDB API calls with full data...\n');

  // Test 1: Get a popular movie with full details (The Matrix - ID: 603)
  print('1. Fetching movie details with images (The Matrix - ID: 603)...');
  try {
    final response = await dio.get('/movie/603', queryParameters: {
      'append_to_response': 'videos,credits,images',
    });
    final file = File('test_responses/movie_603_matrix_full.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
    print('   - Check images.logos array for logo data');
    print('   - Check backdrop_path for hero background');
    print('   - Check poster_path for poster image');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 2: Get a popular TV show with full details (Breaking Bad - ID: 1396)
  print('\n2. Fetching TV show details with images (Breaking Bad - ID: 1396)...');
  try {
    final response = await dio.get('/tv/1396', queryParameters: {
      'append_to_response': 'videos,credits,images',
    });
    final file = File('test_responses/tv_1396_breaking_bad_full.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
    print('   - Check images.logos array for logo data');
    print('   - Check backdrop_path for hero background');
    print('   - Check poster_path for poster image');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 3: Get Law & Order: SVU (ID: 2734) - from the image
  print('\n3. Fetching Law & Order: SVU details (ID: 2734)...');
  try {
    final response = await dio.get('/tv/2734', queryParameters: {
      'append_to_response': 'videos,credits,images',
    });
    final file = File('test_responses/tv_2734_law_order_svu_full.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
    
    // Extract and save logo info separately
    final data = response.data as Map<String, dynamic>;
    final images = data['images'] as Map<String, dynamic>?;
    if (images != null) {
      final logos = images['logos'] as List<dynamic>?;
      if (logos != null && logos.isNotEmpty) {
        print('   - Found ${logos.length} logo(s)');
        final logoFile = File('test_responses/tv_2734_logos.json');
        await logoFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(logos),
        );
        print('   ✓ Logos saved to ${logoFile.path}');
        
        // Show logo URLs
        print('\n   Logo URLs:');
        for (var i = 0; i < logos.length && i < 3; i++) {
          final logo = logos[i] as Map<String, dynamic>;
          final filePath = logo['file_path'] as String?;
          if (filePath != null) {
            final logoUrl = '$imageBaseUrl/w500$filePath';
            print('     ${i + 1}. $logoUrl');
          }
        }
      } else {
        print('   - No logos found in response');
      }
    }
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 4: Get a recent popular movie (Dune: Part Two - ID: 693134)
  print('\n4. Fetching recent movie details (Dune: Part Two - ID: 693134)...');
  try {
    final response = await dio.get('/movie/693134', queryParameters: {
      'append_to_response': 'videos,credits,images',
    });
    final file = File('test_responses/movie_693134_dune2_full.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
  } catch (e) {
    print('   ✗ Error: $e');
  }

  // Test 5: Get a popular series (Stranger Things - ID: 66732)
  print('\n5. Fetching Stranger Things details (ID: 66732)...');
  try {
    final response = await dio.get('/tv/66732', queryParameters: {
      'append_to_response': 'videos,credits,images',
    });
    final file = File('test_responses/tv_66732_stranger_things_full.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(response.data),
    );
    print('   ✓ Saved to ${file.path}');
    
    // Extract logo info
    final data = response.data as Map<String, dynamic>;
    final images = data['images'] as Map<String, dynamic>?;
    if (images != null) {
      final logos = images['logos'] as List<dynamic>?;
      if (logos != null && logos.isNotEmpty) {
        print('   - Found ${logos.length} logo(s)');
      }
    }
  } catch (e) {
    print('   ✗ Error: $e');
  }

  print('\n✓ All tests completed!');
  print('\nCheck the test_responses/ directory for JSON files.');
  print('\nKey fields to look for in the responses:');
  print('  - images.logos[] - Array of logo objects with file_path');
  print('  - backdrop_path - Background image for hero section');
  print('  - poster_path - Poster image for cards');
  print('  - overview - Description text');
  print('  - genres[] - Array of genre objects');
  print('  - vote_average - Rating (0-10 scale)');
  print('  - release_date / first_air_date - Release information');
}


