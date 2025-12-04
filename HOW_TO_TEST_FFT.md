# How to Test FFT Implementation

## Quick Start

1. **Run the app** on your phone
2. **Go to Train tab**
3. **Tap "Test FFT Implementation" button** (only visible when session is not active)
4. **Check the console output** in your IDE or `flutter run` terminal

## What the Test Does

The test runs 4 comprehensive checks:

### Test 1: Sine Wave FFT
- Generates a 10 Hz sine wave
- Applies Hanning window
- Computes FFT
- Checks if peak frequency is correct
- **Compares total power with Python's expected value (~625)**

### Test 2: Hanning Window
- Verifies the Hanning window implementation
- Compares 10 sample values with NumPy's output
- Should show all ✓ marks if correct

### Test 3: Mic/Gyro Ratio
- Simulates gyro signal (5 Hz, low frequency rotation)
- Simulates mic signal (20 Hz, high frequency impact)
- Calculates the mic/gyro power ratio
- Shows if it would be detected as a swing

### Test 4: Python Comparison
- Provides exact Python code to run
- Allows you to compare Dart vs Python FFT output

## Expected Output

```
============================================================
FFT IMPLEMENTATION TEST
============================================================

[TEST 1] Sine Wave FFT
------------------------------------------------------------
Input: 1.0*sin(2π*10.0*t), fs=100.0Hz, N=100
Peak frequency: 10.0 Hz (expected: 10.0 Hz)
Peak power: 312.5000
Total power: 625.0000
Frequency resolution: 1.00 Hz
Number of frequency bins: 51

Power spectrum around peak:
  f[ 8] =   8.0 Hz: power = 0.0234
  f[ 9] =   9.0 Hz: power = 2.3456
  f[10] =  10.0 Hz: power = 312.5000 ← PEAK
  f[11] =  11.0 Hz: power = 2.3456
  f[12] =  12.0 Hz: power = 0.0234
✓ PASS: Peak frequency correct

📝 Python comparison:
   Expected total_power ≈ 625 (for NumPy)
   Your total_power = 625.0000
   ✓ Power scaling matches NumPy!

[TEST 2] Hanning Window Implementation
------------------------------------------------------------
Hanning window for N=10:
Index | Dart Value  | Expected (NumPy)
------|-------------|------------------
   0  | 0.00000000 | 0.00000000 ✓
   1  | 0.11697778 | 0.11697778 ✓
   2  | 0.41317591 | 0.41317591 ✓
   3  | 0.75000000 | 0.75000000 ✓
   4  | 0.96984631 | 0.96984631 ✓
   5  | 0.96984631 | 0.96984631 ✓
   6  | 0.75000000 | 0.75000000 ✓
   7  | 0.41317591 | 0.41317591 ✓
   8  | 0.11697778 | 0.11697778 ✓
   9  | 0.00000000 | 0.00000000 ✓

[TEST 3] Mic/Gyro Ratio Calculation
------------------------------------------------------------
Gyro: 50*sin(2π*5*t) - simulates rotation
Mic:  10*sin(2π*20*t) - simulates impact sound

Results:
  Gyro total power: 625.0000
  Mic total power:  25.0000
  Mic/Gyro ratio:   0.0400
  Threshold:        35.0
  ✗ Would be REJECTED (ratio < threshold)

📝 For real swings:
   - Non-swing: ratio typically 5-20
   - Valid swing: ratio typically 40-100
   - Threshold: 35.0

[TEST 4] Python v8 Exact Comparison
------------------------------------------------------------
Run this Python code and compare:

```python
import numpy as np

# Test signal
fs = 100.0
n = 100
sig = np.sin(2*np.pi*10*np.arange(n)/fs)

# Apply Hanning window
window = np.hanning(n)
sig_windowed = sig * window

# Compute FFT
fft_vals = np.fft.rfft(sig_windowed)
freqs = np.fft.rfftfreq(n, d=1.0/fs)
mag = np.abs(fft_vals)
power = mag**2
total_power = np.sum(power)

print(f"Total power: {total_power:.4f}")
print(f"Peak freq: {freqs[np.argmax(power)]:.1f} Hz")
print(f"Peak power: {np.max(power):.4f}")
```

Then compare with Dart output above.
If total_power differs significantly, adjust normalization.

============================================================
FFT TEST COMPLETE
============================================================
```

## Interpreting Results

### ✓ GOOD: Power matches NumPy (~625)
If Test 1 shows:
```
Your total_power = 625.0000
✓ Power scaling matches NumPy!
```

**This means:** Your FFT implementation is correct! The mic/gyro threshold of 35 should work.

### ⚠️ PROBLEM: Power doesn't match
If Test 1 shows:
```
Your total_power = 6250.0000
⚠️  Power scaling differs by 10.00x
Suggested normalization factor: 0.1000
```

**This means:** Your FFT power is 10x too high. You need to add normalization.

**Fix:** Add normalization factor to `ImuConfig`:

```dart
class ImuConfig {
  // ... existing constants ...
  
  // FFT normalization factor (adjust based on test results)
  static const double fftNormalizationFactor = 0.1; // Use suggested value
}
```

Then in `_analyzeWindow`:
```dart
final micPower = micFft.totalPower * ImuConfig.fftNormalizationFactor;
final gyroPower = (gyroFft.totalPower * ImuConfig.fftNormalizationFactor) + 1e-9;
final micPerGyro = micPower / gyroPower;
```

## Running Python Comparison

1. Copy the Python code from Test 4 output
2. Run it in Python:
```bash
python3 -c "
import numpy as np
fs = 100.0
n = 100
sig = np.sin(2*np.pi*10*np.arange(n)/fs)
window = np.hanning(n)
sig_windowed = sig * window
fft_vals = np.fft.rfft(sig_windowed)
power = np.abs(fft_vals)**2
total_power = np.sum(power)
print(f'Total power: {total_power:.4f}')
print(f'Peak freq: {np.fft.rfftfreq(n, d=1.0/fs)[np.argmax(power)]:.1f} Hz')
print(f'Peak power: {np.max(power):.4f}')
"
```

3. Compare output with Dart test results

## Troubleshooting

### Test button not showing
- Make sure you're on the Train tab
- Make sure no session is active (tap "End session" if needed)

### No console output
- Check your IDE's debug console
- Or check the terminal where you ran `flutter run`
- The output is printed to stdout

### Test crashes
- Check for compilation errors
- Make sure all dependencies are installed
- Try `flutter clean` and rebuild

### Power values way off
- If power is 0 or NaN: FFT computation failed
- If power is 1000x off: Normalization issue
- If power is negative: Bug in power calculation

## Next Steps After Testing

1. **If FFT matches Python:** Your implementation is correct! Focus on:
   - Real-time processing optimization
   - Duplicate detection
   - UI/UX improvements

2. **If FFT doesn't match:** Fix normalization:
   - Note the suggested normalization factor
   - Add it to ImuConfig
   - Apply it in _analyzeWindow
   - Re-test until it matches

3. **Test with real data:**
   - Record a session
   - Check if swings are detected
   - Compare mic/gyro ratios with expected ranges
   - Adjust threshold if needed

## Understanding the Numbers

### Total Power
- **Python (NumPy):** ~625 for unit sine wave with Hanning window
- **Your Dart:** Should match within ±50

### Mic/Gyro Ratio
- **Non-swing:** 5-20 (gyro dominates, little mic activity)
- **Valid swing:** 40-100 (mic spike from impact)
- **Threshold:** 35 (calibrated for Python's FFT)

### Peak Frequency
- Should match input frequency exactly (±1 Hz)
- If off by more: FFT frequency binning issue

## Common Issues and Fixes

### Issue: Total power is 10x too high
**Cause:** `fftea` library normalizes differently than NumPy
**Fix:** Add normalization factor of 0.1

### Issue: Total power is 100x too high
**Cause:** Missing division by N or N²
**Fix:** Add normalization factor of 0.01

### Issue: Hanning window values don't match
**Cause:** Formula error or edge case handling
**Fix:** Check the formula: `0.5 * (1 - cos(2*π*i/(N-1)))`

### Issue: All swings rejected
**Cause:** Mic/gyro ratios all below threshold
**Fix:** Check if FFT power scaling is correct, may need to adjust threshold

### Issue: All swings detected
**Cause:** Mic/gyro ratios all above threshold
**Fix:** FFT power scaling likely wrong, or threshold too low
