# Feedback Analytics Fix Plan

## Problem Identified

The session feedback page shows **HARDCODED** values for:
- Impact Force (avg/max)
- Acceleration (avg/max)  
- Swing Force (avg/max)

### Root Cause

In `history_tab.dart` and `feedback_tab.dart`, the `SessionSummary` model reuses placeholder fields:
- `sweetSpotPct` → being used as Impact Force (hardcoded to 0.6)
- `consistencyPct` → being used as Acceleration (hardcoded to 0.7)

These should be calculated from REAL swing data stored in the database.

## Database Schema

Swings table has ALL the data we need:
```sql
CREATE TABLE swings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL,
  timestamp INTEGER NOT NULL,
  max_omega REAL NOT NULL,           -- rad/s (angular velocity)
  max_vtip REAL NOT NULL,             -- m/s (tip speed) ✅ USED
  impact_amax REAL NOT NULL,          -- m/s² (acceleration) ❌ NOT USED
  impact_severity REAL NOT NULL,      -- RMS-like proxy
  est_force_n REAL NOT NULL,          -- N (estimated force) ❌ NOT USED
  swing_duration_ms INTEGER NOT NULL,
  quality_passed INTEGER NOT NULL,
  shuttle_speed_out REAL,
  force_standardized REAL,
  synced INTEGER DEFAULT 0,
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
)
```

## Fix Strategy

### 1. Update SessionSummary Model
Add proper fields for the 4 metrics:
```dart
class SessionSummary {
  final String id;
  final DateTime date;
  final String title;
  
  // Speed metrics (already working)
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  
  // NEW: Force metrics (from est_force_n)
  final double avgForceN;
  final double maxForceN;
  
  // NEW: Acceleration metrics (from impact_amax)
  final double avgAccelMs2;
  final double maxAccelMs2;
  
  final int hits;
  
  // REMOVE: sweetSpotPct, consistencyPct (placeholders)
}
```

### 2. Update history_tab.dart
Calculate real averages and maxes from swing data:
```dart
// Calculate from REAL swing data
final avgSpeed = swings.map((s) => s.maxVtip * 3.6).reduce((a, b) => a + b) / swings.length;
final maxSpeed = swings.map((s) => s.maxVtip * 3.6).reduce((a, b) => a > b ? a : b);

// NEW: Calculate force metrics
final avgForce = swings.map((s) => s.estForceN).reduce((a, b) => a + b) / swings.length;
final maxForce = swings.map((s) => s.estForceN).reduce((a, b) => a > b ? a : b);

// NEW: Calculate acceleration metrics
final avgAccel = swings.map((s) => s.impactAmax).reduce((a, b) => a + b) / swings.length;
final maxAccel = swings.map((s) => s.impactAmax).reduce((a, b) => a > b ? a : b);

sessions.add(SessionSummary(
  id: sessionId.toString(),
  date: startTime,
  title: sessionMap['stroke_focus'] as String? ?? 'Training',
  avgSpeedKmh: avgSpeed,
  maxSpeedKmh: maxSpeed,
  avgForceN: avgForce,      // ✅ REAL DATA
  maxForceN: maxForce,      // ✅ REAL DATA
  avgAccelMs2: avgAccel,    // ✅ REAL DATA
  maxAccelMs2: maxAccel,    // ✅ REAL DATA
  hits: swings.length,
));
```

### 3. Update feedback_tab.dart
Use real values instead of placeholders:
```dart
// OLD (WRONG):
final impactAvg = s.sweetSpotPct * 100;  // hardcoded 0.6
final accelAvg = s.consistencyPct * 100;  // hardcoded 0.7

// NEW (CORRECT):
final impactAvg = s.avgForceN;   // from real swing data
final impactMax = s.maxForceN;   // from real swing data
final accelAvg = s.avgAccelMs2;  // from real swing data
final accelMax = s.maxAccelMs2;  // from real swing data
```

### 4. Update SessionService
The `getRecentSessions()` and `getSessionDetail()` methods also need to calculate these metrics:
```dart
// In session_service.dart
if (swings.isNotEmpty) {
  avgSpeed = swings.map((s) => s.maxVtip * 3.6).reduce((a, b) => a + b) / swings.length;
  avgForce = swings.map((s) => s.estForceN).reduce((a, b) => a + b) / swings.length;
  maxSpeed = swings.map((s) => s.maxVtip * 3.6).reduce((a, b) => a > b ? a : b);
  maxForce = swings.map((s) => s.estForceN).reduce((a, b) => a > b ? a : b);
  avgAccel = swings.map((s) => s.impactAmax).reduce((a, b) => a + b) / swings.length;
  maxAccel = swings.map((s) => s.impactAmax).reduce((a, b) => a > b ? a : b);
}
```

## Files to Modify

1. ✅ `lib/features/history/history_tab.dart` - Update SessionSummary creation
2. ✅ `lib/features/feedback/feedback_tab.dart` - Use real values
3. ✅ `lib/services/session_service.dart` - Update SessionSummary creation
4. ✅ `lib/core/interfaces/i_session_service.dart` - Update SessionSummary model

## Expected Result

After fix:
- ✅ Avg/Max Swing Speed: Calculated from `max_vtip` (already working)
- ✅ Avg/Max Impact Force: Calculated from `est_force_n` (FIXED)
- ✅ Avg/Max Acceleration: Calculated from `impact_amax` (FIXED)
- ✅ Avg/Max Swing Force: Calculated from swing data (FIXED)

All metrics will be **PER SESSION** and calculated from **DETECTED SWINGS ONLY**.
