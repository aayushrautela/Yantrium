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
import '../../../core/services/tmdb_service.dart';
import '../../../core/services/tmdb_data_extractor.dart';
import '../../../core/services/id_parser.dart';

/// Screen displaying catalogs from all enabled addons in horizontal scrolling lists
class CatalogGridScreen extends StatefulWidget {
  final TextEditingController? searchController;

  const CatalogGridScreen({super.key, this.searchController});

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
  
  // Search state
  late final TextEditingController _searchController;
  List<CatalogItem> _searchResults = [];
  bool _isSearching = false;
  String _selectedFilter = 'All';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _database = AppDatabase();
    _libraryRepository = LibraryRepository(_database);
    _searchController = widget.searchController ?? TextEditingController();
    _loadCatalogs();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    try {
      final results = await _libraryRepository.searchItems(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  List<CatalogItem> _getFilteredResults() {
    List<CatalogItem> filtered;
    
    if (_selectedFilter == 'All') {
      filtered = _searchResults;
    } else if (_selectedFilter == 'TV Series') {
      filtered = _searchResults.where((item) => item.type == 'series').toList();
    } else if (_selectedFilter == 'Movies') {
      filtered = _searchResults.where((item) => item.type == 'movie').toList();
    } else {
      // Genre filter
      filtered = _searchResults.where((item) => 
        item.genres?.any((genre) => genre.toLowerCase() == _selectedFilter.toLowerCase()) ?? false
      ).toList();
    }
    
    // Sort: items with posters first, items without posters at the end
    filtered.sort((a, b) {
      final aHasPoster = a.poster != null && a.poster!.isNotEmpty;
      final bHasPoster = b.poster != null && b.poster!.isNotEmpty;
      
      if (aHasPoster && !bHasPoster) return -1;
      if (!aHasPoster && bHasPoster) return 1;
      return 0; // Keep original order for items in the same group
    });
    
    return filtered;
  }

  List<String> _getAvailableGenres() {
    final genres = <String>{};
    for (final item in _searchResults) {
      if (item.genres != null) {
        genres.addAll(item.genres!);
      }
    }
    return genres.toList()..sort();
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

    // Show search results if searching
    if (_searchController.text.trim().isNotEmpty) {
      return _buildSearchResults();
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

  Widget _buildSearchResults() {
    final filteredResults = _getFilteredResults();
    final availableGenres = _getAvailableGenres();

    return Column(
      children: [
        // Filters
        Padding(
          padding: AppConstants.horizontalPadding.copyWith(
            top: 24,
            bottom: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FILTERS:').h4(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedFilter == 'All',
                    onTap: () => setState(() => _selectedFilter = 'All'),
                  ),
                  _FilterChip(
                    label: 'TV Series',
                    isSelected: _selectedFilter == 'TV Series',
                    onTap: () => setState(() => _selectedFilter = 'TV Series'),
                  ),
                  _FilterChip(
                    label: 'Movies',
                    isSelected: _selectedFilter == 'Movies',
                    onTap: () => setState(() => _selectedFilter = 'Movies'),
                  ),
                  ...availableGenres.take(10).map((genre) => _FilterChip(
                    label: genre,
                    isSelected: _selectedFilter == genre,
                    onTap: () => setState(() => _selectedFilter = genre),
                  )),
                ],
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : filteredResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.mutedForeground,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No results found',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.mutedForeground,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: AppConstants.horizontalPadding.copyWith(
                        bottom: 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department, size: 24),
                              const SizedBox(width: 8),
                              const Text('Trending Now').h3(),
                              const Spacer(),
                              Text(
                                '${filteredResults.length} TITLES',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: _buildSearchGrid(filteredResults),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchGrid(List<CatalogItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        
        // Calculate card width to match catalog cards (240px) but scale responsively
        // Target: ~240px per card with spacing
        final targetCardWidth = 240.0;
        final spacing = 16.0;
        final minCardWidth = 180.0; // Minimum card width
        final maxCardWidth = 280.0; // Maximum card width
        
        // Calculate how many cards fit with target width
        int crossAxisCount = (availableWidth / (targetCardWidth + spacing)).floor();
        crossAxisCount = crossAxisCount.clamp(3, 8); // Between 3 and 8 columns
        
        // Calculate actual card width based on available space
        final actualCardWidth = ((availableWidth - (crossAxisCount - 1) * spacing) / crossAxisCount).clamp(minCardWidth, maxCardWidth);
        
        // Calculate aspect ratio: width / (image height + spacing + text height)
        // Image height = cardWidth * 1.5 (2:3 ratio), text ~42px, spacing 12px
        final imageHeight = actualCardWidth * 1.5;
        final totalHeight = imageHeight + 12 + 42; // image + spacing + text
        final aspectRatio = actualCardWidth / totalHeight;

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 100), // Increased bottom padding to fix overflow
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 32,
            childAspectRatio: aspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _SearchResultCard(item: item, cardWidth: actualCardWidth);
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    // Only dispose if we created it (not passed from parent)
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    _database.close();
    super.dispose();
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.muted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryForeground
                : Theme.of(context).colorScheme.foreground,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final CatalogItem item;
  final double cardWidth;

  const _SearchResultCard({required this.item, required this.cardWidth});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
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
                        child: widget.item.poster != null
                        ? Image.network(
                            widget.item.poster!,
                            fit: BoxFit.cover,
                            width: widget.cardWidth,
                            height: widget.cardWidth * 1.5,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: widget.cardWidth,
                              height: widget.cardWidth * 1.5,
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
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: widget.cardWidth,
                                height: widget.cardWidth * 1.5,
                                color: Theme.of(context).colorScheme.muted,
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              );
                            },
                          )
                        : Container(
                            width: widget.cardWidth,
                            height: widget.cardWidth * 1.5,
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
  late final TmdbService _tmdbService;
  String? _maturityRating;
  String? _numberOfSeasons;

  @override
  void initState() {
    super.initState();
    _tmdbService = TmdbService();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // Load metadata for initial item
    _loadMetadataForCurrentItem();
    
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && !_isAnimating) {
          _nextItem();
        }
      });
    }
  }
  
  Future<void> _loadMetadataForCurrentItem() async {
    if (widget.items.isEmpty) return;
    
    final currentItem = widget.items[_currentIndex];
    _maturityRating = null;
    _numberOfSeasons = null;
    
    try {
      final tmdbId = IdParser.extractTmdbId(currentItem.id);
      int? finalTmdbId = tmdbId;
      
      if (finalTmdbId == null && IdParser.isImdbId(currentItem.id)) {
        finalTmdbId = await _tmdbService.getTmdbIdFromImdb(currentItem.id);
      }
      
      if (finalTmdbId != null) {
        Map<String, dynamic>? tmdbData;
        if (currentItem.type == 'movie') {
          tmdbData = await _tmdbService.getMovieMetadata(finalTmdbId);
        } else if (currentItem.type == 'series') {
          tmdbData = await _tmdbService.getTvMetadata(finalTmdbId);
        }
        
        if (tmdbData != null && mounted) {
          final rating = TmdbDataExtractor.extractMaturityRating(tmdbData, currentItem.type);
          
          String? numSeasons;
          if (currentItem.type == 'series') {
            final additionalMetadata = TmdbDataExtractor.extractAdditionalMetadata(tmdbData, currentItem.type);
            final seasons = additionalMetadata['numberOfSeasons'] as int?;
            if (seasons != null && seasons > 0) {
              numSeasons = '$seasons Season${seasons > 1 ? 's' : ''}';
            }
          }
          
          if (mounted) {
            setState(() {
              _maturityRating = rating;
              _numberOfSeasons = numSeasons;
            });
          }
        }
      }
    } catch (e) {
      // Ignore errors, just don't show rating/seasons
    }
  }

  /// Extract the first date from a date string (handles date ranges like "2022-09-27 - 2025-11-23")
  String _extractFirstDate(String releaseInfo) {
    // If it contains " - " (space-hyphen-space), it's a date range - take the first part
    if (releaseInfo.contains(' - ')) {
      return releaseInfo.split(' - ').first.trim();
    }
    // Otherwise, just return the date as is
    return releaseInfo;
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
    
    // Load metadata for new item
    _loadMetadataForCurrentItem();
    
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
        height: 700,
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          previousItem.background != null
                              ? Image.network(
                                  previousItem.background!,
                                  key: ValueKey(previousItem.id),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
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
                          // Gradient to blend left edge
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Theme.of(context).colorScheme.background,
                                  Theme.of(context).colorScheme.background.withOpacity(0.6),
                                  Theme.of(context).colorScheme.background.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.15, 0.35, 1.0],
                              ),
                            ),
                          ),
                          // Gradient to blend bottom edge
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Theme.of(context).colorScheme.background,
                                  Theme.of(context).colorScheme.background.withOpacity(0.6),
                                  Theme.of(context).colorScheme.background.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.15, 0.35, 1.0],
                              ),
                            ),
                          ),
                        ],
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        currentItem.background != null
                            ? Image.network(
                                currentItem.background!,
                                key: ValueKey(currentItem.id),
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
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
                        // Gradient to blend left edge
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Theme.of(context).colorScheme.background,
                                Theme.of(context).colorScheme.background.withOpacity(0.6),
                                Theme.of(context).colorScheme.background.withOpacity(0.2),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.15, 0.35, 1.0],
                            ),
                          ),
                        ),
                        // Gradient to blend bottom edge
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Theme.of(context).colorScheme.background,
                                Theme.of(context).colorScheme.background.withOpacity(0.6),
                                Theme.of(context).colorScheme.background.withOpacity(0.2),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.15, 0.35, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Gradient to blend left edge (vertical fade from left to right)
            Builder(
              builder: (context) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Theme.of(context).colorScheme.background,
                      Theme.of(context).colorScheme.background.withOpacity(0.6),
                      Theme.of(context).colorScheme.background.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.15, 0.35, 1.0],
                  ),
                ),
              ),
            ),
            // Gradient to blend bottom edge (horizontal fade from bottom to top)
            Builder(
              builder: (context) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Theme.of(context).colorScheme.background,
                      Theme.of(context).colorScheme.background.withOpacity(0.6),
                      Theme.of(context).colorScheme.background.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.15, 0.35, 1.0],
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
                        return ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 800, // Increased max width
                            maxHeight: 300, // Increased max height for better visibility
                          ),
                          child: Image.network(
                            currentItem.logo!,
                            fit: BoxFit.contain, // Maintain aspect ratio, fit within constraints
                            alignment: Alignment.centerLeft,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to title if logo fails to load
                              return Text(currentItem.name.toUpperCase()).h1();
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SizedBox(
                                width: 800,
                                height: 300,
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
                      // Date (first date only)
                      if (currentItem.releaseInfo != null)
                        Text(
                          _extractFirstDate(currentItem.releaseInfo!),
                          style: const TextStyle(fontSize: 16),
                        ),
                      
                      // Seasons (for series)
                      if (currentItem.type == 'series' && _numberOfSeasons != null)
                        Text(
                          _numberOfSeasons!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      
                      // Rating badge (maturity)
                      if (_maturityRating != null)
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
                          child: Text(
                            _maturityRating!,
                            style: const TextStyle(fontSize: 14),
                          ),
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
                          // TODO: Implement add to library functionality
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Add to Library',
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
      _scrollController.offset - 480, // 240px card + 24px spacing = ~264px, scroll 2 cards
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 480, // 240px card + 24px spacing = ~264px, scroll 2 cards
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
          height: 440, // Increased to accommodate 360px image + text
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
              // Left button - centered relative to image (360px / 2 = 180px from top)
              Positioned(
                left: AppConstants.horizontalMargin - 40,
                top: 180 - 20, // Center of 360px image minus half button height
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
                top: 180 - 20, // Center of 360px image minus half button height
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
          width: 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image with rounded corners, no frame, with zoom animation
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 240,
                  height: 360,
                  child: Stack(
                    children: [
                      AnimatedScale(
                        scale: _isHovered ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: widget.item.poster != null
                        ? Image.network(
                            widget.item.poster!,
                            fit: BoxFit.cover,
                          width: 240,
                          height: 360,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 240,
                            height: 360,
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
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 240,
                              height: 360,
                              color: Theme.of(context).colorScheme.muted,
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                        )
                      : Container(
                          width: 240,
                          height: 360,
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
                width: 240,
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
