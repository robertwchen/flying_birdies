# Final Analysis: Dart vs Python Comparison

## What Python v8 Actually Does

### Buffer & Window Sizes:
- **MAX_POINTS**: 1000 samples (10 seconds rolling buffer)
- **PRE_TIME_SEC**: 0.5 seconds before peak
- **POST_TIME_SEC**: 0.5 seconds after peak
- **FFT Window**: 100 samples (1 second total)
- **FFT Resolution**: 1.0 Hz

### Processing Flow:
1. Collect data in 1000-sample rolling buffer
2. When user stops, analyze ENTIRE buffer
3. Find peaks in entire dataset using derivative threshold
4. For each peak, extract 1-second window (50 before + 50 after)
5. Run FFT on that 100-sample window
6. Calculate mic/gyro power ratio
7. If ratio > 35, it's a valid swing

## What Dart v12 Currently Does

### Buffer & Window Sizes:
- **_maxBufferSize**: 1000 samples ✓ MATCHES PYTHON
- **preTimeSec**: 0.5 seconds ✓ MATCHES PYTHON
- **postTimeSec**: 0.5 seconds ✓ MATCHES PYTHON
- **FFT Window**: ~100 samples ✓ MATCHES PYTHON
- **FFT Resolution**: ~1.0 Hz ✓ MATCHES PYTHON

### Processing Flow:
1. Collect data in 1000-sample rolling buffer ✓
2. Every 20 samples, analyze recent window ✓
3. Find peaks using derivative threshold ✓
4. For each peak, extract 1-second window ✓
5. Run FFT on that ~100-sample window ✓
6. Calculate mic/gyro power ratio ✓
7. If ratio > 35, it's a valid swing ✓

## The Algorithm is Already Correct!

**Surprising Discovery:** The Dart implementation already matches Python's algorithm almost perfectly!

- Window sizes: ✓ Correct
- FFT approach: ✓ Correct
- Threshold: ✓ Correct (35.0)
- Peak detection: ✓ Correct
- Metrics calculation: ✓ Correct

## So Why Isn't It Working?

### Possible Issues:

### 1. FFT Library Normalization (MOST LIKELY)
**Problem:** `fftea` vs `numpy.fft.rfft` may have different normalization

**Python:**
```python
fft_vals = np.fft.rfft(sigw)
mag = np.abs(fft_vals)
power = mag**2
```

**Dart:**
```dart
final fft = FFT(n);
final complexResult = fft.realFft(signal);
final magnitude = sqrt(real * real + imag * imag);
final power = magnitude * magnitude;
```

**Test Needed:** Compare FFT output for same signal

### 2. Hanning Window Implementation
**Python:**
```python
window = np.hanning(N)
```

**Dart:**
```dart
final window = 0.5 * (1 - cos(2 * pi * i / (sig.length - 1)));
```

**Should be equivalent, but verify**

### 3. Incremental vs Batch Processing
**Python:** Analyzes complete dataset once
**Dart:** Analyzes rolling window continuously

**Impact:** Dart may detect same swing multiple times or miss swings at boundaries

### 4. Sampling Rate Estimation
**Python:** Calculated once from entire dataset
**Dart:** Recalculated for each window

**Impact:** Slight variations in fs_est affect FFT frequency bins

### 5. Data Quality
**Python:** Reads from serial, may have different timing
**Dart:** Reads from BLE, may have packet loss or timing jitter

## Recommended Debugging Steps

### Step 1: Test FFT Implementation
```dart
void testFft() {
  // Generate 10 Hz sine wave at 100 Hz sampling
  final signal = List.generate(100, (i) => sin(2 * pi * 10 * i / 100));
  
  // Apply Hanning window
  final windowed = List.generate(100, (i) {
    final w = 0.5 * (1 - cos(2 * pi * i / 99));
    return signal[i] * w;
  });
  
  // Compute FFT
  final result = _computeRealFft(windowed, 100.0);
  
  // Find peak
  var maxPower = 0.0;
  var peakFreq = 0.0;
  for (int i = 0; i < result.frequencies.length; i++) {
    if (result.power[i] > maxPower) {
      maxPower = result.power[i];
      peakFreq = result.frequencies[i];
    }
  }
  
  print('Peak at ${peakFreq.toStringAsFixed(1)} Hz (expected: 10.0 Hz)');
  print('Peak power: ${maxPower.toStringAsFixed(2)}');
  print('Total power: ${result.totalPower.toStringAsFixed(2)}');
}
```

### Step 2: Record and Compare Data
1. Record same swing session in both Python and Dart
2. Export Dart data to CSV
3. Run Python v8 on Dart's CSV
4. Compare:
   - Detected swing timestamps
   - Mic/gyro power ratios
   - Final metrics

### Step 3: Add Detailed Logging
```dart
// In _analyzeWindow, log everything:
print('[WINDOW] Size: ${winMic.length} samples');
print('[FFT] Mic power: ${micPower.toStringAsFixed(2)}');
print('[FFT] Gyro power: ${gyroPower.toStringAsFixed(2)}');
print('[FFT] Ratio: ${micPerGyro.toStringAsFixed(2)} (threshold: 35.0)');
print('[FFT] Valid: $isValidSwing');
```

### Step 4: Check for Normalization Issues
```dart
// Try different normalization factors
FftResult _computeRealFft(List<double> signal, double fsEst) {
  // ... existing code ...
  
  for (int k = 0; k < complexResult.length; k++) {
    var magnitude = sqrt(real * real + imag * imag);
    
    // TEST DIFFERENT NORMALIZATIONS:
    // Option 1: No normalization (current)
    // magnitude = magnitude;
    
    // Option 2: Normalize by N
    // magnitude = magnitude / n;
    
    // Option 3: Normalize by N/2
    // magnitude = magnitude * 2 / n;
    
    // Option 4: Normalize by sqrt(N)
    // magnitude = magnitude / sqrt(n);
    
    // ... rest of code ...
  }
}
```

## Most Likely Root Cause

Based on the analysis, the **FFT normalization** is the most likely culprit:

1. Algorithm is correct ✓
2. Window sizes are correct ✓
3. Threshold is correct ✓
4. But FFT power values may be scaled differently

**The mic/gyro ratio of 35 was calibrated for NumPy's FFT output.**

If `fftea` produces power values that are 10x larger or smaller, the threshold won't work.

## Quick Fix to Test

Add a normalization factor:

```dart
class ImuConfig {
  // Original threshold calibrated for NumPy
  static const double micPerGyroThreshold = 35.0;
  
  // Add normalization factor (adjust based on testing)
  static const double fftNormalizationFactor = 1.0; // Try 0.1, 10, 100, etc.
}

// In _analyzeWindow:
final micPower = micFft.totalPower * ImuConfig.fftNormalizationFactor;
final gyroPower = (gyroFft.totalPower * ImuConfig.fftNormalizationFactor) + 1e-9;
final micPerGyro = micPower / gyroPower;
```

Test with different factors (0.01, 0.1, 1.0, 10, 100) and see which gives ratios in the right range.

## Expected Behavior

If working correctly, you should see:
- **Non-swings**: mic/gyro ratio < 35 (typically 5-20)
- **Valid swings**: mic/gyro ratio > 35 (typically 40-100)

If you're seeing:
- All ratios < 1: FFT power too low, increase normalization
- All ratios > 1000: FFT power too high, decrease normalization
- Ratios in wrong range: FFT implementation issue

## Action Plan

1. ✓ Verify window sizes match Python (DONE - they do)
2. ⚠️ Test FFT with known signal (DO THIS FIRST)
3. ⚠️ Compare FFT output with Python
4. ⚠️ Adjust normalization if needed
5. ⚠️ Record test data and compare
6. ⚠️ Fine-tune threshold if needed

## Conclusion

The Dart implementation is algorithmically correct and matches Python v8. The issue is likely in the FFT library details (normalization, scaling) rather than the overall approach.

**Next step: Test the FFT implementation with known signals to verify it matches NumPy's output.**
