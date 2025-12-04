import 'dart:math';
import 'chart_data_point.dart';

/// Result of chart data validation
class ValidationResult {
  final bool isValid;
  final ValidationLevel level;
  final String message;

  const ValidationResult._({
    required this.isValid,
    required this.level,
    required this.message,
  });

  /// Create a success result
  factory ValidationResult.success() {
    return const ValidationResult._(
      isValid: true,
      level: ValidationLevel.success,
      message: 'Data is valid',
    );
  }

  /// Create a warning result (data is usable but has issues)
  factory ValidationResult.warning(String message) {
    return ValidationResult._(
      isValid: true,
      level: ValidationLevel.warning,
      message: message,
    );
  }

  /// Create an error result (data cannot be used)
  factory ValidationResult.error(String message) {
    return ValidationResult._(
      isValid: false,
      level: ValidationLevel.error,
      message: message,
    );
  }

  bool get isError => level == ValidationLevel.error;
  bool get isWarning => level == ValidationLevel.warning;
  bool get isSuccess => level == ValidationLevel.success;
}

/// Validation severity level
enum ValidationLevel {
  success,
  warning,
  error,
}

/// Validates chart data for rendering
///
/// Checks for:
/// - Empty data
/// - Single/two point edge cases
/// - Invalid values (NaN, Infinite, negative)
/// - Outliers (> 3 standard deviations)
class ChartDataValidator {
  /// Validate a list of chart data points
  static ValidationResult validate(List<ChartDataPoint> points) {
    // Check for empty data
    if (points.isEmpty) {
      return ValidationResult.error('No data points provided');
    }

    // Check for single point (limited visualization)
    if (points.length == 1) {
      return ValidationResult.warning(
          'Only one data point - limited visualization');
    }

    // Check for two points (can only draw straight line)
    if (points.length == 2) {
      return ValidationResult.warning(
          'Only two data points - limited visualization');
    }

    // Check for null/invalid values
    final invalidPoints = points.where((p) => !p.isValid).toList();
    if (invalidPoints.isNotEmpty) {
      return ValidationResult.error(
        'Invalid data points detected: ${invalidPoints.length} point(s) with NaN, Infinite, or negative values',
      );
    }

    // Check for outliers (> 3 standard deviations)
    final outliers = _detectOutliers(points);
    if (outliers.isNotEmpty) {
      return ValidationResult.warning(
        'Outliers detected: ${outliers.length} point(s) are more than 3 standard deviations from the mean',
      );
    }

    // Check if all values are the same (flat line)
    final values = points.map((p) => p.y).toList();
    final allSame = values.every((v) => v == values.first);
    if (allSame) {
      return ValidationResult.warning(
        'All values are identical (${values.first.toStringAsFixed(1)}) - will display as flat line',
      );
    }

    return ValidationResult.success();
  }

  /// Detect outliers using 3-sigma rule (> 3 standard deviations from mean)
  static List<ChartDataPoint> _detectOutliers(List<ChartDataPoint> points) {
    if (points.length < 3) {
      return []; // Need at least 3 points for meaningful stats
    }

    final values = points.map((p) => p.y).toList();
    final mean = _calculateMean(values);
    final stdDev = _calculateStdDev(values, mean);

    // If standard deviation is 0, all values are the same (no outliers)
    if (stdDev == 0) return [];

    return points.where((p) => p.isOutlier(mean, stdDev)).toList();
  }

  /// Calculate mean (average) of values
  static double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate standard deviation
  static double _calculateStdDev(List<double> values, double mean) {
    if (values.isEmpty) return 0;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }

  /// Filter out invalid data points and return only valid ones
  static List<ChartDataPoint> filterValid(List<ChartDataPoint> points) {
    return points.where((p) => p.isValid).toList();
  }

  /// Calculate value range with padding
  ///
  /// Returns (min, max) tuple with 10% padding on each side for visual breathing room.
  /// If all values are the same, returns a range with ±10% of the value.
  static (double min, double max) calculateValueRange(
      List<ChartDataPoint> points) {
    if (points.isEmpty) return (0, 100);

    final values = points.map((p) => p.y).toList();
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

  /// Check if data points have sufficient spacing for labels
  ///
  /// Returns true if labels would overlap (< 40px spacing)
  static bool labelsWouldOverlap(int dataPointCount, double chartWidth) {
    if (dataPointCount <= 1) return false;
    final spacing = chartWidth / (dataPointCount - 1);
    return spacing < 40; // Minimum 40px between labels
  }

  /// Calculate optimal label interval to avoid overlap
  ///
  /// Returns the interval (e.g., 1 = show all, 2 = show every other, 5 = show every 5th)
  static int calculateLabelInterval(int dataPointCount, double chartWidth) {
    if (dataPointCount <= 1) return 1;

    final spacing = chartWidth / (dataPointCount - 1);
    if (spacing >= 40) return 1; // Show all labels

    // Calculate how many labels we can fit
    final maxLabels = (chartWidth / 40).floor();
    if (maxLabels <= 0) return dataPointCount; // Show none (edge case)

    // Calculate interval to show approximately maxLabels
    final interval = (dataPointCount / maxLabels).ceil();
    return interval;
  }
}
