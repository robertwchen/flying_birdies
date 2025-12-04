import 'package:flutter/material.dart';
import 'chart_data_point.dart';
import 'interactive_line_chart.dart';
import 'chart_configuration.dart';

/// Handles chart rendering with fallback states for edge cases
///
/// Provides robust error handling for:
/// - Empty data
/// - Single data point
/// - Two data points
/// - Rendering errors
///
/// Example usage:
/// ```dart
/// ChartFallbackHandler.buildChart(
///   dataPoints: dataPoints,
///   yUnit: 'km/h',
///   onRetry: () => _loadData(),
/// )
/// ```
class ChartFallbackHandler {
  /// Build chart with automatic fallback handling
  ///
  /// Returns appropriate widget based on data state:
  /// - Error state if rendering fails
  /// - Empty state if no data
  /// - Single point state if 1 data point
  /// - Two point state if 2 data points
  /// - Full chart if 3+ data points
  static Widget buildChart({
    required List<ChartDataPoint> dataPoints,
    required String yUnit,
    double? minY,
    double? maxY,
    ChartConfiguration? configuration,
    Widget Function(ChartDataPoint point)? tooltipBuilder,
    VoidCallback? onRetry,
    String? errorMessage,
  }) {
    try {
      // Handle empty data
      if (dataPoints.isEmpty) {
        return _buildEmptyState(onRetry: onRetry);
      }

      // Handle single point
      if (dataPoints.length == 1) {
        return _buildSinglePointChart(
          point: dataPoints.first,
          yUnit: yUnit,
        );
      }

      // Handle two points
      if (dataPoints.length == 2) {
        return _buildTwoPointChart(
          points: dataPoints,
          yUnit: yUnit,
        );
      }

      // Render full chart (3+ points)
      return InteractiveLineChart(
        dataPoints: dataPoints,
        yUnit: yUnit,
        minY: minY,
        maxY: maxY,
        configuration: configuration,
        tooltipBuilder: tooltipBuilder,
      );
    } catch (e, stackTrace) {
      debugPrint('Chart rendering error: $e');
      debugPrint('Stack trace: $stackTrace');
      return _buildErrorState(
        message: errorMessage ?? 'Failed to render chart',
        error: e.toString(),
        onRetry: onRetry,
      );
    }
  }

  /// Build empty state widget
  static Widget _buildEmptyState({VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart_outlined,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No data available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start recording swings to see your stats',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build error state widget
  static Widget _buildErrorState({
    required String message,
    required String error,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build single point chart (special case)
  static Widget _buildSinglePointChart({
    required ChartDataPoint point,
    required String yUnit,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.circle,
              size: 48,
              color: const Color(0xFFFF6FD8).withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              point.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${point.y.toStringAsFixed(1)} $yUnit',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (point.shotCount != null) ...[
              const SizedBox(height: 4),
              Text(
                'Shots: ${point.shotCount}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Need at least 2 data points for a chart',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build two point chart (minimal line)
  static Widget _buildTwoPointChart({
    required List<ChartDataPoint> points,
    required String yUnit,
  }) {
    final point1 = points[0];
    final point2 = points[1];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPointColumn(point1, yUnit),
                Container(
                  width: 60,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6FD8), Color(0xFF7E4AED)],
                    ),
                  ),
                ),
                _buildPointColumn(point2, yUnit),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Limited data available',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Record more swings for detailed charts',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build column for a single point in two-point chart
  static Widget _buildPointColumn(ChartDataPoint point, String yUnit) {
    return Column(
      children: [
        Icon(
          Icons.circle,
          size: 32,
          color: const Color(0xFFFF6FD8).withValues(alpha: 0.8),
        ),
        const SizedBox(height: 8),
        Text(
          point.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${point.y.toStringAsFixed(1)} $yUnit',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
