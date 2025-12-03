import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/interfaces/i_session_service.dart';
import '../../state/session_state_notifier.dart';
import '../../models/swing_metrics.dart';

/// Progress tab showing training history and session details
class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  List<SessionSummary> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();

    // Listen for session state changes
    final sessionNotifier = context.read<SessionStateNotifier>();
    sessionNotifier.addListener(_onSessionsChanged);
  }

  @override
  void dispose() {
    final sessionNotifier = context.read<SessionStateNotifier>();
    sessionNotifier.removeListener(_onSessionsChanged);
    super.dispose();
  }

  void _onSessionsChanged() {
    // Reload sessions when notified
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);

    try {
      final sessionService = context.read<ISessionService>();
      final sessions = await sessionService.getRecentSessions(limit: 50);

      // Update the session state notifier with the latest sessions
      final sessionNotifier = context.read<SessionStateNotifier>();
      sessionNotifier.updateRecentSessions(sessions);

      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load sessions: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _showSessionDetails(SessionSummary session) async {
    try {
      final sessionService = context.read<ISessionService>();
      final sessionDetail =
          await sessionService.getSessionDetail(session.sessionId);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _SessionDetailSheet(
          session: sessionDetail.summary,
          swings: sessionDetail.swings,
        ),
      );
    } catch (e) {
      debugPrint('Failed to load session details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Center(
            child: Text(
              'Training History',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_sessions.isEmpty)
            _EmptyState()
          else
            ..._sessions.map((session) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SessionCard(
                    session: session,
                    onTap: () => _showSessionDetails(session),
                  ),
                )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Session card widget
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onTap,
  });

  final SessionSummary session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: .04) : Colors.white;
    final border =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0x14000000);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: .75) : const Color(0xFF6B7280);

    final dateStr = _formatDate(session.startTime);
    final timeStr = _formatTime(session.startTime);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: .04),
                blurRadius: 14,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: .35)),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: subtitleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: subtitleColor,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (session.strokeFocus != null) ...[
              Text(
                session.strokeFocus!,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                _MetricChip(
                  icon: Icons.sports_tennis,
                  label: '${session.swingCount} swings',
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  icon: Icons.timer_outlined,
                  label: '${session.durationMinutes} min',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: 'Avg Speed',
                    value: session.avgSpeed.toStringAsFixed(0),
                    unit: 'km/h',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniMetric(
                    label: 'Avg Force',
                    value: session.avgForce.toStringAsFixed(0),
                    unit: 'N',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(dt.year, dt.month, dt.day);

    if (sessionDate == today) return 'Today';
    if (sessionDate == yesterday) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

/// Metric chip widget
class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark ? Colors.white.withValues(alpha: .06) : const Color(0xFFF3F4FF);
    final textColor =
        isDark ? Colors.white.withValues(alpha: .85) : const Color(0xFF4B5563);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini metric widget
class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? Colors.white.withValues(alpha: .70) : const Color(0xFF6B7280);
    final valueColor = isDark ? Colors.white : const Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: .04) : Colors.white;
    final border =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0x14000000);
    final textColor =
        isDark ? Colors.white.withValues(alpha: .85) : const Color(0xFF4B5563);

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: textColor.withValues(alpha: .5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Training History',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a training session to see your progress here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: .75),
            ),
          ),
        ],
      ),
    );
  }
}

/// Session detail sheet
class _SessionDetailSheet extends StatelessWidget {
  const _SessionDetailSheet({
    required this.session,
    required this.swings,
  });

  final SessionSummary session;
  final List<SwingMetrics> swings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E1220) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: .75) : const Color(0xFF6B7280);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 48,
            height: 6,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(999),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Details',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatDate(session.startTime)} at ${_formatTime(session.startTime)}',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                  ),
                ),
                if (session.strokeFocus != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Focus: ${session.strokeFocus}',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Swings list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: swings.length,
              itemBuilder: (context, index) {
                final swing = swings[index];
                return _SwingRow(swing: swing, index: index + 1);
              },
            ),
          ),

          // Close button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

/// Swing row widget
class _SwingRow extends StatelessWidget {
  const _SwingRow({
    required this.swing,
    required this.index,
  });

  final SwingMetrics swing;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: .04) : Colors.white;
    final border =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0x14000000);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Swing #$index',
                  style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                swing.qualityPassed
                    ? Icons.check_circle
                    : Icons.warning_rounded,
                size: 16,
                color: swing.qualityPassed
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SwingMetric(
                  label: 'Speed',
                  value: swing.maxVtipKmh.toStringAsFixed(0),
                  unit: 'km/h',
                ),
              ),
              Expanded(
                child: _SwingMetric(
                  label: 'Force',
                  value: swing.estForceN.toStringAsFixed(0),
                  unit: 'N',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Swing metric widget
class _SwingMetric extends StatelessWidget {
  const _SwingMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? Colors.white.withValues(alpha: .70) : const Color(0xFF6B7280);
    final valueColor = isDark ? Colors.white : const Color(0xFF111827);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                unit,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
