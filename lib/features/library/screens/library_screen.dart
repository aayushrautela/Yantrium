import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/services/service_locator.dart';
import '../models/catalog_item.dart';
import 'catalog_item_detail_screen.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/smart_image.dart';

/// Library screen displaying saved content
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with WidgetsBindingObserver {
  List<CatalogItem> _libraryItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLibraryItems();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh library when app comes back to foreground
      _loadLibraryItems();
    }
  }

  void refresh() {
    _loadLibraryItems();
  }

  Future<void> _loadLibraryItems() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final items = await ServiceLocator.instance.libraryService.getLibraryItems();
      if (mounted) {
        setState(() {
          _libraryItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading library: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: LoadingIndicator(message: 'Loading library...'),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppConstants.horizontalPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(_error!).h3(),
            ],
          ),
        ),
      );
    }

    if (_libraryItems.isEmpty) {
      return Center(
        child: Padding(
          padding: AppConstants.horizontalPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.video_library_outlined,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text('Library').h3(),
              const SizedBox(height: 8),
              const Text('Your saved content will appear here').muted(),
            ],
          ),
        ),
      );
    }

    // Use the same grid layout as search results
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 
            AppConstants.horizontalPadding.horizontal * 2;
        
        // Calculate card width to match catalog cards (240px) but scale responsively
        final targetCardWidth = 240.0;
        final spacing = 16.0;
        final minCardWidth = 180.0;
        final maxCardWidth = 280.0;
        
        // Calculate how many cards fit with target width
        int crossAxisCount = (availableWidth / (targetCardWidth + spacing)).floor();
        crossAxisCount = crossAxisCount.clamp(3, 8);
        
        // Calculate actual card width based on available space
        final actualCardWidth = ((availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount).clamp(minCardWidth, maxCardWidth);
        
        // Calculate aspect ratio
        final imageHeight = actualCardWidth * 1.5;
        final totalHeight = imageHeight + 12 + 42;
        final aspectRatio = actualCardWidth / totalHeight;

        return Padding(
          padding: AppConstants.horizontalPadding,
          child: GridView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: 32,
              childAspectRatio: aspectRatio,
            ),
            itemCount: _libraryItems.length,
            itemBuilder: (context, index) {
              final item = _libraryItems[index];
              // Use the same card format as search results
              return _LibraryCard(item: item, cardWidth: actualCardWidth);
            },
          ),
        );
      },
    );
  }
}

/// Library card widget - same format as search result cards
class _LibraryCard extends StatefulWidget {
  final CatalogItem item;
  final double cardWidth;

  const _LibraryCard({required this.item, required this.cardWidth});

  @override
  State<_LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<_LibraryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Clickable(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CatalogItemDetailScreen(
                item: widget.item,
              ),
            ),
          );
        },
        child: SizedBox(
          width: widget.cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image with rounded corners, no frame, with zoom animation
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: widget.cardWidth,
                  height: widget.cardWidth * 1.5, // Maintain 2:3 aspect ratio
                  child: Stack(
                    children: [
                      AnimatedScale(
                        scale: _isHovered ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: SmartImage(
                          imageUrl: widget.item.poster,
                          width: widget.cardWidth,
                          height: widget.cardWidth * 1.5,
                          fit: BoxFit.cover,
                          priority: ImagePriority.visible,
                          borderRadius: BorderRadius.circular(8),
                          placeholderBuilder: (context) => Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.muted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  widget.item.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.foreground,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Rating overlay in bottom right corner
                      if (widget.item.imdbRating != null)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(double.tryParse(widget.item.imdbRating!) ?? 0.0).toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Text below the image (centered)
              const SizedBox(height: 12),
              SizedBox(
                width: widget.cardWidth,
                child: Text(
                  widget.item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.3),
                ).semiBold(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
