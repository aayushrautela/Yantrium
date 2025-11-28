import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import '../models/catalog_item.dart';
import '../models/cast_crew_member.dart';
import '../models/episode.dart';
import '../models/stream_info.dart';
import '../../../core/constants/app_constants.dart';
import '../logic/library_repository.dart';
import '../logic/stream_service.dart';
import '../../player/screens/video_player_screen.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/persistent_navigation_header.dart';
import '../../../core/widgets/back_button_overlay.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/id_parser.dart';
import '../../../core/services/tmdb_data_extractor.dart';
import 'episode_detail_screen.dart';

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
  late final StreamService _streamService;
  CatalogItem? _enrichedItem;
  List<CastCrewMember> _cast = [];
  List<CastCrewMember> _crew = [];
  bool _isLoadingCastCrew = false;
  List<CatalogItem> _similarItems = [];
  bool _isLoadingSimilar = false;
  bool _hasAttemptedLoadSimilar = false;
  List<Season> _seasons = [];
  int _selectedSeasonNumber = 1;
  bool _isLoadingEpisodes = false;
  late ScrollController _seasonListScrollController;
  late ScrollController _mainScrollController;
  bool _showSeasonScrollArrow = false;
  bool _isInLibrary = false;
  bool _isCheckingLibrary = true;
  Map<String, dynamic>? _tmdbMetadata; // Store raw TMDB metadata
  String? _maturityRating; // Store maturity rating for hero card
  String? _numberOfSeasons; // Store number of seasons for series

  @override
  void initState() {
    super.initState();
    final database = DatabaseProvider.instance;
    _libraryRepository = LibraryRepository(database);
    _streamService = StreamService(database);
    _seasonListScrollController = ScrollController();
    _seasonListScrollController.addListener(_checkSeasonScroll);
    _mainScrollController = ScrollController();
    _enrichItem();
    _loadCastAndCrew();
    _checkLibraryStatus();
  }

  Future<void> _checkLibraryStatus() async {
    try {
      final isInLib = await ServiceLocator.instance.libraryService.isInLibrary(widget.item.id);
      if (mounted) {
        setState(() {
          _isInLibrary = isInLib;
          _isCheckingLibrary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingLibrary = false;
        });
      }
    }
  }

  Future<void> _toggleLibrary() async {
    final item = _enrichedItem ?? widget.item;
    try {
      final success = await ServiceLocator.instance.libraryService.toggleLibraryStatus(item);
      if (success && mounted) {
        setState(() {
          _isInLibrary = !_isInLibrary;
        });
      }
    } catch (e) {
      debugPrint('Error toggling library status: $e');
    }
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

  Future<void> _enrichItem() async {
    try {
      // Fetch TMDB metadata first and store it for reuse
      final tmdbId = IdParser.extractTmdbId(widget.item.id);
      int? finalTmdbId = tmdbId;
      
      if (finalTmdbId == null && IdParser.isImdbId(widget.item.id)) {
        finalTmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(widget.item.id);
      }
      
      Map<String, dynamic>? tmdbData;
      if (finalTmdbId != null) {
        if (widget.item.type == 'movie') {
          final metadata = await ServiceLocator.instance.tmdbMetadataService.getMovieMetadata(finalTmdbId);
          tmdbData = metadata?.toJson();
        } else if (widget.item.type == 'series') {
          final metadata = await ServiceLocator.instance.tmdbMetadataService.getTvMetadata(finalTmdbId);
          tmdbData = metadata?.toJson();
        }
      }
      
      // Store raw TMDB metadata for reuse in _loadCastAndCrew
      if (tmdbData != null && mounted) {
        setState(() {
          _tmdbMetadata = tmdbData;
        });
      }
      
      // Use cached data for enrichment
      final enriched = await _libraryRepository.enrichItemForHero(
        widget.item,
        cachedTmdbData: tmdbData,
      );
      
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

  Future<void> _handlePlayButton() async {
    final item = _enrichedItem ?? widget.item;
    
    if (kDebugMode) {
      debugPrint('Play button clicked for: ${item.name} (${item.id}, type: ${item.type})');
    }
    
    // For series, we need an episode ID
    String? episodeId;
    Episode? firstEpisode;
    int? firstSeasonNumber;
    if (item.type == 'series') {
      // Load seasons and episodes if not already loaded
      if (_seasons.isEmpty) {
        await _loadSeasonsAndEpisodes(item);
      }
      
      // Get the first episode from season 1
      if (_seasons.isNotEmpty) {
        final firstSeason = _seasons.firstWhere(
          (s) => s.seasonNumber == 1,
          orElse: () => _seasons.first,
        );
        
        if (firstSeason.episodes.isNotEmpty) {
          firstEpisode = firstSeason.episodes.first;
          firstSeasonNumber = firstSeason.seasonNumber;
          // Format episode ID as {showId}:{season}:{episode}
          // First, get the IMDB ID for the show
          final imdbId = await _getImdbIdForItem(item);
          if (imdbId != null) {
            episodeId = '$imdbId:${firstSeason.seasonNumber}:${firstEpisode.episodeNumber}';
            if (kDebugMode) {
              debugPrint('Using episode ID for series: $episodeId (Season ${firstSeason.seasonNumber}, Episode ${firstEpisode.episodeNumber})');
            }
          } else {
            if (kDebugMode) {
              debugPrint('Could not get IMDB ID for series, cannot generate episode ID');
            }
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cannot Play Series'),
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
        } else {
          if (kDebugMode) {
            debugPrint('No episodes found in first season');
          }
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('No Episodes Available'),
                content: const Text('No episodes were found for this series.'),
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
      } else {
        if (kDebugMode) {
          debugPrint('No seasons found for series');
        }
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No Seasons Available'),
              content: const Text('No seasons were found for this series.'),
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
    }
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Fetch streams from all enabled addons
      if (kDebugMode) {
        debugPrint('Fetching streams from addons...');
      }
      
      final streams = await _streamService.getStreamsForItem(item, episodeId: episodeId, cachedTmdbData: _tmdbMetadata);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (kDebugMode) {
        debugPrint('Found ${streams.length} stream(s)');
      }
      
      if (streams.isEmpty) {
        if (kDebugMode) {
          debugPrint('No streams available for ${item.name}');
        }
        // Show message that no streams are available
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No Streams Available'),
              content: const Text('No streams were found for this content. Please try enabling more addons.'),
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
            title: item.type == 'series' && episodeId != null
                ? '${item.name} - S${episodeId.split(':')[1]}E${episodeId.split(':')[2]}'
                : item.name,
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
            // Extract IDs for progress tracking
            final tmdbId = IdParser.extractTmdbId(item.id)?.toString();
            final imdbId = IdParser.isImdbId(item.id) ? item.id : null;
            
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  streamUrl: selectedStream.url,
                  title: item.type == 'series' && episodeId != null
                      ? '${item.name} - S${episodeId.split(':')[1]}E${episodeId.split(':')[2]}'
                      : item.name,
                  subtitles: selectedStream.subtitles?.map((s) => s.url).toList(),
                  logoUrl: item.logo,
                  description: item.type == 'series' && firstEpisode != null
                      ? (firstEpisode.overview ?? item.description)
                      : item.description,
                  episodeName: item.type == 'series' ? firstEpisode?.name : null,
                  seasonNumber: item.type == 'series' ? firstSeasonNumber : null,
                  episodeNumber: item.type == 'series' ? firstEpisode?.episodeNumber : null,
                  isMovie: item.type == 'movie',
                  contentId: item.id,
                  imdbId: imdbId,
                  tmdbId: tmdbId,
                  runtime: item.runtime != null 
                      ? _parseRuntimeToSeconds(item.runtime!)
                      : null,
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
        debugPrint('Error loading streams for ${item.name}: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load streams: $e'),
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

  /// Helper method to get IMDB ID for an item (similar to StreamService._getImdbId)
  Future<String?> _getImdbIdForItem(CatalogItem item) async {
    // If already an IMDB ID, use it directly
    if (IdParser.isImdbId(item.id)) {
      if (kDebugMode) {
        debugPrint('CatalogItemDetailScreen: Item already has IMDB ID: ${item.id}');
      }
      return item.id;
    }

    // Try to extract TMDB ID
    final tmdbId = IdParser.extractTmdbId(item.id);
    if (tmdbId == null) {
      if (kDebugMode) {
        debugPrint('CatalogItemDetailScreen: Could not extract TMDB ID from ${item.id}');
      }
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
        if (kDebugMode) {
          debugPrint('CatalogItemDetailScreen: Extracted IMDB ID from TMDB: $imdbId');
        }
        return imdbId;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CatalogItemDetailScreen: Error fetching IMDB ID from TMDB: $e');
      }
    }

    return null;
  }

  /// Handle playing a specific episode
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
          builder: (context) => AlertDialog(
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
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Fetch streams from all enabled addons
      if (kDebugMode) {
        debugPrint('Fetching streams for episode...');
      }
      
      final streams = await _streamService.getStreamsForItem(seriesItem, episodeId: episodeId);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (kDebugMode) {
        debugPrint('Found ${streams.length} stream(s) for episode');
      }
      
      if (streams.isEmpty) {
        if (kDebugMode) {
          debugPrint('No streams available for episode');
        }
        // Show message that no streams are available
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No Streams Available'),
              content: const Text('No streams were found for this episode. Please try enabling more addons.'),
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
            // Extract IDs for progress tracking
            final tmdbId = IdParser.extractTmdbId(seriesItem.id)?.toString();
            final imdbId = IdParser.isImdbId(seriesItem.id) ? seriesItem.id : null;
            
            Navigator.of(context).push(
              MaterialPageRoute(
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
                  contentId: seriesItem.id,
                  imdbId: imdbId,
                  tmdbId: tmdbId,
                  runtime: episode.runtime != null 
                      ? episode.runtime! * 60 // Convert minutes to seconds
                      : null,
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
        debugPrint('Error loading streams for episode: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load streams: $e'),
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

  Future<void> _loadCastAndCrew() async {
    // Wait a bit for enrichment to complete
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoadingCastCrew = true;
    });

    try {
      final item = _enrichedItem ?? widget.item;
      
      // Reuse stored TMDB metadata if available, otherwise fetch it
      Map<String, dynamic>? tmdbData = _tmdbMetadata;
      
      if (tmdbData == null) {
        final tmdbId = IdParser.extractTmdbId(item.id);
        int? finalTmdbId = tmdbId;
        
        if (finalTmdbId == null && IdParser.isImdbId(item.id)) {
          finalTmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(item.id);
        }

        // Fetch full TMDB metadata to get budget, release_date, runtime, spoken_languages
        if (finalTmdbId != null) {
          if (item.type == 'movie') {
            final metadata = await ServiceLocator.instance.tmdbMetadataService.getMovieMetadata(finalTmdbId);
            tmdbData = metadata?.toJson();
          } else if (item.type == 'series') {
            final metadata = await ServiceLocator.instance.tmdbMetadataService.getTvMetadata(finalTmdbId);
            tmdbData = metadata?.toJson();
          }
        }
      }
      
      // Store raw TMDB metadata for details tab
      if (tmdbData != null && mounted) {
        // Use centralized extractor for maturity rating
        final rating = TmdbDataExtractor.extractMaturityRating(tmdbData, item.type);
        
        // Extract number of seasons for series
        String? numSeasons;
        if (item.type == 'series') {
          final additionalMetadata = TmdbDataExtractor.extractAdditionalMetadata(tmdbData, item.type);
          final seasons = additionalMetadata['numberOfSeasons'] as int?;
          if (seasons != null && seasons > 0) {
            numSeasons = '$seasons Season${seasons > 1 ? 's' : ''}';
          }
        }
        
        setState(() {
          _tmdbMetadata = tmdbData;
          _maturityRating = rating;
          _numberOfSeasons = numSeasons;
        });
      }
      
      // Use centralized extractor for cast and crew
      if (tmdbData != null && mounted) {
        final castAndCrew = TmdbDataExtractor.extractCastAndCrew(tmdbData);
        
        setState(() {
          _cast = castAndCrew['cast']!;
          _crew = castAndCrew['crew']!;
          _isLoadingCastCrew = false;
        });
        return;
      }
      
      // Fallback to repository method if tmdbData is null
      final castCrewData = await _libraryRepository.getCastAndCrewForItem(
        item,
        cachedTmdbData: tmdbData,
      );

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

  /// Parse runtime string (e.g., "120 min") to seconds
  int? _parseRuntimeToSeconds(String runtime) {
    try {
      // Try to extract number from strings like "120 min", "2h 30m", etc.
      final match = RegExp(r'(\d+)').firstMatch(runtime);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        return minutes * 60; // Convert to seconds
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final item = _enrichedItem ?? widget.item;

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
                          ],
                        ),
                      ),

                    // Extended bottom gradient positioned outside backdrop (85% height for 5% buffer)
                    if (item.background != null)
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
                                    style: TextStyle(
                                      fontSize: 60,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            Text(
                              item.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Metadata
                          Wrap(
                            spacing: 16,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Date (first date only)
                              if (item.releaseInfo != null)
                                Text(
                                  _extractFirstDate(item.releaseInfo!),
                                  style: const TextStyle(fontSize: 18),
                                ),

                              // Seasons (for series)
                              if (item.type == 'series' && _numberOfSeasons != null)
                                Text(
                                  _numberOfSeasons!,
                                  style: const TextStyle(fontSize: 18),
                                ),

                              // Rating badge (maturity)
                              if (_maturityRating != null)
                                _buildMaturityRating(_maturityRating, showDescription: false),

                              // Genres
                              if (item.genres != null && item.genres!.isNotEmpty)
                                ...item.genres!.take(2).map((genre) => Container(
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
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    )),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Rating icons row
                          _buildRatingIconsRow(),

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
                                onPressed: () => _handlePlayButton(),
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
                                onPressed: _isCheckingLibrary ? null : _toggleLibrary,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isInLibrary ? Icons.check : Icons.add,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isInLibrary ? 'In Library' : 'My List',
                                      style: const TextStyle(fontSize: 16),
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
    return _buildDetailsContent(item);
  }

  Widget _buildDetailsContent(CatalogItem item) {
    final itemToUse = _enrichedItem ?? item;
    
    // Extract data from TMDB metadata
    String? releaseYear;
    String? language;
    String? budget;
    String? runtimeFormatted;
    String? maturityRating;
    String? maturityRatingDescription;
    
    if (_tmdbMetadata != null) {
      // Extract release year from release_date
      final releaseDate = _tmdbMetadata!['release_date'] as String? ?? 
                         _tmdbMetadata!['first_air_date'] as String?;
      if (releaseDate != null && releaseDate.isNotEmpty) {
        final yearMatch = RegExp(r'^\d{4}').firstMatch(releaseDate);
        if (yearMatch != null) {
          releaseYear = yearMatch.group(0);
        }
      }
      
      // Extract language
      final spokenLanguages = _tmdbMetadata!['spoken_languages'] as List<dynamic>?;
      final originalLanguageData = _tmdbMetadata!['original_language'] as String?;
      final languages = <String>{};
      
      String? originalLanguageName;
      
      // Find the full name of the original language from spoken_languages
      if (originalLanguageData != null && spokenLanguages != null) {
        final matching = spokenLanguages.where(
          (lang) => (lang['iso_639_1'] as String?) == originalLanguageData,
        );
        final originalLangInfo = matching.isEmpty ? null : matching.first as Map<String, dynamic>?;
        if (originalLangInfo != null) {
          originalLanguageName = originalLangInfo['english_name'] as String?;
        }
      }
      
      // Fallback to original language code if full name not found
      if (originalLanguageName == null && originalLanguageData != null && originalLanguageData.isNotEmpty) {
        originalLanguageName = originalLanguageData.toUpperCase();
      }
      
      // Add original language if available
      if (originalLanguageName != null && originalLanguageName.isNotEmpty) {
        languages.add(originalLanguageName);
      }
      
      // Add English if available and different from original
      if (spokenLanguages != null) {
        final matching = spokenLanguages.where(
          (lang) => (lang['english_name'] as String?)?.toLowerCase() == 'english',
        );
        final english = matching.isEmpty ? null : matching.first as Map<String, dynamic>?;
        
        if (english != null) {
          final englishName = english['english_name'] as String?;
          if (englishName != null && englishName.isNotEmpty && englishName.toLowerCase() != originalLanguageName?.toLowerCase()) {
            languages.add(englishName);
          }
        }
      }
      
      if (languages.isNotEmpty) {
        language = languages.join(', ');
      }
      
      // Extract and format budget
      final budgetValue = _tmdbMetadata!['budget'] as int?;
      if (budgetValue != null && budgetValue > 0) {
        if (budgetValue >= 1000000) {
          final millions = budgetValue / 1000000;
          budget = '\$${millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1)} million';
        } else if (budgetValue >= 1000) {
          final thousands = budgetValue / 1000;
          budget = '\$${thousands.toStringAsFixed(thousands.truncateToDouble() == thousands ? 0 : 1)} thousand';
        } else {
          budget = '\$$budgetValue';
        }
      }
      
      // Extract and format runtime
      final runtimeValue = _tmdbMetadata!['runtime'] as int?;
      if (runtimeValue != null && runtimeValue > 0) {
        runtimeFormatted = '$runtimeValue min';
      }
      
      // Use stored maturity rating (already extracted in _loadCastAndCrew)
      maturityRating = _maturityRating;
    }
    
    // Fallback to releaseInfo if TMDB data not available
    if (releaseYear == null && itemToUse.releaseInfo != null && itemToUse.releaseInfo!.isNotEmpty) {
      final yearMatch = RegExp(r'\b(19|20)\d{2}\b').firstMatch(itemToUse.releaseInfo!);
      if (yearMatch != null) {
        releaseYear = yearMatch.group(0);
      }
    }
    
    // Fallback to runtime from CatalogItem if TMDB data not available
    if (runtimeFormatted == null && itemToUse.runtime != null && itemToUse.runtime!.isNotEmpty) {
      final runtimeInt = int.tryParse(itemToUse.runtime!);
      if (runtimeInt != null) {
        runtimeFormatted = '$runtimeInt min';
      } else {
        runtimeFormatted = itemToUse.runtime;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.muted, // Same as TV-14/HD button
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First column: About (50% width)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About ${itemToUse.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (itemToUse.description != null && itemToUse.description!.isNotEmpty)
                  Text(
                    itemToUse.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.mutedForeground,
                      height: 1.5,
                    ),
                  )
                else
                  Text(
                    'No description available.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Second column: Metadata (25% width)
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_crew.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final creators = _crew
                          .where((c) => c.character?.toLowerCase() == 'creator' || 
                                       c.character?.toLowerCase() == 'executive producer')
                          .map((c) => c.name)
                          .take(3)
                          .toList();
                      if (creators.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetadataRow(
                            'CREATED BY',
                            creators.join(', '),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ],
                if (_cast.isNotEmpty) ...[
                  _buildMetadataRow(
                    'CAST',
                    _cast
                        .take(6)
                        .map((c) => c.name)
                        .join(', '),
                  ),
                  const SizedBox(height: 16),
                ],
                if (releaseYear != null) ...[
                  _buildMetadataRow('RELEASE YEAR', releaseYear),
                  const SizedBox(height: 16),
                ],
                if (language != null && language.isNotEmpty) ...[
                  _buildMetadataRow('LANGUAGE', language),
                ],
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Third column: Metadata (25% width)
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (itemToUse.genres != null && itemToUse.genres!.isNotEmpty) ...[
                  _buildMetadataRow(
                    'GENRES',
                    itemToUse.genres!.join(', '),
                  ),
                  const SizedBox(height: 16),
                ],
                if (budget != null && budget.isNotEmpty) ...[
                  _buildMetadataRow('BUDGET', budget),
                  const SizedBox(height: 16),
                ],
                if (runtimeFormatted != null) ...[
                  _buildMetadataRow('RUNTIME', runtimeFormatted),
                  const SizedBox(height: 16),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MATURITY RATING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.mutedForeground,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMaturityRating(_maturityRating),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.foreground,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildMaturityRating(String? rating, {bool showDescription = true}) {
    final hasRating = rating != null && rating.isNotEmpty && rating != 'N/A';
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            border: Border.all(
              color: Theme.of(context).colorScheme.border,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            rating ?? 'N/A',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        if (hasRating && showDescription) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Language, Suggestive Dialogue',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
            ),
          ),
        ],
      ],
    );
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

  /// Format episode air date for display
  String _formatEpisodeDate(String airDate) {
    // TMDB dates are typically in YYYY-MM-DD format, return as is
    // If we need to format differently, parse and reformat here
    return airDate;
  }

  /// Build a row of rating icons (TMDB, IMDb, Rotten Tomatoes, Metacritic)
  Widget _buildRatingIconsRow() {
    // For development phase, use placeholder values (99)
    // In production, these would come from the item or TMDB metadata
    // Only show if rating is present (for production), but for dev we'll always show with 99
    String? tmdbRating;
    if (_tmdbMetadata?['vote_average'] != null) {
      tmdbRating = (_tmdbMetadata!['vote_average'] as num).toStringAsFixed(1);
    } else {
      tmdbRating = '99'; // Placeholder for development
    }
    
    String? imdbRating = widget.item.imdbRating ?? '99'; // Placeholder for development
    String? rottenTomatoesRating = '99'; // Placeholder for development
    String? metacriticRating = '99'; // Placeholder for development

    final ratings = <Map<String, dynamic>>[];
    
    if (tmdbRating != null) {
      ratings.add({
        'icon': Icons.movie,
        'label': 'TMDB',
        'rating': tmdbRating,
        'color': Colors.blue,
      });
    }
    
    if (imdbRating != null) {
      ratings.add({
        'icon': Icons.star,
        'label': 'IMDb',
        'rating': imdbRating,
        'color': Colors.amber,
      });
    }
    
    if (rottenTomatoesRating != null) {
      ratings.add({
        'icon': Icons.local_movies,
        'label': 'RT',
        'rating': rottenTomatoesRating,
        'color': Colors.red,
      });
    }
    
    if (metacriticRating != null) {
      ratings.add({
        'icon': Icons.rate_review,
        'label': 'MC',
        'rating': metacriticRating,
        'color': Colors.green,
      });
    }

    if (ratings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: ratings.asMap().entries.map((entry) {
        final index = entry.key;
        final rating = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRatingIcon(
              icon: rating['icon'] as IconData,
              label: rating['label'] as String,
              rating: rating['rating'] as String,
              color: rating['color'] as Color,
            ),
            if (index < ratings.length - 1) const SizedBox(width: 16),
          ],
        );
      }).toList(),
    );
  }

  /// Build a single rating icon widget
  Widget _buildRatingIcon({
    required IconData icon,
    required String label,
    required String rating,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 22,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $rating',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.foreground,
          ),
        ),
      ],
    );
  }

  Future<void> _loadSeasonsAndEpisodes(CatalogItem item) async {
    if (_isLoadingEpisodes || _seasons.isNotEmpty) return;

    setState(() {
      _isLoadingEpisodes = true;
    });

    try {
      final tmdbId = IdParser.extractTmdbId(item.id);
      int? finalTmdbId = tmdbId;

      if (finalTmdbId == null && IdParser.isImdbId(item.id)) {
        finalTmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(item.id);
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
            if (_seasons.isNotEmpty) {
              _selectedSeasonNumber = _seasons.first.seasonNumber;
            }
            _isLoadingEpisodes = false;
          });
          // Check scroll state after a frame to ensure layout is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _seasonListScrollController.hasClients) {
              _checkSeasonScroll();
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

  Future<void> _loadSimilarItems(CatalogItem item) async {
    if (_isLoadingSimilar || _similarItems.isNotEmpty || _hasAttemptedLoadSimilar) return;

    // Set flag immediately to prevent multiple calls during rebuilds
    _hasAttemptedLoadSimilar = true;
    
    setState(() {
      _isLoadingSimilar = true;
    });

    try {
      final tmdbId = IdParser.extractTmdbId(item.id);
      int? finalTmdbId = tmdbId;

      if (finalTmdbId == null && IdParser.isImdbId(item.id)) {
        finalTmdbId = await ServiceLocator.instance.tmdbMetadataService.getTmdbIdFromImdb(item.id);
      }

      if (finalTmdbId != null) {
        final similarResults =
            await ServiceLocator.instance.tmdbSearchService.getSimilar(finalTmdbId, item.type == 'series' ? 'tv' : 'movie');
        if (mounted) {
          final enrichmentService = ServiceLocator.instance.tmdbEnrichmentService;
          final filteredItems = <CatalogItem>[];
          
          for (final result in similarResults) {
            try {
              // Apply same filtering as search results
              final name = item.type == 'movie' ? (result.title ?? '') : (result.name ?? '');
              final poster = enrichmentService.getImageUrl(result.posterPath);
              final background = enrichmentService.getImageUrl(result.backdropPath, size: 'w1280');
              final releaseDate = item.type == 'movie' ? result.releaseDate : result.firstAirDate;
              final voteAverage = result.voteAverage;
              
              // Skip if missing essential metadata or no poster + no voteAverage
              if (name.isEmpty || 
                  (poster.isEmpty && voteAverage == 0.0) ||
                  releaseDate == null || releaseDate.isEmpty) {
                continue;
              }
              
              final tmdbIdStr = 'tmdb:${result.id}';
              filteredItems.add(CatalogItem.fromJson({
                'id': tmdbIdStr,
                'type': item.type,
                'name': name,
                'poster': poster,
                'background': background,
                'description': result.overview,
                'releaseInfo': releaseDate,
                'imdbRating': voteAverage.toString(),
                'voteCount': result.voteCount,
              }));
            } catch (e) {
              // Skip invalid items
              continue;
            }
          }
          
          // Sort by vote count (highest first), then by rating, then by name
          filteredItems.sort((a, b) {
            final voteCountA = a.voteCount ?? 0;
            final voteCountB = b.voteCount ?? 0;
            
            if (voteCountB != voteCountA) {
              return voteCountB.compareTo(voteCountA);
            }
            
            final ratingA = double.tryParse(a.imdbRating ?? '0') ?? 0.0;
            final ratingB = double.tryParse(b.imdbRating ?? '0') ?? 0.0;
            
            if (ratingB != ratingA) {
              return ratingB.compareTo(ratingA);
            }
            return a.name.compareTo(b.name);
          });
          
          setState(() {
            _similarItems = filteredItems;
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
    // Load similar items when this tab is selected (only if we haven't attempted yet)
    if (!_isLoadingSimilar && _similarItems.isEmpty && !_hasAttemptedLoadSimilar) {
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
              const SizedBox(height: 16),
              Text(
                'No similar ${item.type == 'series' ? 'shows' : 'movies'} found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.mutedForeground,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 32,
            childAspectRatio: aspectRatio,
          ),
          itemCount: _similarItems.length,
          itemBuilder: (context, index) {
            final similarItem = _similarItems[index];
            return _SimilarItemCard(item: similarItem, cardWidth: actualCardWidth);
          },
        );
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
        // Image is circular with diameter = cardWidth * 0.8, text ~42px, spacing 10px
        final imageHeight = actualCardWidth * 0.8; // Circular image diameter
        final totalHeight = imageHeight + 10 + 42; // image + spacing + text
        final aspectRatio = actualCardWidth / totalHeight;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 32,
            childAspectRatio: aspectRatio,
          ),
          itemCount: displayMembers.length,
          itemBuilder: (context, index) {
            final member = displayMembers[index];
            return _CastCrewCard(member: member, cardWidth: actualCardWidth);
          },
        );
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
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
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
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.foreground,
                                      fontWeight:
                                          isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: Theme.of(context).colorScheme.primary,
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
                              Icons.keyboard_arrow_down,
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
                        seriesItem: item,
                        seasonNumber: selectedSeason.seasonNumber,
                        onPlay: () => _handleEpisodePlay(item, selectedSeason.seasonNumber, episode),
                        onNavigate: () {
                          Navigator.of(context).push(
                            material.MaterialPageRoute(
                              builder: (context) => EpisodeDetailScreen(
                                seriesItem: item,
                                episode: episode,
                                seasonNumber: selectedSeason.seasonNumber,
                              ),
                            ),
                          );
                        },
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
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              height: 2,
              width: label.length * 10.0,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

class _CastCrewCard extends StatefulWidget {
  final CastCrewMember member;
  final double cardWidth;

  const _CastCrewCard({
    required this.member,
    required this.cardWidth,
  });

  @override
  State<_CastCrewCard> createState() => _CastCrewCardState();
}

class _CastCrewCardState extends State<_CastCrewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = widget.member.profileImageUrl != null
        ? ServiceLocator.instance.tmdbEnrichmentService.getImageUrl(widget.member.profileImageUrl, size: 'w185')
        : null;

    // Calculate image size as 80% of card width for circular image
    final imageSize = widget.cardWidth * 0.8;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        width: widget.cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular profile image with hover animation
            ClipOval(
              child: AnimatedScale(
                scale: _isHovered ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: profileImageUrl != null
                    ? Image.network(
                        profileImageUrl,
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: imageSize,
                            height: imageSize,
                            color: Theme.of(context).colorScheme.muted,
                            child: Icon(
                              Icons.person,
                              size: imageSize * 0.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .foreground
                                  .withOpacity(0.5),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: imageSize,
                            height: imageSize,
                            color: Theme.of(context).colorScheme.muted,
                            child: const Center(
                              child: material.CircularProgressIndicator(),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: imageSize,
                        height: imageSize,
                        color: Theme.of(context).colorScheme.muted,
                        child: Icon(
                          Icons.person,
                          size: imageSize * 0.5,
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
            SizedBox(
              width: widget.cardWidth,
              child: Text(
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
            ),
            if (widget.member.character != null) ...[
              const SizedBox(height: 4),
              // Character/Role
              SizedBox(
                width: widget.cardWidth,
                child: Text(
                  widget.member.character!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .foreground
                        .withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SimilarItemCard extends StatefulWidget {
  final CatalogItem item;
  final double cardWidth;

  const _SimilarItemCard({required this.item, required this.cardWidth});

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
                                    child: material.CircularProgressIndicator()),
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

  @override
  void didUpdateWidget(_EpisodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episode.episodeNumber != widget.episode.episodeNumber ||
        oldWidget.seasonNumber != widget.seasonNumber ||
        oldWidget.seriesItem.id != widget.seriesItem.id) {
      _checkWatchedStatus();
    }
  }

  Future<void> _checkWatchedStatus() async {
    if (kDebugMode) {
      debugPrint('_EpisodeCard: Checking watched status for episode');
      debugPrint('  Series ID: ${widget.seriesItem.id}');
      debugPrint('  Season: ${widget.seasonNumber}');
      debugPrint('  Episode: ${widget.episode.episodeNumber}');
    }
    
    final tmdbId = IdParser.extractTmdbId(widget.seriesItem.id);
    if (kDebugMode) {
      debugPrint('  Extracted TMDB ID: $tmdbId');
    }
    
    if (tmdbId != null) {
      final tmdbIdStr = tmdbId.toString();
      if (kDebugMode) {
        debugPrint('  Querying database for: tmdbId=$tmdbIdStr, season=${widget.seasonNumber}, episode=${widget.episode.episodeNumber}');
      }
      
      final isWatched = await _database.isEpisodeWatched(
        tmdbIdStr,
        widget.seasonNumber,
        widget.episode.episodeNumber,
      );
      
      if (kDebugMode) {
        debugPrint('  Is watched: $isWatched');
      }
      
      if (mounted) {
        setState(() {
          _isWatched = isWatched;
        });
        if (kDebugMode) {
          debugPrint('  State updated: _isWatched = $_isWatched');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('  No TMDB ID found, cannot check watched status');
      }
    }
  }

  /// Format episode air date for display
  String _formatEpisodeDate(String airDate) {
    // TMDB dates are typically in YYYY-MM-DD format, return as is
    // If we need to format differently, parse and reformat here
    return airDate;
  }

  /// Check if episode is not released yet
  bool _isEpisodeNotReleased() {
    if (widget.episode.airDate == null || widget.episode.airDate!.isEmpty) {
      return true;
    }
    try {
      final airDate = DateTime.parse(widget.episode.airDate!);
      return airDate.isAfter(DateTime.now());
    } catch (e) {
      // If parsing fails, assume it's not released
      return true;
    }
  }

  /// Get episode description, or "To be announced" if not released and description is empty
  String _getEpisodeDescription() {
    final hasDescription = widget.episode.overview != null && 
                          widget.episode.overview!.isNotEmpty;
    
    if (hasDescription) {
      return widget.episode.overview!;
    }
    
    // If no description and episode is not released, show "To be announced"
    if (_isEpisodeNotReleased()) {
      return 'To be announced';
    }
    
    // If no description but episode is released, return empty string
    return '';
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
              onPressed: widget.onNavigate,
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
                                    color: Colors.black.withOpacity(0.4),
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
                                    color: Colors.black.withOpacity(0.4),
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
                                    color: Colors.black.withOpacity(0.4),
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
                        // Play button that captures clicks
                        if (_isHovered)
                          Center(
                            child: AbsorbPointer(
                              absorbing: false,
                              child: Clickable(
                                onPressed: widget.onPlay,
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
                    // Title and description with background
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
                                _getEpisodeDescription(),
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