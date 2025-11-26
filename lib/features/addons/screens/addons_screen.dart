import 'package:flutter/material.dart';
import '../models/addon_config.dart';
import '../logic/addon_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/loading_indicator.dart';
import 'addon_details_screen.dart';

/// Screen to list installed addons and add new ones
class AddonsScreen extends StatefulWidget {
  const AddonsScreen({super.key});

  @override
  State<AddonsScreen> createState() => _AddonsScreenState();
}

class _AddonsScreenState extends State<AddonsScreen> {
  late final AppDatabase _database;
  late final AddonRepository _addonRepository;
  List<AddonConfig> _addons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _database = DatabaseProvider.instance;
    _addonRepository = AddonRepository(_database);
    _loadAddons();
  }

  Future<void> _loadAddons() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final addons = await _addonRepository.listAddons();
      setState(() {
        _addons = addons;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load addons: $e')),
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
          decoration: const InputDecoration(
            labelText: 'Manifest URL',
            hintText: 'https://addon.example.com/manifest.json',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Addon installed successfully')),
        );
        await _loadAddons();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to install addon: $e')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle addon: $e')),
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _addonRepository.removeAddon(addon.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Addon removed')),
          );
          await _loadAddons();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove addon: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading addons...');
    }

    return Scaffold(
      body: _addons.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.extension_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No addons installed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to add an addon',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _addons.length,
              itemBuilder: (context, index) {
                final addon = _addons[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(addon.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Version: ${addon.version}'),
                        if (addon.description != null)
                          Text(
                            addon.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: addon.enabled,
                          onChanged: (_) => _toggleAddon(addon),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeAddon(addon),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AddonDetailsScreen(
                            addon: addon,
                            addonRepository: _addonRepository,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAddon,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    // Note: Don't close the database here - it's a singleton that should remain open
    // for the app's lifetime. Closing it here would break database access for the entire app.
    super.dispose();
  }
}


