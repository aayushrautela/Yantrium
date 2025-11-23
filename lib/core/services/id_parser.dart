/// Utility for parsing content IDs from addons
class IdParser {
  /// Extract TMDB ID from various ID formats
  /// Supports: "tmdb:123", "tt1234567" (IMDB), numeric strings
  static int? extractTmdbId(String contentId) {
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
    
    // Handle IMDB ID (tt1234567)
    if (contentId.startsWith('tt')) {
      return null; // Will need to search by IMDB ID
    }
    
    return null;
  }

  /// Check if ID is an IMDB ID
  static bool isImdbId(String contentId) {
    return contentId.startsWith('tt') && contentId.length >= 9;
  }

  /// Check if ID is a TMDB ID
  static bool isTmdbId(String contentId) {
    if (contentId.startsWith('tmdb:')) {
      return true;
    }
    return int.tryParse(contentId) != null;
  }
}


