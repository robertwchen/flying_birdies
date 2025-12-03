import 'dart:async';
import '../../models/imu_reading.dart';
import '../../models/swing_metrics.dart';

/// Analytics Service interface for dependency injection
abstract class IAnalyticsService {
  /// Stream of detected swings
  Stream<SwingMetrics> get swingStream;

  /// Process a new IMU reading
  void processReading(ImuReading reading);

  /// Reset analyzer state
  void reset();

  /// Get current statistics
  Map<String, dynamic> getStatistics();

  /// Dispose resources
  void dispose();
}
