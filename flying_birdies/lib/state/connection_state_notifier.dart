import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// Connection event for stream
class ConnectionEvent {
  final DeviceConnectionState state;
  final String? deviceId;
  final String? deviceName;
  final DateTime timestamp;

  ConnectionEvent({
    required this.state,
    this.deviceId,
    this.deviceName,
    required this.timestamp,
  });
}

/// Manages connection state and notifies listeners of changes
class ConnectionStateNotifier extends ChangeNotifier {
  DeviceConnectionState _state = DeviceConnectionState.disconnected;
  String? _deviceId;
  String? _deviceName;

  final StreamController<ConnectionEvent> _eventController =
      StreamController<ConnectionEvent>.broadcast();

  DeviceConnectionState get state => _state;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  bool get isConnected => _state == DeviceConnectionState.connected;

  Stream<ConnectionEvent> get connectionEventStream => _eventController.stream;

  /// Update connection state and notify listeners
  void updateConnectionState(
    DeviceConnectionState state, {
    String? deviceId,
    String? deviceName,
  }) {
    _state = state;
    _deviceId = deviceId;
    _deviceName = deviceName;

    // Emit event to stream
    _eventController.add(ConnectionEvent(
      state: state,
      deviceId: deviceId,
      deviceName: deviceName,
      timestamp: DateTime.now(),
    ));

    // Notify UI listeners
    notifyListeners();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}
