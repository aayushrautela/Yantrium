import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' as material;
import '../models/catalog_item.dart';
import '../models/episode.dart' show Episode, Season;
import '../models/stream_info.dart';
import '../../player/screens/video_player_screen.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/persistent_navigation_header.dart';
import '../../../core/widgets/back_button_overlay.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/id_parser.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../logic/stream_service.dart';
import 'package:flutter/foundation.dart';

/// Detail screen for an episode
class EpisodeDetailScreen extends StatefulWidget {
  final CatalogItem seriesItem;
  final Episode episode;
  final int seasonNumber;

  const EpisodeDetailScreen({
    super.key,
    required this.seriesItem,
    required this.episode,
    required this.seasonNumber,
  });

  @override
  State<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends State<EpisodeDetailScreen> {
  late final StreamService _streamService;
  List<Season> _seasons = [];
  int _selectedSeasonNumber = 1;
  bool _isLoadingEpisodes = false;
  late ScrollController _seasonListScrollController;
  late ScrollController _mainScrollController;
  bool _showSeasonScrollArrow = false;

  @override
  void initState() {
    super.initState();
    final database = DatabaseProvider.instance;
    _streamService = StreamService(database);
    _seasonListScrollController = ScrollController();
    _seasonListScrollController.addListener(_checkSeasonScroll);
    _mainScrollController = ScrollController();
    _selectedSeasonNumber = widget.seasonNumber;
    _loadSeasonsAndEpisodes();
  }

  @override
  void dispose() {
    _seasonListScrollController.removeListener(_checkSeasonScroll);
    _seasonListScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  void _checkSeasonScroll() {
    if (!_seasonListScrollController.hasClients) return;
    
    final maxScroll = _seasonListScrollController.position.maxScrollExtent;
    final currentScroll = _seasonListScrollController.position.pixels;
    final canScroll = maxScroll > 0 && currentScroll < maxScroll - 5; // 5px threshold
    
    if (canScroll != _showSeasonScrollArrow) {
      setState(() {
        _showSeasonScrollArrow = canScroll;
      });
    }
  }

  void _scrollToSelectedSeason() {
    if (!_seasonListScrollController.hasClients || _seasons.isEmpty) return;
    
    // Find the index of the selected season
    final selectedIndex = _seasons.indexWhere((s) => s.seasonNumber == _selectedSeasonNumber);
    if (selectedIndex == -1) return;
    
    // Estimate item height (padding + text height, approximately 48px per item)
    const estimatedItemHeight = 48.0;
    final targetOffset = selectedIndex * estimatedItemHeight;
    
    // Scroll to the selected season, ensuring it's visible
    _seasonListScrollController.animateTo(
      targetOffset.clamp(0.0, _seasonListScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: material.Curves.easeInOut,
    );
  }

  Future<void> _loadSeasonsAndEpisodes() async {
    if (_isLoadingEpisodes || _seasons.isNotEmpty) return;

    setState(() {
      _isLoadingEpisodes = true;
    });

    try {
      final tmdbId = IdParser.extractTmdbId(widget.seriesItem.id);
      int? finalTmdbId = tmdbId;

      if (finalTmdbId == null && IdParser.isImdbId(widget.seriesItem.id)) {
        finalTmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(widget.seriesItem.id);
      }

      if (finalTmdbId != null) {
        // Get all seasons
        final seasonsData = await ServiceLocator.instance.tmdbSearchService.getSeasons(finalTmdbId);
        final List<Season> seasons = [];

        for (final seasonData in seasonsData) {
          final seasonNumber = seasonData['season_number'] as int? ?? 0;
          // Skip season 0 (specials)
          if (seasonNumber == 0) continue;

          // Fetch episodes for this season
          final episodesData =
              await ServiceLocator.instance.tmdbSearchService.getSeasonEpisodes(finalTmdbId, seasonNumber);
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
            // Ensure the current episode's season is selected
            if (_seasons.isNotEmpty) {
              // Check if the season exists in the loaded seasons
              final seasonExists = _seasons.any((s) => s.seasonNumber == widget.seasonNumber);
              if (seasonExists) {
                _selectedSeasonNumber = widget.seasonNumber;
              } else {
                // If season doesn't exist, select the first one
                _selectedSeasonNumber = _seasons.first.seasonNumber;
              }
            }
            _isLoadingEpisodes = false;
          });
          // Check scroll state and scroll to selected season after a frame to ensure layout is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _seasonListScrollController.hasClients) {
              _checkSeasonScroll();
              // Scroll to the selected season
              _scrollToSelectedSeason();
            }
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

  Future<void> _handlePlayButton() async {
    if (kDebugMode) {
      debugPrint('Play button clicked for episode: ${widget.episode.name} (S${widget.seasonNumber}E${widget.episode.episodeNumber})');
    }
    
    // Get the IMDB ID for the series
    final imdbId = await _getImdbIdForItem(widget.seriesItem);
    if (imdbId == null) {
      if (kDebugMode) {
        debugPrint('Could not get IMDB ID for series, cannot generate episode ID');
      }
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => material.AlertDialog(
            title: const Text('Cannot Play Episode'),
            content: const Text('Unable to identify this series. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    // Format episode ID as {showId}:{season}:{episode}
    final episodeId = '$imdbId:${widget.seasonNumber}:${widget.episode.episodeNumber}';
    
    if (kDebugMode) {
      debugPrint('Using episode ID: $episodeId');
    }
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: material.CircularProgressIndicator(),
      ),
    );
    
    try {
      // Fetch streams from all enabled addons
      final streams = await _streamService.getStreamsForItem(
        widget.seriesItem,
        episodeId: episodeId,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (streams.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => material.AlertDialog(
              title: const Text('No Streams Available'),
              content: const Text('No streams were found for this episode.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Show stream selection dialog
      if (mounted) {
        final selectedStream = await showDialog<StreamInfo>(
          context: context,
          builder: (context) => _StreamSelectionDialog(
            title: '${widget.seriesItem.name} - S${widget.seasonNumber}E${widget.episode.episodeNumber}',
            streams: streams,
          ),
        );
        
        if (selectedStream != null) {
          if (kDebugMode) {
            debugPrint('Selected stream: ${selectedStream.url}');
            debugPrint('Stream quality: ${selectedStream.quality ?? 'Unknown'}');
            debugPrint('Stream addon: ${selectedStream.addonName ?? selectedStream.addonId ?? 'Unknown'}');
          }
          
          // Navigate to video player with selected stream
          if (mounted) {
            Navigator.of(context).push(
              material.MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  streamUrl: selectedStream.url,
                  title: '${widget.seriesItem.name} - S${widget.seasonNumber}E${widget.episode.episodeNumber}',
                  subtitles: selectedStream.subtitles?.map((s) => s.url).toList(),
                  logoUrl: widget.seriesItem.logo,
                  description: widget.episode.overview ?? widget.seriesItem.description,
                  episodeName: widget.episode.name,
                  seasonNumber: widget.seasonNumber,
                  episodeNumber: widget.episode.episodeNumber,
                  isMovie: false,
                ),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (kDebugMode) {
        debugPrint('Error playing episode: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => material.AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to play episode: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleEpisodePlay(CatalogItem seriesItem, int seasonNumber, Episode episode) async {
    if (kDebugMode) {
      debugPrint('Episode play clicked: ${episode.name} (S${seasonNumber}E${episode.episodeNumber})');
    }
    
    // Get the IMDB ID for the series
    final imdbId = await _getImdbIdForItem(seriesItem);
    if (imdbId == null) {
      if (kDebugMode) {
        debugPrint('Could not get IMDB ID for series, cannot generate episode ID');
      }
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => material.AlertDialog(
            title: const Text('Cannot Play Episode'),
            content: const Text('Unable to identify this series. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    // Format episode ID as {showId}:{season}:{episode}
    final episodeId = '$imdbId:$seasonNumber:${episode.episodeNumber}';
    
    if (kDebugMode) {
      debugPrint('Using episode ID: $episodeId');
    }
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: material.CircularProgressIndicator(),
      ),
    );
    
    try {
      // Fetch streams from all enabled addons
      final streams = await _streamService.getStreamsForItem(
        seriesItem,
        episodeId: episodeId,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (streams.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => material.AlertDialog(
              title: const Text('No Streams Available'),
              content: const Text('No streams were found for this episode.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Show stream selection dialog
      if (mounted) {
        final selectedStream = await showDialog<StreamInfo>(
          context: context,
          builder: (context) => _StreamSelectionDialog(
            title: '${seriesItem.name} - S${seasonNumber}E${episode.episodeNumber}',
            streams: streams,
          ),
        );
        
        if (selectedStream != null) {
          if (kDebugMode) {
            debugPrint('Selected stream: ${selectedStream.url}');
            debugPrint('Stream quality: ${selectedStream.quality ?? 'Unknown'}');
            debugPrint('Stream addon: ${selectedStream.addonName ?? selectedStream.addonId ?? 'Unknown'}');
          }
          
          // Navigate to video player with selected stream
          if (mounted) {
            Navigator.of(context).push(
              material.MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  streamUrl: selectedStream.url,
                  title: '${seriesItem.name} - S${seasonNumber}E${episode.episodeNumber}',
                  subtitles: selectedStream.subtitles?.map((s) => s.url).toList(),
                  logoUrl: seriesItem.logo,
                  description: episode.overview ?? seriesItem.description,
                  episodeName: episode.name,
                  seasonNumber: seasonNumber,
                  episodeNumber: episode.episodeNumber,
                  isMovie: false,
                ),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (kDebugMode) {
        debugPrint('Error playing episode: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => material.AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to play episode: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<String?> _getImdbIdForItem(CatalogItem item) async {
    // If already an IMDB ID, use it directly
    if (IdParser.isImdbId(item.id)) {
      return item.id;
    }

    // Try to extract TMDB ID
    final tmdbId = IdParser.extractTmdbId(item.id);
    if (tmdbId == null) {
      return null;
    }

    // Fetch TMDB metadata to get IMDB ID
    try {
      Map<String, dynamic>? tmdbData;
      if (item.type == 'movie') {
        final metadata = await ServiceLocator.instance.tmdbMetadataService.getMovieMetadata(tmdbId);
        tmdbData = metadata?.toJson();
      } else if (item.type == 'series') {
        final metadata = await ServiceLocator.instance.tmdbMetadataService.getTvMetadata(tmdbId);
        tmdbData = metadata?.toJson();
      }

      if (tmdbData != null) {
        final externalIds = tmdbData['external_ids'] as Map<String, dynamic>?;
        final imdbId = externalIds?['imdb_id'] as String?;
        return imdbId;
      }
    } catch (e) {
      // Ignore errors
    }
    
    return null;
  }

  Widget _buildEpisodesContent() {
    // Load seasons and episodes when this tab is selected
    if (_seasons.isEmpty && !_isLoadingEpisodes) {
      _loadSeasonsAndEpisodes();
    }

    if (_isLoadingEpisodes) {
      return const SizedBox(
        height: 400,
        child: Center(child: material.CircularProgressIndicator()),
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

    // Horizontal layout: seasons list on left, episodes on right
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seasons list
        SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Season header aligned with episode header
              Text(
                'Season',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              // Seasons list
              Container(
                constraints: const BoxConstraints(maxHeight: 600),
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _seasonListScrollController,
                      shrinkWrap: true,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    material.Icons.arrow_forward_ios,
                                    size: 12,
                                    color: Colors.yellow,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Scroll indicator arrow at the bottom
                    if (_showSeasonScrollArrow)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Theme.of(context).colorScheme.background.withOpacity(0.8),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              material.Icons.keyboard_arrow_down,
                              color: Theme.of(context).colorScheme.foreground.withOpacity(0.7),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        // Episodes content
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
                    padding: const EdgeInsets.only(bottom: 40),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: selectedSeason.episodes.length,
                    itemBuilder: (context, index) {
                      final episode = selectedSeason.episodes[index];
                      return _EpisodeCard(
                        episode: episode,
                        seriesItem: widget.seriesItem,
                        seasonNumber: selectedSeason.seasonNumber,
                        onPlay: () => _handleEpisodePlay(widget.seriesItem, selectedSeason.seasonNumber, episode),
                      );
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

  @override
  Widget build(BuildContext context) {
    // Get episode image URL, fallback to show backdrop
    String? backdropUrl;
    if (widget.episode.stillPath != null) {
      backdropUrl = ServiceLocator.instance.tmdbEnrichmentService.getImageUrl(widget.episode.stillPath, size: 'original');
    } else if (widget.seriesItem.background != null) {
      backdropUrl = widget.seriesItem.background;
    }

    return Container(
        color: Theme.of(context).colorScheme.background,
        child: Stack(
          children: [
            // Scrollable content
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _mainScrollController,
                    child: Stack(
                  children: [
                    // Backdrop image in the top right, scaled to 80%
                    if (backdropUrl != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              backdropUrl!,
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
                          ],
                        ),
                      ),

                    // Extended bottom gradient positioned outside backdrop (85% height for 5% buffer)
                    if (backdropUrl != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.height * 0.85,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Theme.of(context).colorScheme.background,
                                Theme.of(context).colorScheme.background,
                                Theme.of(context).colorScheme.background.withOpacity(0.8),
                                Theme.of(context).colorScheme.background.withOpacity(0.7),
                                Theme.of(context).colorScheme.background.withOpacity(0.5),
                                Theme.of(context).colorScheme.background.withOpacity(0.1),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.15, 0.25, 0.4, 0.55, 0.75, 0.85],
                            ),
                          ),
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
                          if (widget.seriesItem.logo != null && widget.seriesItem.logo!.isNotEmpty)
                            SizedBox(
                              width: 600, // Max width constraint
                              height: 250, // Max height constraint
                              child: Image.network(
                                widget.seriesItem.logo!,
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                errorBuilder: (context, error, stackTrace) {
                                  return Text(
                                    widget.seriesItem.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 60,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.yellow,
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            Text(
                              widget.seriesItem.name.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: Colors.yellow,
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Season and episode number with episode name
                          SizedBox(
                            width: 600,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'S${widget.seasonNumber.toString().padLeft(2, '0')}E${widget.episode.episodeNumber.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.episode.name,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Description
                          if (widget.episode.overview != null)
                            SizedBox(
                              width: 600,
                              child: Text(
                                widget.episode.overview!,
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
                                onPressed: () => _handlePlayButton(),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(material.Icons.play_arrow, size: 24),
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
                                    Icon(material.Icons.add, size: 24),
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

                          // Episodes list
                          _buildEpisodesContent(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
            ),
            // Back button overlay - placed last so it's rendered on top
            BackButtonOverlay(
              onBack: () {
                final navigator = Navigator.of(context);
                if (navigator.canPop()) {
                  navigator.pop();
                }
              },
            ),
          ],
        ),
    );
  }
}

// Import EpisodeCard from catalog_item_detail_screen
// We'll need to copy it or import it
class _EpisodeCard extends StatefulWidget {
  final Episode episode;
  final CatalogItem seriesItem;
  final int seasonNumber;
  final VoidCallback onPlay;

  const _EpisodeCard({
    required this.episode,
    required this.seriesItem,
    required this.seasonNumber,
    required this.onPlay,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.episode.stillPath != null
        ? ServiceLocator.instance.tmdbEnrichmentService.getImageUrl(widget.episode.stillPath, size: 'w500')
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Clickable(
        onPressed: widget.onPlay,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Theme.of(context).colorScheme.background,
            child: ClipRect(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Episode image with duration overlay
                Flexible(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (imageUrl != null)
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Theme.of(context).colorScheme.muted,
                            ),
                          )
                        else
                          Container(
                            color: Theme.of(context).colorScheme.muted,
                          ),
                        // Play button overlay (shown on hover)
                        AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            color: material.Colors.black.withOpacity(0.5),
                            child: Center(
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                                ),
                                child: Icon(
                                  material.Icons.play_arrow,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primaryForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Duration badge (top right)
                        if (widget.episode.runtime != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: material.Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.episode.runtime} min',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Episode info
                Flexible(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.episode.episodeNumber}. ${widget.episode.name}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.episode.overview != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.episode.overview!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.foreground.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _StreamSelectionDialog extends StatelessWidget {
  final String title;
  final List<StreamInfo> streams;

  const _StreamSelectionDialog({
    required this.title,
    required this.streams,
  });

  @override
  Widget build(BuildContext context) {
    return material.AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: streams.length,
          itemBuilder: (context, index) {
            final stream = streams[index];
            return material.ListTile(
              title: Text(stream.quality ?? 'Unknown Quality'),
              subtitle: Text(stream.addonName ?? stream.addonId ?? 'Unknown Addon'),
              onTap: () => Navigator.of(context).pop(stream),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
