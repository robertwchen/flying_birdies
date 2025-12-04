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
import '../../state/player_settings_notifier.dart';

class TrainTab extends StatefulWidget {
  const TrainTab({super.key, this.deviceName});

  /// If null, we treat as "not connected".
  final String? deviceName;

  @override
  State<TrainTab> createState() => _TrainTabState();
}

class _TrainTabState extends State<TrainTab> {
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
    // Load player settings on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerSettings = context.read<PlayerSettingsNotifier>();
      playerSettings.loadSettings();
    });
    // Default to first stroke so dropdown has a value.
    _selectedKey =
        _getStrokes(true).first.key; // Default to right-handed initially
  }

  List<_StrokeMeta> _getStrokes(bool isRightHanded) {
    final dominantSide = isRightHanded ? 'right' : 'left';
    final nonDominantSide = isRightHanded ? 'left' : 'right';

    return [
      _StrokeMeta(
        key: 'oh-fh',
        title: 'Overhead Forehand',
        subtitle:
            'Swing above your head on $dominantSide side using a forward forehand motion',
      ),
      _StrokeMeta(
        key: 'oh-bh',
        title: 'Overhead Backhand',
        subtitle:
            'Reach above your head on the $nonDominantSide side and swing using a backhand motion',
      ),
      _StrokeMeta(
        key: 'ua-fh',
        title: 'Underarm Forehand',
        subtitle:
            'Scoop or lift the shuttle from below waist height on the $dominantSide side with a forehand swing',
      ),
      _StrokeMeta(
        key: 'ua-bh',
        title: 'Underarm Backhand',
        subtitle:
            'Use a low backhand swing on the $nonDominantSide side to return or lift the shuttle',
      ),
    ];
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

  _StrokeMeta _currentStroke(bool isRightHanded) {
    final strokes = _getStrokes(isRightHanded);
    final sel = strokes.firstWhere(
      (s) => s.key == _selectedKey,
      orElse: () => strokes.first,
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
    final playerSettings =
        Provider.of<PlayerSettingsNotifier>(context, listen: false);

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
          strokeFocus: _currentStroke(playerSettings.isRightHanded).title,
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

    // Get player settings from Provider (watch for changes)
    final playerSettings = context.watch<PlayerSettingsNotifier>();
    final isRightHanded = playerSettings.isRightHanded;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
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
        const SizedBox(height: 14),

        // Stroke selection card
        Text(
          'Stroke selection',
          style: TextStyle(
            color: primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _StrokeSelectionCard(
          strokes: _getStrokes(isRightHanded),
          selectedKey: _selectedKey,
          onSelect: _onSelectStroke,
        ),

        const SizedBox(height: 16),

        // Live sensor readings section
        Text(
          'Live Sensor Readings',
          style: TextStyle(
            color: primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),

        // Start / End button moved up, directly under the heading.
        _PrimaryButton(
          label: _sessionActive ? 'End session' : 'Start session',
          onTap: _onToggleSession,
        ),

        const SizedBox(height: 10),

        // FFT Test button (for debugging)
        if (!_sessionActive)
          _SecondaryButton(
            label: 'Test FFT Implementation',
            onTap: () {
              final analyticsService =
                  Provider.of<AnalyticsService>(context, listen: false);
              analyticsService.testFft();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('FFT test running - check console output'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

        if (!_sessionActive) const SizedBox(height: 10),

        // Combined session status card
        _SessionStatusCard(
          count: _shotCount,
          isActive: _sessionActive,
          selectedStroke:
              _selectedKey != null ? _currentStroke(isRightHanded).title : null,
        ),

        const SizedBox(height: 10),

        // 4 metrics in a horizontal 2x2 layout
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricSmallCard(
              title: 'Swing Speed',
              value: swingSpeed,
              unit: 'km/h',
            ),
            _MetricSmallCard(
              title: 'Impact Force',
              value: impactForce,
              unit: 'N',
            ),
            _MetricSmallCard(
              title: 'Acceleration',
              value: acceleration,
              unit: 'm/s²',
            ),
            _MetricSmallCard(
              title: 'Swing Force',
              value: swingForce,
              unit: 'N',
            ),
          ],
        ),

        const SizedBox(height: 20),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // dropdown for stroke types (moved to top)
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
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
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
          const SizedBox(height: 10),

          // caption below dropdown
          Text(
            current.subtitle,
            style: TextStyle(
              color: subColor,
              fontSize: 13,
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

// Combined session status card - swing count on left, status on right
class _SessionStatusCard extends StatelessWidget {
  const _SessionStatusCard({
    required this.count,
    required this.isActive,
    this.selectedStroke,
  });

  final int count;
  final bool isActive;
  final String? selectedStroke;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusTitle = isActive ? 'Session live' : 'Session ready';
    final statusSubtitle = !isActive
        ? (selectedStroke == null
            ? 'Choose a stroke above, then tap Start session to begin recording.'
            : 'Tap Start session to start recording $selectedStroke swings.')
        : 'Recording hits for ${selectedStroke ?? 'your stroke'}.\nMetrics update on each registered shot.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .25 : .12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side: Swing count with subtle background
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: .08),
                          Colors.white.withValues(alpha: .04),
                        ]
                      : [
                          const Color(0xFFF9FAFB),
                          const Color(0xFFF3F4F6),
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: .12)
                      : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: .10)
                          : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Shot Count',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: .90)
                            : const Color(0xFF4B5563),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Right side: Session status
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFCF67FF), Color(0xFF78C4FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCF67FF).withValues(alpha: .3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.sports_tennis_rounded,
                    color: Colors.white.withValues(alpha: .95),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusSubtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: .75)
                              : const Color(0xFF6B7280),
                          fontSize: 9,
                          height: 1.3,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Compact session badge for top-right corner
class _CompactSessionBadge extends StatelessWidget {
  const _CompactSessionBadge({
    required this.isActive,
    this.selectedStroke,
  });

  final bool isActive;
  final String? selectedStroke;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusText = isActive ? 'Live' : 'Ready';
    final statusColor =
        isActive ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: .35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Swing count card - white background, centered
class _SwingCountCard extends StatelessWidget {
  const _SwingCountCard({
    required this.count,
    required this.sessionActive,
  });

  final int count;
  final bool sessionActive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.black.withValues(alpha: 0.15) : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: .08)
              : Colors.black.withValues(alpha: .06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: .25)
                : Colors.black.withValues(alpha: .08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontSize: 48,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count == 1 ? 'Swing Detected' : 'Swings Detected',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: .70)
                  : const Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF3F4F6),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: AppTheme.gCTA, // Pink to purple gradient
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .25),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
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
