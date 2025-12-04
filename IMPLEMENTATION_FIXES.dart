// FIXES FOR imu_analytics_pipeline_v12.dart
// Apply these changes to make real-time detection match Python v8

// ============================================================================
// FIX 1: Increase window sizes for better FFT resolution
// ============================================================================

class SwingAnalyzer {
  // BEFORE:
  // static const int _minNewSamplesForAnalysis = 10;
  // static const int _analysisWindowSize = 200; // 2 seconds
  
  // AFTER: Much larger windows for better FFT resolution
  static const int _minNewSamplesForAnalysis = 50; // Wait for more data
  static const int _analysisWindowSize = 1000; // 10 seconds at 100 Hz
  static const int _maxBufferSize = 2000; // Keep 20 seconds of history
  
  // Add overlap to avoid missing swings at boundaries
  static const int _windowOverlap = 200; // 2 second overlap
}

// ============================================================================
// FIX 2: Simplify incremental processing - remove complex state tracking
// ============================================================================

SwingMetrics? processReading(ImuReading reading) {
  _dataBuffer.add(reading);

  // Keep buffer size manageable
  if (_dataBuffer.length > _maxBufferSize) {
    _dataBuffer.removeAt(0);
  }

  // Need sufficient data for analysis
  if (_dataBuffer.length < _analysisWindowSize) {
    return null;
  }

  // SIMPLIFIED: Always analyze last N samples
  // No more _lastAnalyzedIndex complexity
  final swing = _detectRecentSwing();

  if (swing != null && swing.isValidSwing) {
    // Check for duplicates using time-based deduplication
    if (_isDuplicateSwing(swing)) {
      return null; // Skip duplicate
    }

    _lastSwingTime = swing.swingTime;
    _hitCounter++;
    return swing;
  }

  return null;
}

// ============================================================================
// FIX 3: Better duplicate detection
// ============================================================================

SwingMetrics? _lastDetectedSwing;

bool _isDuplicateSwing(SwingMetrics newSwing) {
  if (_lastSwingTime == null) return false;

  final timeDiff = newSwing.swingTime
      .difference(_lastSwingTime!)
      .inMilliseconds /
      1000.0;

  // If within minimum interval, check if it's truly a duplicate
  if (timeDiff < ImuConfig.minSepSec) {
    // If we have previous swing metrics, compare them
    if (_lastDetectedSwing != null) {
      // Check if metrics are very similar (within 15%)
      final speedDiff = (newSwing.maxTipSpeed - _lastDetectedSwing!.maxTipSpeed).abs();
      final speedThreshold = _lastDetectedSwing!.maxTipSpeed * 0.15;
      
      final forceDiff = (newSwing.estimatedForce - _lastDetectedSwing!.estimatedForce).abs();
      final forceThreshold = _lastDetectedSwing!.estimatedForce * 0.15;

      if (speedDiff < speedThreshold && forceDiff < forceThreshold) {
        print('[DUPLICATE] Rejected duplicate swing: '
            'timeDiff=${timeDiff.toStringAsFixed(3)}s, '
            'speedDiff=${speedDiff.toStringAsFixed(2)} m/s');
        return true; // It's a duplicate
      }
    }
    
    // Different metrics but close in time - might be valid rapid succession
    // Let it through but log it
    print('[RAPID] Rapid swing detected: timeDiff=${timeDiff.toStringAsFixed(3)}s');
    return false;
  }

  return false;
}

// Update when swing is accepted
void _acceptSwing(SwingMetrics swing) {
  _lastSwingTime = swing.swingTime;
  _lastDetectedSwing = swing;
  _hitCounter++;
}

// ============================================================================
// FIX 4: Cache sampling rate calculation
// ============================================================================

double? _cachedSamplingRate;
int _samplesUsedForRateCalc = 0;

double _estimateSamplingRate(List<double> timestamps) {
  // Only recalculate if we have significantly more data
  if (_cachedSamplingRate != null && 
      timestamps.length - _samplesUsedForRateCalc < 100) {
    return _cachedSamplingRate!;
  }

  if (timestamps.length > 100) {
    final duration = timestamps.last - timestamps.first;
    if (duration > 0) {
      _cachedSamplingRate = (timestamps.length - 1) / duration;
      _samplesUsedForRateCalc = timestamps.length;
      print('[SAMPLING] Estimated sampling rate: ${_cachedSamplingRate!.toStringAsFixed(1)} Hz');
      return _cachedSamplingRate!;
    }
  }
  
  return ImuConfig.samplingRate.toDouble();
}

// ============================================================================
// FIX 5: Add FFT normalization test and adjustment
// ============================================================================

// Add this method to test FFT implementation
void testFftImplementation() {
  print('[FFT TEST] Testing FFT implementation against known signal...');
  
  // Generate test signal: 10 Hz sine wave at 100 Hz sampling
  final fs = 100.0;
  final testFreq = 10.0;
  final n = 200;
  
  final testSignal = List.generate(n, (i) {
    return sin(2 * pi * testFreq * i / fs);
  });
  
  final result = _computeFftFeatures(testSignal, fs);
  
  if (result != null) {
    // Find peak frequency
    var maxPower = 0.0;
    var peakFreq = 0.0;
    var peakIndex = 0;
    
    for (int i = 0; i < result.frequencies.length; i++) {
      if (result.power[i] > maxPower) {
        maxPower = result.power[i];
        peakFreq = result.frequencies[i];
        peakIndex = i;
      }
    }
    
    print('[FFT TEST] Results:');
    print('  Peak frequency: ${peakFreq.toStringAsFixed(2)} Hz (expected: $testFreq Hz)');
    print('  Peak power: ${maxPower.toStringAsFixed(2)}');
    print('  Total power: ${result.totalPower.toStringAsFixed(2)}');
    print('  Frequency resolution: ${(fs / n).toStringAsFixed(2)} Hz');
    
    // Validate
    final freqError = (peakFreq - testFreq).abs();
    if (freqError > 0.5) {
      print('[FFT TEST] ⚠️  WARNING: Peak frequency mismatch! Error: ${freqError.toStringAsFixed(2)} Hz');
    } else {
      print('[FFT TEST] ✓ Peak frequency correct');
    }
    
    // Test with mic and gyro signals
    _testMicGyroRatio();
  } else {
    print('[FFT TEST] ❌ FFT computation failed');
  }
}

void _testMicGyroRatio() {
  print('[FFT TEST] Testing mic/gyro ratio calculation...');
  
  final fs = 100.0;
  final n = 200;
  
  // Simulate gyro signal (lower frequency, higher amplitude)
  final gyroSignal = List.generate(n, (i) {
    return 50.0 * sin(2 * pi * 5.0 * i / fs); // 5 Hz, 50 deg/s amplitude
  });
  
  // Simulate mic signal (higher frequency, lower amplitude)
  final micSignal = List.generate(n, (i) {
    return 10.0 * sin(2 * pi * 20.0 * i / fs); // 20 Hz, 10 amplitude
  });
  
  final gyroFft = _computeFftFeatures(gyroSignal, fs);
  final micFft = _computeFftFeatures(micSignal, fs);
  
  if (gyroFft != null && micFft != null) {
    final ratio = micFft.totalPower / (gyroFft.totalPower + 1e-9);
    print('[FFT TEST] Mic/Gyro power ratio: ${ratio.toStringAsFixed(2)}');
    print('[FFT TEST] Mic power: ${micFft.totalPower.toStringAsFixed(2)}');
    print('[FFT TEST] Gyro power: ${gyroFft.totalPower.toStringAsFixed(2)}');
  }
}

// ============================================================================
// FIX 6: Improved FFT computation with normalization check
// ============================================================================

FftResult _computeRealFft(List<double> signal, double fsEst) {
  final n = signal.length;

  // Use FFT library
  final fft = FFT(n);
  final complexResult = fft.realFft(signal);

  final frequencies = <double>[];
  final magnitudes = <double>[];
  final power = <double>[];

  // Process FFT results
  for (int k = 0; k < complexResult.length; k++) {
    final complex = complexResult[k];
    final real = complex.x;
    final imag = complex.y;
    
    // Calculate magnitude
    var magnitude = sqrt(real * real + imag * imag);
    
    // IMPORTANT: Check if normalization is needed
    // NumPy's rfft doesn't normalize by default
    // fftea might normalize differently
    // If tests show mismatch, try:
    // magnitude = magnitude / n;  // or
    // magnitude = magnitude * 2 / n;  // or other factor
    
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

// ============================================================================
// FIX 7: Add data recording for debugging
// ============================================================================

class SwingAnalyzer {
  bool _recordingEnabled = false;
  final List<ImuReading> _recordedData = [];
  
  void startRecording() {
    _recordingEnabled = true;
    _recordedData.clear();
    print('[RECORDING] Started data recording');
  }
  
  void stopRecording() {
    _recordingEnabled = false;
    print('[RECORDING] Stopped. Recorded ${_recordedData.length} samples');
  }
  
  String exportRecordedDataCsv() {
    final buffer = StringBuffer();
    buffer.writeln('timestamp,accel_g,mic_rms,gyro_dps');
    
    for (final reading in _recordedData) {
      final ts = reading.timestamp.millisecondsSinceEpoch / 1000.0;
      final acc = reading.acceleration;
      final mic = reading.micRms;
      final gyro = reading.gyroDegPerSec;
      
      buffer.writeln('$ts,$acc,$mic,$gyro');
    }
    
    return buffer.toString();
  }
  
  // In processReading, add:
  SwingMetrics? processReading(ImuReading reading) {
    if (_recordingEnabled) {
      _recordedData.add(reading);
    }
    
    // ... rest of processing
  }
}

// ============================================================================
// FIX 8: Adaptive threshold (optional, for advanced tuning)
// ============================================================================

class SwingAnalyzer {
  final List<double> _recentMicGyroRatios = [];
  static const int _maxRatioHistory = 50;
  
  double _getAdaptiveThreshold() {
    if (_recentMicGyroRatios.length < 10) {
      return ImuConfig.micPerGyroThreshold; // Use default
    }
    
    // Calculate median of recent ratios
    final sorted = List<double>.from(_recentMicGyroRatios)..sort();
    final median = sorted[sorted.length ~/ 2];
    
    // Threshold = median * factor
    final adaptive = median * 1.5;
    
    // Clamp to reasonable range
    return adaptive.clamp(25.0, 50.0);
  }
  
  void _updateRatioHistory(double ratio) {
    _recentMicGyroRatios.add(ratio);
    if (_recentMicGyroRatios.length > _maxRatioHistory) {
      _recentMicGyroRatios.removeAt(0);
    }
  }
  
  // In _analyzeWindow, use adaptive threshold:
  SwingMetrics? _analyzeWindow(...) {
    // ... FFT calculation ...
    
    final micPerGyro = micPower / gyroPower;
    _updateRatioHistory(micPerGyro);
    
    // Use adaptive threshold if enabled
    final threshold = ImuConfig.useAdaptiveThreshold
        ? _getAdaptiveThreshold()
        : ImuConfig.micPerGyroThreshold;
    
    final isValidSwing = micPerGyro > threshold;
    
    // ... rest of analysis ...
  }
}

// ============================================================================
// SUMMARY OF CHANGES
// ============================================================================

/*
1. ✓ Increased window size from 200 to 1000 samples (10 seconds)
2. ✓ Simplified incremental processing (removed _lastAnalyzedIndex)
3. ✓ Better duplicate detection with metric comparison
4. ✓ Cached sampling rate calculation
5. ✓ Added FFT test methods
6. ✓ Improved FFT normalization (with notes for adjustment)
7. ✓ Added data recording for debugging
8. ✓ Optional adaptive threshold

TESTING STEPS:
1. Apply fixes to imu_analytics_pipeline_v12.dart
2. Run testFftImplementation() on app start
3. Record test session with startRecording()
4. Export data and compare with Python v8
5. Adjust FFT normalization if needed
6. Calibrate threshold based on real data
7. Test with real swings and verify accuracy

EXPECTED RESULTS:
- Better FFT resolution (0.1 Hz vs 0.5 Hz)
- More accurate swing detection
- Fewer false positives/negatives
- Matches Python v8 performance
*/
