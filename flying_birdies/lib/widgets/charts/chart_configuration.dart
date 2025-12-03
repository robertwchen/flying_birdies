import 'package:flutter/material.dart';

/// Configuration for chart display options
///
/// Controls visibility of grid, axes, dots, and interaction features.
/// Provides factory constructors for common configurations (minimal, detailed, interactive).
class ChartConfiguration {
  /// Show grid lines
  final bool showGrid;

  /// Show axes (X and Y)
  final bool showAxes;

  /// Show data point dots
  final bool showDots;

  /// Enable touch interactions (tooltips, crosshair)
  final bool enableInteraction;

  /// Line color (if null, uses theme default)
  final Color? lineColor;

  /// Fill color (if null, uses theme default)
  final Color? fillColor;

  /// Line width in pixels
  final double lineWidth;

  /// Data point dot radius
  final double dotRadius;

  /// Show area fill below line
  final bool showFill;

  /// Enable smooth curves (Bezier)
  final bool smoothCurves;

  /// Enable zoom gestures
  final bool enableZoom;

  /// Enable pan gestures
  final bool enablePan;

  /// Show vertical grid lines
  final bool showVerticalGrid;

  /// Show horizontal grid lines
  final bool showHorizontalGrid;

  /// Animation duration in milliseconds
  final int animationDuration;

  const ChartConfiguration({
    this.showGrid = true,
    this.showAxes = true,
    this.showDots = true,
    this.enableInteraction = true,
    this.lineColor,
    this.fillColor,
    this.lineWidth = 3.0,
    this.dotRadius = 4.0,
    this.showFill = true,
    this.smoothCurves = true,
    this.enableZoom = false,
    this.enablePan = false,
    this.showVerticalGrid = false,
    this.showHorizontalGrid = true,
    this.animationDuration = 300,
  });

  /// Minimal configuration - ultra-clean sparkline
  ///
  /// - No grid, no axes, no dots
  /// - Just a smooth line with subtle fill
  /// - Perfect for mini charts on metric cards
  factory ChartConfiguration.minimal() {
    return const ChartConfiguration(
      showGrid: false,
      showAxes: false,
      showDots: false,
      enableInteraction: false,
      lineWidth: 2.0,
      showFill: true,
      smoothCurves: true,
      enableZoom: false,
      enablePan: false,
      animationDuration: 300,
    );
  }

  /// Detailed configuration - clean chart with axes and labels
  ///
  /// - Horizontal grid lines only
  /// - Axes with labels
  /// - Small data point dots
  /// - Basic touch interaction
  /// - Perfect for Feedback tab expanded view
  factory ChartConfiguration.detailed() {
    return const ChartConfiguration(
      showGrid: true,
      showAxes: true,
      showDots: true,
      enableInteraction: true,
      lineWidth: 3.0,
      dotRadius: 4.0,
      showFill: true,
      smoothCurves: true,
      enableZoom: false,
      enablePan: false,
      showVerticalGrid: false,
      showHorizontalGrid: true,
      animationDuration: 400,
    );
  }

  /// Interactive configuration - full-featured chart
  ///
  /// - Both horizontal and vertical grid lines
  /// - Axes with labels
  /// - Data point dots
  /// - Full touch interaction with tooltips
  /// - Zoom and pan support
  /// - Perfect for Stats tab enlarged view
  factory ChartConfiguration.interactive() {
    return const ChartConfiguration(
      showGrid: true,
      showAxes: true,
      showDots: true,
      enableInteraction: true,
      lineWidth: 3.0,
      dotRadius: 5.0,
      showFill: true,
      smoothCurves: true,
      enableZoom: true,
      enablePan: true,
      showVerticalGrid: true,
      showHorizontalGrid: true,
      animationDuration: 500,
    );
  }

  /// Create a copy with optional field overrides
  ChartConfiguration copyWith({
    bool? showGrid,
    bool? showAxes,
    bool? showDots,
    bool? enableInteraction,
    Color? lineColor,
    Color? fillColor,
    double? lineWidth,
    double? dotRadius,
    bool? showFill,
    bool? smoothCurves,
    bool? enableZoom,
    bool? enablePan,
    bool? showVerticalGrid,
    bool? showHorizontalGrid,
    int? animationDuration,
  }) {
    return ChartConfiguration(
      showGrid: showGrid ?? this.showGrid,
      showAxes: showAxes ?? this.showAxes,
      showDots: showDots ?? this.showDots,
      enableInteraction: enableInteraction ?? this.enableInteraction,
      lineColor: lineColor ?? this.lineColor,
      fillColor: fillColor ?? this.fillColor,
      lineWidth: lineWidth ?? this.lineWidth,
      dotRadius: dotRadius ?? this.dotRadius,
      showFill: showFill ?? this.showFill,
      smoothCurves: smoothCurves ?? this.smoothCurves,
      enableZoom: enableZoom ?? this.enableZoom,
      enablePan: enablePan ?? this.enablePan,
      showVerticalGrid: showVerticalGrid ?? this.showVerticalGrid,
      showHorizontalGrid: showHorizontalGrid ?? this.showHorizontalGrid,
      animationDuration: animationDuration ?? this.animationDuration,
    );
  }
}
