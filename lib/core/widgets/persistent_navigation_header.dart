import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../constants/app_constants.dart';

/// Persistent navigation header used across all screens
class PersistentNavigationHeader extends StatefulWidget {
  final int? currentIndex;
  final ValueChanged<int>? onNavigate;
  final TextEditingController? searchController;

  const PersistentNavigationHeader({
    super.key,
    this.currentIndex,
    this.onNavigate,
    this.searchController,
  });

  @override
  State<PersistentNavigationHeader> createState() => _PersistentNavigationHeaderState();
}

class _PersistentNavigationHeaderState extends State<PersistentNavigationHeader> {
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    if (widget.searchController != null) {
      _hasSearchText = widget.searchController!.text.isNotEmpty;
      widget.searchController!.addListener(_onSearchChanged);
    }
  }

  @override
  void didUpdateWidget(PersistentNavigationHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController?.removeListener(_onSearchChanged);
      if (widget.searchController != null) {
        _hasSearchText = widget.searchController!.text.isNotEmpty;
        widget.searchController!.addListener(_onSearchChanged);
      } else {
        _hasSearchText = false;
      }
    }
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _hasSearchText = widget.searchController?.text.isNotEmpty ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double navbarHeight;
    double padding;
    
    if (screenWidth >= 3840) { // 4K and above
      navbarHeight = 100;
      padding = 28;
    } else if (screenWidth >= 2560) { // 1440p (2K)
      navbarHeight = 85;
      padding = 24;
    } else { // 1080p and below
      navbarHeight = 75;
      padding = 20;
    }
    
    return Container(
      height: navbarHeight,
      padding: EdgeInsets.only(
        left: 24,
        right: AppConstants.horizontalMargin,
        top: padding,
        bottom: padding,
      ),
      child: Row(
        children: [
          // Logo
          Text('YANTRIUM').h3().primaryForeground,
          const SizedBox(width: 32),
          
          // Navigation Links (only show if not on detail screen)
          if (widget.currentIndex != null && widget.onNavigate != null) ...[
            _NavLink(
              label: 'Home',
              isActive: widget.currentIndex == 0,
              onPressed: () => widget.onNavigate!(0),
            ),
            const SizedBox(width: 24),
            _NavLink(
              label: 'Library',
              isActive: widget.currentIndex == 1,
              onPressed: () => widget.onNavigate!(1),
            ),
            const SizedBox(width: 24),
            _NavLink(
              label: 'Settings',
              isActive: widget.currentIndex == 2,
              onPressed: () => widget.onNavigate!(2),
            ),
          ],
          
          const Spacer(),
          
          // Search
          SizedBox(
            width: 300,
            height: 40,
            child: widget.currentIndex != 2
                ? Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 20,
                        color: Theme.of(context).colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: widget.searchController != null
                            ? TextField(
                                key: const ValueKey('search_field'),
                                controller: widget.searchController,
                                placeholder: Text(
                                  widget.currentIndex == 1
                                      ? 'Search library'
                                      : 'Titles, people, genres',
                                ),
                              )
                            : TextField(
                                enabled: false,
                                placeholder: Text(
                                  widget.currentIndex == 1
                                      ? 'Search library'
                                      : 'Titles, people, genres',
                                ),
                              ),
                      ),
                      if (_hasSearchText && widget.searchController != null) ...[
                        const SizedBox(width: 8),
                        Clickable(
                          onPressed: () {
                            widget.searchController!.clear();
                            setState(() {
                              _hasSearchText = false;
                            });
                          },
                          child: Icon(
                            Icons.clear,
                            size: 20,
                            color: Theme.of(context).colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _NavLink({
    required this.label,
    this.isActive = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Clickable(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          color: isActive
              ? Theme.of(context).colorScheme.foreground
              : Theme.of(context).colorScheme.mutedForeground,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

