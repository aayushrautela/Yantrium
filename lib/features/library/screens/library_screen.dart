import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../../core/constants/app_constants.dart';

/// Library screen - placeholder for future features
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Center(
        child: Padding(
          padding: AppConstants.horizontalPadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.video_library_outlined,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text('Library').h3(),
              const SizedBox(height: 8),
              const Text('Your saved content will appear here').muted(),
            ],
          ),
        ),
      ),
    );
  }
}
