import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'dart:async';
import '../models/catalog_item.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/persistent_navigation_header.dart';
import 'catalog_item_detail_screen.dart';

/// Search overlay that displays search results in a grid
class SearchOverlay extends StatefulWidget {
  final String initialQuery;

  const SearchOverlay({
    super.key,
    this.initialQuery = '',
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  late final TextEditingController _searchController;
  List<CatalogItem> _results = [];
  bool _isSearching = false;
  bool _hasText = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _hasText = widget.initialQuery.isNotEmpty;
    
    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }
    
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _hasText = _searchController.text.isNotEmpty;
    });
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(_searchController.text);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search both movies and TV shows from TMDB API
      final movieResults = await ServiceLocator.instance.tmdbSearchService.searchMovies(query);
      final tvResults = await ServiceLocator.instance.tmdbSearchService.searchTv(query);
      
      // Combine and convert to CatalogItem
      final allResults = <CatalogItem>[];
      final enrichmentService = ServiceLocator.instance.tmdbEnrichmentService;
      
      for (final movieData in movieResults) {
        try {
          final tmdbIdStr = 'tmdb:${movieData.id}';
          allResults.add(CatalogItem.fromJson({
            'id': tmdbIdStr,
            'type': 'movie',
            'name': movieData.title ?? '',
            'poster': enrichmentService.getImageUrl(movieData.posterPath),
            'background': enrichmentService.getImageUrl(movieData.backdropPath, size: 'w1280'),
            'description': movieData.overview,
            'releaseInfo': movieData.releaseDate,
            'imdbRating': movieData.voteAverage.toString(),
          }));
        } catch (e) {
          // Skip invalid items
          continue;
        }
      }
      
      for (final tvData in tvResults) {
        try {
          final tmdbIdStr = 'tmdb:${tvData.id}';
          allResults.add(CatalogItem.fromJson({
            'id': tmdbIdStr,
            'type': 'series',
            'name': tvData.name ?? '',
            'poster': enrichmentService.getImageUrl(tvData.posterPath),
            'background': enrichmentService.getImageUrl(tvData.backdropPath, size: 'w1280'),
            'description': tvData.overview,
            'releaseInfo': tvData.firstAirDate,
            'imdbRating': tvData.voteAverage.toString(),
          }));
        } catch (e) {
          // Skip invalid items
          continue;
        }
      }
      
      // Sort by rating (highest first), then by name
      allResults.sort((a, b) {
        final ratingA = double.tryParse(a.imdbRating ?? '0') ?? 0.0;
        final ratingB = double.tryParse(b.imdbRating ?? '0') ?? 0.0;
        
        if (ratingB != ratingA) {
          return ratingB.compareTo(ratingA);
        }
        return a.name.compareTo(b.name);
      });
      
      if (mounted) {
        setState(() {
          _results = allResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: AppConstants.horizontalPadding.copyWith(
            top: 16,
            bottom: 16,
          ),
          child: Row(
            children: [
              const Icon(Icons.search),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  placeholder: const Text('Search titles, people, genres'),
                ),
              ),
              if (_hasText)
                Clickable(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _results = [];
                      _hasText = false;
                    });
                  },
                  child: const Icon(Icons.clear),
                ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _buildResults(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text(
              'Start typing to search',
              style: TextStyle(
                color: Theme.of(context).colorScheme.mutedForeground,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
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
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate responsive column count based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (screenWidth > 1600) {
      crossAxisCount = 8;
    } else if (screenWidth > 1200) {
      crossAxisCount = 7;
    } else if (screenWidth > 900) {
      crossAxisCount = 6;
    } else if (screenWidth > 600) {
      crossAxisCount = 5;
    } else {
      crossAxisCount = 4;
    }

    return Padding(
      padding: AppConstants.horizontalPadding.copyWith(
        bottom: 40,
      ),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 32,
          childAspectRatio: 0.52,
        ),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final item = _results[index];
          return _SearchResultCard(item: item);
        },
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  final CatalogItem item;

  const _SearchResultCard({required this.item});

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
          Navigator.of(context).pushReplacement(
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
            mainAxisAlignment: MainAxisAlignment.start,
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
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
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
                                child: const Center(
                                    child: CircularProgressIndicator()),
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
              Flexible(
                child: SizedBox(
                  width: 200,
                  child: Text(
                    widget.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.3),
                  ).semiBold(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
