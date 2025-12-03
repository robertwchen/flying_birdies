import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/swing_metrics.dart';

/// Swing event for stream
class SwingEvent {
  final SwingMetrics swing;
  final DateTime timestamp;

  SwingEvent({
    required this.swing,
    required this.timestamp,
  });
}

/// Manages swing data state and notifies listeners of changes
class SwingDataNotifier extends ChangeNotifier {
  SwingMetrics? _latestSwing;
  int _swingCount = 0;

  final StreamController<SwingEvent> _eventController =
      StreamController<SwingEvent>.broadcast();

  SwingMetrics? get latestSwing => _latestSwing;
  int get swingCount => _swingCount;

  Stream<SwingEvent> get swingEventStream => _eventController.stream;

  /// Add a new swing
  void addSwing(SwingMetrics swing) {
    _latestSwing = swing;
    _swingCount++;

    _eventController.add(SwingEvent(
      swing: swing,
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }

  /// Reset swing data (e.g., when starting a new session)
  void reset() {
    _latestSwing = null;
    _swingCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}
