import 'package:flutter_test/flutter_test.dart';
import 'package:flying_birdies/widgets/charts/stats_tab_chart_data.dart';

void main() {
  group('StatsTabChartData', () {
    late StatsTabChartData chartData;

    setUp(() {
      chartData = StatsTabChartData(
        bucketData: {
          'speed': [0.5, 0.7, 0.6, 0.8],
          'force': [0.4, 0.6, 0.5, 0.7],
        },
        labels: ['Mon', 'Tue', 'Wed', 'Thu'],
        range: TimeRange.weekly,
        totalShots: 40,
      );
    });

    test('getDataPoints returns correct number of points', () {
      final points = chartData.getDataPoints('speed');
      expect(points.length, 4);
    });

    test('getDataPoints denormalizes values correctly', () {
      final points = chartData.getDataPoints('speed');
      // speed range is 80-240 km/h
      // 0.5 normalized = 80 + (0.5 * 160) = 160
      expect(points[0].y, closeTo(160.0, 0.1));
    });

    test('getDataPoints uses correct labels', () {
      final points = chartData.getDataPoints('speed');
      expect(points[0].label, 'Mon');
      expect(points[1].label, 'Tue');
      expect(points[2].label, 'Wed');
      expect(points[3].label, 'Thu');
    });

    test('getDataPoints calculates shot counts', () {
      final points = chartData.getDataPoints('speed');
      // 40 total shots / 4 buckets = 10 shots per bucket
      expect(points[0].shotCount, 10);
    });

    test('getUnit returns correct units', () {
      expect(chartData.getUnit('speed'), 'km/h');
      expect(chartData.getUnit('force'), 'N');
      expect(chartData.getUnit('accel'), 'm/s²');
      expect(chartData.getUnit('sforce'), 'N');
    });

    test('getMetricName returns correct names', () {
      expect(chartData.getMetricName('speed'), 'Swing Speed');
      expect(chartData.getMetricName('force'), 'Impact Force');
      expect(chartData.getMetricName('accel'), 'Acceleration');
      expect(chartData.getMetricName('sforce'), 'Swing Force');
    });

    test('hasData returns true when data exists', () {
      expect(chartData.hasData, true);
    });

    test('hasData returns false when no data', () {
      final emptyData = StatsTabChartData(
        bucketData: {},
        labels: [],
        range: TimeRange.daily,
        totalShots: 0,
      );
      expect(emptyData.hasData, false);
    });

    test('bucketCount returns correct count', () {
      expect(chartData.bucketCount, 4);
    });

    test('rangeDescription returns correct description', () {
      expect(chartData.rangeDescription, 'Last 7 days');

      final dailyData = StatsTabChartData(
        bucketData: {},
        labels: [],
        range: TimeRange.daily,
        totalShots: 0,
      );
      expect(dailyData.rangeDescription, 'Last 24 hours');
    });

    test('getValueRange calculates range with padding', () {
      final (min, max) = chartData.getValueRange('speed');
      // Values should be denormalized and have 10% padding
      expect(min, lessThan(160.0)); // Min value with padding
      expect(max, greaterThan(200.0)); // Max value with padding
    });

    test('getValueRange handles empty data', () {
      final emptyData = StatsTabChartData(
        bucketData: {'speed': []},
        labels: [],
        range: TimeRange.daily,
        totalShots: 0,
      );
      final (min, max) = emptyData.getValueRange('speed');
      expect(min, 0);
      expect(max, 100);
    });

    test('getAverage calculates correct average', () {
      final avg = chartData.getAverage('speed');
      // Average of denormalized values
      expect(avg, greaterThan(0));
    });

    test('getMaximum returns correct maximum', () {
      final max = chartData.getMaximum('speed');
      // Maximum of denormalized values (0.8 normalized)
      expect(max, closeTo(208.0, 0.1)); // 80 + (0.8 * 160)
    });

    test('handles missing metric gracefully', () {
      final points = chartData.getDataPoints('nonexistent');
      expect(points.isEmpty, true);
    });
  });
}
