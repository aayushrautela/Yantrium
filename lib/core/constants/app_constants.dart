import 'package:flutter/material.dart';

/// App-wide constants for consistent spacing and layout
class AppConstants {
  AppConstants._();

  /// Horizontal margin for desktop app content
  /// Provides consistent left/right margins throughout the app
  static const double horizontalMargin = 120.0;

  /// Standard horizontal padding for content sections
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(
    horizontal: horizontalMargin,
  );

  /// Standard padding for content sections (includes horizontal margin)
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: horizontalMargin,
    vertical: 16.0,
  );

  /// Padding for section headers
  static const EdgeInsets sectionHeaderPadding = EdgeInsets.fromLTRB(
    horizontalMargin,
    16.0,
    horizontalMargin,
    8.0,
  );

  /// Padding for cards and containers
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  /// Standard spacing between sections
  static const double sectionSpacing = 24.0;

  /// Standard spacing between items
  static const double itemSpacing = 16.0;
}


