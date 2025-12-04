/// Represents aggregated swing data for a time bucket in Stats tab
///
/// This class stores both the normalized values for visualization (sparklines)
/// and the metadata (shot counts, timestamps) needed for accurate chart tooltips.
class BucketData {
  /// Normalized values (0-1) for visualization in sparklines
  final List<double> normalizedValues;

  /// Number of swings in each bucket
  final List<int> shotCounts;

  /// Timestamp for each bucket (center of time range)
  final List<DateTime> timestamps;

  const BucketData({
    required this.normalizedValues,
    required this.shotCounts,
    required this.timestamps,
  });

  /// Get total number of shots across all buckets
  int get totalShots => shotCounts.fold(0, (sum, count) => sum + count);

  /// Get number of buckets
  int get bucketCount => normalizedValues.length;

  /// Check if bucket has data at given index
  bool hasDataAt(int index) =>
      index >= 0 && index < shotCounts.length && shotCounts[index] > 0;

  @override
  String toString() {
    return 'BucketData(buckets: $bucketCount, totalShots: $totalShots)';
  }
}
