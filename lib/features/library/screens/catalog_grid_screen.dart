import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/services.dart'; // For SystemMouseCursors
import 'package:flutter/animation.dart'; // For AnimationController
import 'package:flutter/material.dart' as material; // For Colors, material.CircularProgressIndicator
import 'dart:async'; // For Timer
import '../models/catalog_item.dart';
import '../logic/library_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/constants/app_constants.dart';
import 'catalog_item_detail_screen.dart';
import '../../../core/services/tmdb_service.dart';
import '../../../core/services/tmdb_data_extractor.dart';
import '../../../core/services/id_parser.dart';
import '../../../core/services/watch_history_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/widgets/smart_image.dart';
import '../../../core/services/image_preloader.dart';
import 'episode_detail_screen.dart';
import '../models/episode.dart';
import '../../../core/services/id_parser.dart';

/// Screen displaying catalogs from all enabled addons in horizontal scrolling lists
class CatalogGridScreen extends StatefulWidget {
  final TextEditingController? searchController;

  const CatalogGridScreen({super.key, this.searchController});

  @override
  State<CatalogGridScreen> createState() => _CatalogGridScreenState();
}

class _CatalogGridScreenState extends State<CatalogGridScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep this screen alive in memory

  late final AppDatabase _database;
  late final LibraryRepository _libraryRepository;
  late final WatchHistoryService _watchHistoryService;
  List<CatalogSection> _catalogSections = [];
  bool _isLoading = true;
  bool _areCatalogsLoaded = false; // Track if catalogs are loaded (for hero navigation blocking)
  String? _error;
  List<CatalogItem> _heroItems = [];

  // Continue Watching state
  List<({CatalogItem item, double progress, int? seasonNumber, int? episodeNumber, String? episodeName})> _continueWatchingItems = [];
  bool _isLoadingContinueWatching = false;

  // Caching and background refresh
  bool _hasLoadedInitialData = false;
  DateTime? _lastLoadTime;
  Timer? _backgroundRefreshTimer;
  bool _isBackgroundRefreshing = false;
  
  // Search state
  late final TextEditingController _searchController;
  List<CatalogItem> _searchResults = [];
  bool _isSearching = false;
  String _selectedFilter = 'All';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();

    _database = DatabaseProvider.instance;
    _libraryRepository = LibraryRepository(_database);
    _watchHistoryService = WatchHistoryService(_database);
    _searchController = widget.searchController ?? TextEditingController();

    // Only load data if we haven't loaded it before or it's stale
    final shouldLoad = !_hasLoadedInitialData || _shouldRefreshData();

    if (shouldLoad) {
      _loadCatalogs();
      _loadContinueWatching();
    }

    // Start background refresh timer (every 30 minutes)
    _startBackgroundRefreshTimer();

    _searchController.addListener(_onSearchChanged);

    // Perform initial search if controller has text
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _loadContinueWatching({bool isBackgroundRefresh = false}) async {
    if (!isBackgroundRefresh && mounted) {
      setState(() {
        _isLoadingContinueWatching = true;
      });
    }

    try {
      // Try to sync watch history from Trakt if authenticated (incremental sync)
      // If not authenticated, we'll use local data as fallback
      final isTraktAuthenticated = await ServiceLocator.instance.traktAuthService.isAuthenticated();
      if (isTraktAuthenticated) {
        // Perform incremental sync in background to avoid blocking UI
        _watchHistoryService.syncWatchHistory().then((syncedCount) {
          debugPrint('Background sync completed: $syncedCount items synced');
        }).catchError((error) {
          debugPrint('Background sync failed: $error');
        });
      } else {
        debugPrint('Trakt not authenticated, using local continue watching data');
      }

      // Get continue watching items (0-80% progress) from local database
      // This works for both Trakt-synced and local-only items
      final historyItems = await _watchHistoryService.getContinueWatching();

      // Convert watch history to catalog items with progress
      final catalogItems = <({CatalogItem item, double progress, int? seasonNumber, int? episodeNumber, String? episodeName})>[];
      for (final history in historyItems) {
        final catalogItem = await _watchHistoryService.watchHistoryToCatalogItem(history);
        if (catalogItem != null) {
          catalogItems.add((
            item: catalogItem,
            progress: history.progress,
            seasonNumber: history.seasonNumber,
            episodeNumber: history.episodeNumber,
            episodeName: history.type == 'episode' ? history.title : null,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _continueWatchingItems = catalogItems;
          if (!isBackgroundRefresh) {
            _isLoadingContinueWatching = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading continue watching: $e');
      if (mounted && !isBackgroundRefresh) {
        setState(() {
          _isLoadingContinueWatching = false;
        });
      }
    }
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

  Future<void> _loadCatalogs({bool isBackgroundRefresh = false}) async {
    if (!mounted) return;

    if (!isBackgroundRefresh) {
      setState(() {
        _isLoading = true;
        _areCatalogsLoaded = false;
        _error = null;
      });
    }

    try {
      // Load catalogs first (fast operation)
      final sections = await _libraryRepository.getCatalogSections();
      if (!mounted) return;

      // Load only first hero item initially (fast)
      final heroItems = await _libraryRepository.getHeroItems(initialEnrichCount: 1);

      if (!mounted) return;

      // Update state
      setState(() {
        _catalogSections = sections;
        _heroItems = heroItems;
        if (!isBackgroundRefresh) {
          _isLoading = false;
          _areCatalogsLoaded = true; // Enable hero navigation after catalogs load
          _hasLoadedInitialData = true;
          _lastLoadTime = DateTime.now();
        }
      });

      // Enrich remaining hero items in background (only for initial load)
      if (!isBackgroundRefresh) {
        _loadRemainingHeroItems();
      }

    } catch (e) {
      if (!mounted) return;
      if (!isBackgroundRefresh) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _areCatalogsLoaded = true; // Still enable navigation even on error
        });
      }
      debugPrint('Catalog loading failed: $e');
    }
  }

  Future<void> _loadRemainingHeroItems() async {
    if (!mounted || _heroItems.length <= 1) return;
    
    try {
      final enrichedItems = await _libraryRepository.enrichRemainingHeroItems(_heroItems);
      if (mounted) {
        setState(() {
          _heroItems = enrichedItems;
        });
      }
    } catch (e) {
      // If enrichment fails, keep existing items
      debugPrint('Error enriching remaining hero items: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      // Show skeleton placeholders while loading
      return RefreshTrigger(
        onRefresh: () async {
          // Don't allow refresh while initially loading
        },
        child: CustomScrollView(
          slivers: [
            // Hero Section Skeleton
            const _HeroSectionSkeleton(),

            // Continue Watching Section Skeleton
            const _ContinueWatchingSectionSkeleton(),

            // Catalog Sections Skeleton
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final titles = ['Popular Movies', 'Trending TV Shows', 'New Releases', 'Top Rated'];
                  return _CatalogSectionSkeleton(title: titles[index % titles.length]);
                },
                childCount: 3, // Show 3 skeleton sections
              ),
            ),
          ],
        ),
      );
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
      onRefresh: () async {
        // Force refresh by resetting cache flags
        _hasLoadedInitialData = false;
        _lastLoadTime = null;
        await _loadCatalogs();
        await _loadContinueWatching();
      },
      child: CustomScrollView(
        slivers: [
          // Hero Section
          if (_heroItems.isNotEmpty)
            _HeroSection(
              items: _heroItems,
              enableNavigation: _areCatalogsLoaded,
            ),
          
          // Continue Watching Section
          if (_continueWatchingItems.isNotEmpty)
            SliverToBoxAdapter(
              child: _ContinueWatchingSection(
                items: _continueWatchingItems,
              ),
            ),
          
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
              ? const Center(child: material.CircularProgressIndicator())
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

  /// Check if data should be refreshed (older than 30 minutes)
  bool _shouldRefreshData() {
    return _lastLoadTime == null ||
           DateTime.now().difference(_lastLoadTime!) > const Duration(minutes: 30);
  }

  /// Start periodic background refresh timer
  void _startBackgroundRefreshTimer() {
    _backgroundRefreshTimer?.cancel();
    _backgroundRefreshTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (mounted && !_isLoading && !_isBackgroundRefreshing) {
        _performBackgroundRefresh();
      }
    });
  }

  /// Perform background refresh without showing loading UI
  Future<void> _performBackgroundRefresh() async {
    _isBackgroundRefreshing = true;
    try {
      await _loadCatalogs(isBackgroundRefresh: true);
      await _loadContinueWatching(isBackgroundRefresh: true);
    } catch (e) {
      debugPrint('Background refresh failed: $e');
    } finally {
      _isBackgroundRefreshing = false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _backgroundRefreshTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    // Only dispose if we created it (not passed from parent)
    if (widget.searchController == null) {
      _searchController.dispose();
    }
    // Note: Don't close the database here - it's a singleton that should remain open
    // for the app's lifetime. Closing it here would break database access for the entire app.
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


/// Hero section with backdrop, logo, and metadata
class _HeroSection extends StatefulWidget {
  final List<CatalogItem> items;
  final bool enableNavigation;

  const _HeroSection({
    required this.items,
    this.enableNavigation = true,
  });

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
    
    // Only start auto-rotation if navigation is enabled
    if (widget.items.length > 1 && widget.enableNavigation) {
      _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && !_isAnimating) {
          _nextItem();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_HeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If navigation was just enabled, start the timer
    if (!oldWidget.enableNavigation && widget.enableNavigation && widget.items.length > 1) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && !_isAnimating) {
          _nextItem();
        }
      });
    } else if (oldWidget.enableNavigation && !widget.enableNavigation) {
      // If navigation was just disabled, stop the timer
      _timer?.cancel();
      _timer = null;
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
    if (widget.items.isEmpty || _isAnimating || !widget.enableNavigation) return;
    final nextIndex = (_currentIndex + 1) % widget.items.length;
    _goToItem(nextIndex);
  }

  void _previousItem() {
    if (widget.items.isEmpty || _isAnimating || !widget.enableNavigation) return;
    final prevIndex = (_currentIndex - 1 + widget.items.length) % widget.items.length;
    _goToItem(prevIndex);
  }

  void _goToItem(int index) {
    if (index < 0 || index >= widget.items.length || _isAnimating || !widget.enableNavigation) return;
    
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
    
    // Reset timer (only if navigation is enabled)
    _timer?.cancel();
    if (widget.items.length > 1 && widget.enableNavigation) {
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
                                  Theme.of(context).colorScheme.background,
                                  Theme.of(context).colorScheme.background.withOpacity(0.8),
                                  Theme.of(context).colorScheme.background.withOpacity(0.5),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.05, 0.1, 0.3, 0.85],
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
                                  Theme.of(context).colorScheme.background,
                                  Theme.of(context).colorScheme.background.withOpacity(0.8),
                                  Theme.of(context).colorScheme.background.withOpacity(0.5),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.05, 0.1, 0.3, 0.85],
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
                      Theme.of(context).colorScheme.background,
                      Theme.of(context).colorScheme.background.withOpacity(0.8),
                      Theme.of(context).colorScheme.background.withOpacity(0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.05, 0.1, 0.3, 0.85],
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
                                child: Center(child: material.CircularProgressIndicator()),
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

/// Skeleton placeholder for catalog item cards
class _CatalogItemCardSkeleton extends StatelessWidget {
  const _CatalogItemCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image skeleton with rounded corners
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 240,
              height: 360,
              color: Theme.of(context).colorScheme.muted,
            ).asSkeleton(),
          ),

          // Text below the image
          const SizedBox(height: 12),
          SizedBox(
            width: 240,
            child: Column(
              children: [
                // Title skeleton - two lines
                Container(
                  height: 16,
                  width: 200,
                  color: Theme.of(context).colorScheme.muted,
                ).asSkeleton(),
                const SizedBox(height: 4),
                Container(
                  height: 16,
                  width: 150,
                  color: Theme.of(context).colorScheme.muted,
                ).asSkeleton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for hero section
class _HeroSectionSkeleton extends StatelessWidget {
  const _HeroSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        width: double.infinity,
        height: 700,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background skeleton
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Theme.of(context).colorScheme.muted,
            ).asSkeleton(),

            // Overlay content skeleton
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              padding: AppConstants.horizontalPadding.copyWith(
                top: 100,
                bottom: 60,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Main content column (title, description, buttons)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title skeleton
                      Container(
                        height: 48,
                        width: 400,
                        color: Colors.white.withOpacity(0.9),
                      ).asSkeleton(),
                      const SizedBox(height: 16),

                      // Description skeleton
                      Container(
                        height: 20,
                        width: 600,
                        color: Colors.white.withOpacity(0.7),
                      ).asSkeleton(),
                      const SizedBox(height: 8),
                      Container(
                        height: 20,
                        width: 500,
                        color: Colors.white.withOpacity(0.7),
                      ).asSkeleton(),
                      const SizedBox(height: 24),

                      // Buttons skeleton
                      Row(
                        children: [
                          Container(
                            height: 48,
                            width: 140,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ).asSkeleton(),
                          const SizedBox(width: 16),
                          Container(
                            height: 48,
                            width: 140,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ).asSkeleton(),
                        ],
                      ),
                    ],
                  ),

                  // Logo skeleton (bottom left corner)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    child: Container(
                      width: 200,
                      height: 60,
                      color: Colors.white.withOpacity(0.8),
                    ).asSkeleton(),
                  ),
                ],
              ),
            ),

            // Indicators at bottom
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.54),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder for continue watching section
class _ContinueWatchingSectionSkeleton extends StatelessWidget {
  const _ContinueWatchingSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppConstants.sectionHeaderPadding,
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline, size: 20),
                const SizedBox(width: 8),
                Container(
                  height: 20,
                  width: 160,
                  color: Theme.of(context).colorScheme.muted,
                ).asSkeleton(),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: Padding(
              padding: EdgeInsets.only(
                left: AppConstants.horizontalMargin,
                right: AppConstants.horizontalMargin,
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Container(
                      width: 320,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          // Background image skeleton
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Theme.of(context).colorScheme.muted,
                            ),
                          ).asSkeleton(),

                          // Progress bar at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.6,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Play button overlay
                          Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                color: Theme.of(context).colorScheme.primaryForeground,
                              ),
                            ),
                          ),

                          // Title overlay
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              height: 16,
                              width: 200,
                              color: Colors.white.withOpacity(0.9),
                            ).asSkeleton(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for catalog sections
class _CatalogSectionSkeleton extends StatelessWidget {
  final String title;

  const _CatalogSectionSkeleton({required this.title});

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
              Container(
                height: 20,
                width: 120,
                color: Theme.of(context).colorScheme.muted,
              ).asSkeleton(),
            ],
          ),
        ),
        SizedBox(
          height: 440,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppConstants.horizontalMargin,
              right: AppConstants.horizontalMargin,
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 6, // Show 6 skeleton cards
              itemBuilder: (context, index) {
                return const Padding(
                  padding: EdgeInsets.only(right: 24),
                  child: _CatalogItemCardSkeleton(),
                );
              },
            ),
          ),
        ),
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
                        child: SmartImage(
                          imageUrl: widget.item.poster,
                          width: 240,
                          height: 360,
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
                      // Play button overlay (shown on hover)
                      AnimatedOpacity(
                        opacity: _isHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: material.Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              size: 40,
                              color: Theme.of(context).colorScheme.primaryForeground,
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

/// Special section for Continue Watching with landscape cards
class _ContinueWatchingSection extends StatefulWidget {
  final List<({CatalogItem item, double progress, int? seasonNumber, int? episodeNumber, String? episodeName})> items;

  const _ContinueWatchingSection({required this.items});

  @override
  State<_ContinueWatchingSection> createState() => _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<_ContinueWatchingSection> {
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
      _scrollController.offset - 700, // Card width + spacing
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 700,
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
              const Text('Continue Watching').h4(),
            ],
          ),
        ),
        SizedBox(
          height: 270, // Height for landscape cards (16:9 ratio, 480x270)
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
                      child: _ContinueWatchingCard(
                        item: widget.items[index].item,
                        progress: widget.items[index].progress,
                        seasonNumber: widget.items[index].seasonNumber,
                        episodeNumber: widget.items[index].episodeNumber,
                        episodeName: widget.items[index].episodeName,
                      ),
                    );
                  },
                ),
              ),
              // Left button
              Positioned(
                left: AppConstants.horizontalMargin - 40,
                top: 135 - 20, // Center of card (270/2 = 135)
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
              // Right button
              Positioned(
                right: AppConstants.horizontalMargin - 40,
                top: 135 - 20, // Center of card (270/2 = 135)
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

/// Landscape card for Continue Watching items
class _ContinueWatchingCard extends StatefulWidget {
  final CatalogItem item;
  final double progress;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeName;

  const _ContinueWatchingCard({
    required this.item,
    required this.progress,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeName,
  });

  @override
  State<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<_ContinueWatchingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Clickable(
        onPressed: () {
          // If this is a specific episode, navigate to episode detail screen
          if (widget.item.type == 'series' && widget.seasonNumber != null && widget.episodeNumber != null) {
            // Create a minimal Episode object
            // The EpisodeDetailScreen will fetch the full data
            final episode = Episode(
              episodeNumber: widget.episodeNumber!,
              name: widget.episodeName ?? 'Episode ${widget.episodeNumber}',
              overview: null, // Will be fetched by screen
              stillPath: null, // Will be fetched by screen
              airDate: null, // Will be fetched by screen
              runtime: null, // Will be fetched by screen
              voteAverage: null, // Will be fetched by screen
            );

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EpisodeDetailScreen(
                  seriesItem: widget.item,
                  episode: episode,
                  seasonNumber: widget.seasonNumber!,
                ),
              ),
            );
          } else {
            // Navigate to series/movie detail screen
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CatalogItemDetailScreen(
                  item: widget.item,
                ),
              ),
            );
          }
        },
        child: SizedBox(
          width: 480, // Landscape 16:9 ratio
          height: 270,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Backdrop image
                AnimatedScale(
                  scale: _isHovered ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: SmartImage(
                    imageUrl: widget.item.background,
                    width: double.infinity,
                    height: 270,
                    fit: BoxFit.cover,
                    priority: ImagePriority.visible,
                    placeholderBuilder: (context) => Container(
                      color: Theme.of(context).colorScheme.muted,
                      child: Center(
                        child: Text(
                          widget.item.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.foreground,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Gradient overlay for better logo/text visibility in bottom left corner
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.bottomLeft,
                          radius: 1.6,
                          colors: [
                            material.Colors.black.withOpacity(0.85),
                            material.Colors.black.withOpacity(0.5),
                            material.Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Up Next Badge (only for episodes with 0% progress, implying they are unreleased/upcoming)
                if (widget.item.type == 'series' && widget.progress == 0.0)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: material.Colors.black.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'UP NEXT',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primaryForeground,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                // Logo overlay (bottom left) - replaced by episode info on hover
                // Use fixed-size container to prevent layout shifts
                Positioned(
                  bottom: 22, // 16px padding + 6px progress bar
                  left: 16,
                  child: SizedBox(
                    width: 240, // Fixed width to prevent shifting
                    height: 80, // Fixed height to prevent shifting
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      child: _isHovered && widget.item.type == 'series' && (widget.episodeName != null || widget.seasonNumber != null || widget.episodeNumber != null)
                          ? // Show episode info on hover
                            Align(
                              key: const ValueKey('episode-info'),
                              alignment: Alignment.bottomLeft,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.episodeName != null && widget.episodeName!.isNotEmpty)
                                    Text(
                                      widget.episodeName!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.foreground,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (widget.seasonNumber != null && widget.episodeNumber != null) ...[
                                    if (widget.episodeName != null && widget.episodeName!.isNotEmpty)
                                      const SizedBox(height: 4),
                                    Text(
                                      'S${widget.seasonNumber.toString().padLeft(2, '0')}E${widget.episodeNumber.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.foreground.withOpacity(0.8),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : // Show logo when not hovered or not a series
                            widget.item.logo != null && widget.item.logo!.isNotEmpty
                                ? Align(
                                    key: const ValueKey('logo'),
                                    alignment: Alignment.bottomLeft,
                                    child: Image.network(
                                      widget.item.logo!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  )
                                : const SizedBox.shrink(key: ValueKey('empty')),
                    ),
                  ),
                ),
                // Play button overlay (shown on hover)
                AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                        boxShadow: [
                          BoxShadow(
                            color: material.Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        size: 40,
                        color: Theme.of(context).colorScheme.primaryForeground,
                      ),
                    ),
                  ),
                ),
                // Progress bar at the bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: material.Colors.black.withOpacity(0.5),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: widget.progress / 100.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

