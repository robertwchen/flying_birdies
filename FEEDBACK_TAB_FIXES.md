# Feedback Tab Fixes - All References to Update

## Lines to Fix in feedback_tab.dart

### 1. Line 443-445: _coachLines function
```dart
// OLD:
final double impactAvg = cur.sweetSpotPct * 100;
final double accelAvg = cur.consistencyPct * 100;

// NEW:
final double impactAvg = cur.avgForceN;
final double accelAvg = cur.avgAccelMs2;
```

### 2. Line 452-455: _coachLines deltas
```dart
// OLD:
final double dImp = hasOther ? impactAvg - other.sweetSpotPct * 100 : 0.0;
final double dAccel = hasOther ? accelAvg - other.consistencyPct * 100 : 0.0;

// NEW:
final double dImp = hasOther ? impactAvg - other.avgForceN : 0.0;
final double dAccel = hasOther ? accelAvg - other.avgAccelMs2 : 0.0;
```

### 3. Line 524-526: _deltas function
```dart
// OLD:
'Impact force': (cur.sweetSpotPct - other.sweetSpotPct) * 100,
'Acceleration': (cur.consistencyPct - other.consistencyPct) * 100,

// NEW:
'Impact force': cur.avgForceN - other.avgForceN,
'Acceleration': cur.avgAccelMs2 - other.avgAccelMs2,
```

### 4. Line 533-535: _tipsFor function
```dart
// OLD:
final impact = s.sweetSpotPct * 100; // TEMP mapping
final accel = s.consistencyPct * 100; // TEMP mapping

// NEW:
final impact = s.avgForceN;
final accel = s.avgAccelMs2;
```

### 5. Line 738-740: _MetricGrid widget
```dart
// OLD:
final impactAvg = s.sweetSpotPct * 100;
final accelAvg = s.consistencyPct * 100;

// NEW:
final impactAvg = s.avgForceN;
final impactMax = s.maxForceN;
final accelAvg = s.avgAccelMs2;
final accelMax = s.maxAccelMs2;
```

### 6. Line 742-744: _MetricGrid derived values
```dart
// OLD:
final impactMax = impactAvg * 1.15;
final accelMax = accelAvg * 1.15;

// NEW:
// Remove these lines - use real max values from above
```

### 7. Line 747-748: _MetricGrid swing force
```dart
// OLD:
final swingForceAvg = (impactAvg + accelAvg) / 2;
final swingForceMax = swingForceAvg * 1.15;

// NEW:
// Swing force is already in avgForceN/maxForceN, so just use those
final swingForceAvg = s.avgForceN;
final swingForceMax = s.maxForceN;
```

## Summary

All references to `sweetSpotPct` and `consistencyPct` need to be replaced with:
- `avgForceN` / `maxForceN` for impact force
- `avgAccelMs2` / `maxAccelMs2` for acceleration

No more multiplying by 100 or deriving max from avg - use REAL values from database!
