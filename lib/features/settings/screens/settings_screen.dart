import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../addons/models/addon_config.dart';
import '../../addons/logic/addon_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../addons/screens/addon_details_screen.dart';
import '../../../core/constants/app_constants.dart';
import '../../library/logic/catalog_preferences_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/theme_service.dart';

/// Check if the app is running in a Flatpak environment
bool _isRunningInFlatpak() {
  // Check for Flatpak environment variables (most reliable indicator)
  final flatpakId = Platform.environment['FLATPAK_ID'];
  if (flatpakId != null && flatpakId.isNotEmpty) {
    return true;
  }
  
  // Check if executable path is in Flatpak app directory
  try {
    final executable = Platform.resolvedExecutable;
    if (executable.startsWith('/app/')) {
      return true;
    }
  } catch (e) {
    // If we can't determine, continue with other checks
  }
  
  return false;
}

/// Open URL in browser, using xdg-open in Flatpak if needed
Future<void> _openUrlInBrowser(String url) async {
  if (_isRunningInFlatpak()) {
    // In Flatpak, use xdg-open directly via portal
    // Try /usr/bin/xdg-open first (standard location in Flatpak runtime)
    try {
      final result = await Process.run('/usr/bin/xdg-open', [url]);
      if (result.exitCode != 0) {
        throw 'xdg-open failed with exit code ${result.exitCode}';
      }
    } catch (e) {
      // Try xdg-open from PATH as fallback
      try {
        final result = await Process.run('xdg-open', [url]);
        if (result.exitCode != 0) {
          throw 'xdg-open failed with exit code ${result.exitCode}';
        }
      } catch (e2) {
        // Final fallback to url_launcher
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          throw 'Could not launch $url: $e2';
        }
      }
    }
  } else {
    // Non-Flatpak: use url_launcher
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }
}

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
  bool _isTraktAuthenticated = false;
  bool _isCheckingTraktAuth = true;
  String? _traktUsername;
  bool _isSyncingWatchHistory = false;
  String? _accentColor;
  bool _isLoadingAccentColor = true;
  String? _defaultAudioLanguage;
  String? _defaultSubtitleLanguage;
  bool _isLoadingPlayerSettings = true;

  @override
  void initState() {
    super.initState();
    _database = DatabaseProvider.instance;
    _addonRepository = AddonRepository(_database);
    _catalogPreferencesRepository = CatalogPreferencesRepository(_database);
    _loadAddons();
    _loadCatalogs();
    _checkTraktAuth();
    _loadAccentColor();
    _loadPlayerSettings();
  }

  Future<void> _loadAccentColor() async {
    final color = await _database.getSettingValue('accent_color');
    if (mounted) {
      setState(() {
        _accentColor = color ?? '#3b82f6'; // Default blue
        _isLoadingAccentColor = false;
      });
    }
  }

  Future<void> _setAccentColor(String color) async {
    // Use theme service to update accent color, which will trigger app rebuild
    await ThemeService().setAccentColorByHex(color);
    if (mounted) {
      setState(() {
        _accentColor = color;
      });
    }
  }

  Future<void> _loadPlayerSettings() async {
    final audioLang = await _database.getSettingValue('default_audio_language');
    final subtitleLang = await _database.getSettingValue('default_subtitle_language');
    if (mounted) {
      setState(() {
        _defaultAudioLanguage = audioLang ?? 'en'; // Default to English
        _defaultSubtitleLanguage = subtitleLang ?? 'en'; // Default to English
        _isLoadingPlayerSettings = false;
      });
    }
  }

  Future<void> _setDefaultAudioLanguage(String language) async {
    await _database.setSetting('default_audio_language', language);
    if (mounted) {
      setState(() {
        _defaultAudioLanguage = language;
      });
    }
  }

  Future<void> _setDefaultSubtitleLanguage(String language) async {
    await _database.setSetting('default_subtitle_language', language);
    if (mounted) {
      setState(() {
        _defaultSubtitleLanguage = language;
      });
    }
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
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400,
            minWidth: 300,
          ),
          child: TextField(
            controller: manifestUrlController,
            placeholder: const Text('https://addon.example.com/manifest.json'),
            autofocus: true,
          ),
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
        child: LoadingIndicator(),
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
    return ListView(
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
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.horizontalMargin,
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _addons.map((addon) => SizedBox(
                  width: 400,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
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
                )).toList(),
              ),
            ),
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
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.horizontalMargin,
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _catalogs.map((catalog) => SizedBox(
                  width: 400,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(catalog.catalogName).h4(),
                                        ),
                                        if (catalog.isHeroSource)
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
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${catalog.addonName} • ${_capitalize(catalog.catalogType)}').muted(),
                                    if (catalog.catalogId != null && catalog.catalogId!.isNotEmpty)
                                      Text('ID: ${catalog.catalogId}').muted().small(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (catalog.isHeroSource)
                                const SizedBox.shrink()
                              else
                                const SizedBox.shrink(),
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
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
          const SizedBox(height: AppConstants.sectionSpacing),

          // Accounts and API Section
          const _SectionHeader(
            title: 'Accounts and API',
            icon: Icons.account_circle,
          ),
          Padding(
            padding: AppConstants.contentPadding,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Trakt').h4(),
                              const SizedBox(height: 4),
                              if (_isCheckingTraktAuth)
                                const Text('Checking authentication status...').muted()
                              else if (_isTraktAuthenticated && _traktUsername != null)
                                Text('Logged in as @$_traktUsername').muted()
                              else if (_isTraktAuthenticated)
                                const Text('Logged in').muted()
                              else
                                const Text('Not connected').muted(),
                            ],
                          ),
                        ),
                        if (_isCheckingTraktAuth)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: LoadingIndicator(),
                          )
                        else if (_isTraktAuthenticated)
                          Row(
                            children: [
                              GhostButton(
                                onPressed: _isSyncingWatchHistory ? null : _syncWatchHistory,
                                child: const Text('Resync Watch History'),
                              ),
                              const SizedBox(width: 8),
                              PrimaryButton(
                                onPressed: _logoutTrakt,
                                child: const Text('Logout'),
                              ),
                            ],
                          )
                        else
                          PrimaryButton(
                            onPressed: _loginTrakt,
                            child: const Text('Login'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.sectionSpacing),

          // Appearance Section
          const _SectionHeader(
            title: 'Appearance',
            icon: Icons.palette,
          ),
          Padding(
            padding: AppConstants.contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Accent Color').semiBold(),
                const SizedBox(height: 12),
                if (_isLoadingAccentColor)
                  const LoadingIndicator(message: 'Loading...')
                else
                  _AccentColorPicker(
                    selectedColor: _accentColor ?? '#3b82f6',
                    onColorSelected: _setAccentColor,
                  ),
                const SizedBox(height: 8),
                const Text('Accent color changes apply immediately.').muted(),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.sectionSpacing),

          // Player Settings Section
          const _SectionHeader(
            title: 'Player Settings',
            icon: Icons.play_circle_outline,
          ),
          if (_isLoadingPlayerSettings)
            Padding(
              padding: AppConstants.contentPadding,
              child: const LoadingIndicator(message: 'Loading player settings...'),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.horizontalMargin,
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // Default Audio Language Card
                  SizedBox(
                    width: 400,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Default Audio Language').h4(),
                                      const SizedBox(height: 4),
                                      const Text('Preferred audio language for playback').muted(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _LanguageSelect(
                              selectedLanguage: _defaultAudioLanguage ?? 'en',
                              onLanguageSelected: _setDefaultAudioLanguage,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Default Subtitle Language Card
                  SizedBox(
                    width: 400,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Default Subtitle Language').h4(),
                                      const SizedBox(height: 4),
                                      const Text('Preferred subtitle language for playback').muted(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _LanguageSelect(
                              selectedLanguage: _defaultSubtitleLanguage ?? 'en',
                              onLanguageSelected: _setDefaultSubtitleLanguage,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
      // Toggle behavior: if already hero, unset it; otherwise, set it as hero
      if (catalog.isHeroSource) {
        await _catalogPreferencesRepository.unsetHeroCatalog(
          catalog.addonId,
          catalog.catalogType,
          catalog.catalogId,
        );
        _loadCatalogs();
        if (mounted) {
          showToast(
            context: context,
            location: ToastLocation.topRight,
            builder: (context, overlay) => SizedBox(
              width: 400,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Hero catalog removed: ${catalog.catalogName}',
                    style: const TextStyle(fontSize: 16),
                    softWrap: true,
                  ),
                ),
              ),
            ),
          );
        }
      } else {
        await _catalogPreferencesRepository.setHeroCatalog(
          catalog.addonId,
          catalog.catalogType,
          catalog.catalogId,
        );
        _loadCatalogs();
        if (mounted) {
          showToast(
            context: context,
            location: ToastLocation.topRight,
            builder: (context, overlay) => SizedBox(
              width: 400,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Hero catalog set to: ${catalog.catalogName}',
                    style: const TextStyle(fontSize: 16),
                    softWrap: true,
                  ),
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showToast(
          context: context,
          location: ToastLocation.topRight,
          builder: (context, overlay) => SizedBox(
            width: 400,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to ${catalog.isHeroSource ? "unset" : "set"} hero catalog: $e',
                  style: const TextStyle(fontSize: 16),
                  softWrap: true,
                ),
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _checkTraktAuth() async {
    setState(() {
      _isCheckingTraktAuth = true;
    });

    try {
      final isAuthenticated = await ServiceLocator.instance.traktAuthService.isAuthenticated();
      String? username;
      if (isAuthenticated) {
        final user = await ServiceLocator.instance.traktAuthService.getCurrentUser();
        username = user?['username'];
      }
      setState(() {
        _isTraktAuthenticated = isAuthenticated;
        _traktUsername = username;
        _isCheckingTraktAuth = false;
      });
    } catch (e) {
      setState(() {
        _isTraktAuthenticated = false;
        _traktUsername = null;
        _isCheckingTraktAuth = false;
      });
    }
  }


  Future<void> _loginTrakt() async {
    if (!ServiceLocator.instance.traktAuthService.isConfigured) {
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Trakt is not configured. Please add TRAKT_CLIENT_ID and TRAKT_CLIENT_SECRET to your .env file.',
              ),
            ),
          ),
        );
      }
      return;
    }

    // Show loading dialog while generating device code
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Generate device code
      final deviceCodeResponse = await ServiceLocator.instance.traktAuthService.generateDeviceCode();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }

      if (deviceCodeResponse == null) {
        if (mounted) {
          showToast(
            context: context,
            builder: (context, overlay) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const Text('Failed to generate device code. Please try again.'),
              ),
            ),
          );
        }
        return;
      }

      // Show device code dialog
      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Connect to Trakt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To connect your Trakt account, please visit the following URL and enter the code:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Code:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      deviceCodeResponse.userCode,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Visit this URL:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(
                deviceCodeResponse.verificationUrl,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This code will expire in ${deviceCodeResponse.expiresIn} seconds.',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            SecondaryButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            PrimaryButton(
              onPressed: () {
                // Open verification URL in browser
                _openUrlInBrowser(deviceCodeResponse.verificationUrl);
                Navigator.of(context).pop(true);
              },
              child: const Text('Open URL & Continue'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        return;
      }

      // Show polling dialog
      bool pollingCancelled = false;
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Waiting for authorization'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LoadingIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Please visit the URL and enter the code to authorize this app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Code: ${deviceCodeResponse.userCode}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            actions: [
              SecondaryButton(
                onPressed: () {
                  pollingCancelled = true;
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }

      // Poll for access token
      final startTime = DateTime.now();
      final expiresAt = startTime.add(Duration(seconds: deviceCodeResponse.expiresIn));
      bool success = false;

      while (!pollingCancelled && DateTime.now().isBefore(expiresAt)) {
        // Wait for the polling interval
        await Future.delayed(Duration(seconds: deviceCodeResponse.interval));

        if (pollingCancelled) break;

        final result = await ServiceLocator.instance.traktAuthService.pollForAccessToken(
          deviceCodeResponse.deviceCode,
          deviceCodeResponse.interval,
        );

        if (result == true) {
          // Success!
          success = true;
          break;
        } else if (result == false) {
          // Failed (expired, denied, etc.)
          break;
        }
        // result == null means still pending, continue polling
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close polling dialog
      }

      if (success) {
        // Update auth status immediately
        await _checkTraktAuth();
        
        // Show blocking loading dialog for syncing history
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LoadingIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Syncing history...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Sync watch history
        try {
          final watchHistoryService = ServiceLocator.instance.watchHistoryService;
          final database = ServiceLocator.instance.database;

          // Clear all existing watch history first
          await database.clearWatchHistory();
          
          // Also clear the last sync timestamp to force a completely fresh sync from scratch
          await database.deleteSetting('last_trakt_sync');

          // Then sync fresh data from Trakt
          final syncedCount = await watchHistoryService.syncWatchHistory(forceRefresh: true);

          if (mounted) {
            Navigator.of(context).pop(); // Close syncing dialog
            
            showToast(
              context: context,
              builder: (context, overlay) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Successfully logged in and synced $syncedCount watch history items from Trakt'),
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop(); // Close syncing dialog
            
            showToast(
              context: context,
              builder: (context, overlay) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Logged in successfully, but failed to sync history: $e'),
                ),
              ),
            );
          }
        }
      } else if (!pollingCancelled) {
        if (mounted) {
          showToast(
            context: context,
            builder: (context, overlay) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Authentication failed or expired. Please try again.',
                ),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close any open dialogs
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error logging in to Trakt: $e'),
            ),
          ),
        );
      }
    }
  }


  Future<void> _logoutTrakt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout from Trakt'),
        content: const Text('Are you sure you want to logout from Trakt?'),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          DestructiveButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ServiceLocator.instance.traktAuthService.logout();
      setState(() {
        _isTraktAuthenticated = false;
        _traktUsername = null;
      });
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Text('Logged out from Trakt'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _syncWatchHistory() async {
    if (!_isTraktAuthenticated) {
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Text('You must be logged in to Trakt to resync watch history'),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSyncingWatchHistory = true;
    });

    // Show progress dialog with state management
    final progressController = StreamController<Map<String, dynamic>>();
    bool isDialogOpen = false;

    void updateProgress(int current, int total, String status) {
      progressController.add({
        'current': current,
        'total': total,
        'status': status,
      });
    }

    void showProgressDialog() {
      if (!mounted || isDialogOpen) return;
      isDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Syncing Watch History'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
                minWidth: 300,
              ),
              child: StreamBuilder<Map<String, dynamic>>(
                stream: progressController.stream,
                initialData: {'current': 0, 'total': 100, 'status': 'Starting sync...'},
                builder: (context, snapshot) {
                  final data = snapshot.data ?? {'current': 0, 'total': 100, 'status': 'Starting sync...'};
                  final current = data['current'] as int? ?? 0;
                  final total = data['total'] as int? ?? 100;
                  final status = data['status'] as String? ?? 'Starting sync...';
                  final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress bar using shadcn Progress component with visible background
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Progress(
                          progress: (progress * 100).clamp(0, 100),
                          min: 0,
                          max: 100,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status text
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.foreground,
                        ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 8),
                        // Progress percentage and count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.foreground,
                              ),
                            ),
                            Text(
                              '$current / $total items',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.foreground,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            actions: [
              GhostButton(
                onPressed: () {
                  ServiceLocator.instance.watchHistoryService.cancelSync();
                  Navigator.of(context).pop();
                  isDialogOpen = false;
                  progressController.close();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    }

    try {
      final watchHistoryService = ServiceLocator.instance.watchHistoryService;
      final database = ServiceLocator.instance.database;

      // Show progress dialog
      showProgressDialog();

      // Clear all existing watch history first
      updateProgress(0, 100, 'Clearing existing history...');
      await Future.delayed(const Duration(milliseconds: 50));
      
      await database.clearWatchHistory();
      
      // Also clear the last sync timestamp to force a completely fresh sync from scratch
      // This ensures we get all history, not just recent changes if any timestamp remained
      await database.deleteSetting('last_trakt_sync');

      // Then sync fresh data from Trakt with progress callback
      final syncedCount = await watchHistoryService.syncWatchHistory(
        forceRefresh: true,
        onProgress: updateProgress,
      );

      // Close progress dialog
      if (mounted && isDialogOpen) {
        progressController.close();
        Navigator.of(context).pop();
        isDialogOpen = false;
      }

      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Successfully resynced $syncedCount watch history items from Trakt'),
            ),
          ),
        );
      }
    } catch (e) {
      // Close progress dialog if open
      if (mounted && isDialogOpen) {
        progressController.close();
        Navigator.of(context).pop();
        isDialogOpen = false;
      }
      
      if (mounted) {
        showToast(
          context: context,
          builder: (context, overlay) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to resync watch history: $e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingWatchHistory = false;
        });
      }
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  @override
  void dispose() {
    // Note: Don't close the database here - it's a singleton that should remain open
    // for the app's lifetime. Closing it here would break database access for the entire app.
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

/// Color picker widget for accent color selection
class _AccentColorPicker extends StatelessWidget {
  final String selectedColor;
  final Function(String) onColorSelected;

  const _AccentColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  // Predefined accent colors
  static const List<Map<String, String>> _colors = [
    {'name': 'Blue', 'value': '#3b82f6'},
    {'name': 'Purple', 'value': '#a855f7'},
    {'name': 'Pink', 'value': '#ec4899'},
    {'name': 'Red', 'value': '#ef4444'},
    {'name': 'Orange', 'value': '#f97316'},
    {'name': 'Yellow', 'value': '#eab308'},
    {'name': 'Green', 'value': '#22c55e'},
    {'name': 'Teal', 'value': '#14b8a6'},
    {'name': 'Cyan', 'value': '#06b6d4'},
    {'name': 'Indigo', 'value': '#6366f1'},
    {'name': 'Rose', 'value': '#f43f5e'},
    {'name': 'Amber', 'value': '#f59e0b'},
  ];

  material.Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return material.Color(int.parse('FF$hexCode', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _colors.map((colorData) {
        final color = _hexToColor(colorData['value']!);
        final isSelected = selectedColor.toLowerCase() == colorData['value']!.toLowerCase();
        
        return Clickable(
          onPressed: () => onColorSelected(colorData['value']!),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.foreground
                    : Theme.of(context).colorScheme.border,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: _getContrastColor(color),
                    size: 24,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  material.Color _getContrastColor(material.Color color) {
    // Calculate relative luminance
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? const material.Color(0xFF000000) : const material.Color(0xFFFFFFFF);
  }
}

/// Language select widget using shadcn-styled Select component
class _LanguageSelect extends StatefulWidget {
  final String selectedLanguage;
  final Function(String) onLanguageSelected;

  const _LanguageSelect({
    required this.selectedLanguage,
    required this.onLanguageSelected,
  });

  @override
  State<_LanguageSelect> createState() => _LanguageSelectState();
}

class _LanguageSelectState extends State<_LanguageSelect> {
  // Full list of common languages
  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'it', 'name': 'Italian'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'ko', 'name': 'Korean'},
    {'code': 'zh', 'name': 'Chinese'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'nl', 'name': 'Dutch'},
    {'code': 'pl', 'name': 'Polish'},
    {'code': 'tr', 'name': 'Turkish'},
    {'code': 'sv', 'name': 'Swedish'},
    {'code': 'da', 'name': 'Danish'},
    {'code': 'no', 'name': 'Norwegian'},
    {'code': 'fi', 'name': 'Finnish'},
    {'code': 'cs', 'name': 'Czech'},
    {'code': 'hu', 'name': 'Hungarian'},
    {'code': 'ro', 'name': 'Romanian'},
    {'code': 'th', 'name': 'Thai'},
    {'code': 'vi', 'name': 'Vietnamese'},
  ];

  String _getLanguageName(String code) {
    return _languages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'code': code, 'name': code.toUpperCase()},
    )['name']!;
  }

  List<Map<String, String>> _filterLanguages(String? searchQuery) {
    if (searchQuery == null || searchQuery.isEmpty) {
      return _languages;
    }
    final query = searchQuery.toLowerCase();
    return _languages
        .where((lang) => 
            lang['name']!.toLowerCase().contains(query) ||
            lang['code']!.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Select<String>(
      itemBuilder: (context, item) {
        return Text(_getLanguageName(item));
      },
      popup: SelectPopup.builder(
        searchPlaceholder: const Text('Search language'),
        emptyBuilder: (context) {
          return const Center(
            child: Text('No language found'),
          );
        },
        builder: (context, searchQuery) async {
          final filteredLanguages = _filterLanguages(searchQuery);
          
          return SelectItemBuilder(
            childCount: filteredLanguages.isEmpty ? 0 : null,
            builder: (context, index) {
              final language = filteredLanguages[index % filteredLanguages.length];
              final isSelected = language['code'] == widget.selectedLanguage;
              
              return SelectItemButton(
                value: language['code']!,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(language['name']!),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      onChanged: (value) {
        if (value != null) {
          widget.onLanguageSelected(value);
        }
      },
      constraints: const BoxConstraints(
        maxHeight: 300,
        minWidth: 200,
      ),
      value: widget.selectedLanguage,
      placeholder: const Text('Select language'),
    );
  }
}

