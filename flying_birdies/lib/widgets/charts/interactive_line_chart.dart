import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'chart_configuration.dart';
import 'chart_data_point.dart';
import 'chart_data_validator.dart';
import 'chart_theme.dart';

/// Interactive line chart widget with full features
///
/// Includes:
/// - X and Y axes with labels
/// - Grid lines (horizontal and/or vertical)
/// - Data point dots
/// - Touch tooltips with crosshair
/// - Optional zoom and pan
///
/// Perfect for detailed chart views (Feedback tab expanded, Stats tab enlarged).
///
/// Example usage:
/// ```dart
/// InteractiveLineChart(
///   dataPoints: dataPoints,
///   xLabels: ['Swing 1', 'Swing 2', 'Swing 3'],
///   yUnit: 'km/h',
///   configuration: ChartConfiguration.detailed(),
/// )
/// ```
class InteractiveLineChart extends StatelessWidget {
  /// Data points to display
  final List<ChartDataPoint> dataPoints;

  /// Labels for X-axis (optional, uses data point labels if not provided)
  final List<String>? xLabels;

  /// Unit for Y-axis (e.g., 'km/h', 'N', 'm/s²')
  final String yUnit;

  /// Minimum Y value (optional, auto-calculated if not provided)
  final double? minY;

  /// Maximum Y value (optional, auto-calculated if not provided)
  final double? maxY;

  /// Configuration (defaults to detailed)
  final ChartConfiguration? configuration;

  /// Custom tooltip builder (optional)
  final Widget Function(ChartDataPoint point)? tooltipBuilder;

  const InteractiveLineChart({
    super.key,
    required this.dataPoints,
    this.xLabels,
    required this.yUnit,
    this.minY,
    this.maxY,
    this.configuration,
    this.tooltipBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChartTheme.fromContext(context);
    final config = configuration ?? ChartConfiguration.detailed();

    // Handle empty data
    if (dataPoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart,
                size: 48, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text(
              'No data available',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Convert to FlSpots
    final spots = dataPoints.map((p) => p.toFlSpot()).toList();

    // Calculate value range
    final (calculatedMinY, calculatedMaxY) =
        ChartDataValidator.calculateValueRange(dataPoints);
    final effectiveMinY = minY ?? calculatedMinY;
    final effectiveMaxY = maxY ?? calculatedMaxY;

    // Calculate label interval for X-axis
    final labelInterval = ChartDataValidator.calculateLabelInterval(
      dataPoints.length,
      300, // Approximate chart width (will be adjusted by fl_chart)
    );

    // Get accessibility settings
    final mediaQuery = MediaQuery.of(context);
    final disableAnimations = mediaQuery.disableAnimations;

    // Create semantic label
    final minValue = dataPoints.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxValue = dataPoints.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    final semanticLabel =
        'Line chart with ${dataPoints.length} data points. Values range from ${minValue.toStringAsFixed(1)} to ${maxValue.toStringAsFixed(1)} $yUnit. Tap to see details.';

    return Semantics(
      label: semanticLabel,
      hint: 'Double tap to interact with chart',
      child: LineChart(
        LineChartData(
          // Grid configuration
          gridData: FlGridData(
            show: config.showGrid,
            drawVerticalLine: config.showVerticalGrid,
            drawHorizontalLine: config.showHorizontalGrid,
            horizontalInterval:
                _calculateGridInterval(effectiveMinY, effectiveMaxY),
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: theme.gridColor,
                strokeWidth: theme.gridLineWidth,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: theme.gridColor.withValues(alpha: 0.5),
                strokeWidth: theme.gridLineWidth,
              );
            },
          ),

          // Titles/axes configuration
          titlesData: FlTitlesData(
            show: config.showAxes,
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),

            // X-axis (bottom)
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: labelInterval.toDouble(),
                getTitlesWidget: (value, meta) {
                  return _buildXAxisLabel(value.toInt(), theme);
                },
              ),
            ),

            // Y-axis (left)
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: _calculateGridInterval(effectiveMinY, effectiveMaxY),
                getTitlesWidget: (value, meta) {
                  return _buildYAxisLabel(value, theme);
                },
              ),
            ),
          ),

          // Border configuration
          borderData: FlBorderData(
            show: config.showAxes,
            border: Border(
              left: BorderSide(
                  color: theme.axisColor, width: theme.axisLineWidth),
              bottom: BorderSide(
                  color: theme.axisColor, width: theme.axisLineWidth),
            ),
          ),

          // Min/max values
          minX: spots.first.x,
          maxX: spots.last.x,
          minY: effectiveMinY,
          maxY: effectiveMaxY,

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

              // Data point dots
              dotData: FlDotData(
                show: config.showDots,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: config.dotRadius,
                    color: theme.dotFillColor,
                    strokeWidth: theme.dotStrokeWidth,
                    strokeColor: theme.dotStrokeColor,
                  );
                },
              ),

              // Area fill below line
              belowBarData: BarAreaData(
                show: config.showFill,
                gradient: theme.fillGradient,
              ),
            ),
          ],

          // Touch interaction
          lineTouchData: LineTouchData(
            enabled: config.enableInteraction,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => theme.tooltipBg,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index < 0 || index >= dataPoints.length) return null;

                  final point = dataPoints[index];
                  return LineTooltipItem(
                    '${point.label}\n${point.y.toStringAsFixed(1)} $yUnit${point.shotCount != null ? '\nShots: ${point.shotCount}' : ''}',
                    theme.tooltipStyle,
                  );
                }).toList();
              },
            ),

            // Crosshair indicator
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: theme.labelColor.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: config.dotRadius + 2,
                        color: theme.dotStrokeColor,
                        strokeWidth: 2,
                        strokeColor: theme.dotFillColor,
                      );
                    },
                  ),
                );
              }).toList();
            },
          ),
        ),
        duration: disableAnimations
            ? Duration.zero
            : Duration(milliseconds: config.animationDuration),
        curve: Curves.easeInOut,
      ),
    );
  }

  /// Build X-axis label widget
  Widget _buildXAxisLabel(int index, ChartTheme theme) {
    if (index < 0 || index >= dataPoints.length) {
      return const SizedBox.shrink();
    }

    final label = xLabels != null && index < xLabels!.length
        ? xLabels![index]
        : dataPoints[index].label;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        label,
        style: theme.axisLabelStyle,
        textAlign: TextAlign.center,
        textScaler: TextScaler.noScaling, // Prevent excessive scaling in charts
      ),
    );
  }

  /// Build Y-axis label widget
  Widget _buildYAxisLabel(double value, ChartTheme theme) {
    return Text(
      '${value.toInt()} $yUnit',
      style: theme.axisLabelStyle,
      textAlign: TextAlign.right,
      textScaler: TextScaler.noScaling, // Prevent excessive scaling in charts
    );
  }

  /// Calculate grid interval for Y-axis
  ///
  /// Aims for 4-6 grid lines
  double _calculateGridInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 0) return 10;

    // Aim for 5 grid lines
    final rawInterval = range / 5;

    // Round to nice numbers (1, 2, 5, 10, 20, 50, 100, etc.)
    final magnitude = pow(10, (log(rawInterval) / ln10).floor()).toDouble();
    final normalized = rawInterval / magnitude;

    double niceInterval;
    if (normalized < 1.5) {
      niceInterval = 1 * magnitude;
    } else if (normalized < 3) {
      niceInterval = 2 * magnitude;
    } else if (normalized < 7) {
      niceInterval = 5 * magnitude;
    } else {
      niceInterval = 10 * magnitude;
    }

    return niceInterval;
  }
}
