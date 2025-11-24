import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'features/library/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize media_kit
  MediaKit.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env file might not exist, continue without it
    // User will need to set it up
  }
  
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
