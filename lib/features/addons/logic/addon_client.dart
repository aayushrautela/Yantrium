import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/addon_manifest.dart';
import '../../library/models/catalog_item.dart';

/// Handles HTTP communication with addon servers
class AddonClient {
  final Dio _dio;
  final String baseUrl;

  AddonClient(this.baseUrl)
      : _dio = Dio(
          BaseOptions(
            baseUrl: _normalizeBaseUrl(baseUrl),
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
            },
          ),
        );

  /// Normalize base URL (remove trailing slash)
  static String _normalizeBaseUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Extract base URL from manifest URL
  /// From manifest URL like `https://domain.com/path/manifest.json`,
  /// extract `https://domain.com/path`
  static String extractBaseUrl(String manifestUrl) {
    final uri = Uri.parse(manifestUrl);
    final pathSegments = List<String>.from(uri.pathSegments);
    if (pathSegments.isNotEmpty && pathSegments.last == 'manifest.json') {
      pathSegments.removeLast();
    }
    return uri.replace(pathSegments: pathSegments).toString();
  }

  /// Fetch manifest from addon server
  Future<AddonManifest> fetchManifest() async {
    try {
      final response = await _dio.get('/manifest.json');
      return AddonManifest.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch manifest: $e');
    }
  }

  /// Static method to fetch manifest from URL
  static Future<AddonManifest> getManifest(String manifestUrl) async {
    final client = AddonClient(extractBaseUrl(manifestUrl));
    return await client.fetchManifest();
  }

  /// Validate manifest structure
  static bool validateManifest(AddonManifest manifest) {
    if (manifest.id.isEmpty) return false;
    if (manifest.version.isEmpty) return false;
    if (manifest.name.isEmpty) return false;
    if (manifest.resources.isEmpty) return false;
    if (manifest.types.isEmpty) return false;
    return true;
  }

  /// Fetch catalog
  /// Path: /catalog/{type}/{id}.json (if id provided)
  ///       /catalog/{type}.json (if id is empty)
  Future<Map<String, List<CatalogItem>>> getCatalog(String type, [String? id]) async {
    try {
      String path;
      if (id != null && id.isNotEmpty) {
        path = '/catalog/$type/${Uri.encodeComponent(id)}.json';
      } else {
        path = '/catalog/$type.json';
      }

      final response = await _dio.get(path);
      final data = response.data as Map<String, dynamic>;
      final metas = data['metas'] as List<dynamic>? ?? [];

      // Safely parse catalog items, skipping invalid ones
      final validItems = <CatalogItem>[];
      for (final item in metas) {
        try {
          if (item is Map<String, dynamic>) {
            validItems.add(CatalogItem.fromJson(item));
          }
        } catch (e) {
          // Skip invalid items and continue
        }
      }
      
      if (kDebugMode && validItems.isEmpty && metas.isNotEmpty) {
        debugPrint('Warning: All ${metas.length} catalog items were invalid or failed to parse');
      }

      return {
        'metas': validItems,
      };
    } on DioException catch (e) {
      // 404 responses for catalogs return empty lists (not errors)
      if (e.response?.statusCode == 404) {
        return {'metas': <CatalogItem>[]};
      }
      throw Exception('Failed to fetch catalog: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch catalog: $e');
    }
  }

  /// Fetch metadata
  /// Path: /meta/{type}/{id}.json
  Future<Map<String, dynamic>> getMeta(String type, String id) async {
    try {
      final path = '/meta/$type/${Uri.encodeComponent(id)}.json';
      final response = await _dio.get(path);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // 404 responses for metadata throw exceptions
      if (e.response?.statusCode == 404) {
        throw Exception('Metadata not found for $type/$id');
      }
      throw Exception('Failed to fetch metadata: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch metadata: $e');
    }
  }

  /// Fetch streams
  /// Path: /stream/{type}/{id}.json
  Future<Map<String, List<dynamic>>> getStreams(String type, String id) async {
    try {
      final path = '/stream/$type/${Uri.encodeComponent(id)}.json';
      
      if (kDebugMode) {
        debugPrint('AddonClient: Making GET request to: $path');
        debugPrint('AddonClient: Full URL: ${_dio.options.baseUrl}$path');
      }
      
      final response = await _dio.get(path);
      
      if (kDebugMode) {
        debugPrint('AddonClient: Response status: ${response.statusCode}');
        debugPrint('AddonClient: Response headers: ${response.headers}');
        debugPrint('AddonClient: Raw response data type: ${response.data.runtimeType}');
        debugPrint('AddonClient: Raw response data: ${response.data}');
      }
      
      final data = response.data as Map<String, dynamic>;

      if (kDebugMode) {
        debugPrint('AddonClient: Parsed data keys: ${data.keys.toList()}');
        debugPrint('AddonClient: Full parsed data: $data');
      }

      // Validate response structure before accessing streams key
      if (!data.containsKey('streams')) {
        if (kDebugMode) {
          debugPrint('AddonClient: Response missing streams key');
          debugPrint('AddonClient: Available keys: ${data.keys.toList()}');
        }
        return {'streams': <dynamic>[]};
      }

      final streamsData = data['streams'];
      if (streamsData is! List) {
        if (kDebugMode) {
          debugPrint('AddonClient: streams is not a list, type: ${streamsData.runtimeType}');
          debugPrint('AddonClient: streams value: $streamsData');
        }
        return {'streams': <dynamic>[]};
      }

      final streams = streamsData;

      if (kDebugMode) {
        debugPrint('AddonClient: Extracted ${streams.length} stream(s) from response');
      }

      return {'streams': streams};
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('AddonClient: DioException - Status: ${e.response?.statusCode}');
        debugPrint('AddonClient: DioException - Message: ${e.message}');
        debugPrint('AddonClient: DioException - Response data: ${e.response?.data}');
      }
      
      // 404 responses for streams return empty lists (not errors)
      if (e.response?.statusCode == 404) {
        if (kDebugMode) {
          debugPrint('AddonClient: 404 response, returning empty streams list');
        }
        return {'streams': <dynamic>[]};
      }
      throw Exception('Failed to fetch streams: ${e.message}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AddonClient: General exception: $e');
      }
      throw Exception('Failed to fetch streams: $e');
    }
  }
}

