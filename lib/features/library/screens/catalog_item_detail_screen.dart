import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart';
import '../models/catalog_item.dart';
import '../models/cast_crew_member.dart';
import '../models/episode.dart';
import '../../../core/constants/app_constants.dart';
import '../logic/library_repository.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/persistent_navigation_header.dart';
import '../../../core/services/tmdb_service.dart';

/// Detail screen for a catalog item (movie or series)
class CatalogItemDetailScreen extends StatefulWidget {
  final CatalogItem item;

  const CatalogItemDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<CatalogItemDetailScreen> createState() =>
      _CatalogItemDetailScreenState();
}

class _CatalogItemDetailScreenState extends State<CatalogItemDetailScreen> {
  int _selectedTab = 0;
  late final LibraryRepository _libraryRepository;
  late final TmdbService _tmdbService;
  CatalogItem? _enrichedItem;
  List<CastCrewMember> _cast = [];
  List<CastCrewMember> _crew = [];
  bool _isLoadingCastCrew = false;
  List<CatalogItem> _similarItems = [];
  bool _isLoadingSimilar = false;
  List<Season> _seasons = [];
  int _selectedSeasonNumber = 1;
  bool _isLoadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    _libraryRepository = LibraryRepository(AppDatabase());
    _tmdbService = TmdbService();
    _enrichItem();
    _loadCastAndCrew();
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

  Future<void> _loadCastAndCrew() async {
    // Wait a bit for enrichment to complete
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoadingCastCrew = true;
    });

    try {
      final item = _enrichedItem ?? widget.item;
      final castCrewData = await _libraryRepository.getCastAndCrewForItem(item);

      if (castCrewData != null && mounted) {
        final parsedCast = (castCrewData['cast'] as List<dynamic>? ?? [])
            .map((c) {
              try {
                return CastCrewMember.fromJson(c);
              } catch (e) {
                return null;
              }
            })
            .whereType<CastCrewMember>()
            .toList();

        final parsedCrew = (castCrewData['crew'] as List<dynamic>? ?? [])
            .map((c) {
              try {
                return CastCrewMember.fromJson(c);
              } catch (e) {
                return null;
              }
            })
            .whereType<CastCrewMember>()
            .toList();

        setState(() {
          _cast = parsedCast;
          _crew = parsedCrew;
          _isLoadingCastCrew = false;
        });
        return;
      }
    } catch (e) {
      // Ignore errors
    }

    if (mounted) {
      setState(() {
        _isLoadingCastCrew = false;
      });
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
      child: Container(
        color: Theme.of(context).colorScheme.background,
        child: Column(
          children: [
            // Top content area
            Expanded(
              child: SingleChildScrollView(
                child: Stack(
                  children: [
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
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Theme.of(context).colorScheme.muted,
                              ),
                            ),
                            // Gradient to blend left edge (vertical fade from left to right)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Theme.of(context).colorScheme.background,
                                    Theme.of(context)
                                        .colorScheme
                                        .background
                                        .withOpacity(0.6),
                                    Theme.of(context)
                                        .colorScheme
                                        .background
                                        .withOpacity(0.2),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.15, 0.35, 1.0],
                                ),
                              ),
                            ),
                            // Gradient to blend bottom edge (horizontal fade from bottom to top)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Theme.of(context).colorScheme.background,
                                    Theme.of(context)
                                        .colorScheme
                                        .background
                                        .withOpacity(0.6),
                                    Theme.of(context)
                                        .colorScheme
                                        .background
                                        .withOpacity(0.2),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.15, 0.35, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Content
                    Padding(
                      padding: EdgeInsets.only(
                        left: AppConstants.horizontalMargin,
                        right: AppConstants.horizontalMargin,
                        top: 120,
                        bottom: 160,
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
                                  // Fixed Math Logic: ((Rating ?? 0) * 10)
                                  '${((double.tryParse(item.imdbRating!) ?? 0) * 10).toInt()}% Match',
                                  style: TextStyle(
                                    color: Colors.green[400],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),

                              // Year
                              if (item.releaseInfo != null)
                                Text(
                                  item.releaseInfo!
                                      .split('-')
                                      .first, // Extract year
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
                                const Text(
                                  '14 Seasons',
                                  style: TextStyle(fontSize: 16),
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
                                isSelected: _selectedTab ==
                                    (item.type == 'series' ? 1 : 0),
                                onTap: () => setState(() => _selectedTab =
                                    item.type == 'series' ? 1 : 0),
                              ),
                              const SizedBox(width: 32),
                              _TabButton(
                                label: 'MORE LIKE THIS',
                                isSelected: _selectedTab ==
                                    (item.type == 'series' ? 2 : 1),
                                onTap: () => setState(() => _selectedTab =
                                    item.type == 'series' ? 2 : 1),
                              ),
                              const SizedBox(width: 32),
                              _TabButton(
                                label: 'DETAILS',
                                isSelected: _selectedTab ==
                                    (item.type == 'series' ? 3 : 2),
                                onTap: () => setState(() => _selectedTab =
                                    item.type == 'series' ? 3 : 2),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Tab content
                          _buildTabContent(item),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(CatalogItem item) {
    final castCrewTabIndex = item.type == 'series' ? 1 : 0;
    final moreLikeThisTabIndex = item.type == 'series' ? 2 : 1;

    if (_selectedTab == 0 && item.type == 'series') {
      return _buildEpisodesContent(item);
    }

    if (_selectedTab == castCrewTabIndex) {
      return _buildCastAndCrewContent();
    }

    if (_selectedTab == moreLikeThisTabIndex) {
      return _buildMoreLikeThisContent(item);
    }

    // DETAILS tab
    return SizedBox(
      width: 600,
      child: const Text(
        'Content for DETAILS',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Future<void> _loadSeasonsAndEpisodes(CatalogItem item) async {
    if (_isLoadingEpisodes || _seasons.isNotEmpty) return;

    setState(() {
      _isLoadingEpisodes = true;
    });

    try {
      final tmdbId = _tmdbService.extractTmdbId(item.id);
      int? finalTmdbId = tmdbId;

      if (finalTmdbId == null && item.id.startsWith('tt')) {
        finalTmdbId = await _tmdbService.getTmdbIdFromImdb(item.id);
      }

      if (finalTmdbId != null) {
        // Get all seasons
        final seasonsData = await _tmdbService.getSeasons(finalTmdbId);
        final List<Season> seasons = [];

        for (final seasonData in seasonsData) {
          final seasonNumber = seasonData['season_number'] as int? ?? 0;
          // Skip season 0 (specials)
          if (seasonNumber == 0) continue;

          // Fetch episodes for this season
          final episodesData =
              await _tmdbService.getSeasonEpisodes(finalTmdbId, seasonNumber);
          if (episodesData != null) {
            final episodesJson =
                episodesData['episodes'] as List<dynamic>? ?? [];
            final episodes = episodesJson
                .map((e) => Episode.fromJson(e as Map<String, dynamic>))
                .toList();

            seasons.add(Season(
              seasonNumber: seasonNumber,
              name: seasonData['name'] as String? ?? 'Season $seasonNumber',
              overview: seasonData['overview'] as String?,
              posterPath: seasonData['poster_path'] as String?,
              episodeCount: seasonData['episode_count'] as int? ?? 0,
              airDate: seasonData['air_date'] as String?,
              episodes: episodes,
            ));
          }
        }

        if (mounted) {
          setState(() {
            _seasons = seasons;
            if (_seasons.isNotEmpty) {
              _selectedSeasonNumber = _seasons.first.seasonNumber;
            }
            _isLoadingEpisodes = false;
          });
          return;
        }
      }
    } catch (e) {
      // Ignore errors
    }

    if (mounted) {
      setState(() {
        _isLoadingEpisodes = false;
      });
    }
  }

  Future<void> _loadSimilarItems(CatalogItem item) async {
    if (_isLoadingSimilar || _similarItems.isNotEmpty) return;

    setState(() {
      _isLoadingSimilar = true;
    });

    try {
      final tmdbId = _tmdbService.extractTmdbId(item.id);
      int? finalTmdbId = tmdbId;

      if (finalTmdbId == null && item.id.startsWith('tt')) {
        finalTmdbId = await _tmdbService.getTmdbIdFromImdb(item.id);
      }

      if (finalTmdbId != null) {
        final similarData =
            await _tmdbService.getSimilar(finalTmdbId, item.type);
        if (mounted) {
          setState(() {
            _similarItems = similarData
                .map((data) => CatalogItem.fromJson(data))
                .toList();
            _isLoadingSimilar = false;
          });
          return;
        }
      }
    } catch (e) {
      // Ignore errors
    }

    if (mounted) {
      setState(() {
        _isLoadingSimilar = false;
      });
    }
  }

  Widget _buildMoreLikeThisContent(CatalogItem item) {
    // Load similar items when this tab is selected
    if (!_isLoadingSimilar && _similarItems.isEmpty) {
      _loadSimilarItems(item);
    }

    if (_isLoadingSimilar) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_similarItems.isEmpty) {
      return SizedBox(
        height: 400,
        child: Center(
          child: Text(
            'No similar titles available',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 32,
        childAspectRatio:
            0.52, // Adjusted to give more vertical space for 2-line titles (200/385 ratio)
      ),
      itemCount: _similarItems.length,
      itemBuilder: (context, index) {
        final similarItem = _similarItems[index];
        return _SimilarItemCard(item: similarItem);
      },
    );
  }

  Widget _buildCastAndCrewContent() {
    if (_isLoadingCastCrew) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Limit to first 15 cast members only
    final displayMembers = _cast.take(15).toList();

    if (displayMembers.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No cast and crew information available',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 32,
        childAspectRatio:
            0.55, // Adjusted to give more vertical space for cast cards
      ),
      itemCount: displayMembers.length,
      itemBuilder: (context, index) {
        final member = displayMembers[index];
        return _CastCrewCard(member: member);
      },
    );
  }

  Widget _buildEpisodesContent(CatalogItem item) {
    // Load seasons and episodes when this tab is selected
    if (_seasons.isEmpty && !_isLoadingEpisodes) {
      _loadSeasonsAndEpisodes(item);
    }

    if (_isLoadingEpisodes) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_seasons.isEmpty) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: Text(
            'No episodes available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final selectedSeason = _seasons.firstWhere(
      (s) => s.seasonNumber == _selectedSeasonNumber,
      orElse: () => _seasons.first,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Season sidebar
        SizedBox(
          width: 200,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _seasons.length,
            itemBuilder: (context, index) {
              final season = _seasons[index];
              final isSelected = season.seasonNumber == _selectedSeasonNumber;

              return Clickable(
                onPressed: () {
                  setState(() {
                    _selectedSeasonNumber = season.seasonNumber;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context)
                            .colorScheme
                            .foreground
                            .withOpacity(0.1)
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: isSelected ? Colors.yellow : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          season.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.yellow
                                : Theme.of(context).colorScheme.foreground,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.yellow,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(width: 32),

        // Episodes grid
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Season header
              Row(
                children: [
                  Text(
                    selectedSeason.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${selectedSeason.episodes.length} Episodes',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .foreground
                          .withOpacity(0.7),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Episodes grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  int crossAxisCount;
                  if (screenWidth > 1600) {
                    crossAxisCount = 4;
                  } else if (screenWidth > 1200) {
                    crossAxisCount = 4;
                  } else if (screenWidth > 800) {
                    crossAxisCount = 3;
                  } else {
                    crossAxisCount = 2;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.55,
                    ),
                    itemCount: selectedSeason.episodes.length,
                    itemBuilder: (context, index) {
                      final episode = selectedSeason.episodes[index];
                      return _EpisodeCard(episode: episode);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
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
              fontSize: 18,
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
              width: label.length * 10.0,
              color: Colors.yellow,
            ),
        ],
      ),
    );
  }
}

class _CastCrewCard extends StatefulWidget {
  final CastCrewMember member;

  const _CastCrewCard({
    required this.member,
  });

  @override
  State<_CastCrewCard> createState() => _CastCrewCardState();
}

class _CastCrewCardState extends State<_CastCrewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tmdbService = TmdbService();
    final profileImageUrl = widget.member.profileImageUrl != null
        ? tmdbService.getImageUrl(widget.member.profileImageUrl, size: 'w185')
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Circular profile image (50% bigger: 100 -> 150) with hover animation
          ClipOval(
            child: AnimatedScale(
              scale: _isHovered ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: profileImageUrl != null
                  ? Image.network(
                      profileImageUrl,
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 150,
                          height: 150,
                          color: Theme.of(context).colorScheme.muted,
                          child: Icon(
                            Icons.person,
                            size: 75,
                            color: Theme.of(context)
                                .colorScheme
                                .foreground
                                .withOpacity(0.5),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 150,
                      height: 150,
                      color: Theme.of(context).colorScheme.muted,
                      child: Icon(
                        Icons.person,
                        size: 75,
                        color: Theme.of(context)
                            .colorScheme
                            .foreground
                            .withOpacity(0.5),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          // Name
          Text(
            widget.member.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.member.character != null) ...[
            const SizedBox(height: 4),
            // Character/Role
            Text(
              widget.member.character!,
              style: TextStyle(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.foreground.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _SimilarItemCard extends StatefulWidget {
  final CatalogItem item;

  const _SimilarItemCard({required this.item});

  @override
  State<_SimilarItemCard> createState() => _SimilarItemCardState();
}

class _SimilarItemCardState extends State<_SimilarItemCard> {
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

class _EpisodeCard extends StatefulWidget {
  final Episode episode;

  const _EpisodeCard({required this.episode});

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tmdbService = TmdbService();
    final imageUrl = widget.episode.stillPath != null
        ? tmdbService.getImageUrl(widget.episode.stillPath, size: 'w500')
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Episode image with duration overlay
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: AnimatedScale(
                    scale: _isHovered ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 180,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: double.infinity,
                              height: 200,
                              color: Theme.of(context).colorScheme.muted,
                              child: const Icon(Icons.image_not_supported),
                            ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: double.infinity,
                                height: 200,
                                color: Theme.of(context).colorScheme.muted,
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              );
                            },
                          )
                        : Container(
                            width: double.infinity,
                            height: 200,
                            color: Theme.of(context).colorScheme.muted,
                            child: const Icon(Icons.image_not_supported),
                          ),
                  ),
                ),
                // Duration overlay
                if (widget.episode.runtime != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.episode.runtime}m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Episode title
          Text(
            '${widget.episode.episodeNumber}. ${widget.episode.name}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          // Episode description
          if (widget.episode.overview != null &&
              widget.episode.overview!.isNotEmpty)
            Flexible(
              child: Text(
                widget.episode.overview!,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.foreground.withOpacity(0.7),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}