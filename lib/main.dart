import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'features/library/screens/home_screen.dart';
import 'core/services/oauth_handler.dart';
import 'core/database/database_provider.dart';
import 'core/services/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Register FVP (must be before runApp)
  fvp.registerWith();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env file might not exist, continue without it
    // User will need to set it up
  }

  // Initialize database and services
  final database = DatabaseProvider.instance;
  await ServiceLocator.instance.initialize(database);

  // Initialize OAuth handler to listen for deep links globally
  OAuthHandler().initialize();
  
  runApp(const YantriumApp());
}

class YantriumApp extends StatelessWidget {
  const YantriumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp(
      title: 'Yantrium',
      theme: ThemeData.dark(
        colorScheme: ColorSchemes.darkDefaultColor,
        radius: 0.5,
            ),
      home: const HomeScreen(),
    );
  }
}
