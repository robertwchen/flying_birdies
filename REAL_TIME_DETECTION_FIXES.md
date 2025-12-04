# Real-Time Hit Detection: Python v8 vs Dart Implementation

## Current Architecture Analysis

### Data Flow in updatedApp
```
BLE Device → BleService.imuDataStream → AnalyticsService.processReading() 
→ SwingAnalyzerV2.processReading() → v12.SwingAnalyzer.processReading()
→ FFT + Detection → SwingMetrics → UI Update
```

### Key Insight: Real-Time Constraint
The Dart app MUST detect swings in real-time as data arrives (100 Hz sampling), unlike Python which analyzes complete recordings in batch mode.

## Critical Problems Identified

### 1. **Small Analysis Window** ⚠️ CRITICAL
**Current:** 200 samples (2 seconds at 100 Hz)
**Python:** Entire dataset (often 10-60 seconds)

**Impact:**
- FFT frequency resolution = fs / N = 100 / 200 = 0.5 Hz
- Python gets much better resolution with larger N
- Mic/gyro power ratio calibrated for Python's resolution won't work

**Fix:**
```dart
// Increase window size significantly
static const int _analysisWindowSize = 500; // 5 seconds minimum
// Or even better: 1000 samples (10 seconds)
```

### 2. **Incremental Processing Complexity** ⚠️ MAJOR
**Current:** Tracks `_lastAnalyzedIndex`, only analyzes new data
**Python:** Analyzes complete dataset once

**Problems:**
- Boundary effects: swings at window edges may be missed
- State management bugs with `_lastAnalyzedIndex`
- Re-analyzing overlapping data causes issues

**Fix:** Use sliding window with proper overlap
```dart
// Instead of tracking last analyzed index, use overlapping windows
static const int _windowOverlap = 100; // 1 second overlap
// Always analyze last N samples, but deduplicate detections by time
```

### 3. **FFT Normalization Mismatch** ⚠️ CRITICAL
**Python:**
```python
window = np.hanning(N)
sigw = sig * window
fft_vals = np.fft.rfft(sigw)
mag = np.abs(fft_vals)
power = mag**2
```

**Dart:**
```dart
final fft = FFT(n);
final complexResult = fft.realFft(signal);
// Manual magnitude calculation
```

**Problem:** `fftea` library may have different normalization than NumPy

**Test Required:**
```dart
// Test with known signal: pure sine wave
// Compare power output with Python
// Adjust normalization if needed
```

### 4. **Sampling Rate Estimation** ⚠️ MODERATE
**Current:** Recalculated for each small window
**Python:** Calculated once from entire dataset

**Fix:**
```dart
// Calculate fs_est once from larger dataset, cache it
double? _cachedSamplingRate;

double _estimateSamplingRate(List<double> timestamps) {
  if (_cachedSamplingRate != null) return _cachedSamplingRate!;
  
  if (timestamps.length > 100) {
    final duration = timestamps.last - timestamps.first;
    if (duration > 0) {
      _cachedSamplingRate = (timestamps.length - 1) / duration;
      return _cachedSamplingRate!;
    }
  }
  return ImuConfig.samplingRate.toDouble();
}
```

### 5. **Duplicate Detection Logic** ⚠️ MODERATE
**Current:** Uses `_lastSwingTime` with 0.5s minimum interval
**Python:** Uses minimum separation in peak detection

**Problem:** May miss rapid successive swings or create false duplicates

**Fix:**
```dart
// Better duplicate detection using swing characteristics
bool _isDuplicateSwing(SwingMetrics newSwing) {
  if (_lastSwingTime == null) return false;
  
  final timeDiff = newSwing.swingTime.difference(_lastSwingTime!).inMilliseconds / 1000.0;
  
  // If within minimum interval AND similar metrics, it's a duplicate
  if (timeDiff < ImuConfig.minSepSec) {
    // Check if metrics are similar (within 10%)
    if (_lastSwingMetrics != null) {
      final speedDiff = (newSwing.maxTipSpeed - _lastSwingMetrics!.maxTipSpeed).abs();
      if (speedDiff < _lastSwingMetrics!.maxTipSpeed * 0.1) {
        return true; // Likely duplicate
      }
    }
  }
  
  return false;
}
```

## Recommended Fixes (Priority Order)

### Priority 1: Increase Window Size
```dart
class SwingAnalyzer {
  // BEFORE: 200 samples (2 seconds)
  static const int _analysisWindowSize = 200;
  
  // AFTER: 1000 samples (10 seconds) - matches Python's typical dataset size
  static const int _analysisWindowSize = 1000;
  
  // Keep more history for better FFT resolution
  static const int _maxBufferSize = 2000; // 20 seconds
}
```

### Priority 2: Fix FFT Power Calculation
```dart
FftResult _computeRealFft(List<double> signal, double fsEst) {
  final n = signal.length;
  final fft = FFT(n);
  final complexResult = fft.realFft(signal);

  final frequencies = <double>[];
  final magnitudes = <double>[];
  final power = <double>[];

  // CRITICAL: Match NumPy's normalization
  // NumPy rfft doesn't normalize, so we need to match that
  for (int k = 0; k < complexResult.length; k++) {
    final complex = complexResult[k];
    final real = complex.x;
    final imag = complex.y;
    
    // Calculate magnitude
    final magnitude = sqrt(real * real + imag * imag);
    
    // IMPORTANT: fftea may need normalization adjustment
    // Test with known signal and compare to Python
    // May need: magnitude = magnitude / n  (or other factor)
    
    final freq = k * fsEst / n;

    frequencies.add(freq);
    magnitudes.add(magnitude);
    power.add(magnitude * magnitude);
  }

  final totalPower = power.reduce((a, b) => a + b);

  return FftResult(
    frequencies: frequencies,
    magnitudes: magnitudes,
    power: power,
    totalPower: totalPower,
  );
}
```

### Priority 3: Simplify Incremental Processing
```dart
SwingMetrics? processReading(ImuReading reading) {
  _dataBuffer.add(reading);

  // Keep buffer manageable
  if (_dataBuffer.length > _maxBufferSize) {
    _dataBuffer.removeAt(0);
  }

  // Need sufficient data
  if (_dataBuffer.length < _analysisWindowSize) {
    return null;
  }

  // SIMPLIFIED: Always analyze last N samples
  // No complex _lastAnalyzedIndex tracking
  final analysisWindow = _dataBuffer.sublist(
    _dataBuffer.length - _analysisWindowSize
  );

  // Detect swings in this window
  final swings = _detectSwingsInWindow(analysisWindow, 0);

  // Return most recent valid swing (if not duplicate)
  if (swings.isNotEmpty) {
    final latestSwing = swings.last;
    if (latestSwing.isValidSwing && !_isDuplicateSwing(latestSwing)) {
      _lastSwingTime = latestSwing.swingTime;
      _lastSwingMetrics = latestSwing;
      _hitCounter++;
      return latestSwing;
    }
  }

  return null;
}
```

### Priority 4: Add FFT Validation Test
```dart
// Add test method to verify FFT matches Python
void _testFftImplementation() {
  // Generate test signal: 10 Hz sine wave
  final fs = 100.0; // 100 Hz sampling
  final f = 10.0;   // 10 Hz signal
  final n = 200;    // 2 seconds
  
  final testSignal = List.generate(n, (i) {
    return sin(2 * pi * f * i / fs);
  });
  
  final result = _computeFftFeatures(testSignal, fs);
  
  if (result != null) {
    // Find peak frequency
    var maxPower = 0.0;
    var peakFreq = 0.0;
    for (int i = 0; i < result.frequencies.length; i++) {
      if (result.power[i] > maxPower) {
        maxPower = result.power[i];
        peakFreq = result.frequencies[i];
      }
    }
    
    print('[FFT TEST] Peak frequency: $peakFreq Hz (expected: 10 Hz)');
    print('[FFT TEST] Peak power: $maxPower');
    print('[FFT TEST] Total power: ${result.totalPower}');
    
    // Should be close to 10 Hz
    if ((peakFreq - 10.0).abs() > 0.5) {
      print('[FFT TEST] WARNING: Peak frequency mismatch!');
    }
  }
}
```

### Priority 5: Calibrate Threshold
```dart
// The mic/gyro threshold may need adjustment for real-time processing
class ImuConfig {
  // Python uses 35.0 with large windows and NumPy FFT
  // May need different value for smaller windows and fftea
  static const double micPerGyroThreshold = 35.0;
  
  // Add adaptive threshold option
  static const bool useAdaptiveThreshold = true;
  static const double thresholdMin = 25.0;
  static const double thresholdMax = 50.0;
}

// In analyzer:
double _calculateAdaptiveThreshold(List<double> recentRatios) {
  if (recentRatios.isEmpty) return ImuConfig.micPerGyroThreshold;
  
  // Use median of recent non-swing ratios as baseline
  final sorted = List<double>.from(recentRatios)..sort();
  final median = sorted[sorted.length ~/ 2];
  
  // Threshold = median + some factor
  final adaptive = median * 1.5;
  
  return adaptive.clamp(
    ImuConfig.thresholdMin,
    ImuConfig.thresholdMax,
  );
}
```

## Testing Strategy

### 1. Record Test Data
```dart
// Add data recording capability
class SwingAnalyzer {
  bool _recordingEnabled = false;
  final List<ImuReading> _recordedData = [];
  
  void startRecording() {
    _recordingEnabled = true;
    _recordedData.clear();
  }
  
  void stopRecording() {
    _recordingEnabled = false;
  }
  
  void exportRecordedData(String filename) {
    // Export to CSV for comparison with Python
    // Format: timestamp, ax, ay, az, gx, gy, gz, mic
  }
}
```

### 2. Compare with Python
1. Record same swing session in both systems
2. Export Dart data to CSV
3. Run Python v8 on Dart's CSV
4. Compare detected swings (timestamps, metrics)
5. Identify where they diverge

### 3. FFT Validation
1. Generate known test signals (sine waves)
2. Compare FFT output between Dart and Python
3. Adjust normalization if needed
4. Verify mic/gyro power ratios match

## Implementation Plan

### Phase 1: Quick Wins (1-2 hours)
1. Increase `_analysisWindowSize` to 1000
2. Increase `_maxBufferSize` to 2000
3. Add FFT test method
4. Test with real data

### Phase 2: Core Fixes (2-4 hours)
1. Simplify incremental processing (remove `_lastAnalyzedIndex`)
2. Implement better duplicate detection
3. Cache sampling rate calculation
4. Add data recording capability

### Phase 3: Calibration (2-4 hours)
1. Record test data from real swings
2. Compare with Python analysis
3. Adjust FFT normalization if needed
4. Calibrate mic/gyro threshold
5. Test adaptive threshold

### Phase 4: Validation (1-2 hours)
1. Side-by-side testing with Python
2. Verify detection accuracy
3. Measure false positive/negative rates
4. Fine-tune parameters

## Expected Improvements

After fixes:
- **Better FFT resolution**: 0.1 Hz vs 0.5 Hz (10x improvement)
- **More context**: 10 seconds vs 2 seconds (5x more data)
- **Simpler logic**: No complex state tracking
- **Better accuracy**: Matches Python's proven algorithm
- **Fewer false positives**: Better duplicate detection
- **Calibrated threshold**: Adjusted for real-time processing

## Key Takeaway

The main issue isn't the algorithm itself (which matches Python), but the **window size** and **FFT implementation details**. Python's success comes from:
1. Large analysis windows (full dataset)
2. Proven NumPy FFT implementation
3. Simple batch processing

For real-time detection, we need to:
1. Use larger windows (10 seconds minimum)
2. Verify FFT matches NumPy
3. Keep processing simple
4. Calibrate threshold for our specific FFT implementation
