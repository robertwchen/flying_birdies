/// Per-swing metrics computed from IMU data
class SwingMetrics {
  final DateTime timestamp;
  final double maxOmega; // rad/s
  final double maxVtip; // m/s
  final double impactAmax; // m/s²
  final double impactSeverity; // RMS-like proxy
  final double estForceN; // N
  final int swingDurationMs; // ms
  final bool qualityPassed; // true if passed all quality gates

  // v8 additions
  final double?
      shuttleSpeedOut; // m/s (v8: estimated shuttle speed = 1.5 * tip speed)
  final double?
      forceStandardized; // N (v8: optional rally force with incoming shuttle)

  const SwingMetrics({
    required this.timestamp,
    required this.maxOmega,
    required this.maxVtip,
    required this.impactAmax,
    required this.impactSeverity,
    required this.estForceN,
    required this.swingDurationMs,
    required this.qualityPassed,
    this.shuttleSpeedOut,
    this.forceStandardized,
  });

  /// Convert tip speed from m/s to km/h for display
  double get maxVtipKmh => maxVtip * 3.6;

  /// Quality gate checks
  static bool passesQualityGates({
    required double maxOmega,
    required double maxVtip,
    required double estForce,
    required int swingDurationMs,
  }) {
    return maxOmega >= 3.0 &&
        maxVtip < 50.0 &&
        estForce < 1000.0 &&
        swingDurationMs >= 100 &&
        swingDurationMs <= 1500;
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'maxOmega': maxOmega,
        'maxVtip': maxVtip,
        'impactAmax': impactAmax,
        'impactSeverity': impactSeverity,
        'estForceN': estForceN,
        'swingDurationMs': swingDurationMs,
        'qualityPassed': qualityPassed ? 1 : 0,
        'shuttleSpeedOut': shuttleSpeedOut,
        'forceStandardized': forceStandardized,
      };

  factory SwingMetrics.fromJson(Map<String, dynamic> json) => SwingMetrics(
        timestamp: DateTime.parse(json['timestamp']),
        maxOmega: (json['maxOmega'] as num).toDouble(),
        maxVtip: (json['maxVtip'] as num).toDouble(),
        impactAmax: (json['impactAmax'] as num).toDouble(),
        impactSeverity: (json['impactSeverity'] as num).toDouble(),
        estForceN: (json['estForceN'] as num).toDouble(),
        swingDurationMs: json['swingDurationMs'] as int,
        qualityPassed: (json['qualityPassed'] as int) == 1,
        shuttleSpeedOut: json['shuttleSpeedOut'] != null
            ? (json['shuttleSpeedOut'] as num).toDouble()
            : null,
        forceStandardized: json['forceStandardized'] != null
            ? (json['forceStandardized'] as num).toDouble()
            : null,
      );
}
