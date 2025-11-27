import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../database/database_provider.dart';

/// Service to manage theme and accent color
class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<String> _colorSchemeName = ValueNotifier<String>('blue');
  ValueNotifier<String> get colorSchemeName => _colorSchemeName;

  /// Map hex color values to shadcn color scheme names
  static const Map<String, String> _hexToSchemeName = {
    '#3b82f6': 'blue',      // Blue
    '#a855f7': 'violet',    // Purple
    '#ec4899': 'rose',      // Pink -> Rose
    '#ef4444': 'red',       // Red
    '#f97316': 'orange',    // Orange
    '#eab308': 'yellow',    // Yellow
    '#22c55e': 'green',     // Green
    '#14b8a6': 'green',     // Teal -> Green (closest match)
    '#06b6d4': 'blue',      // Cyan -> Blue (closest match)
    '#6366f1': 'violet',    // Indigo -> Violet (closest match)
    '#f43f5e': 'rose',      // Rose
    '#f59e0b': 'orange',    // Amber -> Orange (closest match)
  };

  /// Map color scheme names to hex values (for display)
  /// Only includes available color schemes
  static const Map<String, String> _schemeNameToHex = {
    'blue': '#3b82f6',
    'violet': '#a855f7',
    'rose': '#f43f5e',
    'red': '#ef4444',
    'orange': '#f97316',
    'yellow': '#eab308',
    'green': '#22c55e',
  };

  /// Get available color scheme names
  /// Only includes color schemes that are actually available in ColorSchemes
  static List<String> get availableColorSchemes => [
    'blue',
    'green',
    'orange',
    'red',
    'rose',
    'violet',
    'yellow',
  ];

  /// Initialize theme service by loading accent color from database
  Future<void> initialize() async {
    final database = DatabaseProvider.instance;
    final hexColor = await database.getSettingValue('accent_color');
    
    if (hexColor != null) {
      final schemeName = _hexToSchemeName[hexColor.toLowerCase()] ?? 'blue';
      _colorSchemeName.value = schemeName;
    } else {
      // Default to blue
      _colorSchemeName.value = 'blue';
    }
  }

  /// Get current color scheme name
  String get currentColorSchemeName => _colorSchemeName.value;

  /// Get hex color for a scheme name
  String? getHexForSchemeName(String schemeName) {
    return _schemeNameToHex[schemeName];
  }

  /// Get scheme name for a hex color
  String getSchemeNameForHex(String hexColor) {
    return _hexToSchemeName[hexColor.toLowerCase()] ?? 'blue';
  }

  /// Set accent color by hex value
  Future<void> setAccentColorByHex(String hexColor) async {
    final database = DatabaseProvider.instance;
    await database.setSetting('accent_color', hexColor);
    
    final schemeName = getSchemeNameForHex(hexColor);
    _colorSchemeName.value = schemeName;
  }

  /// Set accent color by scheme name
  Future<void> setAccentColorBySchemeName(String schemeName) async {
    final database = DatabaseProvider.instance;
    final hexColor = getHexForSchemeName(schemeName) ?? '#3b82f6';
    await database.setSetting('accent_color', hexColor);
    
    _colorSchemeName.value = schemeName;
  }

  /// Get color scheme for current accent color
  /// Maps color scheme names to ColorSchemes properties
  /// Only uses available color schemes, falls back to default for unavailable ones
  ColorScheme getColorScheme({Brightness brightness = Brightness.dark}) {
    final name = _colorSchemeName.value;
    
    if (brightness == Brightness.dark) {
      switch (name) {
        case 'blue':
          return ColorSchemes.darkBlue;
        case 'green':
          return ColorSchemes.darkGreen;
        case 'orange':
          return ColorSchemes.darkOrange;
        case 'red':
          return ColorSchemes.darkRed;
        case 'rose':
          return ColorSchemes.darkRose;
        case 'violet':
          return ColorSchemes.darkViolet;
        case 'yellow':
          return ColorSchemes.darkYellow;
        // Map unavailable schemes to closest available or default
        case 'gray':
        case 'neutral':
        case 'slate':
        case 'stone':
        case 'zinc':
        default:
          return ColorSchemes.darkDefaultColor;
      }
    } else {
      switch (name) {
        case 'blue':
          return ColorSchemes.lightBlue;
        case 'green':
          return ColorSchemes.lightGreen;
        case 'orange':
          return ColorSchemes.lightOrange;
        case 'red':
          return ColorSchemes.lightRed;
        case 'rose':
          return ColorSchemes.lightRose;
        case 'violet':
          return ColorSchemes.lightViolet;
        case 'yellow':
          return ColorSchemes.lightYellow;
        // Map unavailable schemes to closest available or default
        case 'gray':
        case 'neutral':
        case 'slate':
        case 'stone':
        case 'zinc':
        default:
          return ColorSchemes.lightDefaultColor;
      }
    }
  }

  void dispose() {
    _colorSchemeName.dispose();
  }
}





