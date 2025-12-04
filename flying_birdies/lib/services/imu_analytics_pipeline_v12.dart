import 'dart:math';
import 'package:fftea/fftea.dart';

// Configuration constants matching Python pipeline exactly
class ImuConfig {
  // Physics constants (matching Python TENNISEYE-STYLE PHYSICS CONSTANTS)
  static const double mountToTipDistance = 0.39; // MOUNT_TO_TIP_M
  static const double shuttleMass = 0.0053; // SHUTTLE_MASS_KG (kg)
  static const double contactDurationMs = 2.0; // CONTACT_MS (ms)
  static const double effectiveTipMass = 0.15; // EFFECTIVE_TIP_MASS_KG (kg)
  static const double racketSensorMass =
      0.10; // RACKET_SENSOR_MASS_KG (kg) - badminton racket ~90g + sensor ~10g
  static const double shuttleVsTipRatio = 1.5; // SHUTTLE_VS_TIP_RATIO
  static const double incomingSpeedStdMs = 15.0; // INCOMING_SPEED_STD_MS (m/s)
  static const double gToMs2 = 9.81; // G_TO_MS2 (m/s² per g)
  static const double degToRad = pi / 180.0; // DEG_TO_RAD

  // Detection tuning parameters (matching Python TUNING PARAMS)
  static const double threshStdMult = 1.0; // THRESH_STD_MULT
  static const double minSepSec = 0.50; // MIN_SEP_SEC (seconds)
  static const double preTimeSec = 0.50; // PRE_TIME_SEC (seconds)
  static const double postTimeSec = 0.50; // POST_TIME_SEC (seconds)
  static const double searchRadiusSec = 0.15; // SEARCH_RADIUS_SEC (seconds)

  // FFT validation threshold (matching Python exactly)
  // Python uses 35.0 with NumPy's FFT
  // Power scaling doesn't matter because mic/gyro RATIO cancels out the scaling factor
  // Both mic and gyro are scaled equally, so ratio remains the same
  static const double micPerGyroThreshold = 35.0;

  static const int samplingRate = 100; // Hz (estimated from data)
}

/// Data structure for IMU readings (matching Python data structure)
class ImuReading {
  final DateTime timestamp;
  final double accelX, accelY, accelZ;
  final double gyroX, gyroY, gyroZ;
  final double micRms;

  ImuReading({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.micRms,
  });

  /// Calculate acceleration magnitude (matching Python)
  double get acceleration =>
      sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);

  /// Calculate gyro magnitude in deg/s (matching Python)
  double get gyroDegPerSec =>
      sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);

  /// Calculate angular velocity in rad/s (matching Python)
  double get angularVelocity => gyroDegPerSec * ImuConfig.degToRad;

  /// Calculate tip speed (matching Python)
  double get tipSpeed => angularVelocity * ImuConfig.mountToTipDistance;
}

/// Swing metrics data structure (matching Python output)
class SwingMetrics {
  final DateTime swingTime;
  final double maxAngularVelocity; // rad/s
  final double maxTipSpeed; // m/s
  final double impactAcceleration; // m/s²
  final double estimatedForce; // N (impact force at racket tip)
  final double swingForce; // N (swing force from racket+sensor mass)
  final double shuttleForceActual; // N (shuttle-side force)
  final double shuttleForceStd; // N (standardized rally force)
  final int swingDuration;
  final double micPerGyroRatio; // FFT power ratio
  final bool isValidSwing; // passed FFT validation

  SwingMetrics({
    required this.swingTime,
    required this.maxAngularVelocity,
    required this.maxTipSpeed,
    required this.impactAcceleration,
    required this.estimatedForce,
    required this.swingForce,
    required this.shuttleForceActual,
    required this.shuttleForceStd,
    required this.swingDuration,
    required this.micPerGyroRatio,
    required this.isValidSwing,
  });
}

/// FFT analysis results
class FftResult {
  final List<double> frequencies;
  final List<double> magnitudes;
  final List<double> power;
  final double totalPower;

  FftResult({
    required this.frequencies,
    required this.magnitudes,
    required this.power,
    required this.totalPower,
  });
}

/// Window detection result
class DetectionWindow {
  final int startIndex;
  final int endIndex;
  final int centerIndex;
  final double impactTime;

  DetectionWindow({
    required this.startIndex,
    required this.endIndex,
    required this.centerIndex,
    required this.impactTime,
  });
}

/// Main swing analyzer class (matching Python tenniseye_style_analysis)
class SwingAnalyzer {
  final List<ImuReading> _dataBuffer = [];
  int _hitCounter = 0;
  int _lastAnalyzedIndex = 0; // FIXED: Track what we've already analyzed

  // Track last detected swing time to prevent duplicates
  DateTime? _lastSwingTime;
  static const double _minSwingIntervalSec = 0.5; // Match Python MIN_SEP_SEC

  // Performance monitoring
  int _totalAnalyses = 0;
  int _totalDetections = 0;

  // Incremental processing parameters - MATCHES PYTHON v8
  static const int _minNewSamplesForAnalysis =
      20; // Analyze every 200ms (20 samples at 100 Hz) for real-time detection
  static const int _analysisWindowSize =
      200; // Analyze last 2 seconds (Python uses full dataset, but we need real-time)

  /// Process new IMU reading and detect swings using Python algorithm
  /// FIXED: Incremental processing - only analyze new data, not entire buffer
  SwingMetrics? processReading(ImuReading reading) {
    _dataBuffer.add(reading);

    // Keep buffer size manageable - 10 seconds of history
    if (_dataBuffer.length > 1000) {
      _dataBuffer.removeAt(0);
      _lastAnalyzedIndex = max(0, _lastAnalyzedIndex - 1);
    }

    // Need sufficient data for analysis - wait for full window
    if (_dataBuffer.length < _analysisWindowSize) {
      return null;
    }

    // FIXED: Only analyze if we have enough NEW data since last analysis
    final newSamplesSinceLastAnalysis = _dataBuffer.length - _lastAnalyzedIndex;
    if (newSamplesSinceLastAnalysis < _minNewSamplesForAnalysis) {
      return null; // Wait for more new data
    }

    // Performance monitoring
    final analysisStart = DateTime.now();
    _totalAnalyses++;

    // FIXED: Run detection on recent window only (not entire buffer)
    final swing = _detectRecentSwing();

    // Log performance every 20 analyses
    if (_totalAnalyses % 20 == 0) {
      final analysisDuration = DateTime.now().difference(analysisStart);
      print(
          '[PERF] Analysis #$_totalAnalyses took ${analysisDuration.inMilliseconds}ms | '
          'Detections: $_totalDetections | Buffer: ${_dataBuffer.length}');
    }

    // Update last analyzed index to avoid re-analyzing same data
    _lastAnalyzedIndex = _dataBuffer.length - 50; // Keep 50 samples overlap

    // Check if we detected a valid swing
    if (swing != null && swing.isValidSwing) {
      // CRITICAL FIX: Check for duplicate BEFORE incrementing counter
      // Prevent detecting the same swing multiple times
      if (_lastSwingTime != null) {
        final timeSinceLastSwing =
            swing.swingTime.difference(_lastSwingTime!).inMilliseconds / 1000.0;

        if (timeSinceLastSwing < _minSwingIntervalSec) {
          // This is a duplicate detection of the same swing - ignore it
          print(
              '[DUPLICATE REJECTED] Same swing detected again after ${timeSinceLastSwing.toStringAsFixed(3)}s (< ${_minSwingIntervalSec}s)');
          return null;
        }
      }

      // This is a new, unique swing - count it
      _lastSwingTime = swing.swingTime;
      _hitCounter++;
      _totalDetections++;

      // Log detection latency
      final detectionLatency = DateTime.now().difference(swing.swingTime);
      print(
          '[DETECTION] Hit #$_hitCounter detected with ${detectionLatency.inMilliseconds}ms latency');

      return swing;
    }

    return null;
  }

  /// FIXED: Detect swings in recent window only (incremental processing)
  SwingMetrics? _detectRecentSwing() {
    // Analyze only the most recent window (e.g., last 2 seconds)
    final windowSize = min(_analysisWindowSize, _dataBuffer.length);
    final startIdx = max(0, _dataBuffer.length - windowSize);

    // Extract recent window data
    final recentBuffer = _dataBuffer.sublist(startIdx);

    // Run detection on recent window
    final swings = _detectSwingsInWindow(recentBuffer, startIdx);

    // Return most recent valid swing if any
    if (swings.isNotEmpty) {
      return swings.last;
    }

    return null;
  }

  /// Detect swings in a specific window of data
  List<SwingMetrics> _detectSwingsInWindow(
    List<ImuReading> windowBuffer,
    int bufferStartIndex,
  ) {
    if (windowBuffer.length < 20) return [];

    // Extract data arrays from window
    final timestamps = windowBuffer
        .map((r) => r.timestamp.millisecondsSinceEpoch / 1000.0)
        .toList();
    final accData = windowBuffer.map((r) => r.acceleration).toList();
    final micData = windowBuffer.map((r) => r.micRms).toList();
    final gyroData = windowBuffer.map((r) => r.gyroDegPerSec).toList();

    // Estimate sampling rate
    double fsEst = ImuConfig.samplingRate.toDouble();
    if (timestamps.length > 1) {
      final duration = timestamps.last - timestamps.first;
      if (duration > 0) {
        fsEst = (timestamps.length - 1) / duration;
      }
    }

    // Detect stroke candidates
    final dacc = _calculateDerivative(accData);
    final absDacc = dacc.map((x) => x.abs()).toList();

    final mean = _calculateMean(absDacc);
    final std = _calculateStandardDeviation(absDacc, mean);
    final threshold = mean + ImuConfig.threshStdMult * std;

    // Find peaks
    final peakIndices = _findPeaks(absDacc, threshold, fsEst);

    if (peakIndices.isEmpty) return [];

    // Refine with gyro peaks
    final windows = _refineWithGyroPeaks(
      peakIndices,
      gyroData,
      timestamps,
      fsEst,
    );

    if (windows.isEmpty) return [];

    // Analyze each window
    final swings = <SwingMetrics>[];
    for (final window in windows) {
      final swing = _analyzeWindow(
        window,
        timestamps,
        accData,
        gyroData,
        micData,
        fsEst,
      );
      if (swing != null) {
        swings.add(swing);
      }
    }

    return swings;
  }

  /// Calculate derivative (matching Python np.diff)
  List<double> _calculateDerivative(List<double> data) {
    final result = <double>[];
    for (int i = 1; i < data.length; i++) {
      result.add(data[i] - data[i - 1]);
    }
    return result;
  }

  /// Calculate mean
  double _calculateMean(List<double> data) {
    if (data.isEmpty) return 0.0;
    return data.reduce((a, b) => a + b) / data.length;
  }

  /// Calculate standard deviation
  double _calculateStandardDeviation(List<double> data, double mean) {
    if (data.length < 2) return 0.0;
    final variance =
        data.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / data.length;
    return sqrt(variance);
  }

  /// Find peaks above threshold (matching Python peak detection)
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

  /// Refine peaks with gyro data (matching Python gyro peak refinement)
  List<DetectionWindow> _refineWithGyroPeaks(
    List<int> peakIndices,
    List<double> gyroData,
    List<double> timestamps,
    double fsEst,
  ) {
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

  /// Analyze individual window (matching Python per-window analysis)
  SwingMetrics? _analyzeWindow(
    DetectionWindow window,
    List<double> timestamps,
    List<double> accData,
    List<double> gyroData,
    List<double> micData,
    double fsEst,
  ) {
    // Extract window data
    final winAcc = accData.sublist(window.startIndex, window.endIndex);
    final winGyro = gyroData.sublist(window.startIndex, window.endIndex);
    final winMic = micData.sublist(window.startIndex, window.endIndex);

    // FFT analysis (matching Python compute_fft_features)
    final micFft = _computeFftFeatures(winMic, fsEst);
    final gyroFft = _computeFftFeatures(winGyro, fsEst);

    if (micFft == null || gyroFft == null) {
      print('[DEBUG] FFT computation failed for window');
      return null;
    }

    // Calculate mic/gyro power ratio (matching Python)
    // No normalization needed - ratio cancels out any scaling factor
    // Both mic and gyro are scaled equally by fftea, so ratio is correct
    final micPower = micFft.totalPower;
    final gyroPower = gyroFft.totalPower + 1e-9; // avoid division by zero
    final micPerGyro = micPower / gyroPower;

    // Swing validation (matching Python is_swing = mic_per_gyro > 35)
    final isValidSwing = micPerGyro > ImuConfig.micPerGyroThreshold;

    // Calculate TennisEye-style metrics (matching Python exactly)

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

    // DEBUG OUTPUT (matching Python)
    if (isValidSwing) {
      print(
        '[SWING DETECTED] Hit #${_hitCounter + 1} | '
        't=${window.impactTime.toStringAsFixed(3)}s | '
        'mic/gyro=${micPerGyro.toStringAsFixed(2)} | '
        'a_max=${accelMag.toStringAsFixed(1)} m/s² (${aMaxG.toStringAsFixed(1)} g) | '
        'v_tip=${swingSpeed.toStringAsFixed(2)} m/s | '
        'F_impact=${impactForce.toStringAsFixed(1)} N | '
        'F_shuttle=${shuttleForceActual.toStringAsFixed(1)} N | '
        'F_std15=${shuttleForceStd.toStringAsFixed(1)} N',
      );
      print(
        '[FFT DEBUG] mic_power=${micPower.toStringAsFixed(2)}, '
        'gyro_power=${gyroPower.toStringAsFixed(2)}, '
        'ratio=${micPerGyro.toStringAsFixed(2)}',
      );
    } else {
      print(
        '[REJECTED] t=${window.impactTime.toStringAsFixed(3)}s | '
        'mic/gyro=${micPerGyro.toStringAsFixed(2)} | '
        'a_max=${accelMag.toStringAsFixed(1)} m/s² (${aMaxG.toStringAsFixed(1)} g) | '
        'v_tip=${swingSpeed.toStringAsFixed(2)} m/s | '
        'F_impact=${impactForce.toStringAsFixed(1)} N | '
        'F_shuttle=${shuttleForceActual.toStringAsFixed(1)} N',
      );
      print(
        '[FFT DEBUG] mic_power=${micPower.toStringAsFixed(2)}, '
        'gyro_power=${gyroPower.toStringAsFixed(2)}, '
        'ratio=${micPerGyro.toStringAsFixed(2)} (threshold=${ImuConfig.micPerGyroThreshold})',
      );
    }

    return SwingMetrics(
      swingTime: DateTime.fromMillisecondsSinceEpoch(
        (window.impactTime * 1000).round(),
      ),
      maxAngularVelocity: maxGyroRad,
      maxTipSpeed: swingSpeed,
      impactAcceleration: accelMag,
      estimatedForce: impactForce,
      swingForce: swingForceRacket,
      shuttleForceActual: shuttleForceActual,
      shuttleForceStd: shuttleForceStd,
      swingDuration:
          ((window.endIndex - window.startIndex) / fsEst * 1000).round(),
      micPerGyroRatio: micPerGyro,
      isValidSwing: isValidSwing,
    );
  }

  /// Compute FFT features (matching Python compute_fft_features)
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

  /// Optimized real FFT computation using FFT library (matching Python np.fft.rfft)
  FftResult _computeRealFft(List<double> signal, double fsEst) {
    final n = signal.length;

    // Use FFT library for O(n log n) performance (was O(n²) naive DFT)
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

  /// Get current statistics
  Map<String, dynamic> getCurrentStats() {
    return {'hitCount': _hitCounter, 'bufferSize': _dataBuffer.length};
  }

  /// Reset analyzer state
  void reset() {
    _dataBuffer.clear();
    _hitCounter = 0;
    _lastSwingTime = null;
    _lastAnalyzedIndex = 0; // FIXED: Reset analysis tracking
    _totalAnalyses = 0;
    _totalDetections = 0;
  }

  /// Test FFT implementation against known signal
  void testFftImplementation() {
    print('\n${'=' * 60}');
    print('FFT IMPLEMENTATION TEST');
    print('=' * 60);

    _testSineWave();
    _testHanningWindow();
    _testMicGyroRatio();
    _testPythonComparison();

    print('=' * 60);
    print('FFT TEST COMPLETE');
    print('${'=' * 60}\n');
  }

  /// Test 1: Basic sine wave FFT
  void _testSineWave() {
    print('\n[TEST 1] Sine Wave FFT');
    print('-' * 60);

    final fs = 100.0;
    final testFreq = 10.0;
    final n = 100;
    final amplitude = 1.0;

    // Generate pure sine wave
    final testSignal = List.generate(n, (i) {
      return amplitude * sin(2 * pi * testFreq * i / fs);
    });

    print('Input: ${amplitude}*sin(2π*${testFreq}*t), fs=${fs}Hz, N=$n');

    final result = _computeFftFeatures(testSignal, fs);

    if (result != null) {
      // Find peak
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

      print(
          'Peak frequency: ${peakFreq.toStringAsFixed(1)} Hz (expected: ${testFreq.toStringAsFixed(1)} Hz)');
      print('Peak power: ${maxPower.toStringAsFixed(4)}');
      print('Total power: ${result.totalPower.toStringAsFixed(4)}');
      print('Frequency resolution: ${(fs / n).toStringAsFixed(2)} Hz');
      print('Number of frequency bins: ${result.frequencies.length}');

      // Show power around peak
      print('\nPower spectrum around peak:');
      for (int i = max(0, peakIndex - 2);
          i <= min(result.frequencies.length - 1, peakIndex + 2);
          i++) {
        final marker = i == peakIndex ? ' ← PEAK' : '';
        print(
            '  f[${i.toString().padLeft(2)}] = ${result.frequencies[i].toStringAsFixed(1).padLeft(5)} Hz: '
            'power = ${result.power[i].toStringAsFixed(4)}$marker');
      }

      final freqError = (peakFreq - testFreq).abs();
      if (freqError > 1.0) {
        print(
            '❌ FAIL: Peak frequency error: ${freqError.toStringAsFixed(2)} Hz');
      } else {
        print('✓ PASS: Peak frequency correct');
      }

      // Python comparison note
      print('\n📝 Python comparison:');
      print('   sig = np.sin(2*np.pi*10*np.arange(100)/100)');
      print('   window = np.hanning(100)');
      print('   fft_vals = np.fft.rfft(sig * window)');
      print('   power = np.abs(fft_vals)**2');
      print('   total_power = np.sum(power)');
      print('   Expected total_power ≈ 625 (for NumPy)');
      print('   Your total_power = ${result.totalPower.toStringAsFixed(4)}');

      if ((result.totalPower - 625).abs() < 50) {
        print('   ✓ Power scaling matches NumPy!');
      } else {
        final ratio = result.totalPower / 625;
        print('   ⚠️  Power scaling differs by ${ratio.toStringAsFixed(2)}x');
        print(
            '   Suggested normalization factor: ${(1.0 / ratio).toStringAsFixed(4)}');
      }
    }
  }

  /// Test 2: Hanning window implementation
  void _testHanningWindow() {
    print('\n[TEST 2] Hanning Window Implementation');
    print('-' * 60);

    final n = 10;
    print('Hanning window for N=$n:');
    print('Index | Dart Value  | Expected (NumPy)');
    print('------|-------------|------------------');

    // Expected values from NumPy np.hanning(10)
    final expected = [
      0.0,
      0.11697778,
      0.41317591,
      0.75,
      0.96984631,
      0.96984631,
      0.75,
      0.41317591,
      0.11697778,
      0.0
    ];

    for (int i = 0; i < n; i++) {
      final w = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
      final diff = (w - expected[i]).abs();
      final status = diff < 0.0001 ? '✓' : '❌';
      print(
          '  ${i.toString().padLeft(2)}  | ${w.toStringAsFixed(8)} | ${expected[i].toStringAsFixed(8)} $status');
    }
  }

  /// Test 3: Mic/Gyro ratio with synthetic data
  void _testMicGyroRatio() {
    print('\n[TEST 3] Mic/Gyro Ratio Calculation');
    print('-' * 60);

    final fs = 100.0;
    final n = 100;

    // Simulate gyro signal (lower frequency, represents rotation)
    final gyroSignal = List.generate(n, (i) {
      return 50.0 * sin(2 * pi * 5.0 * i / fs); // 5 Hz, 50 deg/s amplitude
    });

    // Simulate mic signal (higher frequency, represents impact sound)
    final micSignal = List.generate(n, (i) {
      return 10.0 * sin(2 * pi * 20.0 * i / fs); // 20 Hz, 10 amplitude
    });

    print('Gyro: 50*sin(2π*5*t) - simulates rotation');
    print('Mic:  10*sin(2π*20*t) - simulates impact sound');

    final gyroFft = _computeFftFeatures(gyroSignal, fs);
    final micFft = _computeFftFeatures(micSignal, fs);

    if (gyroFft != null && micFft != null) {
      final gyroPower = gyroFft.totalPower;
      final micPower = micFft.totalPower;
      final ratio = micPower / (gyroPower + 1e-9);

      print('\nResults:');
      print('  Gyro total power: ${gyroPower.toStringAsFixed(4)}');
      print('  Mic total power:  ${micPower.toStringAsFixed(4)}');
      print('  Mic/Gyro ratio:   ${ratio.toStringAsFixed(4)}');
      print('  Threshold:        ${ImuConfig.micPerGyroThreshold}');

      if (ratio > ImuConfig.micPerGyroThreshold) {
        print('  ✓ Would be detected as SWING');
      } else {
        print('  ✗ Would be REJECTED (ratio < threshold)');
      }

      print('\n📝 For real swings:');
      print('   - Non-swing: ratio typically 5-20');
      print('   - Valid swing: ratio typically 40-100');
      print('   - Threshold: ${ImuConfig.micPerGyroThreshold}');
    }
  }

  /// Test 4: Python comparison with exact values
  void _testPythonComparison() {
    print('\n[TEST 4] Python v8 Exact Comparison');
    print('-' * 60);

    print('Run this Python code and compare:');
    print('');
    print('```python');
    print('import numpy as np');
    print('');
    print('# Test signal');
    print('fs = 100.0');
    print('n = 100');
    print('sig = np.sin(2*np.pi*10*np.arange(n)/fs)');
    print('');
    print('# Apply Hanning window');
    print('window = np.hanning(n)');
    print('sig_windowed = sig * window');
    print('');
    print('# Compute FFT');
    print('fft_vals = np.fft.rfft(sig_windowed)');
    print('freqs = np.fft.rfftfreq(n, d=1.0/fs)');
    print('mag = np.abs(fft_vals)');
    print('power = mag**2');
    print('total_power = np.sum(power)');
    print('');
    print('print(f"Total power: {total_power:.4f}")');
    print('print(f"Peak freq: {freqs[np.argmax(power)]:.1f} Hz")');
    print('print(f"Peak power: {np.max(power):.4f}")');
    print('```');
    print('');
    print('Then compare with Dart output above.');
    print('If total_power differs significantly, adjust normalization.');
  }
}

/// Utility class for data validation
class DataUtils {
  /// Check if swing metrics are valid (matching Python validation)
  static bool isValidSwing(SwingMetrics swing) {
    return swing.isValidSwing &&
        swing.maxTipSpeed > 0 &&
        swing.impactAcceleration > 0 &&
        swing.estimatedForce > 0;
  }
}
