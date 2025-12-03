import 'chart_data_point.dart';

/// Time range options for Stats tab
enum TimeRange { daily, weekly, monthly, yearly, all }

/// Chart data processor for Stats tab
///
/// Converts bucket data (aggregated swing metrics over time) into chart data points.
/// Handles time-based labels and shot count calculations.
class StatsTabChartData {
  /// Bucket data: map of metric keys to normalized values (0-1 range)
  /// Keys: 'speed', 'force', 'accel', 'sforce'
  final Map<String, List<double>> bucketData;

  /// Labels for each bucket (e.g., "Mon 1", "10:00", "Jan")
  final List<String> labels;

  /// Selected time range
  final TimeRange range;

  /// Total shots across all buckets
  final int totalShots;

  const StatsTabChartData({
    required this.bucketData,
    required this.labels,
    required this.range,
    required this.totalShots,
  });

  /// Get data points for a specific metric
  ///
  /// [metricKey] should be one of: 'speed', 'force', 'accel', 'sforce'
  List<ChartDataPoint> getDataPoints(String metricKey) {
    final series = bucketData[metricKey] ?? [];

    return series.asMap().entries.map((e) {
      final index = e.key;
      final normalizedValue = e.value;

      // De-normalize value back to actual range for display
      final actualValue = _denormalizeValue(normalizedValue, metricKey);

      return ChartDataPoint(
        x: index.toDouble(),
        y: actualValue,
        label: index < labels.length ? labels[index] : 'Bucket $index',
        shotCount: _calculateShotsForBucket(index, series.length),
      );
    }).toList();
  }

  /// De-normalize value from 0-1 range back to actual metric range
  double _denormalizeValue(double normalized, String metricKey) {
    // These ranges match the normalization in stats_tab.dart
    final (min, max) = switch (metricKey) {
      'speed' => (80.0, 240.0), // km/h
      'force' => (20.0, 120.0), // N
      'accel' => (5.0, 45.0), // m/s²
      'sforce' => (10.0, 80.0), // au (swing force)
      _ => (0.0, 100.0), // fallback
    };

    return min + (normalized * (max - min));
  }

  /// Calculate approximate shots for a bucket
  ///
  /// Distributes total shots evenly across buckets
  int _calculateShotsForBucket(int bucketIndex, int totalBuckets) {
    if (totalBuckets == 0) return 0;
    return (totalShots / totalBuckets).round();
  }

  /// Get unit string for a metric
  String getUnit(String metricKey) {
    return switch (metricKey) {
      'speed' => 'km/h',
      'force' => 'N',
      'accel' => 'm/s²',
      'sforce' => 'au',
      _ => '',
    };
  }

  /// Get display name for a metric
  String getMetricName(String metricKey) {
    return switch (metricKey) {
      'speed' => 'Swing Speed',
      'force' => 'Impact Force',
      'accel' => 'Acceleration',
      'sforce' => 'Swing Force',
      _ => metricKey,
    };
  }

  /// Check if we have data
  bool get hasData => bucketData.isNotEmpty && totalShots > 0;

  /// Get number of buckets
  int get bucketCount => labels.length;

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

  /// Calculate value range for a metric (with padding)
  (double min, double max) getValueRange(String metricKey) {
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

  /// Get average value for a metric
  double getAverage(String metricKey) {
    final points = getDataPoints(metricKey);
    if (points.isEmpty) return 0;

    final sum = points.map((p) => p.y).reduce((a, b) => a + b);
    return sum / points.length;
  }

  /// Get maximum value for a metric
  double getMaximum(String metricKey) {
    final points = getDataPoints(metricKey);
    if (points.isEmpty) return 0;

    return points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
  }
}
