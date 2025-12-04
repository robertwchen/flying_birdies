// lib/features/feedback/feedback_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../../widgets/glass_widgets.dart';
import '../../widgets/charts/charts.dart';
import '../../models/session_summary.dart';
import '../../core/interfaces/i_session_service.dart';
import '../../core/interfaces/i_swing_repository.dart';
import '../../models/entities/swing_entity.dart';

/// Comparison choices for the dropdown.
enum BaselineMode { previous, avg7d, avg30d, baseline }

// --- Coach summary thresholds (easy to tweak) ---
const double kStrongAvgSpeed = 240; // km/h
const double kStrongMaxSpeed = 290; // km/h
const double kStrongImpact = 55; // N-ish
const double kStrongAccel = 55; // m/s²-ish

class FeedbackTab extends StatefulWidget {
  const FeedbackTab({
    super.key,
    this.current,
    this.previous,
    this.baseline,
    this.loadLatest,
  });

  final SessionSummary? current;
  final SessionSummary? previous;
  final SessionSummary? baseline;

  /// Optional async loader for "latest session" when opened from bottom nav.
  final Future<SessionSummary?> Function()? loadLatest;

  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab> {
  SessionSummary? _current;
  SessionSummary? _previous;
  SessionSummary? _baseline;

  bool _loading = false;

  BaselineMode _mode = BaselineMode.previous;

  // Which metric's graph is shown.
  GraphMetric _graphMetric = GraphMetric.swingSpeed;

  // Real swing data loaded from database
  List<SwingEntity>? _swingData;

  @override
  void initState() {
    super.initState();
    _current = widget.current;
    _previous = widget.previous;
    _baseline = widget.baseline;

    // Always load swing data if we have a session
    if (_current != null) {
      _loadSwingDataForSession(_current!);
    } else {
      _autoLoad(); // Load latest session
    }
  }

  @override
  void didUpdateWidget(FeedbackTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If widget props changed, update state and reload swing data
    if (widget.current != oldWidget.current ||
        widget.previous != oldWidget.previous ||
        widget.baseline != oldWidget.baseline) {
      setState(() {
        _current = widget.current;
        _previous = widget.previous;
        _baseline = widget.baseline;
      });

      // Reload swing data if session changed
      if (_current != null && _current!.id != oldWidget.current?.id) {
        _loadSwingDataForSession(_current!);
      }
    }
    // If we don't have current data, try to load it
    if (_current == null && !_loading) {
      _autoLoad();
    }
  }

  Future<void> _autoLoad() async {
    if (_loading) return; // Prevent concurrent loads
    setState(() => _loading = true);
    try {
      final loader = widget.loadLatest ?? _loadLatestSession;
      final latest = await loader();
      if (!mounted) return;

      // Load real swing data if we have a session
      List<SwingEntity>? swings;
      if (latest != null) {
        final sessionId = int.tryParse(latest.id);
        if (sessionId != null) {
          swings = await _loadSwingData(sessionId);
        }
      }

      if (!mounted) return;
      setState(() {
        _current = latest;
        _previous = widget.previous;
        _baseline = widget.baseline;
        _swingData = swings;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Load swing data for a specific session
  Future<void> _loadSwingDataForSession(SessionSummary session) async {
    final sessionId = int.tryParse(session.id);
    if (sessionId != null) {
      setState(() => _loading = true);
      final swings = await _loadSwingData(sessionId);
      if (mounted) {
        setState(() {
          _swingData = swings;
          _loading = false;
        });
      }
    }
  }

  /// Load real swing data from database
  Future<List<SwingEntity>> _loadSwingData(int sessionId) async {
    try {
      final swingRepo = context.read<ISwingRepository>();
      final swings = await swingRepo.getSwingsForSession(sessionId);
      debugPrint('Loaded ${swings.length} swings for session $sessionId');
      return swings;
    } catch (e) {
      debugPrint('Failed to load swing data: $e');
      return [];
    }
  }

  // Fetch latest session from service layer
  Future<SessionSummary?> _loadLatestSession() async {
    try {
      final sessionService = context.read<ISessionService>();
      final sessions = await sessionService.getRecentSessions(limit: 1);
      return sessions.isNotEmpty ? sessions.first : null;
    } catch (e) {
      debugPrint('Failed to load latest session: $e');
      return null;
    }
  }

  SessionSummary? _comparisonTarget() {
    final cur = _current;
    if (cur == null) return null;

    switch (_mode) {
      case BaselineMode.previous:
        return _previous;
      case BaselineMode.baseline:
        return _baseline;
      case BaselineMode.avg7d:
      case BaselineMode.avg30d:
        // These will be loaded async, return null for now
        // We'll need to refactor this to use FutureBuilder
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = _current != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryText = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryText =
        isDark ? Colors.white.withValues(alpha: .80) : const Color(0xFF6B7280);

    final cardBg = isDark
        ? Colors.white.withValues(alpha: .06)
        : Colors.white.withValues(alpha: .96);
    final cardBorder =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0xFFE5E7EB);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            systemOverlayStyle:
                isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: primaryText,
                    ),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            title: Text(
              'Feedback',
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: primaryText,
                ),
                onPressed: _autoLoad,
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _autoLoad,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                if (_loading && !has)
                  _LoadingCard(
                    cardBg: cardBg,
                    border: cardBorder,
                    textColor: primaryText,
                    secondary: secondaryText,
                  ),
                if (!has && !_loading)
                  _EmptyStateCard(
                    cardBg: cardBg,
                    border: cardBorder,
                    textColor: primaryText,
                    secondary: secondaryText,
                  ),
                if (has) ...[
                  // Coach Summary - compressed
                  _CoachSummaryCard(
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    lines: _coachLines(_current!, _comparisonTarget()),
                  ),
                  const SizedBox(height: 10),

                  // Session graphs – compressed
                  _GraphSection(
                    session: _current!,
                    swingData: _swingData,
                    metric: _graphMetric,
                    onMetricChanged: (m) {
                      setState(() => _graphMetric = m);
                    },
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),

                  // Metrics grid – compressed
                  _MetricGrid(
                    s: _current!,
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 8),

                  // Hits - compressed
                  _HitsCard(
                    hits: _current!.hits,
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 12),

                  // Comparison + dropdown - compressed
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Comparison',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: .08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: .16)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<BaselineMode>(
                            value: _mode,
                            dropdownColor:
                                isDark ? const Color(0xFF111827) : Colors.white,
                            iconEnabledColor:
                                isDark ? Colors.white : const Color(0xFF4B5563),
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            onChanged: (m) => setState(
                                () => _mode = m ?? BaselineMode.previous),
                            items: const [
                              DropdownMenuItem(
                                value: BaselineMode.previous,
                                child: Text('Last session'),
                              ),
                              DropdownMenuItem(
                                value: BaselineMode.avg7d,
                                child: Text('Last 7 days'),
                              ),
                              DropdownMenuItem(
                                value: BaselineMode.avg30d,
                                child: Text('Last 30 days'),
                              ),
                              DropdownMenuItem(
                                value: BaselineMode.baseline,
                                child: Text('Season best'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _CompareList(
                    deltas: _deltas(_current!, _comparisonTarget()),
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),

                  _TipsCard(
                    tips: _tipsFor(_current!),
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ---------- logic helpers ---------- */

  List<String> _coachLines(SessionSummary cur, SessionSummary? other) {
    // Treat the extra fields as your two physical metrics.
    // (You’re already labelling them as Impact + Acceleration in the UI.)
    final double avg = cur.avgSpeedKmh;
    final double max = cur.maxSpeedKmh;
    final double impactAvg = cur.avgForceN; // Real impact force (N)
    final double accelAvg = cur.avgAccelMs2; // Real acceleration (m/s²)
    final int hits = cur.hits;

    final bool hasOther = other != null;

    // Deltas vs comparison target (if any)
    final double dAvg = hasOther ? avg - other.avgSpeedKmh : 0.0;
    final double dMax = hasOther ? max - other.maxSpeedKmh : 0.0;
    final double dImp = hasOther ? impactAvg - other.avgForceN : 0.0;
    final double dAccel = hasOther ? accelAvg - other.avgAccelMs2 : 0.0;
    final int dHits = hasOther ? hits - other.hits : 0;

    String headline;

    if (!hasOther) {
      // No comparison session: judge this one on its own.
      if (avg >= kStrongAvgSpeed &&
          max >= kStrongMaxSpeed &&
          impactAvg >= kStrongImpact &&
          accelAvg >= kStrongAccel) {
        headline = 'Strong all-round session — fast swings with solid impact.';
      } else if (impactAvg < 45) {
        headline = 'Work on cleaner, stronger contact on the shuttle.';
      } else if (accelAvg < 45) {
        headline =
            'Good contact — now focus on quicker acceleration into the shot.';
      } else if (avg < 200 && max < 260) {
        headline =
            'Controlled pace today — next time, try adding a bit more racket speed.';
      } else {
        headline = 'Solid session — you’re building a stable baseline.';
      }
    } else {
      // We *do* have a comparison target.
      final bool speedUp = dAvg > 3 && dMax > 5;
      final bool impactUp = dImp > 3;
      final bool accelUp = dAccel > 3;
      final bool volumeUp = dHits > 20;

      if (speedUp && impactUp && accelUp) {
        headline = 'Great work — speed, impact, and acceleration all improved.';
      } else if (speedUp && impactUp) {
        headline = 'Swings are faster with stronger impact — nice progress.';
      } else if (speedUp && !impactUp) {
        headline =
            'Speed is up — keep the same strong contact as you swing faster.';
      } else if (impactUp && !speedUp) {
        headline =
            'Impact is stronger even at similar speed — that’s efficient contact.';
      } else if (accelUp && !speedUp) {
        headline =
            'Acceleration improved — you’re getting into the shot more explosively.';
      } else if (volumeUp) {
        headline = 'Big jump in reps — you got a lot more hits this session.';
      } else {
        headline =
            'Very similar to your last session — good consistency overall.';
      }
    }

    // Detail line is simple now.
    final detail = 'Full breakdown below • $hits total hits this session.';

    return [headline, detail];
  }

  Map<String, double?> _deltas(SessionSummary cur, SessionSummary? other) {
    if (other == null) {
      return const {
        'Avg Speed': null,
        'Max Speed': null,
        'Impact force': null,
        'Acceleration': null,
      };
    }
    return {
      'Avg Speed': cur.avgSpeedKmh - other.avgSpeedKmh,
      'Max Speed': cur.maxSpeedKmh - other.maxSpeedKmh,
      'Impact force': cur.avgForceN - other.avgForceN,
      'Acceleration': cur.avgAccelMs2 - other.avgAccelMs2,
    };
  }

  List<String> _tipsFor(SessionSummary s) {
    final tips = <String>[];

    final avg = s.avgSpeedKmh;
    final impact = s.avgForceN; // Real impact force (N)
    final accel = s.avgAccelMs2; // Real acceleration (m/s²)

    // Power
    if (avg < 200) {
      tips.add(
          'Build power: focus on using your legs and core, not just your arm, for 3×10 overhead drives.');
    } else if (avg > 260) {
      tips.add(
          'You have great pace — add 2–3 “control only” rallies where you keep the same power but aim deeper into the court.');
    }

    // Impact / contact quality
    if (impact < 50) {
      tips.add(
          'Contact is a bit light: try 10–15 shadow swings focusing on hitting slightly in front of your body.');
    } else if (impact > 75) {
      tips.add(
          'Impact is strong — mix in a few softer touch shots so you can change pace when you need to.');
    }

    // Acceleration / recovery
    if (accel < 50) {
      tips.add(
          'Work on quick recovery: after each hit, do a small hop back to base before the next swing.');
    } else if (accel > 75) {
      tips.add(
          'Acceleration looks good — keep it up with 2×30-sec multi-shuttle drills where you focus on fast first steps.');
    }

    if (tips.isEmpty) {
      tips.add(
          'Nice balanced session — repeat this pattern next time and add one short drill focused on footwork.');
    }

    return tips;
  }
}

/* ---------------- UI bits ---------------- */

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.secondary,
  });

  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading latest session…',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.secondary,
  });

  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No session selected',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a recent session from History to see detailed tips and comparison.',
            style: TextStyle(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _CoachSummaryCard extends StatelessWidget {
  const _CoachSummaryCard({
    required this.cardBg,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.lines,
  });

  final Color cardBg;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 16, color: primaryText),
              const SizedBox(width: 6),
              Text(
                'Coach Summary',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lines.first,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.s,
    required this.cardBg,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
  });

  final SessionSummary s;
  final Color cardBg;
  final Color border;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    // Use REAL values from swing data
    final impactAvg = s.avgForceN;
    final impactMax = s.maxForceN;
    final accelAvg = s.avgAccelMs2;
    final accelMax = s.maxAccelMs2;

    // Swing force is the same as impact force (est_force_n from database)
    final swingForceAvg = s.avgForceN;
    final swingForceMax = s.maxForceN;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.0,
      ),
      children: [
        _MetricSummaryTile(
          title: 'Swing speed',
          avg: s.avgSpeedKmh.toDouble(),
          max: s.maxSpeedKmh.toDouble(),
          unit: 'km/h',
          cardBg: cardBg,
          border: border,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        _MetricSummaryTile(
          title: 'Swing force',
          avg: swingForceAvg,
          max: swingForceMax,
          unit: 'N',
          cardBg: cardBg,
          border: border,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        _MetricSummaryTile(
          title: 'Impact force',
          avg: impactAvg,
          max: impactMax,
          unit: 'N',
          cardBg: cardBg,
          border: border,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        _MetricSummaryTile(
          title: 'Acceleration',
          avg: accelAvg,
          max: accelMax,
          unit: 'm/s²',
          cardBg: cardBg,
          border: border,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
      ],
    );
  }
}

class _MetricSummaryTile extends StatelessWidget {
  const _MetricSummaryTile({
    required this.title,
    required this.avg,
    required this.max,
    required this.unit,
    required this.cardBg,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
  });

  final String title;
  final double avg;
  final double max;
  final String unit;
  final Color cardBg;
  final Color border;
  final Color primaryText;
  final Color secondaryText;

  String _fmt(num v) => v.toStringAsFixed(v < 10 ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Avg ${_fmt(avg)} $unit',
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Max ${_fmt(max)} $unit',
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HitsCard extends StatelessWidget {
  const _HitsCard({
    required this.hits,
    required this.cardBg,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
  });

  final int hits;
  final Color cardBg;
  final Color border;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(
            'Shot Count',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            '$hits',
            style: TextStyle(
              color: secondaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareList extends StatelessWidget {
  const _CompareList({
    required this.deltas,
    required this.cardBg,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.isDark,
  });

  final Map<String, double?> deltas;
  final Color cardBg;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: deltas.entries
          .map(
            (e) => _DeltaRow(
              label: e.key,
              delta: e.value,
              cardBg: cardBg,
              border: border,
              primaryText: primaryText,
              secondaryText: secondaryText,
              isDark: isDark,
            ),
          )
          .toList(),
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({
    required this.label,
    required this.delta,
    required this.cardBg,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.isDark,
  });

  final String label;
  final double? delta;
  final Color cardBg;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final txt = delta == null
        ? '—'
        : (delta! >= 0
            ? '+${delta!.toStringAsFixed(1)}'
            : '-${delta!.abs().toStringAsFixed(1)}');
    final color = delta == null
        ? secondaryText
        : (delta! >= 0
            ? const Color(0xFF16A34A) // green
            : const Color(0xFFDC2626)); // red

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up,
            size: 16,
            color: secondaryText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            txt,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({
    required this.tips,
    required this.cardBg,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.isDark,
  });

  final List<String> tips;
  final Color cardBg;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color:
                    isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Text(
                'Tips',
                style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• $t',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------- Graph section + mini chart ----------- */

class _GraphSection extends StatelessWidget {
  const _GraphSection({
    required this.session,
    required this.swingData,
    required this.metric,
    required this.onMetricChanged,
    required this.cardBg,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.isDark,
  });

  final SessionSummary session;
  final List<SwingEntity>? swingData;
  final GraphMetric metric;
  final ValueChanged<GraphMetric> onMetricChanged;

  final Color cardBg;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final bool isDark;

  String _metricLabel(GraphMetric m) {
    switch (m) {
      case GraphMetric.swingSpeed:
        return 'Swing speed';
      case GraphMetric.swingForce:
        return 'Swing force';
      case GraphMetric.acceleration:
        return 'Acceleration';
      case GraphMetric.impactForce:
        return 'Impact force';
    }
  }

  String _metricUnit(GraphMetric m) {
    switch (m) {
      case GraphMetric.swingSpeed:
        return 'km/h';
      case GraphMetric.swingForce:
        return 'N';
      case GraphMetric.acceleration:
        return 'm/s²';
      case GraphMetric.impactForce:
        return 'N';
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _metricLabel(metric);
    final unit = _metricUnit(metric);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + dropdown
          Row(
            children: [
              Expanded(
                child: Text(
                  'Session graphs',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: .08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: .16)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<GraphMetric>(
                    value: metric,
                    dropdownColor:
                        isDark ? const Color(0xFF111827) : Colors.white,
                    iconEnabledColor:
                        isDark ? Colors.white : const Color(0xFF4B5563),
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    onChanged: (m) {
                      if (m != null) onMetricChanged(m);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: GraphMetric.swingSpeed,
                        child: Text('Swing speed'),
                      ),
                      DropdownMenuItem(
                        value: GraphMetric.swingForce,
                        child: Text('Swing force'),
                      ),
                      DropdownMenuItem(
                        value: GraphMetric.acceleration,
                        child: Text('Acceleration'),
                      ),
                      DropdownMenuItem(
                        value: GraphMetric.impactForce,
                        child: Text('Impact force'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            '$label over session',
            style: TextStyle(
              color: secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Compressed chart
          SizedBox(
            height: 180,
            width: double.infinity,
            child: swingData != null && swingData!.isNotEmpty
                ? InteractiveLineChart(
                    dataPoints: FeedbackTabChartData(
                      swings: swingData!,
                      metric: metric,
                    ).dataPoints,
                    yUnit: unit,
                    configuration: ChartConfiguration.detailed(),
                  )
                : Center(
                    child: Text(
                      'No swing data available',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
