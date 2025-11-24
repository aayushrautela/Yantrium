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
  final TextEditingController _searchController = TextEditingController();

  late final List<Widget> _screens;

  final List<String> _screenNames = ['Home', 'Library', 'Settings'];

  @override
  void initState() {
    super.initState();
    _screens = [
      CatalogGridScreen(searchController: _searchController),
      const LibraryScreen(),
      const SettingsScreen(),
    ];
  }

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        PersistentNavigationHeader(
          currentIndex: _currentIndex,
          onNavigate: _navigateTo,
          searchController: _currentIndex == 0 ? _searchController : null,
        ),
      ],
      child: _screens[_currentIndex],
    );
  }
}

