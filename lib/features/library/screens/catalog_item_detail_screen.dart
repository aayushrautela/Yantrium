import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart';
import '../models/catalog_item.dart';
import '../../../core/constants/app_constants.dart';
import '../logic/library_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/persistent_navigation_header.dart';

/// Detail screen for a catalog item (movie or series)
class CatalogItemDetailScreen extends StatefulWidget {
  final CatalogItem item;

  const CatalogItemDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<CatalogItemDetailScreen> createState() => _CatalogItemDetailScreenState();
}

class _CatalogItemDetailScreenState extends State<CatalogItemDetailScreen> {
  int _selectedTab = 0;
  late final LibraryRepository _libraryRepository;
  CatalogItem? _enrichedItem;

  @override
  void initState() {
    super.initState();
    _libraryRepository = LibraryRepository(AppDatabase());
    _enrichItem();
  }

  Future<void> _enrichItem() async {
    try {
      final enriched = await _libraryRepository.enrichItemForHero(widget.item);
      if (mounted && enriched != null) {
        // Preserve original logo if it exists, otherwise use enriched logo
        final finalItem = enriched.copyWith(
          logo: widget.item.logo?.isNotEmpty == true 
              ? widget.item.logo 
              : enriched.logo,
        );
        setState(() {
          _enrichedItem = finalItem;
        });
      }
    } catch (e) {
      // Use original item if enrichment fails
      if (mounted) {
        setState(() {
          _enrichedItem = widget.item;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _enrichedItem ?? widget.item;

    return Scaffold(
      headers: [
        PersistentNavigationHeader(
          showBackButton: true,
          onBack: () => Navigator.of(context).pop(),
        ),
      ],
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Solid background color for the whole page
          Container(
            color: Theme.of(context).colorScheme.background,
          ),

          // Backdrop image in the top right, scaled to 80%
          if (item.background != null)
            Positioned(
              top: 0,
              right: 0,
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    item.background!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).colorScheme.muted,
                    ),
                  ),
                  // Gradient to blend left and bottom edges
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Theme.of(context).colorScheme.background.withOpacity(0.5),
                          Theme.of(context).colorScheme.background,
                        ],
                        stops: const [0.0, 0.4, 0.8, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Column(
            children: [
              // Top content area
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: AppConstants.horizontalMargin,
                      right: AppConstants.horizontalMargin,
                      top: 120,
                      bottom: 100,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        if (item.logo != null && item.logo!.isNotEmpty)
                          SizedBox(
                            width: 600, // Max width constraint
                            height: 250, // Max height constraint
                            child: Image.network(
                              item.logo!,
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  item.name.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.yellow,
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Text(
                            item.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.yellow,
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Metadata
                        Wrap(
                          spacing: 16,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Match percentage
                            if (item.imdbRating != null)
                              Text(
                                '${(double.tryParse(item.imdbRating!) ?? 0 * 10).toInt()}% Match',
                                style: TextStyle(
                                  color: Colors.green[400],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),

                            // Year
                            if (item.releaseInfo != null)
                              Text(
                                item.releaseInfo!.split('-').first, // Extract year
                                style: const TextStyle(fontSize: 16),
                              ),

                            // Rating badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.muted,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.border,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TV-14',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),

                            // Seasons (for series)
                            if (item.type == 'series')
                              Text(
                                '14 Seasons',
                                style: const TextStyle(fontSize: 16),
                              ),

                            // HD badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.muted,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.border,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'HD',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Description
                        if (item.description != null)
                          SizedBox(
                            width: 600,
                            child: Text(
                              item.description!,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        const SizedBox(height: 28),

                        // Action Buttons
                        Row(
                          children: [
                            PrimaryButton(
                              onPressed: () {},
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'Play',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SecondaryButton(
                              onPressed: () {},
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'My List',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Navigation tabs
                        Row(
                          children: [
                            // EPISODES tab only for series
                            if (item.type == 'series') ...[
                              _TabButton(
                                label: 'EPISODES',
                                isSelected: _selectedTab == 0,
                                onTap: () => setState(() => _selectedTab = 0),
                              ),
                              const SizedBox(width: 32),
                            ],
                            _TabButton(
                              label: 'CAST & CREW',
                              isSelected: _selectedTab == (item.type == 'series' ? 1 : 0),
                              onTap: () => setState(() => _selectedTab = item.type == 'series' ? 1 : 0),
                            ),
                            const SizedBox(width: 32),
                            _TabButton(
                              label: 'MORE LIKE THIS',
                              isSelected: _selectedTab == (item.type == 'series' ? 2 : 1),
                              onTap: () => setState(() => _selectedTab = item.type == 'series' ? 2 : 1),
                            ),
                            const SizedBox(width: 32),
                            _TabButton(
                              label: 'DETAILS',
                              isSelected: _selectedTab == (item.type == 'series' ? 3 : 2),
                              onTap: () => setState(() => _selectedTab = item.type == 'series' ? 3 : 2),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? Colors.yellow
                  : Theme.of(context).colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              height: 2,
              width: label.length * 8.0,
              color: Colors.yellow,
            ),
        ],
      ),
    );
  }
}

