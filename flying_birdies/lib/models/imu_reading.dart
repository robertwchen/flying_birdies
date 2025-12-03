import 'dart:math' as math;

/// Raw IMU sensor reading from BLE device
class ImuReading {
  final DateTime timestamp;
  final double ax, ay, az; // Accelerometer (m/s²)
  final double gx, gy, gz; // Gyroscope (rad/s)
  final double micRms; // Microphone RMS (for FFT validation)

  const ImuReading({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    this.micRms = 0.0, // Default to 0 if not available
  });

  /// Angular speed magnitude: ω = √(gx² + gy² + gz²)
  double get omega => math.sqrt(gx * gx + gy * gy + gz * gz);

  /// Acceleration magnitude: a = √(ax² + ay² + az²)
  double get accMag => math.sqrt(ax * ax + ay * ay + az * az);

  /// Tip speed: v_tip = ω · r
  /// r = 0.39 m (neck→tip distance, measured: 390mm) - v8 calibrated
  double tipSpeed([double r = 0.39]) => omega * r;
}
