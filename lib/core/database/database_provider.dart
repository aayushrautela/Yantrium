import 'app_database.dart';

/// Singleton provider for AppDatabase instance
/// Ensures only one database instance is created throughout the app
/// to prevent race conditions and database corruption
class DatabaseProvider {
  static AppDatabase? _instance;

  /// Get the singleton AppDatabase instance
  static AppDatabase get instance {
    _instance ??= AppDatabase();
    return _instance!;
  }

  /// Reset the database instance (useful for testing or when database needs to be recreated)
  static void reset() {
    _instance?.close();
    _instance = null;
  }
}


