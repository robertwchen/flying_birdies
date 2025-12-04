# Critical Fixes Implementation Plan

## Problem: Duplicate SessionSummary Models

### Current State:
- **Service Layer Model** (`i_session_service.dart`): Has `int sessionId`, `double avgSpeed`, `double avgForce`
- **UI Layer Model** (`history_tab.dart`): Has `String id`, `double avgSpeedKmh`, `double avgForceN`

### Solution: Create ONE Canonical Model

## Step 1: Create Canonical SessionSummary Model

**Location:** `lib/models/session_summary.dart`

```dart
/// Canonical session summary model used across all layers
class SessionSummary {
  final int sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final String? strokeFocus;
  
  // Metrics
  final int swingCount;
  final double avgSpeedKmh;      // km/h
  final double maxSpeedKmh;      // km/h
  final double avgForceN;        // N
  final double maxForceN;        // N
  final double avgAccelMs2;      // m/s²
  final double maxAccelMs2;      // m/s²
  
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
}
```

## Step 2: Update Service Layer

**File:** `lib/core/interfaces/i_session_service.dart`

- Remove old SessionSummary class
- Import canonical model: `import '../../models/session_summary.dart';`

**File:** `lib/services/session_service.dart`

- Update to use canonical model
- Update calculations to include all fields (avgAccelMs2, maxAccelMs2)

## Step 3: Update UI Layer

**File:** `lib/features/history/history_tab.dart`

- Remove duplicate SessionSummary class
- Import canonical model
- Use `ISessionService.getRecentSessions()` instead of direct DB access
- Remove manual calculations

**File:** `lib/features/feedback/feedback_tab.dart`

- Import canonical model
- Update all references

## Step 4: Remove Direct DB Access

**Before:**
```dart
class _HistoryTabState extends State<HistoryTab> {
  final DatabaseService _db = DatabaseService.instance;
  
  Future<void> _loadAllSessions() async {
    final sessionMaps = await _db.getSessions(limit: 100);
    // Manual calculations...
  }
}
```

**After:**
```dart
class _HistoryTabState extends State<HistoryTab> {
  late final ISessionService _sessionService;
  
  @override
  void initState() {
    super.initState();
    _sessionService = context.read<ISessionService>();
  }
  
  Future<void> _loadAllSessions() async {
    final sessions = await _sessionService.getRecentSessions(limit: 100);
    // Just display - no calculations!
  }
}
```

## Step 5: Delete Unused Code

- Delete `lib/services/mock_metrics.dart`
- Clean up commented Supabase code

## Implementation Order

1. ✅ Create canonical SessionSummary model
2. ✅ Update i_session_service.dart
3. ✅ Update session_service.dart (add missing fields)
4. ✅ Update history_tab.dart (use service, remove duplicate model)
5. ✅ Update feedback_tab.dart (use canonical model)
6. ✅ Delete mock_metrics.dart
7. ✅ Test everything

## Expected Outcome

- ONE SessionSummary model used everywhere
- NO direct database access from UI
- NO duplicate calculation logic
- Clean separation of concerns
- Easier to maintain and test
