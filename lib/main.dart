import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'features/library/screens/home_screen.dart';
import 'core/services/oauth_handler.dart';
import 'core/database/database_provider.dart';
import 'core/services/service_locator.dart';
import 'core/services/theme_service.dart';
import 'core/services/logging_service.dart';

/// Perform graceful shutdown of all services
Future<void> _performGracefulShutdown() async {
  try {
    LoggingService.instance.info('Performing graceful shutdown...');

    // Dispose OAuth handler first as it has active subscriptions
    OAuthHandler().dispose();

    // Dispose all services through service locator
    await ServiceLocator.instance.dispose();

    // Dispose theme service
    ThemeService().dispose();

    LoggingService.instance.info('Graceful shutdown completed successfully');
  } catch (e) {
    LoggingService.instance.error('Error during graceful shutdown', e);
    rethrow;
  }
}

Future<void> _loadEnvironmentFile() async {
  // Try current directory first
  try {
    await dotenv.load(fileName: '.env');
    print('Loaded .env from current directory');
    return;
  } catch (e) {
    print('Could not load .env from current directory: $e');
  }

  // Try executable directory
  try {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final envFile = File('${exeDir.path}/.env');
    if (await envFile.exists()) {
      await dotenv.load(fileName: envFile.path);
      print('Loaded .env from executable directory: ${envFile.path}');
      return;
    }
  } catch (e) {
    print('Could not load .env from executable directory: $e');
  }

  // Try working directory
  try {
    final workingDir = Directory.current;
    final envFile = File('${workingDir.path}/.env');
    if (await envFile.exists()) {
      await dotenv.load(fileName: envFile.path);
      print('Loaded .env from working directory: ${envFile.path}');
      return;
    }
  } catch (e) {
    print('Could not load .env from working directory: $e');
  }

  print('Warning: No .env file found, app will run with limited functionality');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register FVP (must be before runApp)
  fvp.registerWith();

  // Load environment variables - try multiple locations
  await _loadEnvironmentFile();

  // Initialize database and services
  final database = DatabaseProvider.instance;
  await ServiceLocator.instance.initialize(database);

  // Initialize theme service
  await ThemeService().initialize();

  // Initialize OAuth handler to listen for deep links globally
  OAuthHandler().initialize();

  runApp(const YantriumApp());
}

class YantriumApp extends StatefulWidget {
  const YantriumApp({super.key});

  @override
  State<YantriumApp> createState() => _YantriumAppState();
}

class _YantriumAppState extends State<YantriumApp> with WidgetsBindingObserver {
  final _themeService = ThemeService();
  bool _shutdownPerformed = false;

  @override
  void initState() {
    super.initState();
    // Listen to theme changes
    _themeService.colorSchemeName.addListener(_onThemeChanged);

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    _themeService.colorSchemeName.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Handle Trakt service lifecycle changes
    ServiceLocator.instance.traktCoreService.handleAppStateChange(state);

    // Perform graceful shutdown when app is detached (being terminated)
    if (state == AppLifecycleState.detached && !_shutdownPerformed) {
      _shutdownPerformed = true;
      // Perform cleanup asynchronously - don't await as this might not complete
      _performGracefulShutdown().catchError((error) {
        LoggingService.instance.error('Error during app shutdown cleanup', error);
      });
    }
  }

  void _onThemeChanged() {
    setState(() {
      // Rebuild when theme changes
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'Yantrium',
      theme: ThemeData.dark(
        colorScheme: _themeService.getColorScheme(brightness: Brightness.dark),
        radius: 0.5,
      ),
      home: const HomeScreen(),
    );
  }
}
