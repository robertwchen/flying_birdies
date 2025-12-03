// lib/features/feedback/feedback_tab.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../../widgets/glass_widgets.dart';
import '../../widgets/charts/charts.dart';
import '../history/history_tab.dart' show SessionSummary;
import '../../services/database_service.dart';
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
    if (_current == null) _autoLoad();
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

      // Reload swing data for new session
      if (_current != null) {
        final sessionId = int.tryParse(_current!.id);
        if (sessionId != null) {
          _loadSwingData(sessionId).then((swings) {
            if (mounted) {
              setState(() => _swingData = swings);
            }
          });
        }
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
      final loader = widget.loadLatest ?? _mockLatest;
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

  // Fetch latest session from database
  Future<SessionSummary?> _mockLatest() async {
    try {
      final db = DatabaseService.instance;
      final sessionMaps = await db.getSessions(limit: 1);

      if (sessionMaps.isEmpty) return null;

      final sessionMap = sessionMaps.first;
      final sessionId = sessionMap['id'] as int;
      final swings = await db.getSwingsForSession(sessionId);

      if (swings.isEmpty) return null;

      final avgSpeed = swings.map((s) => s.maxVtipKmh).reduce((a, b) => a + b) /
          swings.length;
      final maxSpeed =
          swings.map((s) => s.maxVtipKmh).reduce((a, b) => a > b ? a : b);

      final startTime =
          DateTime.fromMillisecondsSinceEpoch(sessionMap['start_time'] as int);

      return SessionSummary(
        id: sessionId.toString(),
        date: startTime,
        title: sessionMap['stroke_focus'] as String? ?? 'Training',
        avgSpeedKmh: avgSpeed,
        maxSpeedKmh: maxSpeed,
        sweetSpotPct: 0.6, // placeholder
        consistencyPct: 0.7, // placeholder
        hits: swings.length,
      );
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                  // Coach Summary
                  _CoachSummaryCard(
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    lines: _coachLines(_current!, _comparisonTarget()),
                  ),
                  const SizedBox(height: 16),

                  // Session graphs – directly after coach summary.
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
                  const SizedBox(height: 16),

                  // Metrics grid – 4 metrics (no sweet-spot/consistency labels)
                  _MetricGrid(
                    s: _current!,
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 12),

                  // Hits
                  _HitsCard(
                    hits: _current!.hits,
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                  const SizedBox(height: 20),

                  // Comparison + dropdown
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Comparison',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
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
                  const SizedBox(height: 10),

                  _CompareList(
                    deltas: _deltas(_current!, _comparisonTarget()),
                    cardBg: cardBg,
                    border: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

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
    final double impactAvg = cur.sweetSpotPct * 100;
    final double accelAvg = cur.consistencyPct * 100;
    final int hits = cur.hits;

    final bool hasOther = other != null;

    // Deltas vs comparison target (if any)
    final double dAvg = hasOther ? avg - other.avgSpeedKmh : 0.0;
    final double dMax = hasOther ? max - other.maxSpeedKmh : 0.0;
    final double dImp = hasOther ? impactAvg - other.sweetSpotPct * 100 : 0.0;
    final double dAccel =
        hasOther ? accelAvg - other.consistencyPct * 100 : 0.0;
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
      // Again reusing sweetSpot/consistency as impact/accel for now:
      'Impact force': (cur.sweetSpotPct - other.sweetSpotPct) * 100,
      'Acceleration': (cur.consistencyPct - other.consistencyPct) * 100,
    };
  }

  List<String> _tipsFor(SessionSummary s) {
    final tips = <String>[];

    final avg = s.avgSpeedKmh;
    final impact = s.sweetSpotPct * 100; // TEMP mapping
    final accel = s.consistencyPct * 100; // TEMP mapping

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined,
                  size: 22, color: primaryText),
              const SizedBox(width: 8),
              Text(
                'Coach Summary',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lines.first,
            style: TextStyle(
              color: primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lines.last,
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
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
    final impactAvg = s.sweetSpotPct * 100;
    final accelAvg = s.consistencyPct * 100;

    // Until you have real max values for impact/accel, derive from avg.
    final impactMax = impactAvg * 1.15;
    final accelMax = accelAvg * 1.15;

    // TEMP swing-force approximation from impact+accel.
    final swingForceAvg = (impactAvg + accelAvg) / 2;
    final swingForceMax = swingForceAvg * 1.15;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
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
          unit: 'au',
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bigger title font
          Text(
            title,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          // Avg
          Text(
            'Avg ${_fmt(avg)} $unit',
            style: TextStyle(
              color: secondaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          // Max
          Text(
            'Max ${_fmt(max)} $unit',
            style: TextStyle(
              color: secondaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Make "Hits" the bold hero
          Text(
            'Hits',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          // Number is still big, but slightly lighter weight
          Text(
            '$hits',
            style: TextStyle(
              color: secondaryText,
              fontSize: 24,
              fontWeight: FontWeight.w600,
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
      height: 48,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.trending_up,
            size: 18,
            color: secondaryText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            txt,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color:
                    isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              Text(
                'Tips',
                style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $t',
                style: TextStyle(
                  color: secondaryText,
                  height: 1.35,
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
        return 'au';
      case GraphMetric.acceleration:
        return 'm/s²';
      case GraphMetric.impactForce:
        return 'N';
    }
  }

  // Extract real metric data from swing entities
  List<double> _seriesFor(GraphMetric m) {
    // If no real swing data, fall back to synthetic data
    if (swingData == null || swingData!.isEmpty) {
      debugPrint('⚠️ FEEDBACK: No swing data, using synthetic data');
      return _syntheticSeriesFor(m);
    }

    debugPrint(
        '✅ FEEDBACK: Using REAL swing data - ${swingData!.length} swings');
    // Extract the appropriate metric from real swing data
    switch (m) {
      case GraphMetric.swingSpeed:
        // Convert m/s to km/h (multiply by 3.6)
        return swingData!.map((s) => s.maxVtip * 3.6).toList();
      case GraphMetric.swingForce:
        // Use impactSeverity as swing force
        return swingData!.map((s) => s.impactSeverity).toList();
      case GraphMetric.acceleration:
        // Use impactAmax as acceleration (m/s²)
        return swingData!.map((s) => s.impactAmax).toList();
      case GraphMetric.impactForce:
        // Use estForceN as impact force (N)
        return swingData!.map((s) => s.estForceN).toList();
    }
  }

  // Fallback synthetic data when no real swings available
  List<double> _syntheticSeriesFor(GraphMetric m) {
    final impactAvg = session.sweetSpotPct * 100;
    final accelAvg = session.consistencyPct * 100;

    double base;
    switch (m) {
      case GraphMetric.swingSpeed:
        base = session.avgSpeedKmh.toDouble();
        break;
      case GraphMetric.swingForce:
        base = (impactAvg + accelAvg) / 2;
        break;
      case GraphMetric.acceleration:
        base = accelAvg;
        break;
      case GraphMetric.impactForce:
        base = impactAvg;
        break;
    }

    const count = 18;
    return List<double>.generate(count, (i) {
      final t = i / (count - 1); // 0 → 1 across session time
      final bump = 0.1 * (1 - (2 * t - 1) * (2 * t - 1)); // small smooth arch
      return base * (0.9 + bump);
    });
  }

  void _openFullScreenChart(BuildContext context) {
    final label = _metricLabel(metric);
    final unit = _metricUnit(metric);

    // Create chart data from swing entities
    final chartData = swingData != null && swingData!.isNotEmpty
        ? FeedbackTabChartData(swings: swingData!, metric: metric)
        : null;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .7),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final maxWidth = constraints.maxWidth.clamp(0.0, 520.0);
              final dialogBg = isDark ? const Color(0xFF020617) : Colors.white;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: dialogBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: .18)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$label over session',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: secondaryText,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 280,
                          width: double.infinity,
                          child: chartData != null && chartData.hasData
                              ? InteractiveLineChart(
                                  dataPoints: chartData.dataPoints,
                                  yUnit: unit,
                                  configuration: ChartConfiguration.detailed(),
                                )
                              : Center(
                                  child: Text(
                                    'No swing data available',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _metricLabel(metric);
    final unit = _metricUnit(metric);
    final series = _seriesFor(metric);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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

          const SizedBox(height: 12),

          Text(
            '$label trend ($unit)',
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Clickable chart area
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openFullScreenChart(context),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: _MiniBarChart(
                  values: series,
                  lineColor: isDark
                      ? Colors.white.withValues(alpha: .9)
                      : const Color(0xFF1F2937),
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: .12)
                      : const Color(0xFFE5E7EB),
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),
          Text(
            'Tap the chart to expand',
            style: TextStyle(
              color: secondaryText.withValues(alpha: .8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final double range = (maxV - minV).clamp(1e-6, double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final step = values.length > 1 ? w / (values.length - 1) : 0.0;

        final points = <Offset>[];
        for (var i = 0; i < values.length; i++) {
          final x = i * step;
          final norm = (values[i] - minV) / range;
          final y = h - norm * (h - 12); // top padding
          points.add(Offset(x, y));
        }

        return CustomPaint(
          painter: _MiniChartPainter(
            points: points,
            lineColor: lineColor,
            fillColor: fillColor,
          ),
        );
      },
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  _MiniChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
  });

  final List<Offset> points;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final fillPath = Path()
      ..moveTo(points.first.dx, size.height)
      ..addPolygon(points, false)
      ..lineTo(points.last.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(ui.PointMode.polygon, points, linePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor;
  }
}
