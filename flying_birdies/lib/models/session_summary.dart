/// Canonical session summary model used across all layers
///
/// This model represents aggregated session data with calculated metrics
/// from all swings in the session. Used by both service layer and UI.
class SessionSummary {
  final int sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final String? strokeFocus;

  // Swing metrics
  final int swingCount;

  // Speed metrics (from max_vtip in database)
  final double avgSpeedKmh; // km/h
  final double maxSpeedKmh; // km/h

  // Force metrics (from est_force_n in database)
  final double avgForceN; // N
  final double maxForceN; // N

  // Acceleration metrics (from impact_amax in database)
  final double avgAccelMs2; // m/s²
  final double maxAccelMs2; // m/s²

  final int durationMinutes;

  const SessionSummary({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    this.strokeFocus,
    required this.swingCount,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.avgForceN,
    required this.maxForceN,
    required this.avgAccelMs2,
    required this.maxAccelMs2,
    required this.durationMinutes,
  });

  /// For UI display - format date
  DateTime get date => startTime;

  /// For UI display - session title
  String get title => strokeFocus ?? 'Training';

  /// For UI display - hit count
  int get hits => swingCount;

  /// For UI display - session ID as string
  String get id => sessionId.toString();

  @override
  String toString() {
    return 'SessionSummary(sessionId: $sessionId, startTime: $startTime, '
        'swingCount: $swingCount, avgSpeed: $avgSpeedKmh km/h, '
        'avgForce: $avgForceN N, avgAccel: $avgAccelMs2 m/s²)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SessionSummary &&
        other.sessionId == sessionId &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.strokeFocus == strokeFocus &&
        other.swingCount == swingCount &&
        other.avgSpeedKmh == avgSpeedKmh &&
        other.maxSpeedKmh == maxSpeedKmh &&
        other.avgForceN == avgForceN &&
        other.maxForceN == maxForceN &&
        other.avgAccelMs2 == avgAccelMs2 &&
        other.maxAccelMs2 == maxAccelMs2 &&
        other.durationMinutes == durationMinutes;
  }

  @override
  int get hashCode {
    return Object.hash(
      sessionId,
      startTime,
      endTime,
      strokeFocus,
      swingCount,
      avgSpeedKmh,
      maxSpeedKmh,
      avgForceN,
      maxForceN,
      avgAccelMs2,
      maxAccelMs2,
      durationMinutes,
    );
  }
}
