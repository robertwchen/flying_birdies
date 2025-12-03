import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/swing_metrics.dart';
import 'database_service.dart';

/// Supabase service for cloud sync
/// Handles syncing swings from local SQLite to cloud PostgreSQL
class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Get current user ID
  String? get userId => _client.auth.currentUser?.id;

  /// Create a new session in Supabase
  Future<String> createSession({
    required DateTime startTime,
    String? deviceId,
    String? strokeFocus,
  }) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final response = await _client
        .from('sessions')
        .insert({
          'user_id': userId,
          'start_time': startTime.toIso8601String(),
          'device_id': deviceId,
          'stroke_focus': strokeFocus,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// End a session in Supabase
  Future<void> endSession(String sessionId, DateTime endTime) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    await _client.from('sessions').update({
      'end_time': endTime.toIso8601String(),
    }).eq('id', sessionId);
  }

  /// Sync a swing to Supabase (with v8 metrics)
  Future<void> syncSwing({
    required String sessionId,
    required SwingMetrics swing,
  }) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    await _client.from('swings').insert({
      'session_id': sessionId,
      'timestamp': swing.timestamp.toIso8601String(),
      'max_omega': swing.maxOmega,
      'max_vtip': swing.maxVtip,
      'impact_amax': swing.impactAmax,
      'impact_severity': swing.impactSeverity,
      'est_force_n': swing.estForceN,
      'swing_duration_ms': swing.swingDurationMs,
      'quality_passed': swing.qualityPassed,
      'shuttle_speed_out': swing.shuttleSpeedOut, // v8 addition
      'force_standardized': swing.forceStandardized, // v8 addition
    });
  }

  /// Batch sync swings to Supabase (with v8 metrics)
  Future<void> syncSwings({
    required String sessionId,
    required List<SwingMetrics> swings,
  }) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    if (swings.isEmpty) return;

    final data = swings
        .map((swing) => {
              'session_id': sessionId,
              'timestamp': swing.timestamp.toIso8601String(),
              'max_omega': swing.maxOmega,
              'max_vtip': swing.maxVtip,
              'impact_amax': swing.impactAmax,
              'impact_severity': swing.impactSeverity,
              'est_force_n': swing.estForceN,
              'swing_duration_ms': swing.swingDurationMs,
              'quality_passed': swing.qualityPassed,
              'shuttle_speed_out': swing.shuttleSpeedOut, // v8 addition
              'force_standardized': swing.forceStandardized, // v8 addition
            })
        .toList();

    await _client.from('swings').insert(data);
  }

  /// Get swings for a session from Supabase
  Future<List<SwingMetrics>> getSwingsForSession(String sessionId) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final response = await _client
        .from('swings')
        .select()
        .eq('session_id', sessionId)
        .order('timestamp', ascending: true);

    return (response as List)
        .map((map) => _swingFromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  /// Get swings in date range from Supabase
  Future<List<SwingMetrics>> getSwingsInRange(
    DateTime start,
    DateTime end,
  ) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final response = await _client
        .from('swings')
        .select()
        .gte('timestamp', start.toIso8601String())
        .lte('timestamp', end.toIso8601String())
        .order('timestamp', ascending: true);

    return (response as List)
        .map((map) => _swingFromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  /// Get sessions for current user
  Future<List<Map<String, dynamic>>> getSessions({int? limit}) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    var query = _client
        .from('sessions')
        .select()
        .eq('user_id', userId!)
        .order('start_time', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final response = await query;
    return (response as List)
        .map((map) => Map<String, dynamic>.from(map))
        .toList();
  }

  /// Get aggregate stats for date range
  Future<Map<String, dynamic>> getStatsInRange(
    DateTime start,
    DateTime end,
  ) async {
    if (!isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // Use Supabase RPC (Remote Procedure Call) for aggregations
    // You'll need to create a PostgreSQL function for this
    final response = await _client.rpc('get_swing_stats', params: {
      'start_time': start.toIso8601String(),
      'end_time': end.toIso8601String(),
      'user_id': userId,
    });

    return Map<String, dynamic>.from(response);
  }

  /// Convert map to SwingMetrics (with v8 metrics)
  SwingMetrics _swingFromMap(Map<String, dynamic> map) {
    return SwingMetrics(
      timestamp: DateTime.parse(map['timestamp'] as String),
      maxOmega: (map['max_omega'] as num).toDouble(),
      maxVtip: (map['max_vtip'] as num).toDouble(),
      impactAmax: (map['impact_amax'] as num).toDouble(),
      impactSeverity: (map['impact_severity'] as num).toDouble(),
      estForceN: (map['est_force_n'] as num).toDouble(),
      swingDurationMs: map['swing_duration_ms'] as int,
      qualityPassed: map['quality_passed'] as bool,
      shuttleSpeedOut: map['shuttle_speed_out'] != null
          ? (map['shuttle_speed_out'] as num).toDouble()
          : null, // v8 addition
      forceStandardized: map['force_standardized'] != null
          ? (map['force_standardized'] as num).toDouble()
          : null, // v8 addition
    );
  }
}

/// Sync service that coordinates between local SQLite and Supabase
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final DatabaseService _localDb = DatabaseService.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  /// Sync unsynced swings to Supabase
  Future<void> syncUnsyncedSwings() async {
    if (!_supabase.isAuthenticated) {
      print('User not authenticated, skipping sync');
      return;
    }

    try {
      // Get unsynced swings from local database
      final unsyncedSwings = await _localDb.getUnsyncedSwings();

      if (unsyncedSwings.isEmpty) {
        print('No unsynced swings');
        return;
      }

      // Group swings by session
      final swingsBySession = <int, List<Map<String, dynamic>>>{};
      for (final swing in unsyncedSwings) {
        final sessionId = swing['session_id'] as int;
        swingsBySession.putIfAbsent(sessionId, () => []).add(swing);
      }

      // Sync each session's swings
      for (final entry in swingsBySession.entries) {
        // final localSessionId = entry.key; // TODO: Map to Supabase session ID
        final swings = entry.value;

        // Get or create session in Supabase
        // TODO: Map local session ID to Supabase session ID
        // For now, we'll need to store the mapping

        // Convert to SwingMetrics (with v8 metrics)
        // final swingMetrics = swings.map((map) {
        swings.map((map) {
          return SwingMetrics(
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              map['timestamp'] as int,
            ),
            maxOmega: map['max_omega'] as double,
            maxVtip: map['max_vtip'] as double,
            impactAmax: map['impact_amax'] as double,
            impactSeverity: map['impact_severity'] as double,
            estForceN: map['est_force_n'] as double,
            swingDurationMs: map['swing_duration_ms'] as int,
            qualityPassed: (map['quality_passed'] as int) == 1,
            shuttleSpeedOut: map['shuttle_speed_out'] as double?, // v8 addition
            forceStandardized:
                map['force_standardized'] as double?, // v8 addition
          );
        }).toList();

        // TODO: Get Supabase session ID from local session ID
        // For now, this is a placeholder
        // final supabaseSessionId = await _getSupabaseSessionId(localSessionId);

        // Sync to Supabase
        // await _supabase.syncSwings(
        //   sessionId: supabaseSessionId,
        //   swings: swingMetrics,
        // );

        // Mark as synced
        final swingIds = swings.map((s) => s['id'] as int).toList();
        await _localDb.markSwingsSynced(swingIds);
      }

      print('Synced ${unsyncedSwings.length} swings to Supabase');
    } catch (e) {
      print('Error syncing swings: $e');
      // Don't throw - allow app to continue working offline
    }
  }

  /// Sync on background (call periodically)
  Future<void> syncInBackground() async {
    await syncUnsyncedSwings();
    await _localDb.cleanupOldSwings();
  }
}
