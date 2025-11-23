import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../addons/models/addon_config.dart';
import '../../addons/logic/addon_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../addons/screens/addon_details_screen.dart';
import '../../../core/constants/app_constants.dart';
import '../../library/logic/catalog_preferences_repository.dart';

/// Settings screen with all settings in a long scrolling page
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppDatabase _database;
  late final AddonRepository _addonRepository;
  late final CatalogPreferencesRepository _catalogPreferencesRepository;
  List<AddonConfig> _addons = [];
  bool _isLoadingAddons = true;
  List<CatalogInfo> _catalogs = [];
  bool _isLoadingCatalogs = true;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _addonRepository = AddonRepository(_database);
    _catalogPreferencesRepository = CatalogPreferencesRepository(_database);
    _loadAddons();
    _loadCatalogs();
  }

  Future<void> _loadAddons() async {
    setState(() {
      _isLoadingAddons = true;
    });

    try {
      final addons = await _addonRepository.listAddons();
      setState(() {
        _addons = addons;
        _isLoadingAddons = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAddons = false;
      });
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load addons: $e'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _addAddon() async {
    final manifestUrlController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Addon'),
        content: TextField(
          controller: manifestUrlController,
          placeholder: const Text('https://addon.example.com/manifest.json'),
          autofocus: true,
        ),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && manifestUrlController.text.isNotEmpty) {
      await _installAddon(manifestUrlController.text);
    }
  }

  Future<void> _installAddon(String manifestUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await _addonRepository.installAddon(manifestUrl);
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Text('Addon installed successfully'),
            ),
          ),
        );
        await _loadAddons();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to install addon: $e'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleAddon(AddonConfig addon) async {
    try {
      if (addon.enabled) {
        await _addonRepository.disableAddon(addon.id);
      } else {
        await _addonRepository.enableAddon(addon.id);
      }
      await _loadAddons();
    } catch (e) {
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to toggle addon: $e'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeAddon(AddonConfig addon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Addon'),
        content: Text('Are you sure you want to remove ${addon.name}?'),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          DestructiveButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _addonRepository.removeAddon(addon.id);
        if (mounted) {
          showToast(
            context: context,
            builder: (context, overlay) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const Text('Addon removed'),
              ),
            ),
          );
          await _loadAddons();
        }
      } catch (e) {
        if (mounted) {
          showToast(
            context: context,
            builder: (context, overlay) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to remove addon: $e'),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: const [
        AppBar(
          title: Text('Settings'),
        ),
      ],
      child: ListView(
        children: [
          // Addon Management Section
          _SectionHeader(
            title: 'Addon Management',
            icon: Icons.extension,
            action: GhostButton(
              onPressed: _addAddon,
              density: ButtonDensity.icon,
              child: const Icon(Icons.add),
            ),
          ),
          if (_isLoadingAddons)
            Padding(
              padding: AppConstants.contentPadding,
              child: const LoadingIndicator(message: 'Loading addons...'),
            )
          else if (_addons.isEmpty)
            Padding(
              padding: AppConstants.contentPadding,
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.extension_outlined,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    const Text('No addons installed').muted(),
                  ],
                ),
              ),
            )
          else
            ..._addons.map((addon) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.horizontalMargin,
                    vertical: 4,
                  ),
                  child: Clickable(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AddonDetailsScreen(
                            addon: addon,
                            addonRepository: _addonRepository,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(addon.name).h4(),
                                  const SizedBox(height: 4),
                                  Text('Version: ${addon.version}').muted(),
                                  if (addon.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      addon.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ).muted(),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: addon.enabled,
                                  onChanged: (_) => _toggleAddon(addon),
                                ),
                                const SizedBox(width: 8),
                                GhostButton(
                                  onPressed: () => _removeAddon(addon),
                                  density: ButtonDensity.icon,
                                  child: const Icon(Icons.delete),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
          const SizedBox(height: 16),

          // Catalog Management Section
          _SectionHeader(
            title: 'Catalog Management',
            icon: Icons.library_books,
            action: GhostButton(
              onPressed: _loadCatalogs,
              density: ButtonDensity.icon,
              child: const Icon(Icons.refresh),
            ),
          ),
          if (_isLoadingCatalogs)
            Padding(
              padding: AppConstants.contentPadding,
              child: const LoadingIndicator(message: 'Loading catalogs...'),
            )
          else if (_catalogs.isEmpty)
            Padding(
              padding: AppConstants.contentPadding,
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.library_books_outlined,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    const Text('No catalogs available').muted(),
                    const SizedBox(height: 8),
                    const Text('Enable addons with catalog support to see catalogs here.').muted(),
                  ],
                ),
              ),
            )
          else
            ..._catalogs.map((catalog) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.horizontalMargin,
                    vertical: 4,
                  ),
                  child: Card(
                    child: Padding(
                      padding: AppConstants.contentPadding,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(catalog.catalogName).h4(),
                                    if (catalog.isHeroSource) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'HERO',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primaryForeground,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${catalog.addonName} • ${_capitalize(catalog.catalogType)}').muted(),
                                if (catalog.catalogId != null && catalog.catalogId!.isNotEmpty)
                                  Text('ID: ${catalog.catalogId}').muted().small(),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Hero selection button
                              GhostButton(
                                onPressed: () => _setHeroCatalog(catalog),
                                density: ButtonDensity.icon,
                                child: Icon(
                                  catalog.isHeroSource ? Icons.star : Icons.star_border,
                                  color: catalog.isHeroSource
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Enable/disable toggle
                              Switch(
                                value: catalog.enabled,
                                onChanged: (value) => _toggleCatalog(catalog, value),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          const SizedBox(height: AppConstants.sectionSpacing),

          // Appearance Section
          const _SectionHeader(
            title: 'Appearance',
            icon: Icons.palette,
          ),
          Padding(
            padding: AppConstants.contentPadding,
            child: const Text('Appearance settings will be available here.').muted(),
          ),
          const SizedBox(height: AppConstants.sectionSpacing),

          // Player Settings Section
          const _SectionHeader(
            title: 'Player Settings',
            icon: Icons.play_circle_outline,
          ),
          Padding(
            padding: AppConstants.contentPadding,
            child: const Text('Player settings will be available here.').muted(),
          ),
          const SizedBox(height: AppConstants.sectionSpacing),

          // About Section
          const _SectionHeader(
            title: 'About',
            icon: Icons.info_outline,
          ),
          Padding(
            padding: AppConstants.horizontalPadding,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Yantrium').h4(),
                          const SizedBox(height: 4),
                          const Text('Version 1.0.0').muted(),
                        ],
                      ),
                    ),
                    GhostButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('About'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.movie, size: 48),
                                const SizedBox(height: 16),
                                const Text('Yantrium').h3(),
                                const SizedBox(height: 8),
                                const Text('Version 1.0.0').muted(),
                              ],
                            ),
                            actions: [
                              PrimaryButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      density: ButtonDensity.icon,
                      child: const Icon(Icons.info),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      footers: [
        PrimaryButton(
          onPressed: _addAddon,
          density: ButtonDensity.icon,
          child: const Icon(Icons.add),
        ),
      ],
    );
  }

  Future<void> _loadCatalogs() async {
    setState(() {
      _isLoadingCatalogs = true;
    });

    try {
      final catalogs = await _catalogPreferencesRepository.getAvailableCatalogs();
      setState(() {
        _catalogs = catalogs;
        _isLoadingCatalogs = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCatalogs = false;
      });
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: AppConstants.contentPadding,
              child: Text('Failed to load catalogs: $e'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleCatalog(CatalogInfo catalog, bool enabled) async {
    try {
      await _catalogPreferencesRepository.toggleCatalogEnabled(
        catalog.addonId,
        catalog.catalogType,
        catalog.catalogId,
        enabled,
      );
      _loadCatalogs();
    } catch (e) {
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: AppConstants.contentPadding,
              child: Text('Failed to toggle catalog: $e'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _setHeroCatalog(CatalogInfo catalog) async {
    try {
      await _catalogPreferencesRepository.setHeroCatalog(
        catalog.addonId,
        catalog.catalogType,
        catalog.catalogId,
      );
      _loadCatalogs();
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: AppConstants.contentPadding,
              child: Text('Hero catalog set to: ${catalog.catalogName}'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: AppConstants.contentPadding,
              child: Text('Failed to set hero catalog: $e'),
            ),
          ),
        );
      }
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppConstants.sectionHeaderPadding,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(title).h4(),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}
