import '../../models/entities/swing_entity.dart';
import '../../models/entities/swing_entity_extensions.dart';
import 'chart_data_point.dart';

/// Metric types for Feedback tab charts
///
/// Note: This enum should match the GraphMetric enum in feedback_tab.dart
/// We define it here to avoid circular dependencies.
enum GraphMetric {
  swingSpeed,
  swingForce,
  acceleration,
  impactForce,
}

/// Chart data processor for Feedback tab
///
/// Converts swing entities into chart data points for visualization.
/// Handles metric extraction and value range calculation.
class FeedbackTabChartData {
  final List<SwingEntity> swings;
  final GraphMetric metric;

  const FeedbackTabChartData({
    required this.swings,
    required this.metric,
  });

  /// Get data points for the selected metric
  List<ChartDataPoint> get dataPoints {
    return swings.asMap().entries.map((e) {
      final index = e.key;
      final swing = e.value;
      final value = _extractMetricValue(swing, metric);

      return ChartDataPoint(
        x: index.toDouble(),
        y: value,
        label: 'Swing ${index + 1}',
        shotCount: 1,
        timestamp: swing.timestamp,
      );
    }).toList();
  }

  /// Extract metric value from swing entity
  double _extractMetricValue(SwingEntity swing, GraphMetric metric) {
    switch (metric) {
      case GraphMetric.swingSpeed:
        return swing.maxVtipKmh; // m/s to km/h
      case GraphMetric.swingForce:
        return swing.swingForce; // impactSeverity
      case GraphMetric.acceleration:
        return swing.acceleration; // impactAmax
      case GraphMetric.impactForce:
        return swing.impactForce; // estForceN
    }
  }

  /// Get unit string for the selected metric
  String get unit {
    switch (metric) {
      case GraphMetric.swingSpeed:
        return 'km/h';
      case GraphMetric.swingForce:
        return 'N';
      case GraphMetric.acceleration:
        return 'm/s²';
      case GraphMetric.impactForce:
        return 'N';
    }
  }

  /// Get metric display name
  String get metricName {
    switch (metric) {
      case GraphMetric.swingSpeed:
        return 'Swing Speed';
      case GraphMetric.swingForce:
        return 'Swing Force';
      case GraphMetric.acceleration:
        return 'Acceleration';
      case GraphMetric.impactForce:
        return 'Impact Force';
    }
  }

  /// Calculate value range with 10% padding
  (double min, double max) get valueRange {
    if (dataPoints.isEmpty) return (0, 100);

    final values = dataPoints.map((p) => p.y).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    // If all values are the same, create a range around that value
    if (minValue == maxValue) {
      final value = minValue;
      if (value == 0) {
        return (0, 10); // Special case for zero
      }
      return (value * 0.9, value * 1.1);
    }

    // Add 10% padding on each side
    return (minValue * 0.9, maxValue * 1.1);
  }

  /// Get average value for the selected metric
  double get average {
    if (dataPoints.isEmpty) return 0;
    final sum = dataPoints.map((p) => p.y).reduce((a, b) => a + b);
    return sum / dataPoints.length;
  }

  /// Get maximum value for the selected metric
  double get maximum {
    if (dataPoints.isEmpty) return 0;
    return dataPoints.map((p) => p.y).reduce((a, b) => a > b ? a : b);
  }

  /// Get minimum value for the selected metric
  double get minimum {
    if (dataPoints.isEmpty) return 0;
    return dataPoints.map((p) => p.y).reduce((a, b) => a < b ? a : b);
  }

  /// Check if we have data
  bool get hasData => swings.isNotEmpty;

  /// Get number of swings
  int get swingCount => swings.length;
}
