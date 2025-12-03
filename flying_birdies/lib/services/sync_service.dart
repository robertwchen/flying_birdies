import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/interfaces/i_sync_service.dart';
import '../core/interfaces/i_session_repository.dart';
import '../core/interfaces/i_swing_repository.dart';
import '../core/logger.dart';
import '../core/exceptions.dart';

/// Sync Service for syncing local data to Supabase
class SyncService implements ISyncService {
  final ISessionRepository _sessionRepo;
  final ISwingRepository _swingRepo;
  final SupabaseClient _supabase;
  final ILogger _logger;

  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();

  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  SyncService(
    this._sessionRepo,
    this._swingRepo,
    this._supabase,
    this._logger,
  );

  @override
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  @override
  Future<void> syncSession(int localSessionId) async {
    if (_isSyncing) {
      _logger.warning('Sync already in progress');
      return;
    }

    try {
      _isSyncing = true;
      _emitStatus(isSyncing: true, pendingCount: 1, syncedCount: 0);

      _logger.info('Syncing session', context: {'sessionId': localSessionId});

      // Check authentication
      if (_supabase.auth.currentUser == null) {
        throw SyncException(
          'User not authenticated',
          isRetryable: false,
          context: 'syncSession',
        );
      }

      // Get local session
      final session = await _sessionRepo.getSession(localSessionId);
      if (session == null) {
        throw SyncException(
          'Session not found',
          isRetryable: false,
          context: 'sessionId: $localSessionId',
        );
      }

      // Check if session already has cloud ID
      String cloudSessionId;
      if (session.cloudSessionId != null) {
        cloudSessionId = session.cloudSessionId!;
        _logger.debug('Using existing cloud session ID',
            context: {'cloudSessionId': cloudSessionId});
      } else {
        // Create session in Supabase
        cloudSessionId = await _createCloudSession(session);
        _logger.info('Created cloud session',
            context: {'cloudSessionId': cloudSessionId});

        // Update local session with cloud ID
        final updatedSession = session.copyWith(
          cloudSessionId: cloudSessionId,
          synced: true,
        );
        await _sessionRepo.updateSession(localSessionId, updatedSession);
      }

      // Get unsynced swings for this session
      final swings = await _swingRepo.getSwingsForSession(localSessionId);
      final unsyncedSwings = swings.where((s) => !s.synced).toList();

      if (unsyncedSwings.isEmpty) {
        _logger.debug('No unsynced swings for session');
        _emitStatus(isSyncing: false, pendingCount: 0, syncedCount: 0);
        return;
      }

      // Sync swings in batches
      await _syncSwingsBatch(cloudSessionId, unsyncedSwings);

      _logger.info('Session synced successfully',
          context: {'swingCount': unsyncedSwings.length});
      _emitStatus(
          isSyncing: false,
          pendingCount: 0,
          syncedCount: unsyncedSwings.length);
    } catch (e, stackTrace) {
      _logger.error('Failed to sync session', error: e, stackTrace: stackTrace);
      _emitStatus(
          isSyncing: false,
          pendingCount: 0,
          syncedCount: 0,
          error: e.toString());

      if (e is SyncException) rethrow;

      throw SyncException(
        'Failed to sync session',
        isRetryable: _isRetryableError(e),
        context: 'sessionId: $localSessionId',
        originalError: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Future<void> syncAllPending() async {
    if (_isSyncing) {
      _logger.warning('Sync already in progress');
      return;
    }

    try {
      _isSyncing = true;
      _logger.info('Starting sync of all pending data');

      // Check authentication
      if (_supabase.auth.currentUser == null) {
        throw SyncException(
          'User not authenticated',
          isRetryable: false,
          context: 'syncAllPending',
        );
      }

      // Get all sessions that need syncing
      final recentSessions = await _sessionRepo.getRecentSessions(limit: 100);
      final unsyncedSessions = recentSessions
          .where((s) => !s.synced || s.cloudSessionId == null)
          .toList();

      if (unsyncedSessions.isEmpty) {
        _logger.debug('No unsynced sessions');
        _emitStatus(isSyncing: false, pendingCount: 0, syncedCount: 0);
        return;
      }

      _emitStatus(
          isSyncing: true,
          pendingCount: unsyncedSessions.length,
          syncedCount: 0);

      int syncedCount = 0;
      for (final session in unsyncedSessions) {
        try {
          await syncSession(session.id!);
          syncedCount++;
          _emitStatus(
              isSyncing: true,
              pendingCount: unsyncedSessions.length - syncedCount,
              syncedCount: syncedCount);
        } catch (e) {
          _logger.error('Failed to sync session',
              error: e, context: {'sessionId': session.id});
          // Continue with other sessions
        }
      }

      _logger.info('Sync completed', context: {
        'syncedCount': syncedCount,
        'total': unsyncedSessions.length
      });
      _emitStatus(isSyncing: false, pendingCount: 0, syncedCount: syncedCount);
    } catch (e, stackTrace) {
      _logger.error('Failed to sync all pending',
          error: e, stackTrace: stackTrace);
      _emitStatus(
          isSyncing: false,
          pendingCount: 0,
          syncedCount: 0,
          error: e.toString());

      if (e is SyncException) rethrow;

      throw SyncException(
        'Failed to sync all pending data',
        isRetryable: _isRetryableError(e),
        originalError: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Future<void> enableAutoSync() async {
    _logger.info('Enabling auto sync');

    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      _logger.debug('Auto sync triggered');
      try {
        await syncAllPending();
      } catch (e) {
        _logger.error('Auto sync failed', error: e);
        // Don't throw - allow app to continue
      }
    });

    _logger.info('Auto sync enabled');
  }

  @override
  Future<void> disableAutoSync() async {
    _logger.info('Disabling auto sync');
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _logger.info('Auto sync disabled');
  }

  /// Create a session in Supabase
  Future<String> _createCloudSession(dynamic session) async {
    try {
      final response = await _supabase
          .from('sessions')
          .insert({
            'user_id': _supabase.auth.currentUser!.id,
            'start_time': session.startTime.toIso8601String(),
            'end_time': session.endTime?.toIso8601String(),
            'device_id': session.deviceId,
            'stroke_focus': session.strokeFocus,
          })
          .select('id')
          .single();

      return response['id'] as String;
    } catch (e, stackTrace) {
      _logger.error('Failed to create cloud session',
          error: e, stackTrace: stackTrace);
      throw SyncException(
        'Failed to create cloud session',
        isRetryable: _isRetryableError(e),
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Sync swings in batches
  Future<void> _syncSwingsBatch(
      String cloudSessionId, List<dynamic> swings) async {
    const batchSize = 50;

    for (int i = 0; i < swings.length; i += batchSize) {
      final batch = swings.skip(i).take(batchSize).toList();

      try {
        // Convert to Supabase format
        final data = batch.map((swing) {
          return {
            'session_id': cloudSessionId,
            'timestamp': swing.timestamp.toIso8601String(),
            'max_omega': swing.maxOmega,
            'max_vtip': swing.maxVtip,
            'impact_amax': swing.impactAmax,
            'impact_severity': swing.impactSeverity,
            'est_force_n': swing.estForceN,
            'swing_duration_ms': swing.swingDurationMs,
            'quality_passed': swing.qualityPassed,
            'shuttle_speed_out': swing.shuttleSpeedOut,
            'force_standardized': swing.forceStandardized,
          };
        }).toList();

        // Insert batch
        await _supabase.from('swings').insert(data);

        // Mark as synced
        final swingIds = batch.map((s) => s.id! as int).toList();
        await _swingRepo.markSwingsSynced(swingIds);

        _logger.debug('Synced batch',
            context: {'batchSize': batch.length, 'batchIndex': i ~/ batchSize});
      } catch (e, stackTrace) {
        _logger.error('Failed to sync batch',
            error: e,
            stackTrace: stackTrace,
            context: {'batchIndex': i ~/ batchSize});

        // Retry with exponential backoff
        await _retryWithBackoff(() async {
          final data = batch.map((swing) {
            return {
              'session_id': cloudSessionId,
              'timestamp': swing.timestamp.toIso8601String(),
              'max_omega': swing.maxOmega,
              'max_vtip': swing.maxVtip,
              'impact_amax': swing.impactAmax,
              'impact_severity': swing.impactSeverity,
              'est_force_n': swing.estForceN,
              'swing_duration_ms': swing.swingDurationMs,
              'quality_passed': swing.qualityPassed,
              'shuttle_speed_out': swing.shuttleSpeedOut,
              'force_standardized': swing.forceStandardized,
            };
          }).toList();

          await _supabase.from('swings').insert(data);

          final swingIds = batch.map((s) => s.id! as int).toList();
          await _swingRepo.markSwingsSynced(swingIds);
        });
      }
    }
  }

  /// Retry with exponential backoff
  Future<void> _retryWithBackoff(Future<void> Function() action,
      {int maxRetries = 3}) async {
    int retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        await action();
        return;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          rethrow;
        }

        final delayMs = 1000 * (1 << retryCount); // Exponential: 2s, 4s, 8s
        _logger.warning('Retry attempt $retryCount after ${delayMs}ms');
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  /// Check if error is retryable
  bool _isRetryableError(dynamic error) {
    // Network errors are retryable
    if (error.toString().contains('SocketException') ||
        error.toString().contains('TimeoutException') ||
        error.toString().contains('NetworkException')) {
      return true;
    }

    // Supabase rate limit errors are retryable
    if (error.toString().contains('429') ||
        error.toString().contains('rate limit')) {
      return true;
    }

    // Server errors (5xx) are retryable
    if (error.toString().contains('500') ||
        error.toString().contains('502') ||
        error.toString().contains('503')) {
      return true;
    }

    return false;
  }

  /// Emit sync status
  void _emitStatus({
    required bool isSyncing,
    required int pendingCount,
    required int syncedCount,
    String? error,
  }) {
    _syncStatusController.add(SyncStatus(
      isSyncing: isSyncing,
      pendingCount: pendingCount,
      syncedCount: syncedCount,
      error: error,
    ));
  }

  @override
  void dispose() {
    _logger.info('Disposing SyncService');
    _autoSyncTimer?.cancel();
    _syncStatusController.close();
  }
}
