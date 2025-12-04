# Pipeline Comparison: Python v8 vs Dart v12

## Critical Differences Found

### 1. **FFT Implementation Difference** ⚠️ MAJOR ISSUE
**Python v8 (Working):**
```python
window = np.hanning(N)
sigw = sig * window
fft_vals = np.fft.rfft(sigw)
freqs = np.fft.rfftfreq(N, d=1.0/fs_est)
mag = np.abs(fft_vals)
power = mag**2
```

**Dart v12 (Buggy):**
```dart
final fft = FFT(n);
final complexResult = fft.realFft(signal);
// Extract real and imaginary parts from Float64x2
final real = complex.x;
final imag = complex.y;
final magnitude = sqrt(real * real + imag * imag);
```

**Problem:** The `fftea` library's FFT implementation may not match NumPy's `rfft` exactly. The frequency binning, normalization, and windowing might differ.

### 2. **Processing Mode Difference** ⚠️ MAJOR ISSUE
**Python v8 (Working):**
- Batch processing: Collects ALL data first, then analyzes entire dataset
- Analyzes complete time series with full context
- Can see patterns across entire recording

**Dart v12 (Buggy):**
- Incremental/streaming processing: Analyzes data as it arrives
- Only looks at recent 200-sample window
- Limited context, may miss patterns that span longer periods
- `_lastAnalyzedIndex` tracking adds complexity and potential bugs

### 3. **Data Collection Timing**
**Python v8:**
```python
# Collects data continuously via serial thread
# Analysis runs AFTER data collection is complete
# User closes plot window to trigger analysis
```

**Dart v12:**
```dart
// Analyzes on EVERY new reading
// processReading() called in real-time
// No "complete dataset" concept
```

### 4. **Window Detection Logic**
**Python v8:**
- Finds ALL peaks in complete dataset
- Refines ALL peaks with gyro data
- Analyzes ALL windows

**Dart v12:**
- Only analyzes last 200 samples (2 seconds)
- May miss swings that occurred earlier
- `_lastAnalyzedIndex` prevents re-analysis but may skip data

### 5. **FFT Frequency Resolution**
**Python v8:**
```python
freqs = np.fft.rfftfreq(N, d=1.0/fs_est)
# Frequency resolution = fs_est / N
# Larger N = better frequency resolution
```

**Dart v12:**
```dart
final freq = k * fsEst / n;
// Same formula BUT n is limited to window size
// Smaller windows = worse frequency resolution
```

### 6. **Hanning Window Application**
**Python v8:**
```python
window = np.hanning(N)  # NumPy's optimized implementation
sigw = sig * window
```

**Dart v12:**
```dart
final window = 0.5 * (1 - cos(2 * pi * i / (sig.length - 1)));
windowed.add(sig[i] * window);
// Manual implementation - should be equivalent but check edge cases
```

## Root Causes of Bugs

### 1. **Incremental Processing Issues**
The Dart version tries to be "smart" by only analyzing new data, but this causes:
- Loss of context for pattern detection
- Potential for missing swings at window boundaries
- Complex state management with `_lastAnalyzedIndex`
- Race conditions in real-time processing

### 2. **FFT Library Mismatch**
`fftea` vs `numpy.fft`:
- Different normalization conventions
- Different handling of DC component
- Potential numerical precision differences
- Float64x2 SIMD types vs regular complex numbers

### 3. **Sampling Rate Estimation**
**Python v8:**
```python
duration = ts[-1] - ts[0]
fs_est = (len(ts) - 1) / duration
# Uses ENTIRE dataset for accurate estimate
```

**Dart v12:**
```dart
// Uses small window for fs_est
// May get inaccurate sampling rate
// Affects all frequency calculations
```

## Recommendations to Fix Dart Version

### Option 1: Match Python's Batch Processing (RECOMMENDED)
1. Collect data in buffer without analysis
2. When user stops recording, analyze entire buffer
3. Remove incremental processing logic
4. Remove `_lastAnalyzedIndex` complexity

### Option 2: Fix Incremental Processing
1. Use larger analysis windows (5-10 seconds minimum)
2. Use overlapping windows to avoid boundary issues
3. Verify FFT implementation matches NumPy
4. Add proper state management for multi-swing detection

### Option 3: Hybrid Approach
1. Keep incremental for real-time feedback
2. Add "final analysis" pass on complete dataset
3. Use Python-style batch processing for final metrics
4. Show preliminary results during recording

## Specific Bugs to Fix

1. **FFT Power Calculation:**
   - Verify `fftea` normalization matches NumPy
   - Check if power calculation needs scaling factor
   - Test with known signals (sine waves)

2. **Window Size:**
   - Increase `_analysisWindowSize` from 200 to 500+ samples
   - Match Python's full-dataset analysis

3. **Sampling Rate:**
   - Calculate fs_est from larger dataset
   - Don't recalculate for every window

4. **State Management:**
   - Simplify or remove `_lastAnalyzedIndex`
   - Use simpler duplicate detection

5. **Threshold Calibration:**
   - Verify `micPerGyroThreshold = 35.0` works with Dart FFT
   - May need recalibration due to FFT differences

## Testing Strategy

1. **Record same swing with both systems**
2. **Compare FFT outputs** (frequencies, magnitudes, power)
3. **Compare detected peaks** (timestamps, values)
4. **Compare final metrics** (swing speed, force, etc.)
5. **Identify where they diverge**

## Conclusion

The Python v8 works because it:
- Uses proven NumPy FFT implementation
- Analyzes complete dataset with full context
- Simple, straightforward batch processing
- No complex state management

The Dart v12 has issues because it:
- Uses different FFT library with potential mismatches
- Tries to be too clever with incremental processing
- Limited context from small windows
- Complex state management prone to bugs

**Recommendation:** Rewrite Dart version to match Python's batch processing approach, or thoroughly validate that `fftea` produces identical results to NumPy's `rfft`.
