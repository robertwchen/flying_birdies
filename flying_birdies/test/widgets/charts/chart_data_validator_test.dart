import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/widgets/charts/chart_data_point.dart';
import 'package:flying_birdies/widgets/charts/chart_data_validator.dart';

void main() {
  group('ChartDataValidator', () {
    group('validate', () {
      test('returns error for empty data', () {
        final result = ChartDataValidator.validate([]);
        expect(result.isError, true);
        expect(result.message, contains('No data points'));
      });

      test('returns warning for single point', () {
        final points = [
          ChartDataPoint(x: 0, y: 100, label: 'Point 1'),
        ];
        final result = ChartDataValidator.validate(points);
        expect(result.isWarning, true);
        expect(result.message, contains('one data point'));
      });

      test('returns warning for two points', () {
        final points = [
          ChartDataPoint(x: 0, y: 100, label: 'Point 1'),
          ChartDataPoint(x: 1, y: 150, label: 'Point 2'),
        ];
        final result = ChartDataValidator.validate(points);
        expect(result.isWarning, true);
        expect(result.message, contains('two data points'));
      });

      test('returns success for valid data', () {
        final points = [
          ChartDataPoint(x: 0, y: 100, label: 'Point 1'),
          ChartDataPoint(x: 1, y: 150, label: 'Point 2'),
          ChartDataPoint(x: 2, y: 120, label: 'Point 3'),
        ];
        final result = ChartDataValidator.validate(points);
        expect(result.isSuccess, true);
      });

      test('returns error for invalid values', () {
        final points = [
          ChartDataPoint(x: 0, y: 100, label: 'Point 1'),
          ChartDataPoint(x: 1, y: double.nan, label: 'Point 2'),
          ChartDataPoint(x: 2, y: 120, label: 'Point 3'),
        ];
        final result = ChartDataValidator.validate(points);
        expect(result.isError, true);
        expect(result.message, contains('Invalid data points'));
      });

      test('returns warning for all same values', () {
        final points = [
          ChartDataPoint(x: 0, y: 100, label: 'Point 1'),
          ChartDataPoint(x: 1, y: 100, label: 'Point 2'),
          ChartDataPoint(x: 2, y: 100, label: 'Point 3'),
        ];
        final result = ChartDataValidator.validate(points);
        expect(result.isWarning, true);
        expect(result.message, contains('identical'));
      });
    });

    group('filterValid', () {
      test('filters out invalid points', () {
        final points = [
          ChartDataPoint(x: 0, y: 100, label: 'Valid 1'),
          ChartDataPoint(x: 1, y: double.nan, label: 'Invalid'),
          ChartDataPoint(x: 2, y: 120, label: 'Valid 2'),
          ChartDataPoint(x: 3, y: -10, label: 'Invalid 2'),
        ];
        final valid = ChartDataValidator.filterValid(points);
        expect(valid.length, 2);
        expect(valid[0].label, 'Valid 1');
        expect(valid[1].label, 'Valid 2');
      });
    });

    group('calculateValueRange', () {
      test('returns default range for empty data', () {
        final (min, max) = ChartDataValidator.calculateValueRange([]);
        expect(min, 0);
        expect(max, 100);
      });

      test('calculates range with 10% padding', () {
        final points = [
          ChartDataPoint(x: 0, y: 100, label: 'Point 1'),
          ChartDataPoint(x: 1, y: 200, label: 'Point 2'),
        ];
        final (min, max) = ChartDataValidator.calculateValueRange(points);
        expect(min, closeTo(90.0, 0.01)); // 100 * 0.9
        expect(max, closeTo(220.0, 0.01)); // 200 * 1.1
      });

      test('handles all same values', () {
        final points = [
          ChartDataPoint(x: 0, y: 100, label: 'Point 1'),
          ChartDataPoint(x: 1, y: 100, label: 'Point 2'),
        ];
        final (min, max) = ChartDataValidator.calculateValueRange(points);
        expect(min, closeTo(90.0, 0.01)); // 100 * 0.9
        expect(max, closeTo(110.0, 0.01)); // 100 * 1.1
      });

      test('handles zero value', () {
        final points = [
          ChartDataPoint(x: 0, y: 0, label: 'Point 1'),
          ChartDataPoint(x: 1, y: 0, label: 'Point 2'),
        ];
        final (min, max) = ChartDataValidator.calculateValueRange(points);
        expect(min, 0);
        expect(max, 10);
      });
    });

    group('labelsWouldOverlap', () {
      test('returns false for sufficient spacing', () {
        final result = ChartDataValidator.labelsWouldOverlap(5, 300);
        expect(result, false); // 300 / 4 = 75px spacing
      });

      test('returns true for insufficient spacing', () {
        final result = ChartDataValidator.labelsWouldOverlap(20, 300);
        expect(result, true); // 300 / 19 = ~15px spacing
      });

      test('returns false for single point', () {
        final result = ChartDataValidator.labelsWouldOverlap(1, 300);
        expect(result, false);
      });
    });

    group('calculateLabelInterval', () {
      test('returns 1 for sufficient spacing', () {
        final interval = ChartDataValidator.calculateLabelInterval(5, 300);
        expect(interval, 1); // Show all labels
      });

      test('returns interval for insufficient spacing', () {
        final interval = ChartDataValidator.calculateLabelInterval(20, 300);
        expect(interval, greaterThan(1)); // Skip some labels
      });

      test('returns 1 for single point', () {
        final interval = ChartDataValidator.calculateLabelInterval(1, 300);
        expect(interval, 1);
      });

      test('calculates correct interval for many points', () {
        final interval = ChartDataValidator.calculateLabelInterval(100, 300);
        // 300 / 40 = 7.5 max labels, so interval should be ~14
        expect(interval, greaterThanOrEqualTo(10));
      });
    });
  });
}
