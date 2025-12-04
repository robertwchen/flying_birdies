# Python v8 Actual Behavior - Detailed Analysis

## Buffer Configuration

```python
MAX_POINTS = 1000  # Maximum buffer size during live collection
```

**What this means:**
- During live data collection, Python keeps a rolling buffer of **1000 samples**
- At 100 Hz sampling rate = **10 seconds** of data
- When buffer exceeds 1000, oldest sample is dropped

## Analysis Window Configuration

```python
PRE_TIME_SEC  = 0.50  # 0.5 seconds before impact
POST_TIME_SEC = 0.50  # 0.5 seconds after impact
```

**What this means:**
- Each detected swing gets a window of **PRE + POST = 1.0 second total**
- At 100 Hz: pre_samples = 50, post_samples = 50
- **Window size per swing = ~100 samples (1 second)**

## Critical Insight: Python's Two-Phase Approach

### Phase 1: Data Collection (Real-Time)
```python
def read_serial():
    # Continuously collect data into buffer
    while True:
        # Read sensor data
        timestamps.append(ts)
        acc_data.append(acc_val)
        mic_data.append(mic_val)
        gyro_data.append(gyro_val)
        
        # Keep buffer at MAX_POINTS (1000 samples)
        if len(acc_data) > MAX_POINTS:
            timestamps.pop(0)
            acc_data.pop(0)
            mic_data.pop(0)
            gyro_data.pop(0)
```

**Key Point:** During collection, Python does **NO ANALYSIS**. Just stores data.

### Phase 2: Analysis (Batch, After Collection)
```python
def tenniseye_style_analysis():
    # User closes plot window, then this runs
    
    # 1) Use ENTIRE collected dataset
    ts   = np.array(timestamps)    # All timestamps
    acc  = np.array(acc_data)      # All acceleration data
    mic  = np.array(mic_data)      # All mic data
    gyro = np.array(gyro_data)     # All gyro data
    
    # 2) Find ALL peaks in entire dataset
    dacc = np.diff(acc)
    # ... find all peaks ...
    
    # 3) For EACH detected peak, create a 1-second window
    for idx in peak_indices:
        # Create window: 0.5s before + 0.5s after = 1 second
        start = refined_center - pre_samples  # -50 samples
        end   = refined_center + post_samples # +50 samples
        
        # Extract 1-second window
        win_acc  = acc[start:end]    # ~100 samples
        win_gyro = gyro[start:end]   # ~100 samples
        win_mic  = mic[start:end]    # ~100 samples
        
        # 4) Run FFT on this 1-second window
        mic_fft  = compute_fft_features(win_mic)   # FFT of 100 samples
        gyro_fft = compute_fft_features(win_gyro)  # FFT of 100 samples
```

## The Real Window Sizes

### For Peak Detection:
- **Entire dataset** (could be 1000 samples, 5000 samples, whatever was collected)
- Looks at ALL data to find acceleration peaks
- This is why it's so accurate - full context

### For FFT Analysis (Per Swing):
- **1 second window** (100 samples at 100 Hz)
- PRE_TIME_SEC (0.5s) + POST_TIME_SEC (0.5s) = 1.0 second
- FFT resolution = 100 Hz / 100 samples = **1.0 Hz**

## Why Python Works So Well

1. **Peak Detection**: Uses entire dataset (1000+ samples)
   - Full context for finding swings
   - Can see patterns across entire session
   - Accurate threshold calculation from all data

2. **FFT Analysis**: Uses 1-second windows per swing
   - Focused on the actual swing event
   - 1 Hz frequency resolution is sufficient
   - Mic/gyro ratio calibrated for this window size

3. **No Real-Time Constraint**: Batch processing
   - Can take time to analyze
   - No latency requirements
   - Can iterate over all data multiple times

## Implications for Dart Real-Time Implementation

### What We Got Wrong:
❌ **Assumption**: Python uses large FFT windows (10+ seconds)
✓ **Reality**: Python uses **1-second FFT windows** per swing

❌ **Assumption**: Need 1000-sample windows for good FFT
✓ **Reality**: Python uses **100-sample windows** (1 second)

### What We Need to Match:

1. **Peak Detection Context**:
   - Python: Entire dataset (1000+ samples)
   - Dart: Should use large buffer (1000 samples = 10 seconds)
   - ✓ This is correct

2. **FFT Window Size**:
   - Python: 100 samples (1 second) per swing
   - Dart: Currently trying 200-500 samples
   - ❌ This is WRONG - should be ~100 samples

3. **FFT Resolution**:
   - Python: 1.0 Hz (100 samples at 100 Hz)
   - Dart: 0.5 Hz (200 samples) or 0.2 Hz (500 samples)
   - ❌ We're over-engineering this

## Corrected Understanding

### Python's Actual Approach:
```
1. Collect data in 1000-sample rolling buffer (10 seconds)
2. When user stops, analyze ENTIRE buffer to find peaks
3. For EACH peak, extract 1-second window (100 samples)
4. Run FFT on that 1-second window
5. Calculate mic/gyro ratio from FFT
6. Threshold: ratio > 35 = valid swing
```

### Dart Real-Time Equivalent:
```
1. Maintain 1000-sample rolling buffer (10 seconds) ✓ CORRECT
2. Every 20-50 samples, analyze ENTIRE buffer to find peaks
3. For EACH peak, extract 1-second window (100 samples) ← FIX THIS
4. Run FFT on that 1-second window ← FIX THIS
5. Calculate mic/gyro ratio from FFT
6. Threshold: ratio > 35 = valid swing
```

## The Fix We Actually Need

### Current Dart (WRONG):
```dart
static const int _analysisWindowSize = 500; // 5 seconds
// Then runs FFT on entire 500-sample window
```

### Corrected Dart (MATCHES PYTHON):
```dart
static const int _bufferSize = 1000; // 10 seconds for peak detection
static const int _fftWindowSize = 100; // 1 second for FFT per swing

// Process:
1. Keep 1000-sample buffer
2. Find peaks in entire buffer
3. For each peak, extract 100-sample window (0.5s before + 0.5s after)
4. Run FFT on that 100-sample window
5. Calculate mic/gyro ratio
```

## Key Revelation

**Python does NOT use large FFT windows!**

- Peak detection: Uses full dataset (1000+ samples)
- FFT analysis: Uses 1-second windows (100 samples)
- FFT resolution: 1.0 Hz (not 0.1 Hz or 0.2 Hz)

**The mic/gyro threshold of 35 was calibrated for 100-sample FFT windows, not 500-sample windows!**

This is why Dart isn't working - we're using the wrong FFT window size.

## Correct Implementation

```dart
class SwingAnalyzer {
  // Buffer for peak detection (matches Python MAX_POINTS)
  static const int _maxBufferSize = 1000; // 10 seconds
  
  // Window for FFT analysis (matches Python PRE_TIME + POST_TIME)
  static const double _preTimeSec = 0.5;   // 0.5 seconds before
  static const double _postTimeSec = 0.5;  // 0.5 seconds after
  // Total FFT window = 1.0 second = 100 samples at 100 Hz
  
  // How often to run peak detection
  static const int _minNewSamplesForAnalysis = 20; // Every 200ms
}

// In _analyzeWindow:
SwingMetrics? _analyzeWindow(DetectionWindow window, ...) {
  // Extract 1-second window around the peak (matches Python)
  final preSamples = (ImuConfig.preTimeSec * fsEst).round();  // 50
  final postSamples = (ImuConfig.postTimeSec * fsEst).round(); // 50
  
  final windowStart = max(0, window.centerIndex - preSamples);
  final windowEnd = min(accData.length, window.centerIndex + postSamples);
  
  // This gives us ~100 samples (1 second)
  final winAcc = accData.sublist(windowStart, windowEnd);
  final winGyro = gyroData.sublist(windowStart, windowEnd);
  final winMic = micData.sublist(windowStart, windowEnd);
  
  // Run FFT on 100-sample window (matches Python)
  final micFft = _computeFftFeatures(winMic, fsEst);   // N = 100
  final gyroFft = _computeFftFeatures(winGyro, fsEst); // N = 100
  
  // Now the threshold of 35 should work correctly!
}
```

## Summary

**What Python Actually Does:**
- Buffer: 1000 samples (10 seconds)
- Peak detection: Entire buffer
- FFT window: 100 samples (1 second) per swing
- FFT resolution: 1.0 Hz
- Threshold: 35 (calibrated for 100-sample FFT)

**What Dart Should Do:**
- Buffer: 1000 samples (10 seconds) ✓
- Peak detection: Entire buffer ✓
- FFT window: 100 samples (1 second) per swing ❌ Currently 200-500
- FFT resolution: 1.0 Hz ❌ Currently 0.5-0.2 Hz
- Threshold: 35 ✓

**The main bug: We're using 200-500 sample FFT windows when Python uses 100-sample windows!**
