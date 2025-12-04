import '../models/imu_reading.dart' as app_models;
import '../models/swing_metrics.dart' as app_models;

// Import v12 pipeline as a library
import 'imu_analytics_pipeline_v12.dart' as v12;

/// Wrapper class that adapts v12 pipeline to our app models
class SwingAnalyzerV2 {
  final v12.SwingAnalyzer _v12Analyzer = v12.SwingAnalyzer();

  /// Process reading using v12 algorithm
  app_models.SwingMetrics? processReading(app_models.ImuReading reading) {
    // Convert app model to v12 model
    final v12Reading = v12.ImuReading(
      timestamp: reading.timestamp,
      accelX: reading.ax,
      accelY: reading.ay,
      accelZ: reading.az,
      gyroX: reading.gx,
      gyroY: reading.gy,
      gyroZ: reading.gz,
      micRms: reading.micRms,
    );

    // Process with v12 analyzer
    final v12Swing = _v12Analyzer.processReading(v12Reading);

    // Convert v12 result to app model
    if (v12Swing != null && v12Swing.isValidSwing) {
      return app_models.SwingMetrics(
        timestamp: v12Swing.swingTime,
        maxOmega: v12Swing.maxAngularVelocity,
        maxVtip: v12Swing.maxTipSpeed,
        impactAmax: v12Swing.impactAcceleration,
        impactSeverity: v12Swing
            .swingForce, // Swing force in N (racket+sensor mass * accel)
        estForceN: v12Swing.estimatedForce, // Impact force at tip in N
        swingDurationMs: v12Swing.swingDuration,
        qualityPassed: v12Swing.isValidSwing,
        shuttleSpeedOut: v12Swing.maxTipSpeed * v12.ImuConfig.shuttleVsTipRatio,
        forceStandardized: v12Swing.shuttleForceStd,
      );
    }

    return null;
  }

  /// Clear analyzer state
  void clear() {
    _v12Analyzer.reset();
  }

  /// Get current statistics
  Map<String, double> getCurrentStats() {
    final stats = _v12Analyzer.getCurrentStats();
    return {
      'hitCount': (stats['hitCount'] as int).toDouble(),
      'bufferSize': (stats['bufferSize'] as int).toDouble(),
    };
  }
}
