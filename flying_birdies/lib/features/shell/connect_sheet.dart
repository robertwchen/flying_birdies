import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../../app/theme.dart';
import '../../core/interfaces/i_ble_service.dart';
import '../../core/interfaces/i_connection_persistence_service.dart';
import '../../state/connection_state_notifier.dart';

class BleDevice {
  final String id;
  final String name;
  const BleDevice({required this.id, required this.name});
}

/// Open the connect sheet and get the connected device (or null if cancelled)
Future<BleDevice?> showConnectSheet(BuildContext context) {
  return showModalBottomSheet<BleDevice?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .35),
    builder: (_) => const _ConnectSheet(),
  );
}

class _ConnectSheet extends StatefulWidget {
  const _ConnectSheet();

  @override
  State<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<_ConnectSheet> {
  late final IBleService _bleService;
  late final ConnectionStateNotifier _connectionNotifier;
  late final IConnectionPersistenceService _persistenceService;

  bool _scanning = false;
  bool _connected = false;
  BleDevice? _selected;
  List<BleDevice> _devices = const [];
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _bleService = context.read<IBleService>();
    _connectionNotifier = context.read<ConnectionStateNotifier>();
    _persistenceService = context.read<IConnectionPersistenceService>();

    // Check if already connected
    if (_connectionNotifier.isConnected) {
      _connected = true;
      _selected = BleDevice(
        id: _connectionNotifier.deviceId ?? '',
        name: _connectionNotifier.deviceName ?? 'Connected Device',
      );
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning) return;

    setState(() {
      _scanning = true;
      _devices = [];
      _selected = null;
      _connected = false;
    });

    // Cancel any existing scan
    await _scanSubscription?.cancel();

    // Use REAL BLE scan from BleService with longer timeout
    final discoveredDevices = <String, BleDevice>{};

    _scanSubscription = _bleService
        .scanForDevices(
      timeout: const Duration(seconds: 15), // Increased timeout
    )
        .listen(
      (device) {
        // Only add devices with names (filter out unnamed devices)
        if (device.name.isNotEmpty &&
            !discoveredDevices.containsKey(device.id)) {
          discoveredDevices[device.id] = BleDevice(
            id: device.id,
            name: device.name,
          );

          if (mounted) {
            setState(() {
              _devices = discoveredDevices.values.toList();
            });
          }
        }
      },
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
      onError: (error) {
        debugPrint('BLE scan error: $error');
        if (mounted) setState(() => _scanning = false);
      },
    );

    // Auto-stop scanning after timeout
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _scanning) {
        _scanSubscription?.cancel();
        setState(() => _scanning = false);
      }
    });
  }

  Future<void> _connect() async {
    if (_selected == null) {
      return _startScan();
    }

    // Stop scanning immediately when connecting
    await _scanSubscription?.cancel();

    if (mounted) {
      setState(() => _scanning = true);
    }

    try {
      // If already connected to a different device, disconnect first
      if (_connected && _bleService.isConnected) {
        debugPrint(
            'Disconnecting from current device before connecting to new one');
        await _bleService.disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Use REAL BLE connection with device name
      await _bleService.connectToDevice(_selected!.id,
          deviceName: _selected!.name);

      // Wait a moment for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      // Start data collection
      await _bleService.startDataCollection();

      // Save device for auto-reconnect
      await _persistenceService.saveLastDevice(
        _selected!.id,
        _selected!.name,
      );

      // Update connection state notifier
      _connectionNotifier.updateConnectionState(
        DeviceConnectionState.connected,
        deviceId: _selected!.id,
        deviceName: _selected!.name,
      );

      if (mounted) {
        setState(() {
          _scanning = false;
          _connected = true;
        });
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      if (mounted) {
        setState(() {
          _scanning = false;
          _connected = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }

  Future<void> _forgetDevice() async {
    try {
      // Clear saved device
      await _persistenceService.clearLastDevice();

      // Disconnect from current device
      await _bleService.disconnect();

      if (mounted) {
        setState(() {
          _connected = false;
          _selected = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device forgotten')),
        );
      }
    } catch (e) {
      debugPrint('Error forgetting device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to forget device: $e')),
        );
      }
    }
  }

  Color get _bannerColor {
    if (_connected) return const Color(0xFF16A34A).withValues(alpha: .18);
    if (_scanning) return const Color(0xFF7C3AED).withValues(alpha: .18);
    if (_devices.isEmpty) return const Color(0xFFF0433A).withValues(alpha: .16);
    return Colors.white.withValues(alpha: .08);
  }

  IconData get _bannerIcon {
    if (_connected) return Icons.check_circle_rounded;
    if (_scanning) return Icons.wifi_tethering_rounded;
    if (_devices.isEmpty) return Icons.error_outline;
    return Icons.info_outline_rounded;
  }

  String get _bannerTitle {
    if (_connected) return 'Device Connected';
    if (_scanning) return 'Scanning for Devices…';
    if (_devices.isEmpty) return 'No Device Found';
    return 'Select a Device';
  }

  String get _bannerSubtitle {
    if (_connected) return 'You\'re ready to train';
    if (_scanning) return 'Keep your sensor powered on';
    if (_devices.isEmpty) return 'Make sure your sensor is on.';
    return 'Tap a device below to pair & connect';
  }

  String get _ctaText {
    if (_connected) return 'Done';
    if (_selected != null) return 'Pair & Connect';
    if (_devices.isEmpty) return 'Scan for Devices';
    return 'Scan Again';
  }

  VoidCallback? get _ctaAction {
    if (_connected) {
      return () => Navigator.of(context).pop(_selected);
    }
    // Allow connecting even while scanning if a device is selected
    if (_selected != null) return _connect;
    if (_devices.isEmpty) return _startScan;
    return _startScan; // Scan again if devices exist but none selected
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = screenHeight * 0.85; // Max 85% of screen height

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + keyboardHeight),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1220).withValues(alpha: .88),
                borderRadius: radius,
                border: Border.all(color: Colors.white.withValues(alpha: .06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .40),
                    blurRadius: 28,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab handle
                  Container(
                    width: 48,
                    height: 6,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),

                  // Content - wrapped in scrollable area with proper constraints
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Pill
                            Container(
                              height: 36,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF7C3AED),
                                    Color(0xFF6D28D9)
                                  ],
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bluetooth,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Bluetooth',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Title + subtitle
                            const Text(
                              'Smart Racket Sensor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Connect your Flying Birdies sensor',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .75),
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Status banner
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _bannerColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: .08)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_bannerIcon,
                                      size: 20,
                                      color: _connected
                                          ? const Color(0xFF16A34A)
                                          : _scanning
                                              ? const Color(0xFF7C3AED)
                                              : (_devices.isEmpty
                                                  ? const Color(0xFFF0433A)
                                                  : Colors.white70)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _bannerTitle,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _bannerSubtitle,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: .72),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (_scanning) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: .08),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    const Color(0xFF7C3AED)
                                        .withValues(alpha: .85),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),

                            // Device area with proper constraints
                            if (_devices.isEmpty && !_scanning && !_connected)
                              _EmptyState(onScan: _startScan)
                            else if (_devices.isNotEmpty)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Available Devices (${_devices.length})',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: .85),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Use Column with map instead of ListView for proper scrolling
                                  ..._devices.map(
                                    (d) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _DeviceRow(
                                        device: d,
                                        selected: _selected?.id == d.id,
                                        onTap: () {
                                          // Only select the device, don't auto-connect
                                          if (mounted) {
                                            setState(() => _selected = d);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (_connected && _selected != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      color: const Color(0xFF16A34A),
                                    ),
                                    child: const Text(
                                      'CONNECTED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selected!.name,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: .75),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Forget Device button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18),
                                  label: const Text('Forget Device'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFF0433A),
                                    side: BorderSide(
                                      color: const Color(0xFFF0433A)
                                          .withValues(alpha: .5),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _forgetDevice,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // CTA Button - Fixed at bottom
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .04),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: .06),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _ctaAction,
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient:
                                const LinearGradient(colors: AppTheme.gCTA),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .30),
                                blurRadius: 16,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            height: 52,
                            child: Text(
                              _ctaText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .06),
                      border: Border(
                          top: BorderSide(
                              color: Colors.white.withValues(alpha: .06))),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.selected,
    required this.onTap,
  });

  final BleDevice device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: .04),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: .28)
                : Colors.white.withValues(alpha: .08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Colors.white : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.id,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .65),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.bluetooth, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: .04),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0433A).withValues(alpha: .20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.search_off,
                color: Color(0xFFF0433A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No devices yet. Turn on your sensor and scan.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .78),
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onScan,
            child: const Text('Scan',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
