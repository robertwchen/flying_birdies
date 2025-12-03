import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../../models/imu_reading.dart';

/// BLE Service interface for dependency injection
abstract class IBleService {
  /// Stream of connection state changes
  Stream<DeviceConnectionState> get connectionStateStream;

  /// Stream of IMU data readings
  Stream<ImuReading> get imuDataStream;

  /// Current connection state
  DeviceConnectionState get currentState;

  /// Connected device ID (null if not connected)
  String? get connectedDeviceId;

  /// Check if currently connected
  bool get isConnected;

  /// Request necessary BLE permissions
  Future<bool> requestPermissions();

  /// Scan for BLE devices
  Stream<DiscoveredDevice> scanForDevices({Duration timeout});

  /// Connect to a specific device
  Future<void> connectToDevice(String deviceId);

  /// Disconnect from current device
  Future<void> disconnect();

  /// Start collecting IMU data from connected device
  Future<void> startDataCollection();

  /// Stop collecting IMU data
  void stopDataCollection();

  /// Dispose resources
  void dispose();
}
