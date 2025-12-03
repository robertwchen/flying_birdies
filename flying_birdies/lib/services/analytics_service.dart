import 'dart:async';
import '../core/interfaces/i_analytics_service.dart';
import '../core/logger.dart';
import '../core/exceptions.dart';
import '../models/imu_reading.dart';
import '../models/swing_metrics.dart';
import 'imu_analytics_v2.dart';

/// Analytics Service for processing IMU data and detecting swings
class AnalyticsService implements IAnalyticsService {
  final SwingAnalyzerV2 _analyzer;
  final ILogger _logger;

  final StreamController<SwingMetrics> _swingStreamController =
      StreamController<SwingMetrics>.broadcast();

  AnalyticsService(this._logger, {SwingAnalyzerV2? analyzer})
      : _analyzer = analyzer ?? SwingAnalyzerV2();

  @override
  Stream<SwingMetrics> get swingStream => _swingStreamController.stream;

  @override
  void processReading(ImuReading reading) {
    try {
      // Process reading through analyzer
      final swing = _analyzer.processReading(reading);

      // If a valid swing was detected, emit it through the stream
      if (swing != null && swing.qualityPassed) {
        _logger.debug('Swing detected', context: {
          'maxVtip': swing.maxVtip,
          'estForceN': swing.estForceN,
          'qualityPassed': swing.qualityPassed,
        });

        _swingStreamController.add(swing);
      }
    } catch (e, stackTrace) {
      _logger.error('Error processing IMU reading',
          error: e, stackTrace: stackTrace);
      throw AnalyticsException(
        'Failed to process IMU reading',
        context: 'processReading',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void reset() {
    try {
      _logger.info('Resetting analyzer state');
      _analyzer.clear();
      _logger.debug('Analyzer state reset');
    } catch (e, stackTrace) {
      _logger.error('Error resetting analyzer',
          error: e, stackTrace: stackTrace);
      throw AnalyticsException(
        'Failed to reset analyzer',
        context: 'reset',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Map<String, dynamic> getStatistics() {
    try {
      return _analyzer.getCurrentStats();
    } catch (e, stackTrace) {
      _logger.error('Error getting statistics',
          error: e, stackTrace: stackTrace);
      throw AnalyticsException(
        'Failed to get statistics',
        context: 'getStatistics',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _logger.info('Disposing AnalyticsService');
    _swingStreamController.close();
  }
}
