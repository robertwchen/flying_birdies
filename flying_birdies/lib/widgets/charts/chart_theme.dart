import 'package:flutter/material.dart';

/// Theme configuration for charts with dark/light mode support
///
/// Provides consistent colors, text styles, and gradients for all charts
/// matching the app's design language (purple #7E4AED to pink #FF6FD8).
class ChartTheme {
  final bool isDark;

  const ChartTheme({required this.isDark});

  // ============================================================================
  // COLORS
  // ============================================================================

  /// Primary line color - adapts to theme
  Color get lineColor =>
      isDark ? const Color(0xFFFF6FD8) : const Color(0xFF7E4AED);

  /// Fill color for area below line (15% opacity)
  Color get fillColor => lineColor.withValues(alpha: 0.15);

  /// Grid line color - subtle, doesn't overpower data
  Color get gridColor => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.05);

  /// Axis line color
  Color get axisColor => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);

  /// Label text color
  Color get labelColor => isDark ? Colors.white70 : Colors.black54;

  /// Tooltip background color
  Color get tooltipBg => isDark
      ? const Color(0xFF0F1525).withValues(alpha: 0.95)
      : const Color(0xFF111827).withValues(alpha: 0.95);

  /// Tooltip text color
  Color get tooltipText => Colors.white;

  /// Data point dot color (white fill)
  Color get dotFillColor => Colors.white;

  /// Data point dot stroke color (matches line)
  Color get dotStrokeColor => lineColor;

  // ============================================================================
  // TEXT STYLES
  // ============================================================================

  /// Text style for axis labels (e.g., "Swing 1", "200 km/h")
  TextStyle get axisLabelStyle => TextStyle(
        color: labelColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );

  /// Text style for tooltip content
  TextStyle get tooltipStyle => TextStyle(
        color: tooltipText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      );

  /// Text style for axis values (larger, bolder)
  TextStyle get axisValueStyle => TextStyle(
        color: labelColor,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      );

  // ============================================================================
  // GRADIENTS
  // ============================================================================

  /// Gradient for line (purple to pink)
  LinearGradient get lineGradient => const LinearGradient(
        colors: [Color(0xFFFF6FD8), Color(0xFF7E4AED)],
      );

  /// Gradient for area fill below line (fades to transparent)
  LinearGradient get fillGradient => LinearGradient(
        colors: [
          const Color(0xFFFF6FD8).withValues(alpha: 0.15),
          const Color(0xFF7E4AED).withValues(alpha: 0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  // ============================================================================
  // DIMENSIONS
  // ============================================================================

  /// Standard line width for charts
  double get lineWidth => 3.0;

  /// Data point dot radius
  double get dotRadius => 4.0;

  /// Data point dot stroke width
  double get dotStrokeWidth => 2.0;

  /// Grid line stroke width
  double get gridLineWidth => 1.0;

  /// Axis line stroke width
  double get axisLineWidth => 1.0;

  /// Tooltip border radius
  double get tooltipBorderRadius => 8.0;

  /// Tooltip padding (horizontal)
  double get tooltipPaddingHorizontal => 12.0;

  /// Tooltip padding (vertical)
  double get tooltipPaddingVertical => 8.0;

  // ============================================================================
  // OPACITY VALUES
  // ============================================================================

  /// Fill opacity for area below line
  double get fillOpacity => 0.15;

  /// Grid line opacity
  double get gridOpacity => isDark ? 0.08 : 0.05;

  /// Axis line opacity
  double get axisOpacity => 0.1;

  // ============================================================================
  // FACTORY CONSTRUCTORS
  // ============================================================================

  /// Create theme from BuildContext (detects dark mode automatically)
  factory ChartTheme.fromContext(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ChartTheme(isDark: brightness == Brightness.dark);
  }

  /// Create light theme
  factory ChartTheme.light() => const ChartTheme(isDark: false);

  /// Create dark theme
  factory ChartTheme.dark() => const ChartTheme(isDark: true);
}
