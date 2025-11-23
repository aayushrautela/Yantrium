# Addon System Documentation

This document describes the addon system implementation for the Stremio service. Addons are external services that provide content catalogs, metadata, and streaming links following the Stremio Addon SDK specification.

## Language

This implementation is written in **Dart** using the Flutter framework.

## Architecture Overview

The addon system consists of three main components:

1. **AddonManager** - Manages addon installation, storage, and lifecycle
2. **AddonClient** - Handles HTTP communication with addon servers
3. **AddonRepository** - Provides a clean interface for the application layer

## Data Models

### Addon

Represents an installed addon in the system.

```dart
class Addon {
  final String id;                    // Unique addon identifier
  final String name;                  // Display name
  final String version;               // Version string
  final String? description;         // Optional description
  final String manifestUrl;           // Full URL to manifest.json
  final String baseUrl;               // Base URL for API requests
  final bool enabled;                 // Whether addon is active
  final String manifestData;          // Full manifest as JSON string
  final List<dynamic> resources;      // Supported resources (e.g., ["catalog", "meta", "stream"])
  final List<String> types;           // Supported content types (e.g., ["movie", "series"])
  final DateTime createdAt;          // Installation timestamp
  final DateTime updatedAt;          // Last update timestamp
}
```

### AddonManifest

Represents the manifest.json structure from an addon server.

```dart
class AddonManifest {
  final String id;
  final String version;
  final String name;
  final String? description;
  final List<dynamic> resources;      // Can be strings or objects with 'name' field
  final List<String> types;
  final List<CatalogDefinition> catalogs;
  final List<String>? idPrefixes;     // e.g., ["tmdb:"]
  final String? background;          // Background image URL
  final String? logo;                // Logo image URL
  final String? contactEmail;
  final Map<String, dynamic>? behaviorHints;
}
```

### CatalogDefinition

Defines a catalog available from the addon.

```dart
class CatalogDefinition {
  final String type;                 // "movie" or "series"
  final String? id;                  // Catalog ID (e.g., "tmdb.top", "tmdb.trending")
  final String? name;                // Display name
  // Additional fields may include:
  // - pageSize: int
  // - extra: List<Map> (for filtering options)
}
```

### CatalogItem

Represents a single item in a catalog response.

```dart
class CatalogItem {
  final String id;                   // Content ID (e.g., "tt1234567" or "tmdb:123")
  final String type;                 // "movie" or "series"
  final String name;                 // Title
  final String? poster;              // Poster image URL
  final String? background;         // Background image URL
  final String? logo;
  final String? description;
  final String? releaseInfo;
  final List<String>? genres;
  final String? imdbRating;
  final String? runtime;
}
```

### Meta

Detailed metadata for a specific content item.

```dart
class Meta {
  final String id;
  final String type;
  final String name;
  final String? poster;
  final String? posterShape;
  final String? background;
  final String? logo;
  final String? description;
  final String? releaseInfo;
  final List<String>? director;
  final List<String>? cast;
  final List<String>? genres;
  final String? imdbRating;
  final String? runtime;
  final String? website;
  final List<Video>? videos;         // Trailers, etc.
}
```

### Stream

Represents a playable stream from an addon.

```dart
class Stream {
  final String? id;
  final String? title;
  final String? name;
  final String? description;
  final String url;                  // Stream URL (required)
  final String? quality;              // e.g., "1080p", "720p"
  final String? type;                // e.g., "movie", "series"
  final List<Subtitle>? subtitles;
  final Map<String, dynamic>? behaviorHints;
  final String? addonId;
  final String? addonName;
}
```

## Core Components

### AddonManager

Manages addon lifecycle and storage. Currently uses in-memory storage (Map).

**Key Methods:**

```dart
// Install addon from manifest URL
Future<Addon> installAddon(String manifestUrl)

// List all installed addons
Future<List<Addon>> listAddons()

// Get specific addon by ID
Future<Addon?> getAddon(String id)

// Enable/disable addon
Future<bool> enableAddon(String id)
Future<bool> disableAddon(String id)

// Remove addon
Future<bool> removeAddon(String id)

// Update addon manifest (refresh from URL)
Future<Addon> updateAddon(String id)

// Get only enabled addons
Future<List<Addon>> getEnabledAddons()

// Check if addon supports a resource
static bool hasResource(List<dynamic> resources, String resourceName)
```

**Installation Process:**

1. Extract base URL from manifest URL
2. Fetch manifest using `AddonClient.getManifest(manifestUrl)`
3. Validate manifest structure
4. Create Addon object with metadata
5. Store in memory (preserve enabled state if updating existing addon)
6. Return Addon object

**Base URL Extraction:**

From manifest URL like `https://domain.com/path/manifest.json`, extract `https://domain.com/path`.

### AddonClient

Handles HTTP communication with addon servers using Dio HTTP client.

**Configuration:**
- Timeout: 30 seconds (connect and receive)
- Base URL: Automatically normalized (removes trailing slash)
- Headers: `Accept: application/json`

**Key Methods:**

```dart
// Fetch manifest from addon server
Future<AddonManifest> fetchManifest()

// Fetch catalog
// Path: /catalog/{type}/{id}.json (if id provided)
//       /catalog/{type}.json (if id is empty)
Future<Map<String, List<CatalogItem>>> getCatalog(String type, [String? id])

// Fetch metadata
// Path: /meta/{type}/{id}.json
Future<Map<String, Meta>> getMeta(String type, String id)

// Fetch streams
// Path: /stream/{type}/{id}.json
Future<Map<String, List<Stream>>> getStreams(String type, String id)

// Static methods for installation
static Future<AddonManifest> getManifest(String manifestUrl)
static String extractBaseUrl(String manifestUrl)
static bool validateManifest(AddonManifest manifest)
```

**URL Encoding:**

Content IDs must be URL-encoded when constructing paths. Use `Uri.encodeComponent(id)`.

**Error Handling:**

- 404 responses for catalogs/streams return empty lists (not errors)
- 404 responses for metadata throw exceptions
- Network errors and timeouts throw exceptions with descriptive messages

**Catalog Path Logic:**

```dart
// If catalog ID is provided and not empty:
final path = '/catalog/$type/${Uri.encodeComponent(catalogId)}.json';

// If catalog ID is empty or null:
final path = '/catalog/$type.json';
```

### AddonRepository

Provides a clean interface for the application layer, communicating with backend isolate.

**Key Methods:**

```dart
Future<List<Addon>> listAddons()
Future<Addon> getAddon(String id)
Future<void> installAddon(String manifestUrl)
Future<void> enableAddon(String id)
Future<void> disableAddon(String id)
Future<void> removeAddon(String id)
```

## API Endpoints

Addons follow the Stremio Addon SDK specification. All endpoints return JSON.

### Manifest

**GET** `/manifest.json`

Returns the addon manifest with metadata, supported resources, and catalog definitions.

### Catalog

**GET** `/catalog/{type}/{id}.json` (with catalog ID)
**GET** `/catalog/{type}.json` (without catalog ID)

**Response Format:**
```json
{
  "metas": [
    {
      "id": "tt1234567",
      "type": "movie",
      "name": "Movie Title",
      "poster": "https://...",
      "background": "https://...",
      ...
    }
  ]
}
```

**Important Notes:**
- Catalog IDs come from the `catalogs` array in the manifest
- Not all addons support empty catalog IDs
- Always check manifest for available catalog IDs before requesting

### Metadata

**GET** `/meta/{type}/{id}.json`

**Response Format:**
```json
{
  "meta": {
    "id": "tt1234567",
    "type": "movie",
    "name": "Movie Title",
    ...
  }
}
```

### Streams

**GET** `/stream/{type}/{id}.json`

**Response Format:**
```json
{
  "streams": [
    {
      "url": "https://...",
      "title": "Stream Title",
      "quality": "1080p",
      ...
    }
  ]
}
```

## Resource Checking

Resources in manifests can be:
1. **Simple strings**: `["catalog", "meta", "stream"]`
2. **Objects with name**: `[{"name": "catalog"}, {"name": "meta"}]`

Use `AddonManager.hasResource()` to check support:

```dart
if (AddonManager.hasResource(addon.resources, "catalog")) {
  // Addon supports catalog
}
```

## Catalog Handling

### Reading Catalog Definitions

Catalogs are defined in the manifest's `catalogs` array:

```json
{
  "catalogs": [
    { "type": "movie", "id": "tmdb.top", "name": "Popular" },
    { "type": "movie", "id": "tmdb.trending", "name": "Trending" },
    { "type": "series", "id": "" }  // Empty ID means use /catalog/series.json
  ]
}
```

### Fetching Catalogs

1. Parse catalog definitions from manifest
2. Match by type (and optionally by catalog ID)
3. Use catalog ID when constructing request path
4. Handle 404 errors gracefully (return empty list)

**Example:**
```dart
final addon = await addonManager.getAddon(addonId);
final manifest = AddonManifest.fromJson(jsonDecode(addon.manifestData));

// Find catalogs for "movie" type
final movieCatalogs = manifest.catalogs.where((c) => c.type == "movie");

for (final catalog in movieCatalogs) {
  final catalogId = catalog.id ?? '';
  final result = await addonClient.getCatalog("movie", catalogId.isEmpty ? null : catalogId);
  // Process result['metas']
}
```

## Error Handling

### Manifest Validation

Required fields:
- `id` (non-empty)
- `version` (non-empty)
- `name` (non-empty)
- `resources` (non-empty array)
- `types` (non-empty array)

### Network Errors

- Timeout: 30 seconds
- Connection errors: Throw exception with message
- HTTP errors: 
  - 404 for catalog/stream: Return empty list
  - 404 for meta: Throw exception
  - Other 4xx/5xx: Throw exception

### Best Practices

1. Always validate manifest before installation
2. URL-encode content IDs in paths
3. Handle 404s appropriately (empty lists vs exceptions)
4. Check resource support before making requests
5. Use catalog IDs from manifest, not empty strings unless catalog has no ID

## Usage Examples

### Installing an Addon

```dart
final manager = AddonManager();
final manifestUrl = "https://addon.example.com/manifest.json";

try {
  final addon = await manager.installAddon(manifestUrl);
  print('Installed: ${addon.name} (${addon.id})');
} catch (e) {
  print('Installation failed: $e');
}
```

### Fetching Catalog

```dart
final addon = await manager.getAddon("addon-id");
final client = AddonClient(addon.baseUrl);

// Fetch catalog with ID
final result = await client.getCatalog("movie", "tmdb.top");
final items = result['metas'] as List<CatalogItem>;

// Fetch catalog without ID
final result2 = await client.getCatalog("movie", null);
```

### Fetching Metadata

```dart
final client = AddonClient(addon.baseUrl);
final result = await client.getMeta("movie", "tt1234567");
final meta = result['meta'] as Meta;
```

### Fetching Streams

```dart
final client = AddonClient(addon.baseUrl);
final result = await client.getStreams("movie", "tt1234567");
final streams = result['streams'] as List<Stream>;
```

### Managing Addons

```dart
final manager = AddonManager();

// List all addons
final allAddons = await manager.listAddons();

// Get enabled addons only
final enabledAddons = await manager.getEnabledAddons();

// Enable/disable
await manager.enableAddon("addon-id");
await manager.disableAddon("addon-id");

// Remove
await manager.removeAddon("addon-id");

// Update (refresh manifest)
await manager.updateAddon("addon-id");
```

## Dependencies

Required packages:
- `dio` - HTTP client
- `http` - Alternative HTTP client (optional)
- `dart:convert` - JSON encoding/decoding

## Storage

Currently uses in-memory storage (`Map<String, Addon>`). For persistence:
1. Implement database storage in `AddonManager`
2. Load addons from database on initialization
3. Save addons to database on install/update/remove

## Testing

Test files available:
- `test_addon_install_simple.dart` - Basic installation test
- `test_addon_install.dart` - Full installation test
- `test_install_addon.dart` - Installation with database

Test manifest URL example:
```
https://94c8cb9f702d-tmdb-addon.baby-beamup.club/.../manifest.json
```

## Notes

1. **Catalog IDs are critical**: Many addons require specific catalog IDs. Always read them from the manifest.

2. **Resource format flexibility**: Resources can be strings or objects. Handle both cases.

3. **Base URL extraction**: Must correctly extract base URL from manifest URL for API requests.

4. **URL encoding**: Always encode content IDs when constructing paths.

5. **Error handling**: Distinguish between "not found" (404) and other errors. Catalogs/streams can return empty lists, but metadata should throw.

6. **Timeout handling**: 30-second timeout is reasonable for slow addon servers.

7. **Enabled state preservation**: When updating an existing addon, preserve its enabled state.

## Implementation Checklist

When implementing this system in another language:

- [ ] Create Addon data model
- [ ] Create AddonManifest data model
- [ ] Create CatalogDefinition data model
- [ ] Create CatalogItem, Meta, Stream models
- [ ] Implement AddonManager with storage
- [ ] Implement AddonClient with HTTP client
- [ ] Implement base URL extraction
- [ ] Implement manifest fetching and validation
- [ ] Implement catalog fetching with proper path logic
- [ ] Implement metadata fetching
- [ ] Implement stream fetching
- [ ] Implement resource checking (string and object formats)
- [ ] Implement error handling (404 vs other errors)
- [ ] Implement URL encoding for content IDs
- [ ] Add timeout configuration
- [ ] Test with real addon servers

