import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'chart_configuration.dart';
import 'chart_data_point.dart';
import 'chart_theme.dart';

/// Minimal line chart widget - ultra-clean sparkline
///
/// Perfect for mini charts on metric cards. Shows just a smooth line with
/// subtle gradient fill, no axes, no grid, no labels.
///
/// Example usage:
/// ```dart
/// MinimalLineChart(
///   dataPoints: [
///     ChartDataPoint(x: 0, y: 100, label: ''),
///     ChartDataPoint(x: 1, y: 150, label: ''),
///     ChartDataPoint(x: 2, y: 120, label: ''),
///   ],
/// )
/// ```
class MinimalLineChart extends StatelessWidget {
  /// Data points to display
  final List<ChartDataPoint> dataPoints;

  /// Optional configuration (defaults to minimal)
  final ChartConfiguration? configuration;

  /// Optional callback when chart is tapped
  final VoidCallback? onTap;

  const MinimalLineChart({
    super.key,
    required this.dataPoints,
    this.configuration,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChartTheme.fromContext(context);
    final config = configuration ?? ChartConfiguration.minimal();

    // Handle empty data
    if (dataPoints.isEmpty) {
      return const Center(
        child: Text(
          'No data',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      );
    }

    // Convert to FlSpots
    final spots = dataPoints.map((p) => p.toFlSpot()).toList();

    return GestureDetector(
      onTap: onTap,
      child: LineChart(
        LineChartData(
          // No grid for minimal look
          gridData: const FlGridData(show: false),

          // No titles/axes for minimal look
          titlesData: const FlTitlesData(show: false),

          // No border for minimal look
          borderData: FlBorderData(show: false),

          // Min/max values
          minX: spots.first.x,
          maxX: spots.last.x,
          minY: _calculateMinY(spots),
          maxY: _calculateMaxY(spots),

          // Line data
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: config.smoothCurves,
              curveSmoothness: 0.35,
              preventCurveOverShooting: true,
              gradient: theme.lineGradient,
              barWidth: config.lineWidth,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false), // No dots for minimal
              belowBarData: BarAreaData(
                show: config.showFill,
                gradient: theme.fillGradient,
              ),
            ),
          ],

          // No touch interaction for minimal
          lineTouchData: const LineTouchData(enabled: false),
        ),
        duration: Duration(milliseconds: config.animationDuration),
        curve: Curves.easeInOut,
      ),
    );
  }

  /// Calculate minimum Y value with padding
  double _calculateMinY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    final minValue = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    return minValue * 0.9; // 10% padding below
  }

  /// Calculate maximum Y value with padding
  double _calculateMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 100;
    final maxValue = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return maxValue * 1.1; // 10% padding above
  }
}
