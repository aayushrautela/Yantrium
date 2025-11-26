import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'features/library/screens/home_screen.dart';
import 'core/services/oauth_handler.dart';
import 'core/database/database_provider.dart';
import 'core/services/service_locator.dart';
import 'core/services/theme_service.dart';

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

class _YantriumAppState extends State<YantriumApp> {
  final _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    // Listen to theme changes
    _themeService.colorSchemeName.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.colorSchemeName.removeListener(_onThemeChanged);
    super.dispose();
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
