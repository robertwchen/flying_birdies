/// Database entity for swings
class SwingEntity {
  final int? id;
  final int sessionId;
  final DateTime timestamp;
  final double maxOmega;
  final double maxVtip;
  final double impactAmax;
  final double impactSeverity;
  final double estForceN;
  final int swingDurationMs;
  final bool qualityPassed;
  final double? shuttleSpeedOut;
  final double? forceStandardized;
  final bool synced;

  SwingEntity({
    this.id,
    required this.sessionId,
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
    this.synced = false,
  });

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'max_omega': maxOmega,
      'max_vtip': maxVtip,
      'impact_amax': impactAmax,
      'impact_severity': impactSeverity,
      'est_force_n': estForceN,
      'swing_duration_ms': swingDurationMs,
      'quality_passed': qualityPassed ? 1 : 0,
      'shuttle_speed_out': shuttleSpeedOut,
      'force_standardized': forceStandardized,
      'synced': synced ? 1 : 0,
    };
  }

  /// Create from database map
  factory SwingEntity.fromMap(Map<String, dynamic> map) {
    return SwingEntity(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      maxOmega: (map['max_omega'] as num).toDouble(),
      maxVtip: (map['max_vtip'] as num).toDouble(),
      impactAmax: (map['impact_amax'] as num).toDouble(),
      impactSeverity: (map['impact_severity'] as num).toDouble(),
      estForceN: (map['est_force_n'] as num).toDouble(),
      swingDurationMs: map['swing_duration_ms'] as int,
      qualityPassed: (map['quality_passed'] as int) == 1,
      shuttleSpeedOut: map['shuttle_speed_out'] != null
          ? (map['shuttle_speed_out'] as num).toDouble()
          : null,
      forceStandardized: map['force_standardized'] != null
          ? (map['force_standardized'] as num).toDouble()
          : null,
      synced: (map['synced'] as int?) == 1,
    );
  }

  /// Create a copy with updated fields
  SwingEntity copyWith({
    int? id,
    int? sessionId,
    DateTime? timestamp,
    double? maxOmega,
    double? maxVtip,
    double? impactAmax,
    double? impactSeverity,
    double? estForceN,
    int? swingDurationMs,
    bool? qualityPassed,
    double? shuttleSpeedOut,
    double? forceStandardized,
    bool? synced,
  }) {
    return SwingEntity(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      maxOmega: maxOmega ?? this.maxOmega,
      maxVtip: maxVtip ?? this.maxVtip,
      impactAmax: impactAmax ?? this.impactAmax,
      impactSeverity: impactSeverity ?? this.impactSeverity,
      estForceN: estForceN ?? this.estForceN,
      swingDurationMs: swingDurationMs ?? this.swingDurationMs,
      qualityPassed: qualityPassed ?? this.qualityPassed,
      shuttleSpeedOut: shuttleSpeedOut ?? this.shuttleSpeedOut,
      forceStandardized: forceStandardized ?? this.forceStandardized,
      synced: synced ?? this.synced,
    );
  }

  @override
  String toString() {
    return 'SwingEntity(id: $id, sessionId: $sessionId, timestamp: $timestamp, '
        'maxOmega: $maxOmega, maxVtip: $maxVtip, synced: $synced)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SwingEntity &&
        other.id == id &&
        other.sessionId == sessionId &&
        other.timestamp == timestamp &&
        other.maxOmega == maxOmega &&
        other.maxVtip == maxVtip &&
        other.impactAmax == impactAmax &&
        other.impactSeverity == impactSeverity &&
        other.estForceN == estForceN &&
        other.swingDurationMs == swingDurationMs &&
        other.qualityPassed == qualityPassed &&
        other.shuttleSpeedOut == shuttleSpeedOut &&
        other.forceStandardized == forceStandardized &&
        other.synced == synced;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      sessionId,
      timestamp,
      maxOmega,
      maxVtip,
      impactAmax,
      impactSeverity,
      estForceN,
      swingDurationMs,
      qualityPassed,
      shuttleSpeedOut,
      forceStandardized,
      synced,
    );
  }
}
