import 'package:flutter/material.dart';

/// Video player screen with MPV integration
/// This is a placeholder for future implementation
class VideoPlayerScreen extends StatelessWidget {
  final String streamUrl;
  final String? title;

  const VideoPlayerScreen({
    super.key,
    required this.streamUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Video Player'),
      ),
      body: const Center(
        child: Text('Video player will be implemented in a future stage'),
      ),
    );
  }
}


