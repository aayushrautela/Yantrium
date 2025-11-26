import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

enum ImagePriority { hero, visible, nearViewport, background }

class SmartImage extends StatefulWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final ImagePriority priority;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext)? placeholderBuilder;
  final Widget Function(BuildContext, String)? errorBuilder;

  const SmartImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.priority = ImagePriority.visible,
    this.borderRadius,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  State<SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends State<SmartImage> {
  bool _shouldLoad = false;
  final String _visibilityKey = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    // Immediate load for hero images
    if (widget.priority == ImagePriority.hero) {
      _shouldLoad = true;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: widget.borderRadius,
      ),
      child: widget.placeholderBuilder?.call(context) ?? const SizedBox.shrink(),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: widget.borderRadius,
      ),
      child: widget.errorBuilder?.call(context, widget.imageUrl ?? '') ??
             Center(child: Icon(Icons.image_not_supported)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    // Skip lazy loading for hero images
    if (widget.priority == ImagePriority.hero) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
      );
    }

    // Lazy load for other priorities
    return VisibilityDetector(
      key: Key(_visibilityKey),
      onVisibilityChanged: (visibilityInfo) {
        final visibleFraction = visibilityInfo.visibleFraction;
        if (visibleFraction > 0.1 && !_shouldLoad && mounted) {
          setState(() => _shouldLoad = true);
        }
      },
      child: _shouldLoad
          ? CachedNetworkImage(
              imageUrl: widget.imageUrl!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              placeholder: (context, url) => _buildPlaceholder(),
              errorWidget: (context, url, error) => _buildErrorWidget(),
            )
          : _buildPlaceholder(),
    );
  }
}