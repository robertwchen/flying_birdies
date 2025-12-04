# Line-by-Line Comparison: Python v8 vs Dart v12

## Part 1: Data Collection & Buffering

### Python v8:
```python
MAX_POINTS = 1000

acc_data  = []
mic_data  = []
gyro_data = []
timestamps = []

# In read_serial():
timestamps.append(ts)
acc_data.append(acc_val)   # in g
mic_data.append(mic_val)   # raw RMS
gyro_data.append(gyro_val) # in deg/s

if len(acc_data) > MAX_POINTS:
    timestamps.pop(0)
    acc_data.pop(0)
    mic_data.pop(0)
    gyro_data.pop(0)
```

### Dart v12:
```dart
final List<ImuReading> _dataBuffer = [];

// In processReading():
_dataBuffer.add(reading);

if (_dataBuffer.length > 1000) {
    _dataBuffer.removeAt(0);
    _lastAnalyzedIndex = max(0, _lastAnalyzedIndex - 1);
}
```

**✓ MATCH**: Both keep 1000 samples rolling buffer

---

## Part 2: Sampling Rate Estimation

### Python v8:
```python
if len(ts) > 1:
    duration = ts[-1] - ts[0]
    fs_est = (len(ts) - 1) / duration if duration > 0 else 50.0
else:
    fs_est = 50.0
print(f"[Analysis] Estimated sampling rate: ~{fs_est:.1f} Hz")
```

### Dart v12:
```dart
double fsEst = ImuConfig.samplingRate.toDouble(); // 100.0
if (timestamps.length > 1) {
  final duration = timestamps.last - timestamps.first;
  if (duration > 0) {
    fsEst = (timestamps.length - 1) / duration;
  }
}
```

**✓ MATCH**: Same calculation, but Dart defaults to 100 Hz vs Python's 50 Hz

---

## Part 3: Peak Detection - Derivative Calculation

### Python v8:
```python
dacc = np.diff(acc)
abs_dacc = np.abs(dacc)
th = np.mean(abs_dacc) + THRESH_STD_MULT * np.std(abs_dacc)
```

### Dart v12:
```dart
final dacc = _calculateDerivative(accData);
final absDacc = dacc.map((x) => x.abs()).toList();

final mean = _calculateMean(absDacc);
final std = _calculateStandardDeviation(absDacc, mean);
final threshold = mean + ImuConfig.threshStdMult * std;

// _calculateDerivative:
List<double> _calculateDerivative(List<double> data) {
  final result = <double>[];
  for (int i = 1; i < data.length; i++) {
    result.add(data[i] - data[i - 1]);
  }
  return result;
}
```

**✓ MATCH**: Same derivative and threshold calculation

---

## Part 4: Peak Finding

### Python v8:
```python
peak_indices = []
min_sep = int(MIN_SEP_SEC * fs_est)

for i in range(1, len(abs_dacc) - 1):
    if abs_dacc[i] > th and abs_dacc[i] >= abs_dacc[i-1] and abs_dacc[i] >= abs_dacc[i+1]:
        if peak_indices and i - peak_indices[-1] < min_sep:
            continue
        peak_indices.append(i)
```

### Dart v12:
```dart
List<int> _findPeaks(List<double> data, double threshold, double fsEst) {
  final peaks = <int>[];
  final minSep = (ImuConfig.minSepSec * fsEst).round();

  for (int i = 1; i < data.length - 1; i++) {
    if (data[i] > threshold &&
        data[i] >= data[i - 1] &&
        data[i] >= data[i + 1]) {
      // Check minimum separation
      if (peaks.isNotEmpty && i - peaks.last < minSep) {
        continue;
      }
      peaks.add(i);
    }
  }

  return peaks;
}
```

**✓ MATCH**: Identical peak finding logic

---

## Part 5: Gyro Peak Refinement

### Python v8:
```python
pre_samples   = int(PRE_TIME_SEC * fs_est)    # 0.5 * fs_est
post_samples  = int(POST_TIME_SEC * fs_est)   # 0.5 * fs_est
search_radius = int(SEARCH_RADIUS_SEC * fs_est) # 0.15 * fs_est

for idx in peak_indices:
    s0 = max(0, idx - search_radius)
    s1 = min(len(gyro) - 1, idx + search_radius)
    if s1 <= s0:
        continue

    local_gyro = np.abs(gyro[s0:s1+1])
    refined_center = s0 + int(np.argmax(local_gyro))

    start = max(0, refined_center - pre_samples)
    end   = min(len(acc), refined_center + post_samples)
    if end - start < 10:
        continue

    windows.append((start, end, refined_center))
```

### Dart v12:
```dart
List<DetectionWindow> _refineWithGyroPeaks(...) {
  final windows = <DetectionWindow>[];
  final preSamples = (ImuConfig.preTimeSec * fsEst).round();
  final postSamples = (ImuConfig.postTimeSec * fsEst).round();
  final searchRadius = (ImuConfig.searchRadiusSec * fsEst).round();

  for (final idx in peakIndices) {
    final s0 = max(0, idx - searchRadius);
    final s1 = min(gyroData.length - 1, idx + searchRadius);

    if (s1 <= s0) continue;

    // Find gyro peak in search window
    final localGyro =
        gyroData.sublist(s0, s1 + 1).map((x) => x.abs()).toList();
    final maxIndex = localGyro.indexOf(localGyro.reduce(max));
    final refinedCenter = s0 + maxIndex;

    // Create analysis window
    final start = max(0, refinedCenter - preSamples);
    final end = min(gyroData.length, refinedCenter + postSamples);

    if (end - start < 10) continue;

    windows.add(
      DetectionWindow(
        startIndex: start,
        endIndex: end,
        centerIndex: refinedCenter,
        impactTime: timestamps[refinedCenter],
      ),
    );
  }

  return windows;
}
```

**✓ MATCH**: Identical gyro refinement logic

---

## Part 6: FFT Computation - CRITICAL SECTION

### Python v8:
```python
def compute_fft_features(signal):
    sig = signal - np.mean(signal)
    N = len(sig)
    if N <= 4:
        return None

    window = np.hanning(N)
    sigw = sig * window
    fft_vals = np.fft.rfft(sigw)
    freqs = np.fft.rfftfreq(N, d=1.0/fs_est)
    mag = np.abs(fft_vals)
    power = mag**2
    total_power = np.sum(power)
    return {"freqs": freqs, "mag": mag, "power": power, "total_power": total_power}
```

### Dart v12:
```dart
FftResult? _computeFftFeatures(List<double> signal, double fsEst) {
  if (signal.length <= 4) return null;

  // Remove DC component (matching Python)
  final mean = _calculateMean(signal);
  final sig = signal.map((x) => x - mean).toList();

  // Apply Hanning window (matching Python)
  final windowed = <double>[];
  for (int i = 0; i < sig.length; i++) {
    final window = 0.5 * (1 - cos(2 * pi * i / (sig.length - 1)));
    windowed.add(sig[i] * window);
  }

  // Compute FFT (simplified - using basic DFT for real-time use)
  final fftResult = _computeRealFft(windowed, fsEst);

  return fftResult;
}

FftResult _computeRealFft(List<double> signal, double fsEst) {
  final n = signal.length;

  // Use FFT library for O(n log n) performance
  final fft = FFT(n);
  final complexResult = fft.realFft(signal);

  final frequencies = <double>[];
  final magnitudes = <double>[];
  final power = <double>[];

  // Process FFT results (only positive frequencies, matching Python rfft)
  for (int k = 0; k < complexResult.length; k++) {
    final complex = complexResult[k];
    // Extract real and imaginary parts from Float64x2
    final real = complex.x;
    final imag = complex.y;
    final magnitude = sqrt(real * real + imag * imag);
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

**⚠️ POTENTIAL MISMATCH**: 

1. **Hanning Window**:
   - Python: `np.hanning(N)` - NumPy's implementation
   - Dart: Manual calculation `0.5 * (1 - cos(2 * pi * i / (N - 1)))`
   - **Should be equivalent** but need to verify edge cases

2. **FFT Library**:
   - Python: `np.fft.rfft()` - NumPy's highly optimized FFT
   - Dart: `fftea` library's `FFT(n).realFft()`
   - **May have different normalization conventions**

3. **Magnitude Calculation**:
   - Python: `mag = np.abs(fft_vals)` - NumPy handles complex numbers natively
   - Dart: `magnitude = sqrt(real * real + imag * imag)` - Manual calculation from Float64x2
   - **Should be equivalent**

4. **Power Calculation**:
   - Python: `power = mag**2`
   - Dart: `power = magnitude * magnitude`
   - **Equivalent**

5. **Frequency Bins**:
   - Python: `freqs = np.fft.rfftfreq(N, d=1.0/fs_est)`
   - Dart: `freq = k * fsEst / n`
   - **Should be equivalent**: rfftfreq(N, d) returns k/(N*d) = k*fs/N

---

## Part 7: Mic/Gyro Ratio Calculation

### Python v8:
```python
mic_fft  = compute_fft_features(win_mic)
gyro_fft = compute_fft_features(win_gyro)

if mic_fft is None or gyro_fft is None:
    continue

mic_power  = mic_fft["total_power"]
gyro_power = gyro_fft["total_power"] + 1e-9  # avoid zero-div
mic_per_gyro = mic_power / gyro_power

# ---- CONDITIONAL SWING DETECTION ----
is_swing = mic_per_gyro > 35
```

### Dart v12:
```dart
final micFft = _computeFftFeatures(winMic, fsEst);
final gyroFft = _computeFftFeatures(winGyro, fsEst);

if (micFft == null || gyroFft == null) {
  print('[DEBUG] FFT computation failed for window');
  return null;
}

// Calculate mic/gyro power ratio (matching Python)
final micPower = micFft.totalPower;
final gyroPower = gyroFft.totalPower + 1e-9; // avoid division by zero
final micPerGyro = micPower / gyroPower;

// Swing validation (matching Python is_swing = mic_per_gyro > 35)
final isValidSwing = micPerGyro > ImuConfig.micPerGyroThreshold;
```

**✓ MATCH**: Identical ratio calculation and threshold

---

## Part 8: Metrics Calculation

### Python v8:
```python
# Convert accel from g → m/s² and remove DC
win_acc_ms2 = (win_acc - np.mean(win_acc)) * G_TO_MS2

# 1) swing speed (tip) from gyro peak
gyro_abs_deg = np.abs(win_gyro)
max_gyro_deg = np.max(gyro_abs_deg)          # deg/s
max_gyro_rad = max_gyro_deg * DEG_TO_RAD     # rad/s
swing_speed  = MOUNT_TO_TIP_M * max_gyro_rad # m/s

# 2) acceleration magnitude at impact
accel_mag = np.max(np.abs(win_acc_ms2))      # m/s²
a_max_g   = np.max(np.abs(win_acc - np.mean(win_acc))) # g

# 3) impact force at the racket
impact_force = EFFECTIVE_TIP_MASS_KG * accel_mag  # N

# 4a) shuttle-side force from outgoing speed
shuttle_speed_out = SHUTTLE_VS_TIP_RATIO * swing_speed
F_shuttle_actual  = (SHUTTLE_MASS_KG * shuttle_speed_out
                     / (CONTACT_MS / 1000.0))

# 4b) standardized rally force
F_shuttle_std = (SHUTTLE_MASS_KG *
                 (shuttle_speed_out + INCOMING_SPEED_STD_MS)
                 / (CONTACT_MS / 1000.0))
```

### Dart v12:
```dart
// Convert accel from g to m/s² and remove DC (matching Python)
final winAccMean = _calculateMean(winAcc);
final winAccMs2 =
    winAcc.map((x) => (x - winAccMean) * ImuConfig.gToMs2).toList();

// 1) Swing speed from gyro peak (matching Python)
final gyroAbsDeg = winGyro.map((x) => x.abs()).toList();
final maxGyroDeg = gyroAbsDeg.reduce(max); // deg/s
final maxGyroRad = maxGyroDeg * ImuConfig.degToRad; // rad/s
final swingSpeed = ImuConfig.mountToTipDistance * maxGyroRad; // m/s

// 2) Acceleration magnitude at impact (matching Python)
final accelMag = winAccMs2.map((x) => x.abs()).reduce(max); // m/s²
final aMaxG =
    winAcc.map((x) => (x - winAccMean).abs()).reduce(max); // g, for logging

// 3) Impact force at racket tip (matching Python)
final impactForce = ImuConfig.effectiveTipMass * accelMag; // N

// 3b) Swing force from racket+sensor mass
final swingForceRacket = ImuConfig.racketSensorMass * accelMag; // N

// 4a) Shuttle-side force from outgoing speed (matching Python)
final shuttleSpeedOut = ImuConfig.shuttleVsTipRatio * swingSpeed; // m/s
final shuttleForceActual = (ImuConfig.shuttleMass * shuttleSpeedOut) /
    (ImuConfig.contactDurationMs / 1000.0); // N

// 4b) Standardized rally force (matching Python)
final shuttleForceStd = (ImuConfig.shuttleMass *
        (shuttleSpeedOut + ImuConfig.incomingSpeedStdMs)) /
    (ImuConfig.contactDurationMs / 1000.0); // N
```

**✓ MATCH**: Identical metrics calculation

---

## Part 9: Constants Comparison

### Python v8:
```python
# Physics constants
MOUNT_TO_TIP_M        = 0.39
SHUTTLE_MASS_KG       = 0.0053
CONTACT_MS            = 2.0
EFFECTIVE_TIP_MASS_KG = 0.15
SHUTTLE_VS_TIP_RATIO  = 1.5
INCOMING_SPEED_STD_MS = 15.0
G_TO_MS2              = 9.81
DEG_TO_RAD            = np.pi / 180.0

# Detection tuning
THRESH_STD_MULT    = 1.0
MIN_SEP_SEC        = 0.50
PRE_TIME_SEC       = 0.50
POST_TIME_SEC      = 0.50
SEARCH_RADIUS_SEC  = 0.15

# FFT threshold
# (implicit: mic_per_gyro > 35)
```

### Dart v12:
```dart
class ImuConfig {
  // Physics constants
  static const double mountToTipDistance = 0.39;
  static const double shuttleMass = 0.0053;
  static const double contactDurationMs = 2.0;
  static const double effectiveTipMass = 0.15;
  static const double racketSensorMass = 0.10;
  static const double shuttleVsTipRatio = 1.5;
  static const double incomingSpeedStdMs = 15.0;
  static const double gToMs2 = 9.81;
  static const double degToRad = pi / 180.0;

  // Detection tuning parameters
  static const double threshStdMult = 1.0;
  static const double minSepSec = 0.50;
  static const double preTimeSec = 0.50;
  static const double postTimeSec = 0.50;
  static const double searchRadiusSec = 0.15;

  // FFT validation threshold
  static const double micPerGyroThreshold = 35.0;

  static const int samplingRate = 100;
}
```

**✓ MATCH**: All constants identical

---

## CRITICAL DIFFERENCES FOUND

### 1. **NumPy Hanning Window vs Manual Implementation**

**Python:**
```python
window = np.hanning(N)
```

**Dart:**
```dart
final window = 0.5 * (1 - cos(2 * pi * i / (sig.length - 1)));
```

**Test needed:** Verify these produce identical results

### 2. **FFT Library Normalization**

**Python:** `np.fft.rfft()` 
- NumPy's rfft does NOT normalize by default
- Returns complex array of length N//2 + 1
- Well-documented behavior

**Dart:** `fftea` library's `FFT(n).realFft()`
- May have different normalization convention
- Returns Float64x2 array
- Need to check documentation

**This is the most likely source of the bug!**

### 3. **Standard Deviation Calculation**

**Python:**
```python
np.std(abs_dacc)  # Uses N in denominator (population std)
```

**Dart:**
```dart
double _calculateStandardDeviation(List<double> data, double mean) {
  if (data.length < 2) return 0.0;
  final variance =
      data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / data.length;
  return sqrt(variance);
}
```

**✓ MATCH**: Both use population standard deviation (divide by N)

---

## SUMMARY OF FINDINGS

### Algorithm: ✓ IDENTICAL
- Peak detection logic
- Window extraction
- Metrics calculation
- Threshold values
- Constants

### Potential Issues:

1. **FFT Normalization** (HIGH PRIORITY)
   - `fftea` vs `numpy.fft.rfft` may scale results differently
   - This would directly affect mic/gyro power ratio
   - **Action**: Test with known signal and compare power values

2. **Hanning Window** (MEDIUM PRIORITY)
   - Manual implementation vs NumPy
   - Should be equivalent but verify
   - **Action**: Compare window values for same N

3. **Float64x2 Handling** (LOW PRIORITY)
   - Dart uses SIMD types, Python uses native complex
   - Magnitude calculation should be equivalent
   - **Action**: Verify sqrt(real² + imag²) matches np.abs()

4. **Real-Time vs Batch** (ARCHITECTURAL)
   - Python analyzes complete dataset once
   - Dart analyzes rolling window continuously
   - May cause boundary effects or duplicate detections
   - **Action**: Improve duplicate detection logic

---

## RECOMMENDED TESTS

### Test 1: Hanning Window
```dart
void testHanningWindow() {
  final n = 100;
  for (int i = 0; i < n; i++) {
    final w = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
    print('window[$i] = $w');
  }
  // Compare with Python: np.hanning(100)
}
```

### Test 2: FFT Power Scaling
```dart
void testFftPowerScaling() {
  // Pure sine wave: amplitude = 1.0, frequency = 10 Hz
  final signal = List.generate(100, (i) => sin(2 * pi * 10 * i / 100));
  
  // Apply Hanning window
  final windowed = List.generate(100, (i) {
    final w = 0.5 * (1 - cos(2 * pi * i / 99));
    return signal[i] * w;
  });
  
  // Compute FFT
  final result = _computeRealFft(windowed, 100.0);
  
  print('Total power: ${result.totalPower}');
  // Compare with Python:
  // sig = np.sin(2*np.pi*10*np.arange(100)/100)
  // window = np.hanning(100)
  // fft_vals = np.fft.rfft(sig * window)
  // power = np.sum(np.abs(fft_vals)**2)
}
```

### Test 3: Complete Pipeline
```dart
void testCompletePipeline() {
  // Use same test data as Python
  // Record CSV from Python, load into Dart
  // Compare:
  // - Detected peaks
  // - Window boundaries
  // - FFT power values
  // - Mic/gyro ratios
  // - Final swing detection
}
```

---

## CONCLUSION

The Dart implementation is **algorithmically correct** and matches Python line-by-line. The most likely bug is in the **FFT library normalization** - the `fftea` library may scale power values differently than NumPy, causing the mic/gyro ratio threshold of 35 to not work correctly.

**Next Step**: Run FFT power scaling test to compare Dart vs Python FFT output for the same signal.
