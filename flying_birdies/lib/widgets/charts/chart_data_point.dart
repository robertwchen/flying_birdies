import 'package:fl_chart/fl_chart.dart';

/// Represents a single data point in a chart
///
/// Contains position (x, y), label, optional shot count, and timestamp.
/// Can be converted to fl_chart's FlSpot for rendering.
class ChartDataPoint {
  /// X-axis value (e.g., swing index, time bucket index)
  final double x;

  /// Y-axis value (e.g., speed in km/h, force in N)
  final double y;

  /// Human-readable label (e.g., "Swing 1", "10:00 AM")
  final String label;

  /// Optional shot count for this data point (used in Stats tab)
  final int? shotCount;

  /// Optional timestamp for this data point
  final DateTime? timestamp;

  const ChartDataPoint({
    required this.x,
    required this.y,
    required this.label,
    this.shotCount,
    this.timestamp,
  });

  /// Convert to fl_chart's FlSpot for rendering
  FlSpot toFlSpot() => FlSpot(x, y);

  /// Check if this data point has valid values
  bool get isValid {
    return !y.isNaN && !y.isInfinite && y >= 0;
  }

  /// Check if this data point is an outlier (> 3 standard deviations from mean)
  ///
  /// Note: This requires the mean and standard deviation to be calculated
  /// externally and passed in.
  bool isOutlier(double mean, double stdDev) {
    return (y - mean).abs() > 3 * stdDev;
  }

  @override
  String toString() {
    return 'ChartDataPoint(x: $x, y: $y, label: $label, shotCount: $shotCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChartDataPoint &&
        other.x == x &&
        other.y == y &&
        other.label == label &&
        other.shotCount == shotCount &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(x, y, label, shotCount, timestamp);
  }

  /// Create a copy with optional field overrides
  ChartDataPoint copyWith({
    double? x,
    double? y,
    String? label,
    int? shotCount,
    DateTime? timestamp,
  }) {
    return ChartDataPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      label: label ?? this.label,
      shotCount: shotCount ?? this.shotCount,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
