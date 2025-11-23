import 'dart:io';

/// Service for file read/write operations
/// Used for local addon support (future use)
class FileService {
  /// Read file content as string
  static Future<String> readFile(String path) async {
    final file = File(path);
    return await file.readAsString();
  }

  /// Write string content to file
  static Future<void> writeFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  /// Check if file exists
  static Future<bool> fileExists(String path) async {
    final file = File(path);
    return await file.exists();
  }

  /// Delete file
  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}


