import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart'; // For SystemMouseCursors
import 'package:flutter/foundation.dart'; // For kDebugMode
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
  late ScrollController _episodesScrollController;
  bool _showSeasonScrollArrow = false;
  late Episode _currentEpisode; // Current episode with potentially enriched data

  @override
  void initState() {
    super.initState();
    final database = DatabaseProvider.instance;
    _streamService = StreamService(database);
    _seasonListScrollController = ScrollController();
    _seasonListScrollController.addListener(_checkSeasonScroll);
    _mainScrollController = ScrollController();
    _episodesScrollController = ScrollController();
    _selectedSeasonNumber = widget.seasonNumber;
    _currentEpisode = widget.episode;
    
    // If the current episode is missing details (like airDate, overview, stillPath), fetch them immediately
    // This is faster than waiting for all seasons to load
    if (_currentEpisode.airDate == null || _currentEpisode.stillPath == null || _currentEpisode.overview == null || _currentEpisode.runtime == null) {
      _fetchCurrentEpisodeDetails();
    }
    
    _loadSeasonsAndEpisodes();
  }

  @override
  void dispose() {
    _seasonListScrollController.removeListener(_checkSeasonScroll);
    _seasonListScrollController.dispose();
    _mainScrollController.dispose();
    _episodesScrollController.dispose();
    super.dispose();
  }

  void _scrollEpisodesLeft() {
    _episodesScrollController.animateTo(
      _episodesScrollController.offset - 480, // 400px card + 24px spacing + some buffer
      duration: const Duration(milliseconds: 300),
      curve: material.Curves.easeInOut,
    );
  }

  void _scrollEpisodesRight() {
    _episodesScrollController.animateTo(
      _episodesScrollController.offset + 480, // 400px card + 24px spacing + some buffer
      duration: const Duration(milliseconds: 300),
      curve: material.Curves.easeInOut,
    );
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

  Future<void> _fetchCurrentEpisodeDetails() async {
    try {
      final tmdbId = IdParser.extractTmdbId(widget.seriesItem.id);
      int? finalTmdbId = tmdbId;

      if (finalTmdbId == null && IdParser.isImdbId(widget.seriesItem.id)) {
        finalTmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(widget.seriesItem.id);
      }

      if (finalTmdbId != null) {
        // Fetch just the current season to get the episode details quickly
        final seasonData = await ServiceLocator.instance.tmdbSearchService.getSeasonEpisodes(finalTmdbId, _selectedSeasonNumber);
        
        if (seasonData != null && seasonData['episodes'] != null && mounted) {
          final episodes = seasonData['episodes'] as List<dynamic>;
          final episodeData = episodes.firstWhere(
            (e) => e['episode_number'] == _currentEpisode.episodeNumber,
            orElse: () => null,
          );

          if (episodeData != null && mounted) {
            setState(() {
              _currentEpisode = Episode.fromJson(episodeData);
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching current episode details: $e');
      }
    }
  }

  /// Switch to a different episode on the current page
  Future<void> _switchToEpisode(Episode episode, int seasonNumber) async {
    if (kDebugMode) {
      debugPrint('Switching to episode: ${episode.name} (S${seasonNumber}E${episode.episodeNumber})');
    }
    
    setState(() {
      _currentEpisode = episode;
      _selectedSeasonNumber = seasonNumber;
    });

    // Fetch episode details if needed
    if (episode.airDate == null || episode.stillPath == null || episode.overview == null || episode.runtime == null) {
      await _fetchEpisodeDetails(episode, seasonNumber);
    }
  }

  /// Fetch details for a specific episode
  Future<void> _fetchEpisodeDetails(Episode episode, int seasonNumber) async {
    try {
      final tmdbId = IdParser.extractTmdbId(widget.seriesItem.id);
      int? finalTmdbId = tmdbId;

      if (finalTmdbId == null && IdParser.isImdbId(widget.seriesItem.id)) {
        finalTmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(widget.seriesItem.id);
      }

      if (finalTmdbId != null) {
        // Fetch the season to get the episode details
        final seasonData = await ServiceLocator.instance.tmdbSearchService.getSeasonEpisodes(finalTmdbId, seasonNumber);
        
        if (seasonData != null && seasonData['episodes'] != null && mounted) {
          final episodes = seasonData['episodes'] as List<dynamic>;
          final episodeData = episodes.firstWhere(
            (e) => e['episode_number'] == episode.episodeNumber,
            orElse: () => null,
          );

          if (episodeData != null && mounted) {
            setState(() {
              _currentEpisode = Episode.fromJson(episodeData);
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching episode details: $e');
      }
    }
  }

  /// Format episode air date for display
  String _formatEpisodeDate(String airDate) {
    // TMDB dates are typically in YYYY-MM-DD format, return as is
    // If we need to format differently, parse and reformat here
    return airDate;
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

    // Combine all episodes from all seasons into a single list
    final allEpisodes = <({Episode episode, int seasonNumber})>[];
    for (final season in _seasons) {
      for (final episode in season.episodes) {
        allEpisodes.add((episode: episode, seasonNumber: season.seasonNumber));
      }
    }

    // Calculate episode card height based on aspect ratio 1.2
    // Card width is 400px (similar to continue watching cards)
    final cardWidth = 400.0;
    final cardHeight = cardWidth / 1.2;
    // Image takes 3/5 of the card height (flex: 3 out of total flex: 5)
    final imageHeight = cardHeight * (3 / 5);
    final imageCenter = imageHeight / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppConstants.sectionHeaderPadding,
          child: Row(
            children: [
              const Icon(Icons.play_circle_outline, size: 20),
              const SizedBox(width: 8),
              Text('Episodes').h4(),
              const SizedBox(width: 12),
              Text(
                '${allEpisodes.length} Episodes',
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
        ),
        SizedBox(
          height: cardHeight,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: AppConstants.horizontalMargin,
                  right: AppConstants.horizontalMargin,
                ),
                child: ListView.builder(
                  controller: _episodesScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: allEpisodes.length,
                  itemBuilder: (context, index) {
                    final episodeData = allEpisodes[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: SizedBox(
                        width: cardWidth,
                        child: _EpisodeCard(
                          episode: episodeData.episode,
                          seriesItem: widget.seriesItem,
                          seasonNumber: episodeData.seasonNumber,
                          onPlay: () => _handleEpisodePlay(widget.seriesItem, episodeData.seasonNumber, episodeData.episode),
                          onNavigate: () => _switchToEpisode(episodeData.episode, episodeData.seasonNumber),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Left button - centered relative to image
              Positioned(
                left: AppConstants.horizontalMargin - 40,
                top: imageCenter - 20, // Center of image minus half button height
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Clickable(
                    onPressed: _scrollEpisodesLeft,
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
                top: imageCenter - 20, // Center of image minus half button height
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Clickable(
                    onPressed: _scrollEpisodesRight,
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get episode image URL, fallback to show backdrop
    String? backdropUrl;
    if (_currentEpisode.stillPath != null) {
      backdropUrl = ServiceLocator.instance.tmdbEnrichmentService.getImageUrl(_currentEpisode.stillPath, size: 'original');
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
                      // 1. Backdrop image in the top right, scaled to 80%
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
                                backdropUrl,
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

                      // 2. Extended bottom gradient positioned outside backdrop
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

                      // 3. Main Content (Text Info + Episodes List)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              left: AppConstants.horizontalMargin,
                              right: AppConstants.horizontalMargin,
                              top: 120,
                              bottom: 60,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Logo
                                if (widget.seriesItem.logo != null && widget.seriesItem.logo!.isNotEmpty)
                                  SizedBox(
                                    width: 600,
                                    height: 250,
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
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            'S${widget.seasonNumber.toString().padLeft(2, '0')}E${_currentEpisode.episodeNumber.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withOpacity(0.7),
                                            ),
                                          ),
                                          // Duration
                                          if (_currentEpisode.runtime != null) ...[
                                            const SizedBox(width: 16),
                                            Text(
                                              '${_currentEpisode.runtime}m',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                          // Release Date
                                          if (_currentEpisode.airDate != null && _currentEpisode.airDate!.isNotEmpty) ...[
                                            const SizedBox(width: 16),
                                            Text(
                                              _formatEpisodeDate(_currentEpisode.airDate!),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white.withOpacity(0.7),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _currentEpisode.name,
                                        style: const TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Description
                                if (_currentEpisode.overview != null && _currentEpisode.overview!.isNotEmpty)
                                  SizedBox(
                                    width: 600,
                                    child: Text(
                                      _currentEpisode.overview!,
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
                              ],
                            ),
                          ),

                          // Episodes list
                          _buildEpisodesContent(),
                          
                          const SizedBox(height: 50),
                        ],
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

// Episode card widget for horizontal scrolling list
class _EpisodeCard extends StatefulWidget {
  final Episode episode;
  final CatalogItem seriesItem;
  final int seasonNumber;
  final VoidCallback onPlay;
  final VoidCallback onNavigate;

  const _EpisodeCard({
    required this.episode,
    required this.seriesItem,
    required this.seasonNumber,
    required this.onPlay,
    required this.onNavigate,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _isHovered = false;
  bool _isWatched = false;
  late final AppDatabase _database;

  @override
  void initState() {
    super.initState();
    _database = DatabaseProvider.instance;
    _checkWatchedStatus();
  }

  Future<void> _checkWatchedStatus() async {
    final tmdbId = IdParser.extractTmdbId(widget.seriesItem.id);
    if (tmdbId != null) {
      final tmdbIdStr = tmdbId.toString();
      final isWatched = await _database.isEpisodeWatched(
        tmdbIdStr,
        widget.seasonNumber,
        widget.episode.episodeNumber,
      );
      if (mounted) {
        setState(() {
          _isWatched = isWatched;
        });
      }
    }
  }

  /// Format episode air date for display
  String _formatEpisodeDate(String airDate) {
    // TMDB dates are typically in YYYY-MM-DD format, return as is
    // If we need to format differently, parse and reformat here
    return airDate;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.episode.stillPath != null
        ? ServiceLocator.instance.tmdbEnrichmentService.getImageUrl(widget.episode.stillPath, size: 'w500')
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Clickable(
              onPressed: () {
                if (kDebugMode) {
                  debugPrint('Episode card clicked - navigating to: ${widget.episode.name}');
                }
                widget.onNavigate();
              },
              child: Container(
                color: Theme.of(context).colorScheme.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Episode image
                  Flexible(
                    flex: 3,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRect(
                              child: AnimatedScale(
                                scale: _isHovered ? 1.1 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: imageUrl != null
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (context, error, stackTrace) =>
                                            Container(
                                          width: double.infinity,
                                          color: Theme.of(context).colorScheme.muted.withOpacity(0.7),
                                        ),
                                      )
                                    : Container(
                                        width: double.infinity,
                                        color: Theme.of(context).colorScheme.muted.withOpacity(0.7),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        // Watched tag
                        if (_isWatched)
                          Positioned(
                            top: 8,
                            left: 8,
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
                                'Watched',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primaryForeground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        // Runtime overlay
                        if (widget.episode.runtime != null)
                          Positioned(
                            bottom: 8,
                            right: widget.episode.airDate != null ? 120 : 8,
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
                                '${widget.episode.runtime}m',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primaryForeground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        // Date overlay
                        if (widget.episode.airDate != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
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
                                _formatEpisodeDate(widget.episode.airDate!),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primaryForeground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        // Background overlay that ignores pointer events
                        if (_isHovered)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        // Play button that captures clicks - use AbsorbPointer to only capture button area
                        if (_isHovered)
                          Center(
                            child: AbsorbPointer(
                              absorbing: false,
                              child: Clickable(
                                onPressed: () {
                                  if (kDebugMode) {
                                    debugPrint('Play button clicked for: ${widget.episode.name}');
                                  }
                                  widget.onPlay();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Title and description
                  Flexible(
                    flex: 2,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      color: Theme.of(context).colorScheme.muted,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
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
                          // Episode description
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              widget.episode.overview ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .foreground
                                    .withOpacity(0.7),
                                height: 1.4,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
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
        ),
          // Border overlay - doesn't change card dimensions
          if (_isHovered)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple dialog to select a stream
class _StreamSelectionDialog extends StatelessWidget {
  final String title;
  final List<StreamInfo> streams;

  const _StreamSelectionDialog({
    required this.title,
    required this.streams,
  });

  String _getStreamDisplayName(StreamInfo stream) {
    // Display name as heading (like NuvioStreaming)
    return stream.name ?? stream.title ?? 'Unnamed Stream';
  }

  @override
  Widget build(BuildContext context) {
    return material.Dialog(
      child: material.Container(
          width: 500,
          constraints: const material.BoxConstraints(maxHeight: 600),
          padding: const material.EdgeInsets.all(24),
          child: material.Column(
            mainAxisSize: material.MainAxisSize.min,
            crossAxisAlignment: material.CrossAxisAlignment.start,
            children: [
              // Header
              material.Row(
                children: [
                  material.Expanded(
                    child: Text(title).h4(),
                  ),
                  material.IconButton(
                    icon: const material.Icon(material.Icons.close),
                    onPressed: () => material.Navigator.of(context).pop(),
                  ),
                ],
              ),
            const material.SizedBox(height: 8),
            Text('${streams.length} stream${streams.length != 1 ? 's' : ''} available').muted(),
            const material.SizedBox(height: 24),
            
            // Stream list
            material.Flexible(
              child: streams.isEmpty
                  ? material.Center(
                      child: material.Column(
                        mainAxisSize: material.MainAxisSize.min,
                        children: [
                          material.Icon(
                            material.Icons.video_library_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.mutedForeground,
                          ),
                          const material.SizedBox(height: 16),
                          const Text('No streams available').muted(),
                        ],
                      ),
                    )
                  : material.ListView.builder(
                      shrinkWrap: true,
                      itemCount: streams.length,
                      itemBuilder: (context, index) {
                        final stream = streams[index];
                        return _StreamItem(
                          stream: stream,
                          displayName: _getStreamDisplayName(stream),
                          onTap: () => material.Navigator.of(context).pop(stream),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamItem extends StatefulWidget {
  final StreamInfo stream;
  final String displayName;
  final VoidCallback onTap;

  const _StreamItem({
    required this.stream,
    required this.displayName,
    required this.onTap,
  });

  @override
  State<_StreamItem> createState() => _StreamItemState();
}

class _StreamItemState extends State<_StreamItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Clickable(
        onPressed: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? Theme.of(context).colorScheme.muted
                : Theme.of(context).colorScheme.background,
            border: Border.all(
              color: _isHovered
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Play icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Stream info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.displayName).semiBold(),
                    if ((widget.stream.description != null &&
                        widget.stream.description!.isNotEmpty) ||
                        (widget.stream.title != null &&
                        widget.stream.title!.isNotEmpty)) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.stream.description ?? widget.stream.title ?? '',
                      ).muted().small(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}