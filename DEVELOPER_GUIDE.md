# Developer Guide - Refactored Architecture

## Quick Start

### Getting Services

**Old Way (DON'T USE):**
```dart
final bleService = BleService.instance; // ❌ Singleton
```

**New Way (USE THIS):**
```dart
final bleService = context.read<IBleService>(); // ✅ Dependency Injection
```

### Available Services

```dart
// Core
final logger = context.read<ILogger>();

// Data Layer
final sessionRepo = context.read<ISessionRepository>();
final swingRepo = context.read<ISwingRepository>();

// Services
final bleService = context.read<IBleService>();
final analyticsService = context.read<IAnalyticsService>();
final sessionService = context.read<ISessionService>();
final syncService = context.read<ISyncService>();

// State Notifiers
final connectionNotifier = context.watch<ConnectionStateNotifier>();
final sessionNotifier = context.watch<SessionStateNotifier>();
final swingNotifier = context.watch<SwingDataNotifier>();
```

## Common Patterns

### 1. Listening to Connection State

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final connectionNotifier = context.watch<ConnectionStateNotifier>();
    final isConnected = connectionNotifier.isConnected;
    
    return Text(isConnected ? 'Connected' : 'Disconnected');
  }
}
```

### 2. Starting a Session

```dart
final sessionService = context.read<ISessionService>();
final sessionNotifier = context.read<SessionStateNotifier>();

// Start session
final sessionId = await sessionService.startSession(
  userId: 'user123',
  deviceId: 'device456',
  strokeFocus: 'Forehand',
);

// Update notifier
sessionNotifier.startSession(sessionId);
```

### 3. Recording a Swing

```dart
final sessionService = context.read<ISessionService>();
final sessionNotifier = context.read<SessionStateNotifier>();

// Record swing
await sessionService.recordSwing(sessionId, swingMetrics);

// Notifier automatically updates via event stream
```

### 4. Ending a Session

```dart
final sessionService = context.read<ISessionService>();
final sessionNotifier = context.read<SessionStateNotifier>();

// End session
await sessionService.endSession(sessionId);

// Update notifier
sessionNotifier.endSession();

// Progress tab will automatically update!
```

### 5. Syncing Data

```dart
final syncService = context.read<ISyncService>();

// Sync specific session
await syncService.syncSession(localSessionId);

// Sync all pending
await syncService.syncAllPending();

// Enable auto-sync
await syncService.enableAutoSync();
```

### 6. Listening to Sync Status

```dart
final syncService = context.read<ISyncService>();

StreamBuilder<SyncStatus>(
  stream: syncService.syncStatusStream,
  builder: (context, snapshot) {
    final status = snapshot.data;
    if (status?.isSyncing == true) {
      return CircularProgressIndicator();
    }
    if (status?.error != null) {
      return Text('Error: ${status!.error}');
    }
    return Text('${status?.pendingCount ?? 0} pending');
  },
)
```

### 7. Querying Sessions

```dart
final sessionService = context.read<ISessionService>();

// Get recent sessions
final sessions = await sessionService.getRecentSessions(limit: 50);

// Get session detail
final detail = await sessionService.getSessionDetail(sessionId);
```

### 8. Querying Swings

```dart
final swingRepo = context.read<ISwingRepository>();

// Get swings for session
final swings = await swingRepo.getSwingsForSession(sessionId);

// Get swings in date range
final start = DateTime.now().subtract(Duration(days: 7));
final end = DateTime.now();
final swings = await swingRepo.getSwingsInRange(start, end);

// Get stats
final stats = await swingRepo.getStatsInRange(start, end);
```

## Error Handling

### Catching Typed Exceptions

```dart
try {
  await sessionService.startSession(...);
} on DatabaseException catch (e) {
  logger.error('Database error', error: e);
  // Handle database error
} on BleException catch (e) {
  logger.error('Bluetooth error', error: e);
  // Handle BLE error
} on SyncException catch (e) {
  logger.error('Sync error', error: e);
  // Handle sync error
} catch (e) {
  logger.error('Unknown error', error: e);
  // Handle unknown error
}
```

### Exception Properties

```dart
final exception = DatabaseException(
  'Failed to save session',
  'createSession',
  context: 'userId: user123',
  originalError: sqlError,
  stackTrace: stackTrace,
);

print(exception.message);        // 'Failed to save session'
print(exception.operation);      // 'createSession'
print(exception.context);        // 'userId: user123'
print(exception.originalError);  // Original SQL error
print(exception.stackTrace);     // Stack trace
```

## State Management

### When to use `read` vs `watch`

**Use `context.read<T>()`:**
- In event handlers (onPressed, onTap, etc.)
- When you only need to call methods
- When you don't need to rebuild on changes

**Use `context.watch<T>()`:**
- In build methods
- When you need to rebuild on state changes
- When displaying state in UI

```dart
// ✅ Good
ElevatedButton(
  onPressed: () {
    final service = context.read<ISessionService>(); // read in handler
    service.startSession(...);
  },
  child: Text('Start'),
)

// ✅ Good
Widget build(BuildContext context) {
  final notifier = context.watch<SessionStateNotifier>(); // watch in build
  return Text('Active: ${notifier.hasActiveSession}');
}

// ❌ Bad
ElevatedButton(
  onPressed: () {
    final notifier = context.watch<SessionStateNotifier>(); // watch in handler
    // This will cause unnecessary rebuilds!
  },
  child: Text('Start'),
)
```

## Testing

### Unit Testing with Mocks

```dart
// Create mock
class MockSessionService extends Mock implements ISessionService {}

// Use in test
test('should start session', () async {
  final mockService = MockSessionService();
  when(mockService.startSession(...)).thenAnswer((_) async => 123);
  
  // Test your widget/logic with mock
});
```

### Property-Based Testing

```dart
import 'package:test/test.dart';
import 'package:test_api/test_api.dart' as test_api;

test('session timestamps should be ordered', () {
  // Generate random sessions
  final sessions = generateRandomSessions(100);
  
  // Save to database
  for (final session in sessions) {
    await repo.createSession(session);
  }
  
  // Query back
  final retrieved = await repo.getRecentSessions();
  
  // Verify ordering
  for (int i = 0; i < retrieved.length - 1; i++) {
    expect(
      retrieved[i].startTime.isAfter(retrieved[i + 1].startTime),
      isTrue,
    );
  }
});
```

## Logging

### Log Levels

```dart
final logger = context.read<ILogger>();

logger.debug('Debug message', context: {'key': 'value'});
logger.info('Info message', context: {'key': 'value'});
logger.warning('Warning message', context: {'key': 'value'});
logger.error('Error message', error: exception, stackTrace: stackTrace);
```

### Log Context

Always provide context for better debugging:

```dart
logger.info('Starting session', context: {
  'userId': userId,
  'deviceId': deviceId,
  'strokeFocus': strokeFocus,
});
```

## Database

### Migrations

Database migrations are automatic. Current version: 2

**Version 1 → 2:**
- Added `cloud_session_id` column to sessions
- Added `synced` column to sessions and swings

### Transactions

```dart
final db = await dbHelper.database;
await db.transaction((txn) async {
  // All operations in transaction
  await txn.insert('sessions', sessionData);
  await txn.insert('swings', swingData);
  // Automatically commits or rolls back on error
});
```

## Best Practices

### 1. Always Use Interfaces

```dart
// ✅ Good
final ISessionService sessionService;

// ❌ Bad
final SessionService sessionService;
```

### 2. Inject Dependencies

```dart
// ✅ Good
class MyService {
  final ILogger logger;
  final ISessionRepository repo;
  
  MyService(this.logger, this.repo);
}

// ❌ Bad
class MyService {
  final logger = ConsoleLogger();
  final repo = SessionRepository.instance;
}
```

### 3. Handle Errors Properly

```dart
// ✅ Good
try {
  await service.doSomething();
} on SpecificException catch (e) {
  logger.error('Failed to do something', error: e);
  // Show user-friendly message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Operation failed')),
  );
}

// ❌ Bad
try {
  await service.doSomething();
} catch (e) {
  print(e); // Don't use print!
}
```

### 4. Use Notifiers for UI Updates

```dart
// ✅ Good
sessionNotifier.endSession();
// Progress tab automatically updates

// ❌ Bad
setState(() {
  // Manually update every widget
});
```

### 5. Dispose Resources

```dart
@override
void dispose() {
  _subscription?.cancel();
  _controller?.dispose();
  super.dispose();
}
```

## Common Issues

### Issue: "Provider not found"

**Solution:** Make sure you're using the context that has access to providers:

```dart
// ❌ Bad - using context before MultiProvider
final service = context.read<IService>();

// ✅ Good - using context inside MultiProvider
MultiProvider(
  providers: ServiceLocator.createProviders(),
  child: Builder(
    builder: (context) {
      final service = context.read<IService>(); // ✅ Works!
      return MyApp();
    },
  ),
)
```

### Issue: "BuildContext used across async gap"

**Solution:** Check if widget is still mounted:

```dart
await someAsyncOperation();

if (!mounted) return; // ✅ Check before using context

ScaffoldMessenger.of(context).showSnackBar(...);
```

### Issue: "Notifier not updating UI"

**Solution:** Use `context.watch` instead of `context.read`:

```dart
// ❌ Bad
final notifier = context.read<MyNotifier>();

// ✅ Good
final notifier = context.watch<MyNotifier>();
```

## Resources

- **Architecture Diagram:** See `REFACTORING_COMPLETE.md`
- **Requirements:** `.kiro/specs/backend-refactor-frontend-integration/requirements.md`
- **Design:** `.kiro/specs/backend-refactor-frontend-integration/design.md`
- **Tasks:** `.kiro/specs/backend-refactor-frontend-integration/tasks.md`

## Need Help?

1. Check the interface documentation in `lib/core/interfaces/`
2. Look at existing implementations in `lib/services/`
3. Review tests in `test/` for usage examples
4. Check this guide for common patterns

---

**Happy Coding!** 🚀
