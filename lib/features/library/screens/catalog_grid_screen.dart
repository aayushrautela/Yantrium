import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/services.dart'; // For SystemMouseCursors
import 'package:flutter/animation.dart'; // For AnimationController
import 'dart:async'; // For Timer
import '../models/catalog_item.dart';
import '../logic/library_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/constants/app_constants.dart';
import 'catalog_item_detail_screen.dart';

/// Screen displaying catalogs from all enabled addons in horizontal scrolling lists
class CatalogGridScreen extends StatefulWidget {
  const CatalogGridScreen({super.key});

  @override
  State<CatalogGridScreen> createState() => _CatalogGridScreenState();
}

class _CatalogGridScreenState extends State<CatalogGridScreen> {
  late final AppDatabase _database;
  late final LibraryRepository _libraryRepository;
  List<CatalogSection> _catalogSections = [];
  bool _isLoading = true;
  String? _error;
  List<CatalogItem> _heroItems = [];

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _libraryRepository = LibraryRepository(_database);
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sections = await _libraryRepository.getCatalogSections();
      if (!mounted) return;
      
      // Get hero items from the selected hero catalog
      final heroItems = await _libraryRepository.getHeroItems();
      
      setState(() {
        _catalogSections = sections;
        _heroItems = heroItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading catalogs...');
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text('Error loading catalogs').h3(),
            const SizedBox(height: 8),
            Padding(
              padding: AppConstants.horizontalPadding,
              child: Text(_error!).muted().textCenter(),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              onPressed: _loadCatalogs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_catalogSections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.library_books_outlined,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text('No catalogs available').h3(),
            const SizedBox(height: 8),
            const Text('Install and enable addons to see catalogs').muted(),
            const SizedBox(height: 16),
            PrimaryButton(
              onPressed: _loadCatalogs,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshTrigger(
      onRefresh: _loadCatalogs,
      child: CustomScrollView(
        slivers: [
          // Hero Section
          if (_heroItems.isNotEmpty)
            _HeroSection(items: _heroItems),
          
          // Catalog Sections
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final section = _catalogSections[index];
                return _CatalogSection(
                  title: section.title,
                  addonName: section.addonName,
                  items: section.items,
                );
              },
              childCount: _catalogSections.length,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }
}


/// Hero section with backdrop, logo, and metadata
class _HeroSection extends StatefulWidget {
  final List<CatalogItem> items;

  const _HeroSection({required this.items});

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  Timer? _timer;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isAnimating = false;
  bool _isForward = true; // true = right direction, false = left direction

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && !_isAnimating) {
          _nextItem();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _nextItem() {
    if (widget.items.isEmpty || _isAnimating) return;
    final nextIndex = (_currentIndex + 1) % widget.items.length;
    _goToItem(nextIndex);
  }

  void _previousItem() {
    if (widget.items.isEmpty || _isAnimating) return;
    final prevIndex = (_currentIndex - 1 + widget.items.length) % widget.items.length;
    _goToItem(prevIndex);
  }

  void _goToItem(int index) {
    if (index < 0 || index >= widget.items.length || _isAnimating) return;
    
    // Determine direction: forward if index is greater (or wrapping around from end to start)
    // backward if index is less (or wrapping around from start to end)
    bool isForward;
    if (index > _currentIndex) {
      // Normal forward
      isForward = true;
    } else if (index < _currentIndex) {
      // Normal backward
      isForward = false;
    } else {
      // Same index, use forward as default
      isForward = true;
    }
    
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
      _isAnimating = true;
      _isForward = isForward;
    });
    
    _animationController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
    
    // Reset timer
    _timer?.cancel();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && !_isAnimating) {
          _nextItem();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    final currentItem = widget.items[_currentIndex];
    final previousItem = _isAnimating && _previousIndex != _currentIndex
        ? widget.items[_previousIndex]
        : null;
    
    return SliverToBoxAdapter(
      child: SizedBox(
        width: double.infinity,
        height: 600,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Previous backdrop (slides out)
            if (previousItem != null && _isAnimating)
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  // Previous slides out in opposite direction of new
                  final slideOutOffset = _isForward
                      ? -_slideAnimation.value * MediaQuery.of(context).size.width  // Out to left
                      : _slideAnimation.value * MediaQuery.of(context).size.width;   // Out to right
                  return Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(slideOutOffset, 0),
                      child: previousItem.background != null
                          ? Image.network(
                              previousItem.background!,
                              key: ValueKey(previousItem.id),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Container(
                                key: ValueKey(previousItem.id),
                                width: double.infinity,
                                height: double.infinity,
                                color: Theme.of(context).colorScheme.muted,
                              ),
                            )
                          : Container(
                              key: ValueKey(previousItem.id),
                              width: double.infinity,
                              height: double.infinity,
                              color: Theme.of(context).colorScheme.muted,
                            ),
                    ),
                  );
                },
              ),
            
            // Current backdrop (slides in)
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                // Current slides in from the direction we're going
                final slideInOffset = _isAnimating
                    ? (_isForward
                        ? (1.0 - _slideAnimation.value) * MediaQuery.of(context).size.width  // From right
                        : -(1.0 - _slideAnimation.value) * MediaQuery.of(context).size.width) // From left
                    : 0.0;
                return Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(slideInOffset, 0),
                    child: currentItem.background != null
                        ? Image.network(
                            currentItem.background!,
                            key: ValueKey(currentItem.id),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => Container(
                              key: ValueKey(currentItem.id),
                              width: double.infinity,
                              height: double.infinity,
                              color: Theme.of(context).colorScheme.muted,
                            ),
                          )
                        : Container(
                            key: ValueKey(currentItem.id),
                            width: double.infinity,
                            height: double.infinity,
                            color: Theme.of(context).colorScheme.muted,
                          ),
                  ),
                );
              },
            ),
            
            // Gradient Overlay (top to bottom)
            Builder(
              builder: (context) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Theme.of(context).colorScheme.background.withOpacity(0.3),
                      Theme.of(context).colorScheme.background,
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            
            // Left side darkening overlay
            Builder(
              builder: (context) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.6],
                  ),
                ),
              ),
            ),
            
            // Navigation Buttons
            if (widget.items.length > 1) ...[
              // Left Button
              Positioned(
                left: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Clickable(
                      onPressed: _previousItem,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.background.withOpacity(0.8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.border,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: Theme.of(context).colorScheme.foreground,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Right Button
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Clickable(
                      onPressed: _nextItem,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.background.withOpacity(0.8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.border,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.foreground,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            
            // Content
            Positioned(
              left: AppConstants.horizontalMargin,
              right: AppConstants.horizontalMargin,
              bottom: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // NEW SEASON tag
                  if (currentItem.type == 'series')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.muted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'NEW SEASON',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Logo from TMDB
                  Builder(
                    builder: (context) {
                      if (currentItem.logo != null && currentItem.logo!.isNotEmpty) {
                        return SizedBox(
                          width: 600, // Fixed width for all logos
                          height: 150, // Max height constraint
                          child: Image.network(
                            currentItem.logo!,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to title if logo fails to load
                              return Text(currentItem.name.toUpperCase()).h1();
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 600,
                                height: 150,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                          ),
                        );
                      } else {
                        return Text(currentItem.name.toUpperCase()).h1();
                      }
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Metadata
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Match percentage
                      if (currentItem.imdbRating != null)
                        Text(
                          '${(double.tryParse(currentItem.imdbRating!) ?? 0 * 10).toInt()}% Match',
                          style: TextStyle(
                            color: Colors.green[400],
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      
                      // Year range
                      if (currentItem.releaseInfo != null)
                        Text(
                          currentItem.releaseInfo!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      
                      // Rating badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.mutedForeground,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TV-14',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      
                      // Seasons (for series)
                      if (currentItem.type == 'series' && currentItem.releaseInfo != null)
                        Text(
                          '26 Seasons',
                          style: const TextStyle(fontSize: 16),
                        ),
                      
                      // Genres
                      if (currentItem.genres != null && currentItem.genres!.isNotEmpty)
                        ...currentItem.genres!.take(2).map((genre) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.mutedForeground,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                genre,
                                style: const TextStyle(fontSize: 14),
                              ),
                            )),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Description
                  if (currentItem.description != null)
                    SizedBox(
                      width: 700,
                      child: Text(
                        currentItem.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, height: 1.5),
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
                              'Play Now',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SecondaryButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => CatalogItemDetailScreen(
                                item: currentItem,
                              ),
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'More Info',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A catalog section with a title and horizontal scrolling list of items
class _CatalogSection extends StatefulWidget {
  final String title;
  final String addonName;
  final List<CatalogItem> items;

  const _CatalogSection({
    required this.title,
    required this.addonName,
    required this.items,
  });

  @override
  State<_CatalogSection> createState() => _CatalogSectionState();
}

class _CatalogSectionState extends State<_CatalogSection> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 400,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 400,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppConstants.sectionHeaderPadding,
          child: Row(
            children: [
              const Icon(Icons.access_time, size: 20),
              const SizedBox(width: 8),
              Text(widget.title).h4(),
            ],
          ),
        ),
        SizedBox(
          height: 360,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: AppConstants.horizontalMargin,
                  right: AppConstants.horizontalMargin,
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: _CatalogItemCard(item: widget.items[index]),
                    );
                  },
                ),
              ),
              // Left button - centered relative to image (300px / 2 = 150px from top)
              Positioned(
                left: AppConstants.horizontalMargin - 40,
                top: 150 - 20, // Center of 300px image minus half button height
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Clickable(
                    onPressed: _scrollLeft,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.background.withOpacity(0.8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.border,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        color: Theme.of(context).colorScheme.foreground,
                      ),
                    ),
                  ),
                ),
              ),
              // Right button - centered relative to image
              Positioned(
                right: AppConstants.horizontalMargin - 40,
                top: 150 - 20, // Center of 300px image minus half button height
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Clickable(
                    onPressed: _scrollRight,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.background.withOpacity(0.8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.border,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.sectionSpacing),
      ],
    );
  }
}

class _CatalogItemCard extends StatefulWidget {
  final CatalogItem item;

  const _CatalogItemCard({required this.item});

  @override
  State<_CatalogItemCard> createState() => _CatalogItemCardState();
}

class _CatalogItemCardState extends State<_CatalogItemCard> {
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
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image with rounded corners, no frame, with zoom animation
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 200,
                  height: 300,
                  child: AnimatedScale(
                    scale: _isHovered ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: widget.item.poster != null
                        ? Image.network(
                            widget.item.poster!,
                            fit: BoxFit.cover,
                          width: 200,
                          height: 300,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 200,
                            height: 300,
                            color: Theme.of(context).colorScheme.muted,
                            child: const Icon(Icons.image_not_supported),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 200,
                              height: 300,
                              color: Theme.of(context).colorScheme.muted,
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                        )
                      : Container(
                          width: 200,
                          height: 300,
                          color: Theme.of(context).colorScheme.muted,
                          child: const Icon(Icons.image_not_supported),
                        ),
                  ),
                ),
              ),
              
              // Text below the image (centered)
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
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
