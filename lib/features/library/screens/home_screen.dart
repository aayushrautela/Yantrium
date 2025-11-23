import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'catalog_grid_screen.dart';
import 'library_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../core/widgets/persistent_navigation_header.dart';

/// Main navigation screen with tabs for Home, Library, and Settings
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CatalogGridScreen(),
    const LibraryScreen(),
    const SettingsScreen(),
  ];

  final List<String> _screenNames = ['Home', 'Library', 'Settings'];

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        PersistentNavigationHeader(
          currentIndex: _currentIndex,
          onNavigate: _navigateTo,
        ),
      ],
      child: _screens[_currentIndex],
    );
  }
}

