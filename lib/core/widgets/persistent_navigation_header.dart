import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../core/constants/app_constants.dart';

/// Persistent navigation header used across all screens
class PersistentNavigationHeader extends StatelessWidget {
  final int? currentIndex;
  final ValueChanged<int>? onNavigate;
  final bool showBackButton;
  final VoidCallback? onBack;

  const PersistentNavigationHeader({
    super.key,
    this.currentIndex,
    this.onNavigate,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppConstants.horizontalPadding.copyWith(
        top: 16,
        bottom: 16,
      ),
      child: Row(
        children: [
          // Back button (if on detail screen)
          if (showBackButton && onBack != null) ...[
            GhostButton(
              onPressed: onBack,
              density: ButtonDensity.icon,
              child: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 16),
          ],
          
          // Logo
          Text('YANTRIUM').h3().primaryForeground,
          const SizedBox(width: 32),
          
          // Navigation Links (only show if not on detail screen)
          if (currentIndex != null && onNavigate != null) ...[
            _NavLink(
              label: 'Home',
              isActive: currentIndex == 0,
              onPressed: () => onNavigate!(0),
            ),
            const SizedBox(width: 24),
            _NavLink(
              label: 'Library',
              isActive: currentIndex == 1,
              onPressed: () => onNavigate!(1),
            ),
            const SizedBox(width: 24),
            _NavLink(
              label: 'Settings',
              isActive: currentIndex == 2,
              onPressed: () => onNavigate!(2),
            ),
          ],
          
          const Spacer(),
          
          // Search
          SizedBox(
            width: 300,
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: Theme.of(context).colorScheme.mutedForeground,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    placeholder: const Text('Search titles, people, genres'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // Notifications
          GhostButton(
            density: ButtonDensity.icon,
            child: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: 8),
          
          // Profile
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.muted,
            ),
          ),
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
          color: isActive
              ? Theme.of(context).colorScheme.foreground
              : Theme.of(context).colorScheme.mutedForeground,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

