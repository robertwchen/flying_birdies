import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/widgets/charts/chart_data_point.dart';

void main() {
  group('ChartDataPoint', () {
    test('creates valid data point', () {
      final point = ChartDataPoint(
        x: 1.0,
        y: 100.0,
        label: 'Test',
      );

      expect(point.x, 1.0);
      expect(point.y, 100.0);
      expect(point.label, 'Test');
      expect(point.shotCount, null);
      expect(point.timestamp, null);
    });

    test('creates data point with all fields', () {
      final timestamp = DateTime(2024, 1, 1);
      final point = ChartDataPoint(
        x: 2.0,
        y: 150.0,
        label: 'Swing 2',
        shotCount: 10,
        timestamp: timestamp,
      );

      expect(point.x, 2.0);
      expect(point.y, 150.0);
      expect(point.label, 'Swing 2');
      expect(point.shotCount, 10);
      expect(point.timestamp, timestamp);
    });

    test('converts to FlSpot correctly', () {
      final point = ChartDataPoint(x: 3.0, y: 200.0, label: 'Test');
      final spot = point.toFlSpot();

      expect(spot.x, 3.0);
      expect(spot.y, 200.0);
    });

    test('isValid returns true for valid values', () {
      final point = ChartDataPoint(x: 1.0, y: 100.0, label: 'Test');
      expect(point.isValid, true);
    });

    test('isValid returns false for NaN', () {
      final point = ChartDataPoint(x: 1.0, y: double.nan, label: 'Test');
      expect(point.isValid, false);
    });

    test('isValid returns false for infinite', () {
      final point = ChartDataPoint(x: 1.0, y: double.infinity, label: 'Test');
      expect(point.isValid, false);
    });

    test('isValid returns false for negative values', () {
      final point = ChartDataPoint(x: 1.0, y: -10.0, label: 'Test');
      expect(point.isValid, false);
    });

    test('isOutlier detects outliers correctly', () {
      final point = ChartDataPoint(x: 1.0, y: 100.0, label: 'Test');

      // Not an outlier (within 3 std dev)
      expect(point.isOutlier(50.0, 20.0), false);

      // Is an outlier (> 3 std dev)
      expect(point.isOutlier(50.0, 5.0), true);
    });

    test('isOutlier handles zero std dev', () {
      final point = ChartDataPoint(x: 1.0, y: 100.0, label: 'Test');

      // Zero std dev means all values are the same, no outliers
      expect(point.isOutlier(100.0, 0.0), false);
    });
  });
}
