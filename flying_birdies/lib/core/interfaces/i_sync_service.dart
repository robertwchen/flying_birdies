import 'dart:async';

/// Sync status information
class SyncStatus {
  final bool isSyncing;
  final int pendingCount;
  final int syncedCount;
  final String? error;

  SyncStatus({
    required this.isSyncing,
    required this.pendingCount,
    required this.syncedCount,
    this.error,
  });
}

/// Sync Service interface for dependency injection
abstract class ISyncService {
  /// Stream of sync status updates
  Stream<SyncStatus> get syncStatusStream;

  /// Sync a specific session
  Future<void> syncSession(int localSessionId);

  /// Sync all pending data
  Future<void> syncAllPending();

  /// Enable automatic background sync
  Future<void> enableAutoSync();

  /// Disable automatic background sync
  Future<void> disableAutoSync();

  /// Dispose resources
  void dispose();
}
