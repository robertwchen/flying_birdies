import 'dart:math';

// Configuration constants matching Python pipeline exactly
class ImuConfig {
  // Physics constants (matching Python TENNISEYE-STYLE PHYSICS CONSTANTS)
  static const double mountToTipDistance = 0.39; // MOUNT_TO_TIP_M
  static const double shuttleMass = 0.0053; // SHUTTLE_MASS_KG (kg)
  static const double contactDurationMs = 2.0; // CONTACT_MS (ms)
  static const double effectiveTipMass = 0.15; // EFFECTIVE_TIP_MASS_KG (kg)
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

  // FFT validation threshold (matching Python conditional swing detection)
  static const double micPerGyroThreshold =
      15.0; // Lowered from 20 to be more sensitive (was rejecting valid swings)

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
  final double estimatedForce; // N (impact force at racket)
  final double swingForce; // N (shuttle-side force)
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

  // Track last detected swing time to prevent duplicates
  DateTime? _lastSwingTime;
  static const double _minSwingIntervalSec = 0.5; // Match Python MIN_SEP_SEC

  /// Process new IMU reading and detect swings using Python algorithm
  SwingMetrics? processReading(ImuReading reading) {
    _dataBuffer.add(reading);

    // Keep buffer size manageable (equivalent to Python MAX_POINTS)
    if (_dataBuffer.length > 1000) {
      _dataBuffer.removeAt(0);
    }

    // Need sufficient data for analysis (matching Python minimum)
    if (_dataBuffer.length < 100) {
      return null;
    }

    // Run detection algorithm on current buffer
    final swings = _detectSwings();

    // Return the most recent swing if any, but only if it's new
    if (swings.isNotEmpty) {
      final latestSwing = swings.last;

      // Check if this is a valid swing and not a duplicate
      if (latestSwing.isValidSwing) {
        // Check if enough time has passed since last swing
        if (_lastSwingTime == null ||
            latestSwing.swingTime.difference(_lastSwingTime!).inMilliseconds /
                    1000.0 >=
                _minSwingIntervalSec) {
          _lastSwingTime = latestSwing.swingTime;
          _hitCounter++;
          return latestSwing;
        }
      }
    }

    return null;
  }

  /// Main detection algorithm (matching Python tenniseye_style_analysis)
  List<SwingMetrics> _detectSwings() {
    if (_dataBuffer.length < 20) return [];

    // Extract data arrays (matching Python data extraction)
    final timestamps = _dataBuffer
        .map((r) => r.timestamp.millisecondsSinceEpoch / 1000.0)
        .toList();
    final accData = _dataBuffer.map((r) => r.acceleration).toList(); // in g
    final micData = _dataBuffer.map((r) => r.micRms).toList();
    final gyroData =
        _dataBuffer.map((r) => r.gyroDegPerSec).toList(); // in deg/s

    // 1) Estimate sampling rate (matching Python)
    double fsEst = ImuConfig.samplingRate.toDouble();
    if (timestamps.length > 1) {
      final duration = timestamps.last - timestamps.first;
      if (duration > 0) {
        fsEst = (timestamps.length - 1) / duration;
      }
    }

    // 2) Detect stroke candidates on |d(acc)| (matching Python exactly)
    final dacc = _calculateDerivative(accData);
    final absDacc = dacc.map((x) => x.abs()).toList();

    final mean = _calculateMean(absDacc);
    final std = _calculateStandardDeviation(absDacc, mean);
    final threshold = mean + ImuConfig.threshStdMult * std;

    // DEBUG: Print detection parameters
    print(
      '[Analysis] Buffer size: ${_dataBuffer.length}, Estimated fs: ${fsEst.toStringAsFixed(1)} Hz',
    );
    print(
      '[Analysis] Derivative threshold: ${threshold.toStringAsFixed(3)} (mean=${mean.toStringAsFixed(3)}, std=${std.toStringAsFixed(3)})',
    );

    // Find peaks above threshold (matching Python peak detection)
    final peakIndices = _findPeaks(absDacc, threshold, fsEst);

    print('[Analysis] Detected ${peakIndices.length} stroke candidates');
    if (peakIndices.isEmpty) return [];

    // 3) Refine center with gyro peak (matching Python)
    final windows = _refineWithGyroPeaks(
      peakIndices,
      gyroData,
      timestamps,
      fsEst,
    );

    print(
      '[Analysis] Built ${windows.length} windows (pre=${ImuConfig.preTimeSec}s, post=${ImuConfig.postTimeSec}s)',
    );
    if (windows.isEmpty) return [];

    // 4) Analyze each window (matching Python per-window analysis)
    final swings = <SwingMetrics>[];

    for (int i = 0; i < windows.length; i++) {
      print('[Analysis] Analyzing window ${i + 1}/${windows.length}');
      final swing = _analyzeWindow(
        windows[i],
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

    // 3) Impact force at racket (matching Python)
    final impactForce = ImuConfig.effectiveTipMass * accelMag; // N

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
      swingForce: shuttleForceActual,
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

  /// Simplified real FFT computation
  FftResult _computeRealFft(List<double> signal, double fsEst) {
    final n = signal.length;
    final frequencies = <double>[];
    final magnitudes = <double>[];
    final power = <double>[];

    // Compute only positive frequencies (matching Python rfft)
    for (int k = 0; k <= n ~/ 2; k++) {
      double real = 0.0;
      double imag = 0.0;

      for (int i = 0; i < n; i++) {
        final angle = -2 * pi * k * i / n;
        real += signal[i] * cos(angle);
        imag += signal[i] * sin(angle);
      }

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
