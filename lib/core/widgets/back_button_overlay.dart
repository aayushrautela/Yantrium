import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter/material.dart' as material;

/// Standardized back button overlay for detail screens
/// Positioned in the top left corner as an overlay
class BackButtonOverlay extends StatelessWidget {
  final VoidCallback? onBack;
  final EdgeInsets? padding;

  const BackButtonOverlay({
    super.key,
    this.onBack,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final callback = onBack ?? () {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    };
    
    return Positioned(
      top: padding?.top ?? 24,
      left: padding?.left ?? 24,
      child: material.Material(
        color: Colors.transparent,
        child: material.InkWell(
          onTap: callback,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: material.Colors.black.withOpacity(0.5),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
