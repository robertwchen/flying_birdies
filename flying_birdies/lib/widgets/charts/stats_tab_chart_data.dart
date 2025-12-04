import 'package:intl/intl.dart';
import 'chart_data_point.dart';

/// Time range options for Stats tab
enum TimeRange { daily, weekly, monthly, yearly, all }

/// Chart data processor for Stats tab
///
/// Converts individual swing data into chart data points for visualization.
/// Each point represents one swing (not time-bucketed aggregates).
class StatsTabChartData {
  /// All swings in the selected time range
  final List<dynamic> swings;

  /// Metric key to display ('speed', 'force', 'accel', 'sforce')
  final String metricKey;

  /// Selected time range
  final TimeRange range;

  /// Total shots
  final int totalShots;

  const StatsTabChartData({
    required this.swings,
    required this.metricKey,
    required this.range,
    required this.totalShots,
  });

  /// Get data points for the selected metric
  ///
  /// Each point represents one individual swing
  List<ChartDataPoint> getDataPoints(String metricKey) {
    return swings.asMap().entries.map((e) {
      final index = e.key;
      final swing = e.value;

      final value = _extractMetricValue(swing, metricKey);
      final label = _formatLabel(swing.timestamp, index);

      return ChartDataPoint(
        x: index.toDouble(),
        y: value,
        label: label,
        shotCount: 1, // Each point is one swing
        timestamp: swing.timestamp,
      );
    }).toList();
  }

  /// Extract metric value from swing
  double _extractMetricValue(dynamic swing, String metricKey) {
    return switch (metricKey) {
      'speed' => swing.maxVtip * 3.6, // m/s to km/h
      'force' => swing.estForceN,
      'accel' => swing.impactAmax,
      'sforce' => swing.impactSeverity,
      _ => 0.0,
    };
  }

  /// Format label for a swing based on timestamp
  String _formatLabel(DateTime timestamp, int index) {
    final formatter = DateFormat('MMM d, HH:mm');
    return formatter.format(timestamp);
  }

  /// Get unit string for the metric
  String get unit {
    return switch (metricKey) {
      'speed' => 'km/h',
      'force' => 'N',
      'accel' => 'm/s²',
      'sforce' => 'N',
      _ => '',
    };
  }

  /// Get display name for the metric
  String get metricName {
    return switch (metricKey) {
      'speed' => 'Swing Speed',
      'force' => 'Impact Force',
      'accel' => 'Acceleration',
      'sforce' => 'Swing Force',
      _ => metricKey,
    };
  }

  /// Check if we have data
  bool get hasData => swings.isNotEmpty;

  /// Get time range description
  String get rangeDescription {
    return switch (range) {
      TimeRange.daily => 'Last 24 hours',
      TimeRange.weekly => 'Last 7 days',
      TimeRange.monthly => 'Last 30 days',
      TimeRange.yearly => 'Last 12 months',
      TimeRange.all => 'All time',
    };
  }

  /// Calculate value range for the metric (with padding)
  (double min, double max) get valueRange {
    final points = getDataPoints(metricKey);
    if (points.isEmpty) return (0, 100);

    final values = points.map((p) => p.y).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    // If all values are the same, create a range around that value
    if (minValue == maxValue) {
      final value = minValue;
      if (value == 0) {
        return (0, 10);
      }
      return (value * 0.9, value * 1.1);
    }

    // Add 10% padding on each side
    return (minValue * 0.9, maxValue * 1.1);
  }

  /// Get average value for the metric
  double get average {
    final points = getDataPoints(metricKey);
    if (points.isEmpty) return 0;

    final sum = points.map((p) => p.y).reduce((a, b) => a + b);
    return sum / points.length;
  }

  /// Get maximum value for the metric
  double get maximum {
    final points = getDataPoints(metricKey);
    if (points.isEmpty) return 0;

    return points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
  }
}
