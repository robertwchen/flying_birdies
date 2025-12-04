import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core
import '../core/logger.dart';

// Data Layer
import '../data/database_helper.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/swing_repository.dart';

// Services
import '../services/ble_service.dart';
import '../services/analytics_service.dart';
import '../services/session_service.dart';
import '../services/sync_service.dart';
import '../services/connection_persistence_service.dart';

// Service Interfaces
import '../core/interfaces/i_ble_service.dart';
import '../core/interfaces/i_analytics_service.dart';
import '../core/interfaces/i_session_service.dart';
import '../core/interfaces/i_sync_service.dart';
import '../core/interfaces/i_session_repository.dart';
import '../core/interfaces/i_swing_repository.dart';
import '../core/interfaces/i_connection_persistence_service.dart';

// State Management
import '../state/connection_state_notifier.dart';
import '../state/session_state_notifier.dart';
import '../state/swing_data_notifier.dart';
import '../state/player_settings_notifier.dart';

/// Service Locator for Dependency Injection
/// Sets up all providers for the app
class ServiceLocator {
  // Store SharedPreferences instance
  static SharedPreferences? _sharedPreferences;

  /// Initialize SharedPreferences (must be called before createProviders)
  static Future<void> initialize() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  /// Create all providers for the app
  static List<SingleChildWidget> createProviders() {
    if (_sharedPreferences == null) {
      throw StateError(
        'ServiceLocator.initialize() must be called before createProviders()',
      );
    }

    // Create logger
    final logger = ConsoleLogger('FlyingBirdies');

    // Create database helper
    final dbHelper = DatabaseHelper(logger);

    // Create repositories
    final sessionRepo = SessionRepository(dbHelper, logger);
    final swingRepo = SwingRepository(dbHelper, logger);

    // Create state notifiers first (needed by services)
    final connectionStateNotifier = ConnectionStateNotifier();
    final sessionStateNotifier = SessionStateNotifier();
    final swingDataNotifier = SwingDataNotifier();
    final playerSettingsNotifier = PlayerSettingsNotifier();

    // Create connection persistence service
    final connectionPersistenceService = ConnectionPersistenceService(
      _sharedPreferences!,
      logger,
    );

    // Create services (inject connectionStateNotifier into BleService)
    final bleService = BleService(
      logger,
      connectionStateNotifier: connectionStateNotifier,
    );
    final analyticsService = AnalyticsService(logger);
    final sessionService = SessionService(sessionRepo, swingRepo, logger);
    final syncService = SyncService(
      sessionRepo,
      swingRepo,
      Supabase.instance.client,
      logger,
    );

    return [
      // Core
      Provider<ILogger>.value(value: logger),

      // Data Layer
      Provider<DatabaseHelper>.value(value: dbHelper),
      Provider<ISessionRepository>.value(value: sessionRepo),
      Provider<ISwingRepository>.value(value: swingRepo),

      // Services (provide both concrete and interface types)
      Provider<BleService>.value(value: bleService),
      Provider<IBleService>.value(value: bleService),
      Provider<AnalyticsService>.value(value: analyticsService),
      Provider<IAnalyticsService>.value(value: analyticsService),
      Provider<SessionService>.value(value: sessionService),
      Provider<ISessionService>.value(value: sessionService),
      Provider<SyncService>.value(value: syncService),
      Provider<ISyncService>.value(value: syncService),
      Provider<ConnectionPersistenceService>.value(
        value: connectionPersistenceService,
      ),
      Provider<IConnectionPersistenceService>.value(
        value: connectionPersistenceService,
      ),

      // State Notifiers
      ChangeNotifierProvider<ConnectionStateNotifier>.value(
        value: connectionStateNotifier,
      ),
      ChangeNotifierProvider<SessionStateNotifier>.value(
        value: sessionStateNotifier,
      ),
      ChangeNotifierProvider<SwingDataNotifier>.value(
        value: swingDataNotifier,
      ),
      ChangeNotifierProvider<PlayerSettingsNotifier>.value(
        value: playerSettingsNotifier,
      ),
    ];
  }

  /// Dispose all services
  static void dispose(List<SingleChildWidget> providers) {
    // Services will be disposed when providers are disposed
    // This is handled automatically by Provider
  }
}
