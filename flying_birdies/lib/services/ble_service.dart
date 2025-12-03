import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/imu_reading.dart';
import '../core/interfaces/i_ble_service.dart';
import '../core/logger.dart';
import '../core/exceptions.dart';
import '../state/connection_state_notifier.dart';

/// BLE Service for connecting to Flying Birdies IMU device
class BleService implements IBleService {
  final FlutterReactiveBle _ble;
  final ILogger _logger;
  final ConnectionStateNotifier? _connectionStateNotifier;

  BleService(
    this._logger, {
    FlutterReactiveBle? ble,
    ConnectionStateNotifier? connectionStateNotifier,
  })  : _ble = ble ?? FlutterReactiveBle(),
        _connectionStateNotifier = connectionStateNotifier;

  // Temporary backward compatibility - deprecated, use Provider instead
  static BleService? _instance;
  static BleService get instance {
    _instance ??= BleService(ConsoleLogger('BleService'));
    return _instance!;
  }

  // Temporary backward compatibility getter
  Stream<ImuReading> get imuStream => imuDataStream;

  // BLE Configuration - Flying Birdies UUIDs
  static const String serviceUuid = '61a73540-8fd9-4e85-8537-f387fad03705';
  static const String accelXCharUuid = '61a73541-8fd9-4e85-8537-f387fad03705';
  static const String accelYCharUuid = '61a73542-8fd9-4e85-8537-f387fad03705';
  static const String accelZCharUuid = '61a73543-8fd9-4e85-8537-f387fad03705';
  static const String gyroXCharUuid = '61a73544-8fd9-4e85-8537-f387fad03705';
  static const String gyroYCharUuid = '61a73545-8fd9-4e85-8537-f387fad03705';
  static const String gyroZCharUuid = '61a73546-8fd9-4e85-8537-f387fad03705';
  static const String micRmsCharUuid = '61a7354A-8fd9-4e85-8537-f387fad03705';

  // State
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  final List<StreamSubscription> _characteristicSubscriptions = [];
  String? _connectedDeviceId;
  DeviceConnectionState _connectionState = DeviceConnectionState.disconnected;
  Timer? _connectionMonitor;
  bool _intentionalDisconnect = false;

  // Current sensor values
  double? _currentAccelX, _currentAccelY, _currentAccelZ;
  double? _currentGyroX, _currentGyroY, _currentGyroZ;
  double? _currentMicRms;

  // IMU data stream
  final StreamController<ImuReading> _imuStreamController =
      StreamController<ImuReading>.broadcast();

  // Connection state stream
  final StreamController<DeviceConnectionState> _connectionStateController =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  Stream<ImuReading> get imuDataStream => _imuStreamController.stream;

  @override
  Stream<DeviceConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  DeviceConnectionState get currentState => _connectionState;

  @override
  bool get isConnected => _connectionState == DeviceConnectionState.connected;

  @override
  String? get connectedDeviceId => _connectedDeviceId;

  /// Request necessary permissions for BLE
  @override
  Future<bool> requestPermissions() async {
    try {
      _logger.info('Requesting BLE permissions');

      final permissions = [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ];

      for (final permission in permissions) {
        final status = await permission.request();
        if (!status.isGranted) {
          _logger.warning('Permission denied',
              context: {'permission': permission.toString()});
          return false;
        }
      }

      _logger.info('All BLE permissions granted');
      return true;
    } catch (e, stackTrace) {
      _logger.error('Failed to request permissions',
          error: e, stackTrace: stackTrace);
      throw BleException(
        'Failed to request BLE permissions',
        'permissions',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Scan for BLE devices
  @override
  Stream<DiscoveredDevice> scanForDevices(
      {Duration timeout = const Duration(seconds: 15)}) {
    try {
      _logger.info('Starting BLE device scan',
          context: {'timeout': timeout.inSeconds});

      return _ble.scanForDevices(withServices: []).timeout(
        timeout,
        onTimeout: (sink) {
          _logger.info('BLE scan timeout');
          sink.close();
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to start BLE scan',
          error: e, stackTrace: stackTrace);
      throw BleException(
        'Failed to start BLE device scan',
        'scan',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Connect to a device
  @override
  Future<void> connectToDevice(String deviceId) async {
    try {
      _logger.info('Connecting to device', context: {'deviceId': deviceId});
      await disconnect();

      _intentionalDisconnect = false;
      _connectionState = DeviceConnectionState.connecting;

      _connectionSubscription = _ble
          .connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 30),
      )
          .listen(
        (connectionState) async {
          _connectionState = connectionState.connectionState;

          // Emit connection state change
          _connectionStateController.add(connectionState.connectionState);

          _logger.debug('Connection state changed',
              context: {'state': connectionState.connectionState.toString()});

          if (connectionState.connectionState ==
              DeviceConnectionState.connected) {
            _connectedDeviceId = deviceId;
            _logger.info('Device connected', context: {'deviceId': deviceId});

            // Update ConnectionStateNotifier
            _connectionStateNotifier?.updateConnectionState(
              DeviceConnectionState.connected,
              deviceId: deviceId,
              deviceName: 'StrikePro Sensor',
            );

            await _discoverServices(deviceId);
            _startConnectionMonitor();
          } else if (connectionState.connectionState ==
              DeviceConnectionState.disconnected) {
            _logger.warning('Device disconnected',
                context: {'deviceId': deviceId});

            // Update ConnectionStateNotifier
            _connectionStateNotifier?.updateConnectionState(
              DeviceConnectionState.disconnected,
            );

            await _handleDisconnection();
          }
        },
        onError: (error) {
          _logger.error('Connection error',
              error: error, context: {'deviceId': deviceId});
          _handleDisconnection();
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to connect to device',
          error: e, stackTrace: stackTrace, context: {'deviceId': deviceId});
      throw BleException(
        'Failed to connect to device',
        'connect',
        context: 'deviceId: $deviceId',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Monitor connection and attempt reconnection if needed
  void _startConnectionMonitor() {
    _connectionMonitor?.cancel();
    _connectionMonitor = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_connectionState == DeviceConnectionState.disconnected &&
          !_intentionalDisconnect &&
          _connectedDeviceId != null) {
        // Attempt reconnection
        connectToDevice(_connectedDeviceId!);
      }
    });
  }

  /// Discover services on connected device
  Future<void> _discoverServices(String deviceId) async {
    try {
      _logger.debug('Discovering services', context: {'deviceId': deviceId});
      await _ble.discoverAllServices(deviceId);
      await _ble.getDiscoveredServices(deviceId);
      _logger.info('Services discovered', context: {'deviceId': deviceId});
    } catch (e, stackTrace) {
      _logger.error('Service discovery failed',
          error: e, stackTrace: stackTrace, context: {'deviceId': deviceId});
      throw BleException(
        'Failed to discover services',
        'discover',
        context: 'deviceId: $deviceId',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Start collecting IMU data
  @override
  Future<void> startDataCollection() async {
    if (_connectedDeviceId == null) {
      throw BleException(
        'Cannot start data collection: no device connected',
        'startDataCollection',
      );
    }

    try {
      _logger.info('Starting data collection',
          context: {'deviceId': _connectedDeviceId});

      final characteristics = [
        (accelXCharUuid, 'accelX'),
        (accelYCharUuid, 'accelY'),
        (accelZCharUuid, 'accelZ'),
        (gyroXCharUuid, 'gyroX'),
        (gyroYCharUuid, 'gyroY'),
        (gyroZCharUuid, 'gyroZ'),
        (micRmsCharUuid, 'micRms'),
      ];

      for (final (charUuid, sensorType) in characteristics) {
        final characteristic = QualifiedCharacteristic(
          serviceId: Uuid.parse(serviceUuid),
          characteristicId: Uuid.parse(charUuid),
          deviceId: _connectedDeviceId!,
        );

        final subscription =
            _ble.subscribeToCharacteristic(characteristic).listen(
          (data) => _onSensorDataReceived(data, sensorType),
          onError: (error) {
            _logger.error('Characteristic subscription error',
                error: error,
                context: {'sensorType': sensorType, 'charUuid': charUuid});
          },
        );

        _characteristicSubscriptions.add(subscription);
      }

      _logger.info('Data collection started');
    } catch (e, stackTrace) {
      _logger.error('Failed to start data collection',
          error: e, stackTrace: stackTrace);
      throw BleException(
        'Failed to start data collection',
        'startDataCollection',
        context: 'deviceId: $_connectedDeviceId',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stop collecting IMU data
  @override
  void stopDataCollection() {
    _logger.info('Stopping data collection');

    for (var subscription in _characteristicSubscriptions) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();

    _currentAccelX = _currentAccelY = _currentAccelZ = null;
    _currentGyroX = _currentGyroY = _currentGyroZ = null;
    _currentMicRms = null;

    _logger.debug('Data collection stopped');
  }

  /// Handle incoming sensor data
  void _onSensorDataReceived(List<int> data, String sensorType) {
    if (data.isEmpty) return;

    try {
      // Parse as UTF-8 string (same as v11)
      final dataString = String.fromCharCodes(data).trim();
      if (dataString.isEmpty) return;

      final value = double.tryParse(dataString);
      if (value == null) {
        _logger.warning('Failed to parse sensor data',
            context: {'sensorType': sensorType, 'data': dataString});
        return;
      }

      // Update current values
      switch (sensorType) {
        case 'accelX':
          _currentAccelX = value;
          break;
        case 'accelY':
          _currentAccelY = value;
          break;
        case 'accelZ':
          _currentAccelZ = value;
          break;
        case 'gyroX':
          _currentGyroX = value;
          break;
        case 'gyroY':
          _currentGyroY = value;
          break;
        case 'gyroZ':
          _currentGyroZ = value;
          break;
        case 'micRms':
          _currentMicRms = value;
          break;
      }

      // If we have all 7 values, emit an IMU reading
      if (_currentAccelX != null &&
          _currentAccelY != null &&
          _currentAccelZ != null &&
          _currentGyroX != null &&
          _currentGyroY != null &&
          _currentGyroZ != null &&
          _currentMicRms != null) {
        final reading = ImuReading(
          timestamp: DateTime.now(),
          ax: _currentAccelX!,
          ay: _currentAccelY!,
          az: _currentAccelZ!,
          gx: _currentGyroX!,
          gy: _currentGyroY!,
          gz: _currentGyroZ!,
          micRms: _currentMicRms!,
        );

        _imuStreamController.add(reading);
      }
    } catch (e, stackTrace) {
      _logger.error('Error processing sensor data',
          error: e,
          stackTrace: stackTrace,
          context: {'sensorType': sensorType});
    }
  }

  /// Handle disconnection
  Future<void> _handleDisconnection() async {
    _connectionState = DeviceConnectionState.disconnected;
    stopDataCollection();

    // Don't clear device ID if we want to reconnect
    if (_intentionalDisconnect) {
      _connectedDeviceId = null;
      _connectionMonitor?.cancel();
      _connectionMonitor = null;
    }
  }

  /// Disconnect from device
  @override
  Future<void> disconnect() async {
    _logger.info('Disconnecting from device',
        context: {'deviceId': _connectedDeviceId});

    _intentionalDisconnect = true;
    _connectionMonitor?.cancel();
    _connectionMonitor = null;

    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _handleDisconnection();

    // Update ConnectionStateNotifier
    _connectionStateNotifier?.updateConnectionState(
      DeviceConnectionState.disconnected,
    );

    _connectedDeviceId = null;
    _logger.info('Disconnected');
  }

  /// Clean up resources
  void dispose() {
    _logger.info('Disposing BleService');
    _connectionMonitor?.cancel();
    disconnect();
    _imuStreamController.close();
    _connectionStateController.close();
  }
}
