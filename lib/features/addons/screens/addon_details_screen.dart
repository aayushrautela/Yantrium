import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../models/addon_config.dart';
import '../logic/addon_repository.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/back_button_overlay.dart';

/// Screen showing detailed information about an addon
class AddonDetailsScreen extends StatelessWidget {
  final AddonConfig addon;
  final AddonRepository addonRepository;

  const AddonDetailsScreen({
    super.key,
    required this.addon,
    required this.addonRepository,
  });

  @override
  Widget build(BuildContext context) {
    final manifest = addonRepository.getManifest(addon);

    return Stack(
      children: [
        // Back button overlay
        BackButtonOverlay(
          onBack: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
          },
        ),
        // Content
        ListView(
      padding: AppConstants.contentPadding,
      children: [
        _buildSection(
          'Information',
          [
            _buildInfoRow('ID', addon.id),
            _buildInfoRow('Version', addon.version),
            _buildInfoRow('Base URL', addon.baseUrl),
            _buildInfoRow('Manifest URL', addon.manifestUrl),
            if (addon.description != null)
              _buildInfoRow('Description', addon.description!),
            _buildInfoRow('Status', addon.enabled ? 'Enabled' : 'Disabled'),
          ],
        ),
        const SizedBox(height: AppConstants.sectionSpacing),
        _buildSection(
          'Supported Types',
          [
            Wrap(
              spacing: 8,
              children: addon.types
                  .map((type) => Chip(child: Text(type)))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.sectionSpacing),
        _buildSection(
          'Resources',
          [
            Wrap(
              spacing: 8,
              children: manifest.resources
                  .map((resource) {
                    final name = resource is String
                        ? resource
                        : (resource as Map<String, dynamic>)['name'] as String;
                    return Chip(child: Text(name));
                  })
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.sectionSpacing),
        _buildSection(
          'Catalogs',
          manifest.catalogs.isEmpty
              ? [const Text('No catalogs available').muted()]
              : manifest.catalogs
                  .map((catalog) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      catalog.name ?? catalog.id ?? 'Unnamed',
                                    ).h4(),
                                    const SizedBox(height: 4),
                                    Text('Type: ${catalog.type}').muted(),
                                  ],
                                ),
                              ),
                              if (catalog.id != null && catalog.id!.isNotEmpty)
                                Text('ID: ${catalog.id}').muted(),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
        ),
      ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title).h4(),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:').semiBold(),
          ),
          Expanded(
            child: Text(value).muted(),
          ),
        ],
      ),
    );
  }
}
