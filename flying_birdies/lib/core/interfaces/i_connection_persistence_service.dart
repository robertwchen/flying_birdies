import '../../models/device_info.dart';

/// Interface for persisting BLE connection information across app sessions
abstract class IConnectionPersistenceService {
  /// Save the last connected device information
  Future<void> saveLastDevice(String deviceId, String deviceName);

  /// Get the last connected device information
  /// Returns null if no device has been saved
  Future<DeviceInfo?> getLastDevice();

  /// Clear the last connected device information
  Future<void> clearLastDevice();

  /// Check if a last device exists in storage
  Future<bool> hasLastDevice();
}
