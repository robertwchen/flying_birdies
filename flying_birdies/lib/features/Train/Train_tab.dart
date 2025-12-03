// lib/features/Train/train_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../services/ble_service.dart';
import '../../services/analytics_service.dart';
import '../../services/session_service.dart';
import '../../state/connection_state_notifier.dart';
import '../../state/session_state_notifier.dart';

class TrainTab extends StatefulWidget {
  const TrainTab({super.key, this.deviceName});

  /// If null, we treat as "not connected".
  final String? deviceName;

  @override
  State<TrainTab> createState() => _TrainTabState();
}

class _TrainTabState extends State<TrainTab> {
  // Exactly 4 strokes (no level labels)
  static const _strokes = <_StrokeMeta>[
    _StrokeMeta(
      key: 'oh-fh',
      title: 'Overhead Forehand',
      subtitle: 'Power overhead attack shot',
    ),
    _StrokeMeta(
      key: 'oh-bh',
      title: 'Overhead Backhand',
      subtitle: 'High defensive clear/backcourt',
    ),
    _StrokeMeta(
      key: 'ua-fh',
      title: 'Underarm Forehand',
      subtitle: 'Soft finesse to front court',
    ),
    _StrokeMeta(
      key: 'ua-bh',
      title: 'Underarm Backhand',
      subtitle: 'Fast horizontal drive',
    ),
  ];

  String? _selectedKey;
  bool _sessionActive = false;
  int _shotCount = 0;

  // Live metrics – only updated when a **shot** is registered.
  double swingSpeed = 0; // km/h
  double impactForce = 0; // N
  double acceleration = 0; // m/s^2
  double swingForce = 0; // arbitrary unit

  // Stream subscriptions
  StreamSubscription? _imuSubscription;
  StreamSubscription? _swingSubscription;
  StreamSubscription? _connectionSubscription;

  int? _currentSessionId;

  @override
  void initState() {
    super.initState();
    // Default to first stroke so dropdown has a value.
    _selectedKey = _strokes.first.key;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get services from Provider
    final bleService = Provider.of<BleService>(context, listen: false);
    final analyticsService =
        Provider.of<AnalyticsService>(context, listen: false);
    final sessionService = Provider.of<SessionService>(context, listen: false);

    // Cancel existing subscriptions
    _imuSubscription?.cancel();
    _swingSubscription?.cancel();
    _connectionSubscription?.cancel();

    // Subscribe to IMU data stream and process through analytics
    _imuSubscription = bleService.imuDataStream.listen((reading) {
      if (_sessionActive) {
        analyticsService.processReading(reading);
      }
    });

    // Subscribe to swing detection stream
    _swingSubscription = analyticsService.swingStream.listen((swing) {
      if (_sessionActive && mounted) {
        setState(() {
          // Update all 4 metrics from detected swing
          swingSpeed = swing.maxVtip * 3.6; // m/s to km/h
          impactForce = swing.estForceN;
          acceleration = swing.impactAmax;
          swingForce = swing.impactSeverity;
          _shotCount += 1;
        });

        // Save to database via SessionService
        if (_currentSessionId != null) {
          sessionService.recordSwing(_currentSessionId!, swing);
        }
      }
    });

    // Subscribe to connection state changes
    _connectionSubscription = bleService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          // Trigger rebuild when connection state changes
        });
      }
    });
  }

  @override
  void dispose() {
    _imuSubscription?.cancel();
    _swingSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  _StrokeMeta get _currentStroke {
    final sel = _strokes.firstWhere(
      (s) => s.key == _selectedKey,
      orElse: () => _strokes.first,
    );
    return sel;
  }

  void _onSelectStroke(String key) {
    setState(() {
      _selectedKey = key;
    });
  }

  Future<void> _onToggleSession() async {
    final bleService = Provider.of<BleService>(context, listen: false);
    final analyticsService =
        Provider.of<AnalyticsService>(context, listen: false);
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final sessionStateNotifier =
        Provider.of<SessionStateNotifier>(context, listen: false);

    // You must be connected before starting.
    if (!_sessionActive) {
      if (!bleService.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connect your sensor before starting a session.'),
          ),
        );
        return;
      }

      // Start new session
      try {
        final sessionId = await sessionService.startSession(
          userId: null, // TODO: Get from auth service
          deviceId: bleService.connectedDeviceId,
          strokeFocus: _currentStroke.title,
        );

        setState(() {
          _currentSessionId = sessionId;
          _shotCount = 0;
          swingSpeed = 0;
          impactForce = 0;
          acceleration = 0;
          swingForce = 0;
          _sessionActive = true;
        });

        // Clear analyzer state
        analyticsService.reset();

        // Update session state notifier
        sessionStateNotifier.startSession(sessionId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start session: $e')),
          );
        }
      }
    } else {
      // End session
      if (_currentSessionId != null) {
        try {
          await sessionService.endSession(_currentSessionId!);

          // Update session state notifier
          sessionStateNotifier.endSession();
        } catch (e) {
          debugPrint('Failed to end session: $e');
        }
      }

      setState(() {
        _sessionActive = false;
        _currentSessionId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF111827);

    // Get connection state from Provider
    final connectionState = context.watch<ConnectionStateNotifier>();
    final isConnected = connectionState.isConnected;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Header row: icon + title + connection pill
        Row(
          children: [
            const Icon(
              Icons.podcasts_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Train',
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const Spacer(),
            _ConnectionPill(
              isConnected: isConnected,
              deviceName: connectionState.deviceName ??
                  widget.deviceName ??
                  'No sensor',
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Stroke selection card
        Text(
          'Stroke selection',
          style: TextStyle(
            color: primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _StrokeSelectionCard(
          strokes: _strokes,
          selectedKey: _selectedKey,
          onSelect: _onSelectStroke,
        ),

        const SizedBox(height: 22),

        // Live sensor readings section
        Row(
          children: [
            Text(
              'Live Sensor Readings',
              style: TextStyle(
                color: primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            _ShotCountPill(
              count: _shotCount,
              sessionActive: _sessionActive,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Start / End button moved up, directly under the heading.
        _PrimaryButton(
          label: _sessionActive ? 'End session' : 'Start session',
          onTap: _onToggleSession,
        ),

        const SizedBox(height: 12),

        _LiveSensorHeroCard(
          isActive: _sessionActive,
          selectedStroke: _selectedKey != null ? _currentStroke.title : null,
        ),

        const SizedBox(height: 14),

        // 4 metrics in a horizontal 2x2 layout
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricSmallCard(
              title: 'Swing speed',
              value: swingSpeed,
              unit: 'km/h',
            ),
            _MetricSmallCard(
              title: 'Impact force',
              value: impactForce,
              unit: 'N',
            ),
            _MetricSmallCard(
              title: 'Acceleration',
              value: acceleration,
              unit: 'm/s²',
            ),
            _MetricSmallCard(
              title: 'Swing force',
              value: swingForce,
              unit: 'au',
            ),
          ],
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}

/* ==================== SMALL WIDGETS ==================== */

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({
    required this.isConnected,
    required this.deviceName,
  });

  final bool isConnected;
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    final color =
        isConnected ? const Color(0xFF22C55E) : const Color(0xFFF97316);
    final bg = color.withValues(alpha: .16);

    // Display actual device name when connected, or "Not connected" when disconnected
    final displayText = isConnected ? deviceName : 'Not connected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StrokeSelectionCard extends StatelessWidget {
  const _StrokeSelectionCard({
    required this.strokes,
    required this.selectedKey,
    required this.onSelect,
  });

  final List<_StrokeMeta> strokes;
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final border =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0x14000000);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor =
        isDark ? Colors.white.withValues(alpha: .80) : const Color(0xFF4B5563);

    final selectedValue = selectedKey ?? strokes.first.key;
    final current = strokes.firstWhere(
      (s) => s.key == selectedValue,
      orElse: () => strokes.first,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header line (current stroke)
          Text(
            current.title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current.subtitle,
            style: TextStyle(
              color: subColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          // dropdown for stroke types
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: .06)
                  : const Color(0xFFF3F4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: .18)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedValue,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF151A29) : Colors.white,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: .85)
                      : const Color(0xFF4B5563),
                ),
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
                items: strokes
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s.key,
                        child: Text(s.title),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) onSelect(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSensorHeroCard extends StatelessWidget {
  const _LiveSensorHeroCard({
    required this.isActive,
    required this.selectedStroke,
  });

  final bool isActive;
  final String? selectedStroke;

  @override
  Widget build(BuildContext context) {
    final statusTitle = isActive ? 'Session live' : 'Session ready';

    final statusSubtitle = !isActive
        ? (selectedStroke == null
            ? 'Choose a stroke above, then tap Start session to begin recording.'
            : 'Tap Start session to start recording $selectedStroke swings.')
        : 'Recording hits for ${selectedStroke ?? 'your stroke'}.\nMetrics update on each registered shot.';

    return Container(
      height: 140, // bumped up so text doesn't overflow
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFCF67FF), Color(0xFF78C4FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .28),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: AppTheme.gCTA),
              ),
              child: Icon(
                Icons.sports_tennis_rounded,
                color: Colors.white.withValues(alpha: .90),
                size: 40,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusTitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .98),
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusSubtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .88),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShotCountPill extends StatelessWidget {
  const _ShotCountPill({
    required this.count,
    required this.sessionActive,
  });

  final int count;
  final bool sessionActive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark ? Colors.white.withValues(alpha: .06) : const Color(0xFFE5E7EB);
    final textColor =
        isDark ? Colors.white.withValues(alpha: .9) : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? .18 : .10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'shots',
            style: TextStyle(
              color: textColor.withValues(alpha: .85),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (sessionActive) ...[
            const SizedBox(width: 6),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricSmallCard extends StatelessWidget {
  const _MetricSmallCard({
    required this.title,
    required this.value,
    required this.unit,
  });

  final String title;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: .04) : Colors.white;
    final border =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0x14000000);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final unitColor =
        isDark ? Colors.white.withValues(alpha: .80) : const Color(0xFF6B7280);

    final displayValue =
        value <= 0 ? '--' : value.toStringAsFixed(value < 10 ? 1 : 0);

    return SizedBox(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayValue,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: unitColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StrokeMeta {
  final String key;
  final String title;
  final String subtitle;

  const _StrokeMeta({
    required this.key,
    required this.title,
    required this.subtitle,
  });
}
