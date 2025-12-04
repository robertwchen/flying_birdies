import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../feedback/feedback_tab.dart';
import '../../core/interfaces/i_session_service.dart';
import '../../models/session_summary.dart';
import '../../state/session_state_notifier.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late final ISessionService _sessionService;

  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDay = DateTime.now();

  List<SessionSummary> _allSessions = [];
  bool _loading = true;
  int _totalSessions = 0;
  int _activeDays = 0;
  int _totalHits = 0;

  @override
  void initState() {
    super.initState();
    _sessionService = context.read<ISessionService>();
    _loadAllSessions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen for session changes from Provider
    final sessionNotifier = context.read<SessionStateNotifier>();
    sessionNotifier
        .removeListener(_onSessionsChanged); // Remove if already added
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
    _loadAllSessions();
  }

  Future<void> _loadAllSessions() async {
    setState(() => _loading = true);

    try {
      // Use service layer - no manual calculations needed!
      final sessions = await _sessionService.getRecentSessions(limit: 100);

      // Calculate summary statistics
      final uniqueDays = <String>{};
      int totalHits = 0;

      for (final session in sessions) {
        // Track unique days
        final dayKey =
            '${session.startTime.year}-${session.startTime.month}-${session.startTime.day}';
        uniqueDays.add(dayKey);
        totalHits += session.swingCount;
      }

      setState(() {
        _allSessions = sessions;
        _totalSessions = sessions.length;
        _activeDays = uniqueDays.length;
        _totalHits = totalHits;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load sessions: $e');
      setState(() => _loading = false);
    }
  }

  List<SessionSummary> _getSessionsForDay(DateTime day) {
    return _allSessions.where((s) {
      return s.date.year == day.year &&
          s.date.month == day.month &&
          s.date.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleColor =
        isDark ? Colors.white : const Color(0xFF111827); // slate-900
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: .85) : const Color(0xFF4B5563);

    final sessions = _getSessionsForDay(_selectedDay);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const SizedBox(height: 8),
        Text(
          'History',
          style: TextStyle(
            color: titleColor,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else
          _StatRow(items: [
            _TopStat(label: 'Sessions', value: '$_totalSessions'),
            _TopStat(label: 'Active Days', value: '$_activeDays'),
            _TopStat(label: 'Total Hits', value: '$_totalHits'),
          ]),
        const SizedBox(height: 18),
        _MonthCard(
          focusedMonth: _focusedMonth,
          selectedDay: _selectedDay,
          onPrev: () => setState(() {
            _focusedMonth =
                DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
          }),
          onNext: () => setState(() {
            _focusedMonth =
                DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
          }),
          onPickDay: (d) => setState(() => _selectedDay = d),
        ),
        const SizedBox(height: 18),
        Text(
          'Previous sessions',
          style: TextStyle(
            color: titleColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty && !_loading)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: .06) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: .10)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              'No sessions on this day',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final s = sessions[i];
              final previous = i > 0 ? sessions[i - 1] : null;
              final baseline =
                  _allSessions.isNotEmpty ? _allSessions.first : null;

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Per-session view (this is where per-session graphs live)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeedbackTab(
                        current: s,
                        previous: previous,
                        baseline: baseline,
                      ),
                    ),
                  );
                },
                child: _SessionTile(session: s),
              );
            },
          ),
      ],
    );
  }
}

/* ───────────── UI bits ───────────── */

class _StatRow extends StatelessWidget {
  const _StatRow({required this.items});
  final List<_TopStat> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.white.withValues(alpha: .06) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0xFFE5E7EB);
    final labelColor =
        isDark ? Colors.white.withValues(alpha: .85) : const Color(0xFF6B7280);
    final valueColor = isDark ? Colors.white : const Color(0xFF111827);

    return Row(
      children: items
          .map(
            (e) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.value,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TopStat {
  final String label;
  final String value;
  const _TopStat({required this.label, required this.value});
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.focusedMonth,
    required this.selectedDay,
    required this.onPrev,
    required this.onNext,
    required this.onPickDay,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onPickDay;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startWeekday = first.weekday; // 1=Mon … 7=Sun
    final leading = (startWeekday % 7); // Sun-start grid

    final totalCells = leading + daysInMonth;

    final cardBg = isDark ? Colors.white.withValues(alpha: .06) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0xFFE5E7EB);
    final monthTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _RoundIcon(onTap: onPrev, icon: Icons.chevron_left),
              const Spacer(),
              Text(
                '${_monthName(focusedMonth.month)} ${focusedMonth.year}',
                style: TextStyle(
                  color: monthTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              _RoundIcon(onTap: onNext, icon: Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 10),
          const _WeekHeader(),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            itemCount: totalCells,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (_, i) {
              if (i < leading) return const SizedBox.shrink();
              final day = i - leading + 1;
              final date = DateTime(focusedMonth.year, focusedMonth.month, day);
              final isSel = _isSameDay(selectedDay, date);

              final selBg =
                  isDark ? const Color(0xFF6B8BFF) : const Color(0xFF4F46E5);
              final normalBg = isDark
                  ? Colors.white.withValues(alpha: .08)
                  : const Color(0xFFF3F4FF);
              final borderColorDay = isSel
                  ? (isDark
                      ? Colors.white.withValues(alpha: .30)
                      : const Color(0xFF4338CA))
                  : (isDark
                      ? Colors.white.withValues(alpha: .10)
                      : const Color(0xFFE5E7EB));
              final textColor = isSel
                  ? Colors.white
                  : (isDark
                      ? Colors.white.withValues(alpha: .92)
                      : const Color(0xFF111827));

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onPickDay(date),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSel ? selBg : normalBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColorDay),
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Selected: ${selectedDay.year}-${_pad(selectedDay.month)}-${_pad(selectedDay.day)}',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: .65)
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[m - 1];
  }

  String _pad(int n) => n < 10 ? '0$n' : '$n';
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        isDark ? Colors.white.withValues(alpha: .7) : const Color(0xFF6B7280);
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days
          .map(
            (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.onTap, required this.icon});
  final VoidCallback onTap;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0xFFF3F4FF);

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white : const Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final SessionSummary session;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.white.withValues(alpha: .06) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: .80) : const Color(0xFF4B5563);
    final iconBg =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0xFFF3F4FF);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cardBg,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.query_stats_rounded,
              color: isDark ? Colors.white : const Color(0xFF4B5563),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session • ${session.title}',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                // UPDATED: removed Sweet Spot %, now using Hits
                Text(
                  'Max ${session.maxSpeedKmh.toStringAsFixed(0)} km/h • '
                  'Hits ${session.hits}',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF9CA3AF),
          ),
        ],
      ),
    );
  }
}

// SessionSummary model now imported from lib/models/session_summary.dart
// All session data comes from ISessionService - no manual calculations in UI!
