import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../../app/theme.dart';
import '../../widgets/glass_widgets.dart';
import '../../core/interfaces/i_swing_repository.dart';
import '../../core/interfaces/i_session_repository.dart';
import '../../core/interfaces/i_sync_service.dart';
import '../../state/connection_state_notifier.dart';
import '../../state/session_state_notifier.dart';

import '../Train/train_tab.dart';
import '../history/history_tab.dart';
import '../stats/stats_tab.dart';

import 'connect_sheet.dart'; // BleDevice + showConnectSheet()

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Real stats
  int _weekSessions = 0;
  double _weekAvgSpeed = 0;
  double _weekAvgForce = 0;
  int _currentStreak = 0;
  bool _loadingStats = true;

  Future<void> _openConnectSheet() async {
    final result = await showConnectSheet(context);
    if (result != null) {
      // Connection state is now managed by ConnectionStateNotifier
      // The connect sheet should update the notifier
    }
  }

  void _handlePrimaryCta() {
    final connectionNotifier = context.read<ConnectionStateNotifier>();
    if (connectionNotifier.isConnected) {
      setState(() => _index = 1); // Train tab
    } else {
      _openConnectSheet();
    }
  }

  void _goToHistory() => setState(() => _index = 2);

  void _openProfile() {
    Navigator.of(context).pushNamed('/profile');
  }

  @override
  void initState() {
    super.initState();
    _loadWeekStats();

    // Listen for session state changes
    final sessionNotifier = context.read<SessionStateNotifier>();
    sessionNotifier.addListener(_onSessionsChanged);

    // Listen for connection state changes
    final connectionNotifier = context.read<ConnectionStateNotifier>();
    connectionNotifier.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    final sessionNotifier = context.read<SessionStateNotifier>();
    sessionNotifier.removeListener(_onSessionsChanged);

    final connectionNotifier = context.read<ConnectionStateNotifier>();
    connectionNotifier.removeListener(_onConnectionChanged);

    super.dispose();
  }

  void _onSessionsChanged() {
    // Reload stats when sessions change
    _loadWeekStats();
  }

  void _onConnectionChanged() {
    // Trigger rebuild when connection state changes
    setState(() {});
  }

  Future<void> _loadWeekStats() async {
    try {
      final swingRepo = context.read<ISwingRepository>();
      final sessionRepo = context.read<ISessionRepository>();
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 7));

      final statsMap = await swingRepo.getStatsInRange(start, end);
      final sessions = await sessionRepo.getSessionsInRange(start, end);
      final streak = await swingRepo.getCurrentStreak();

      if (mounted) {
        setState(() {
          _weekSessions = sessions.length;
          _weekAvgSpeed =
              (statsMap['avg_vtip'] as double? ?? 0.0) * 3.6; // m/s to km/h
          _weekAvgForce = statsMap['avg_force'] as double? ?? 0.0;
          _currentStreak = streak;
          _loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load week stats: $e');
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connectionNotifier = context.watch<ConnectionStateNotifier>();
    final isConnected =
        connectionNotifier.state == DeviceConnectionState.connected;
    final deviceName = connectionNotifier.deviceName;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              _HomeTab(
                isConnected: isConnected,
                deviceName: deviceName,
                onOpenConnect: _openConnectSheet,
                onPrimaryCta: _handlePrimaryCta,
                onGoToHistory: _goToHistory,
                onOpenProfile: _openProfile,
                weekSessions: _weekSessions,
                weekAvgSpeed: _weekAvgSpeed,
                weekAvgForce: _weekAvgForce,
                currentStreak: _currentStreak,
                loadingStats: _loadingStats,
              ),
              TrainTab(deviceName: deviceName),
              const HistoryTab(),
              StatsTab(),
            ],
          ),
        ),
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: .18)
                    : Colors.white.withValues(alpha: .85),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: .10)
                        : Colors.black.withValues(alpha: .08),
                  ),
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  navigationBarTheme: NavigationBarThemeData(
                    height: 56,
                    backgroundColor: Colors.transparent,
                    indicatorColor: isDark
                        ? Colors.white.withValues(alpha: .16)
                        : AppTheme.seed.withValues(alpha: .12),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    iconTheme: WidgetStateProperty.resolveWith((s) {
                      final sel = s.contains(WidgetState.selected);
                      return IconThemeData(
                        color: sel
                            ? (isDark ? Colors.white : AppTheme.seed)
                            : (isDark
                                ? Colors.white.withValues(alpha: .70)
                                : Colors.black.withValues(alpha: .45)),
                        size: 22,
                      );
                    }),
                    labelTextStyle: WidgetStateProperty.resolveWith((s) {
                      final sel = s.contains(WidgetState.selected);
                      return TextStyle(
                        color: sel
                            ? (isDark ? Colors.white : AppTheme.seed)
                            : (isDark
                                ? Colors.white.withValues(alpha: .70)
                                : Colors.black.withValues(alpha: .55)),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      );
                    }),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.podcasts_outlined),
                      selectedIcon: Icon(Icons.podcasts_rounded),
                      label: 'Train',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month_rounded),
                      label: 'History',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart_rounded),
                      label: 'Stats',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =============================================================
/// HOME TAB
/// =============================================================
class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.onOpenConnect,
    required this.onPrimaryCta,
    required this.onGoToHistory,
    required this.onOpenProfile,
    required this.isConnected,
    required this.weekSessions,
    required this.weekAvgSpeed,
    required this.weekAvgForce,
    required this.currentStreak,
    required this.loadingStats,
    this.deviceName,
  });

  final VoidCallback onOpenConnect;
  final VoidCallback onPrimaryCta;
  final VoidCallback onGoToHistory;
  final VoidCallback onOpenProfile;
  final bool isConnected;
  final String? deviceName;
  final int weekSessions;
  final double weekAvgSpeed;
  final double weekAvgForce;
  final int currentStreak;
  final bool loadingStats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? Colors.white.withValues(alpha: .70) : const Color(0xFF6B7280);

    final subtitle = isConnected
        ? 'Connected to ${deviceName ?? 'your sensor'}'
        : 'Connect your sensor to start training';
    final ctaText = isConnected ? 'Start Session' : 'Connect Sensor';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6FD8), Color(0xFF7E4AED)],
                ),
              ),
              child:
                  const Icon(Icons.show_chart, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (r) =>
                  const LinearGradient(colors: AppTheme.titleGradient)
                      .createShader(r),
              child: Text(
                'StrikePro',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ),
            const Spacer(),
            const _SyncStatusIndicator(),
            const SizedBox(width: 8),
            _BluetoothStatusChip(
              isConnected: isConnected,
              deviceName: deviceName,
              onTap: onOpenConnect,
            ),
            const SizedBox(width: 8),
            _IconChip(icon: Icons.person_outline, onTap: onOpenProfile),
          ],
        ),
        const SizedBox(height: 12),

        // Welcome text
        Text(
          'Welcome back! 👋',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),

        // Hero card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0x332F1A77), const Color(0x333560A8)]
                  : [
                      const Color(0xFF6B21A8),
                      const Color(0xFF4338CA)
                    ], // Darker purple gradient for light mode
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: .10)
                  : Colors.white.withValues(alpha: .20),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: .25)
                    : Colors.black.withValues(alpha: .15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFCF67FF), Color(0xFF78C4FF)],
                    ),
                  ),
                  child: Icon(
                    isConnected
                        ? Icons.sports_tennis_rounded
                        : Icons.monitor_heart,
                    color: Colors.white.withValues(alpha: .88),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Start Your Journey',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isConnected
                      ? 'You’re paired and ready. Start a live session to track swings, speed, and accuracy.'
                      : 'Connect your smart racket and complete your first training session to unlock streaks, achievements, and detailed analytics.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .80),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                BounceTap(
                  onTap: onPrimaryCta,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(colors: AppTheme.gCTA),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .30),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(
                      ctaText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Your Week card
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: .12)
                          : Colors.black.withValues(alpha: .04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_graph_rounded,
                        size: 16,
                        color: isDark ? Colors.white : const Color(0xFF111827)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Your Week',
                    style: TextStyle(
                      color: primaryTextColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  BounceTap(
                    onTap: onGoToHistory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: .10)
                            : Colors.black.withValues(alpha: .04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: .12)
                              : Colors.black.withValues(alpha: .08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open History',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right,
                              size: 16,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              loadingStats
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatTile(label: 'Sessions', value: '$weekSessions'),
                        _StatTile(
                          label: 'Avg Speed',
                          value: weekAvgSpeed > 0
                              ? '${weekAvgSpeed.toStringAsFixed(0)} km/h'
                              : '--',
                        ),
                        _StatTile(
                          label: 'Avg Force',
                          value: weekAvgForce > 0
                              ? '${weekAvgForce.toStringAsFixed(0)} N'
                              : '--',
                        ),
                        _StatTile(label: 'Streak', value: '${currentStreak}d'),
                      ],
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BluetoothStatusChip extends StatelessWidget {
  const _BluetoothStatusChip({
    required this.isConnected,
    this.deviceName,
    this.onTap,
  });

  final bool isConnected;
  final String? deviceName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        isConnected ? const Color(0xFF22C55E) : const Color(0xFFF97316);
    final bg = isConnected
        ? color.withValues(alpha: .16)
        : (isDark
            ? Colors.white.withValues(alpha: .08)
            : Colors.white.withValues(alpha: .90));

    return BounceTap(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isConnected
                ? color.withValues(alpha: .6)
                : (isDark
                    ? Colors.white.withValues(alpha: .12)
                    : Colors.black.withValues(alpha: .06)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              size: 18,
              color: isConnected
                  ? color
                  : (isDark ? Colors.white : const Color(0xFF111827)),
            ),
            if (isConnected && deviceName != null) ...[
              const SizedBox(width: 6),
              Text(
                deviceName!,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BounceTap(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: .08)
              : Colors.white.withValues(alpha: .90),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: .12)
                : Colors.black.withValues(alpha: .06),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white : const Color(0xFF111827),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark ? Colors.white : const Color(0xFF111827);
    final labelColor =
        isDark ? Colors.white.withValues(alpha: .70) : const Color(0xFF6B7280);

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: labelColor, fontSize: 13),
        ),
      ],
    );
  }
}

/// Sync status indicator widget
class _SyncStatusIndicator extends StatelessWidget {
  const _SyncStatusIndicator();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final syncService = context.watch<ISyncService>();

    return StreamBuilder<SyncStatus>(
      stream: syncService.syncStatusStream,
      initialData: SyncStatus(
        isSyncing: false,
        pendingCount: 0,
        syncedCount: 0,
      ),
      builder: (context, snapshot) {
        final status = snapshot.data!;

        // Don't show if nothing to sync and not syncing
        if (!status.isSyncing &&
            status.pendingCount == 0 &&
            status.error == null) {
          return const SizedBox.shrink();
        }

        return BounceTap(
          onTap: status.error != null
              ? () async {
                  // Retry sync on error
                  try {
                    await syncService.syncAllPending();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sync failed: $e')),
                      );
                    }
                  }
                }
              : null,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: status.error != null
                  ? const Color(0xFFF59E0B).withValues(alpha: .18)
                  : (isDark
                      ? Colors.white.withValues(alpha: .08)
                      : Colors.white.withValues(alpha: .90)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: status.error != null
                    ? const Color(0xFFF59E0B).withValues(alpha: .35)
                    : (isDark
                        ? Colors.white.withValues(alpha: .12)
                        : Colors.black.withValues(alpha: .06)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status.isSyncing)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  )
                else if (status.error != null)
                  Icon(
                    Icons.sync_problem,
                    size: 16,
                    color: const Color(0xFFF59E0B),
                  )
                else
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 16,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                if (status.pendingCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${status.pendingCount}',
                    style: TextStyle(
                      color: status.error != null
                          ? const Color(0xFFF59E0B)
                          : (isDark ? Colors.white : const Color(0xFF111827)),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
