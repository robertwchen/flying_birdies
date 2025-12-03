/// Database entity for sessions
class SessionEntity {
  final int? id;
  final String? userId;
  final DateTime startTime;
  final DateTime? endTime;
  final String? deviceId;
  final String? strokeFocus;
  final String? cloudSessionId; // For sync mapping
  final bool synced;
  final DateTime createdAt;

  SessionEntity({
    this.id,
    this.userId,
    required this.startTime,
    this.endTime,
    this.deviceId,
    this.strokeFocus,
    this.cloudSessionId,
    this.synced = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'device_id': deviceId,
      'stroke_focus': strokeFocus,
      'cloud_session_id': cloudSessionId,
      'synced': synced ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create from database map
  factory SessionEntity.fromMap(Map<String, dynamic> map) {
    return SessionEntity(
      id: map['id'] as int?,
      userId: map['user_id'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: map['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int)
          : null,
      deviceId: map['device_id'] as String?,
      strokeFocus: map['stroke_focus'] as String?,
      cloudSessionId: map['cloud_session_id'] as String?,
      synced: (map['synced'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Create a copy with updated fields
  SessionEntity copyWith({
    int? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    String? deviceId,
    String? strokeFocus,
    String? cloudSessionId,
    bool? synced,
    DateTime? createdAt,
  }) {
    return SessionEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      deviceId: deviceId ?? this.deviceId,
      strokeFocus: strokeFocus ?? this.strokeFocus,
      cloudSessionId: cloudSessionId ?? this.cloudSessionId,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'SessionEntity(id: $id, userId: $userId, startTime: $startTime, '
        'endTime: $endTime, deviceId: $deviceId, strokeFocus: $strokeFocus, '
        'cloudSessionId: $cloudSessionId, synced: $synced)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SessionEntity &&
        other.id == id &&
        other.userId == userId &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.deviceId == deviceId &&
        other.strokeFocus == strokeFocus &&
        other.cloudSessionId == cloudSessionId &&
        other.synced == synced;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      startTime,
      endTime,
      deviceId,
      strokeFocus,
      cloudSessionId,
      synced,
    );
  }
}
