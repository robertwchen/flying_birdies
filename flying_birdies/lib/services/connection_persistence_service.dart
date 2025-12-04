import 'package:shared_preferences/shared_preferences.dart';
import '../core/interfaces/i_connection_persistence_service.dart';
import '../core/logger.dart';
import '../models/device_info.dart';

/// Implementation of connection persistence using SharedPreferences
class ConnectionPersistenceService implements IConnectionPersistenceService {
  final SharedPreferences _prefs;
  final ILogger _logger;

  // Storage keys
  static const String _keyDeviceId = 'last_device_id';
  static const String _keyDeviceName = 'last_device_name';
  static const String _keyLastConnected = 'last_connected_timestamp';

  ConnectionPersistenceService(this._prefs, this._logger);

  @override
  Future<void> saveLastDevice(String deviceId, String deviceName) async {
    try {
      await _prefs.setString(_keyDeviceId, deviceId);
      await _prefs.setString(_keyDeviceName, deviceName);
      await _prefs.setInt(
        _keyLastConnected,
        DateTime.now().millisecondsSinceEpoch,
      );

      _logger.info(
        'Saved last device',
        context: {'id': deviceId, 'name': deviceName},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to save last device',
        error: e,
        stackTrace: stackTrace,
        context: {'deviceId': deviceId, 'deviceName': deviceName},
      );
      rethrow;
    }
  }

  @override
  Future<DeviceInfo?> getLastDevice() async {
    try {
      final id = _prefs.getString(_keyDeviceId);
      final name = _prefs.getString(_keyDeviceName);
      final timestamp = _prefs.getInt(_keyLastConnected);

      if (id == null || name == null || timestamp == null) {
        _logger.debug('No last device found in storage');
        return null;
      }

      final deviceInfo = DeviceInfo(
        id: id,
        name: name,
        lastConnected: DateTime.fromMillisecondsSinceEpoch(timestamp),
      );

      _logger.debug(
        'Retrieved last device',
        context: {'device': deviceInfo.toString()},
      );

      return deviceInfo;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to retrieve last device',
        error: e,
        stackTrace: stackTrace,
      );
      // Return null on error to allow graceful degradation
      return null;
    }
  }

  @override
  Future<void> clearLastDevice() async {
    try {
      await _prefs.remove(_keyDeviceId);
      await _prefs.remove(_keyDeviceName);
      await _prefs.remove(_keyLastConnected);

      _logger.info('Cleared last device');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to clear last device',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<bool> hasLastDevice() async {
    try {
      final hasDevice = _prefs.containsKey(_keyDeviceId);
      _logger.debug('Has last device: $hasDevice');
      return hasDevice;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check for last device',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
