import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';

/// Simple test script to fetch raw stream data from addons via HTTP
/// Usage: dart run scripts/test_streams_simple.dart
Future<void> main() async {
  // Create output directory
  final outputDir = Directory('stream_test_data');
  if (!await outputDir.exists()) {
    await outputDir.create();
  }

  print('Testing Raw Stream Data Collection...\n');

  // Test addons - specific addons for Matrix 4 testing
  final testAddons = [
    {'name': 'Torrentio', 'baseUrl': 'https://torrentio.strem.fun'},
    {'name': 'AIOStreams', 'baseUrl': 'https://aiostreamsfortheweak.nhyira.dev/stremio/8bef529c-a970-4a14-8b1a-1da9ea9a6600/eyJpdiI6IkNSNUZKcEZZVUplYXZkMkN0R2dQekE9PSIsImVuY3J5cHRlZCI6Illzdk1VYjh0cXROVG9reUt4bTBPdDEyT3NPMG9Oa1N4cDVuM2gzMEpyVUU9IiwidHlwZSI6ImFpb0VuY3J5cHQifQ'},
    {'name': 'Nuvio Streams', 'baseUrl': 'https://nuviostreams.hayd.uk'},
    // Add more addon URLs here as needed
  ];

  if (testAddons.isEmpty) {
    print('No addons configured!');
    print('Please add addon configurations to the testAddons list.');
    print('Each addon should have a name and baseUrl.');
    print('');
    print('Example working Stremio addon URLs you can try:');
    print('  - https://v3-cinemeta.strem.io');
    print('  - https://opensubtitles-v3.strem.io');
    print('  - Or find more at: https://stremio-addons-updated.now.sh');
    return;
  }

  // Test content - Matrix 4 (The Matrix Resurrections)
  final testContent = [
    {'type': 'movie', 'id': 'tt10838180', 'name': 'The Matrix Resurrections'},
  ];

  int requestCount = 0;

  for (final addon in testAddons) {
    print('Testing addon: ${addon['name']} (${addon['baseUrl']})');

    final dio = Dio(BaseOptions(
      baseUrl: addon['baseUrl'] as String,
      headers: {
        'User-Agent': 'Yantrium/1.0',
        'Accept': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    for (final content in testContent) {
      requestCount++;
      final type = content['type'];
      final id = content['id'];
      final name = content['name'];

      print('  $requestCount. Fetching $type: $name ($id)');

      try {
        final path = '/stream/$type/${Uri.encodeComponent(id!)}.json';
        final fullUrl = '${addon['baseUrl']}$path';

        print('    URL: $fullUrl');

        final response = await dio.get(path);

        // Save raw response data
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'raw_${addon['name']!.replaceAll(' ', '_').toLowerCase()}_${type}_${id}_${timestamp}.json';

        final rawData = {
          'addon': {
            'name': addon['name'],
            'baseUrl': addon['baseUrl'],
          },
          'request': {
            'type': type,
            'id': id,
            'contentName': name,
            'path': path,
            'fullUrl': fullUrl,
          },
          'response': {
            'statusCode': response.statusCode,
            'headers': response.headers.map,
            'data': response.data,
          },
          'timestamp': DateTime.now().toIso8601String(),
        };

        final file = File('${outputDir.path}/$filename');
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(rawData),
        );

        print('    ✓ Saved to ${file.path} (${response.data.toString().length} chars)');

        // Small delay to be respectful to addon servers
        await Future.delayed(const Duration(milliseconds: 500));

      } catch (e) {
        print('    ✗ Error: $e');

        // Save error data with response body if available
        Map<String, dynamic> errorDetails = {
          'type': e.runtimeType.toString(),
          'message': e.toString(),
        };

        // Add DioException specific details
        if (e is DioException) {
          errorDetails.addAll({
            'statusCode': e.response?.statusCode,
            'statusMessage': e.response?.statusMessage,
            'headers': e.response?.headers.map,
            'responseData': e.response?.data,
          });
        }

        final errorData = {
          'addon': {
            'name': addon['name'],
            'baseUrl': addon['baseUrl'],
          },
        'request': {
          'type': type,
          'id': id,
          'contentName': name,
          'fullUrl': '${addon['baseUrl']}/stream/$type/${Uri.encodeComponent(id!)}.json',
        },
          'error': errorDetails,
          'timestamp': DateTime.now().toIso8601String(),
        };

        final filename = 'error_${addon['name']!.replaceAll(' ', '_').toLowerCase()}_${type}_${id}_${DateTime.now().millisecondsSinceEpoch}.json';
        final file = File('${outputDir.path}/$filename');
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(errorData),
        );
        print('    ! Saved error to ${file.path}');
      }
    }

    print('');
  }

  // List all created files
  final files = await outputDir.list().toList();
  final jsonFiles = files.where((f) => f.path.endsWith('.json')).toList();

  print('✓ Raw stream data collection completed!');
  print('Created ${jsonFiles.length} JSON files in ${outputDir.path}/:');
  print('');

  for (final file in jsonFiles) {
    final stat = await file.stat();
    final sizeKB = (stat.size / 1024).round();
    print('  ${file.path.split('/').last} (${sizeKB}KB)');
  }

  print('');
  print('File types:');
  print('  - raw_*.json: Raw HTTP responses from addons');
  print('  - error_*.json: Error data when requests failed');
  print('');
  print('Analyze the "response.data" field in raw_*.json files to see what');
  print('additional stream information is available from addons!');
  print('');
  print('To use this script:');
  print('1. Find working Stremio addon URLs (search for "Stremio addons" online)');
  print('2. Add them to the testAddons list in the format:');
  print('   {\'name\': \'Addon Name\', \'baseUrl\': \'https://addon-url.com\'}');
  print('3. Run: dart run scripts/test_streams_simple.dart');
  print('');
  print('The script will create JSON files containing the raw API responses.');
  print('Examine the "response.data.streams" array to see what fields are available');
  print('that your app isn\'t currently parsing!');
}
