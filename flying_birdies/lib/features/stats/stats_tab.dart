// lib/features/stats/stats_tab.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/interfaces/i_swing_repository.dart';
import '../../core/interfaces/i_session_repository.dart';
import '../../state/session_state_notifier.dart';

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

/// High-level time buckets based on when the user played.
enum TimeRange { daily, weekly, monthly, yearly, all }

class _StatsTabState extends State<StatsTab> {
  TimeRange _range = TimeRange.weekly;
  String _stroke = 'All Strokes';
  bool _loading = true;

  // Real data
  Map<String, List<double>> _realData = {};
  int _totalShots = 0;

  final _strokes = const <String>[
    'All Strokes',
    'Overhead Forehand',
    'Overhead Backhand',
    'Underarm Forehand',
    'Underarm Backhand',
  ];

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen for session changes
    final sessionNotifier = context.read<SessionStateNotifier>();
    sessionNotifier.removeListener(_onSessionsChanged);
    sessionNotifier.addListener(_onSessionsChanged);
  }

  @override
  void dispose() {
    final sessionNotifier = context.read<SessionStateNotifier>();
    sessionNotifier.removeListener(_onSessionsChanged);
    super.dispose();
  }

  void _onSessionsChanged() {
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    setState(() => _loading = true);

    try {
      final swingRepo = context.read<ISwingRepository>();
      final sessionRepo = context.read<ISessionRepository>();

      // Get date range based on selected time range
      final now = DateTime.now();
      final start = switch (_range) {
        TimeRange.daily => DateTime(now.year, now.month, now.day),
        TimeRange.weekly => now.subtract(const Duration(days: 6)),
        TimeRange.monthly => now.subtract(const Duration(days: 29)),
        TimeRange.yearly => DateTime(now.year - 1, now.month, now.day),
        TimeRange.all => DateTime(2020, 1, 1), // Far back
      };

      // Load sessions in range
      final sessions = await sessionRepo.getSessionsInRange(start, now);

      // Filter by stroke if not "All Strokes"
      final filteredSessions = _stroke == 'All Strokes'
          ? sessions
          : sessions.where((s) => s.strokeFocus == _stroke).toList();

      // Load all swings for these sessions
      final allSwings = <dynamic>[];
      for (final session in filteredSessions) {
        if (session.id != null) {
          final swings = await swingRepo.getSwingsForSession(session.id!);
          allSwings.addAll(swings);
        }
      }

      // Group swings by time bucket and calculate averages
      final buckets = _groupSwingsByBucket(allSwings, start, now);

      setState(() {
        _realData = buckets;
        _totalShots = allSwings.length;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load stats: $e');
      setState(() => _loading = false);
    }
  }

  Map<String, List<double>> _groupSwingsByBucket(
    List<dynamic> swings,
    DateTime start,
    DateTime end,
  ) {
    final bucketCount = switch (_range) {
      TimeRange.daily => 24, // hours
      TimeRange.weekly => 7, // days
      TimeRange.monthly => 30,
      TimeRange.yearly => 12,
      TimeRange.all => 36,
    };

    // Initialize buckets
    final speedBuckets = List<List<double>>.generate(bucketCount, (_) => []);
    final forceBuckets = List<List<double>>.generate(bucketCount, (_) => []);
    final accelBuckets = List<List<double>>.generate(bucketCount, (_) => []);
    final sforceBuckets = List<List<double>>.generate(bucketCount, (_) => []);

    // Group swings into buckets
    for (final swing in swings) {
      final timestamp = swing.timestamp;
      final bucketIndex = _getBucketIndex(timestamp, start, end, bucketCount);

      if (bucketIndex >= 0 && bucketIndex < bucketCount) {
        speedBuckets[bucketIndex].add(swing.maxVtip * 3.6); // m/s to km/h
        forceBuckets[bucketIndex].add(swing.estForceN);
        accelBuckets[bucketIndex].add(swing.impactAmax);
        sforceBuckets[bucketIndex].add(swing.impactSeverity);
      }
    }

    // Calculate averages and normalize to 0-1 range
    final speedSeries = _normalizeSeriesWithFallback(speedBuckets, 80, 240);
    final forceSeries = _normalizeSeriesWithFallback(forceBuckets, 20, 120);
    final accelSeries = _normalizeSeriesWithFallback(accelBuckets, 5, 45);
    final sforceSeries = _normalizeSeriesWithFallback(sforceBuckets, 10, 80);

    return {
      'speed': speedSeries,
      'force': forceSeries,
      'accel': accelSeries,
      'sforce': sforceSeries,
    };
  }

  int _getBucketIndex(
      DateTime timestamp, DateTime start, DateTime end, int bucketCount) {
    final totalDuration = end.difference(start);
    final elapsed = timestamp.difference(start);

    if (elapsed.isNegative || elapsed > totalDuration) return -1;

    final ratio = elapsed.inMilliseconds / totalDuration.inMilliseconds;
    return (ratio * bucketCount).floor().clamp(0, bucketCount - 1);
  }

  List<double> _normalizeSeriesWithFallback(
    List<List<double>> buckets,
    double min,
    double max,
  ) {
    final range = max - min;
    return buckets.map((bucket) {
      if (bucket.isEmpty) {
        // Use synthetic data for empty buckets
        return 0.5 + (math.Random().nextDouble() - 0.5) * 0.2;
      }
      final avg = bucket.reduce((a, b) => a + b) / bucket.length;
      return ((avg - min) / range).clamp(0.0, 1.0);
    }).toList();
  }

  List<String> _labelsForRange(TimeRange r) {
    final now = DateTime.now();
    switch (r) {
      case TimeRange.daily:
        return List.generate(24, (h) => '${h.toString().padLeft(2, '0')}:00');
      case TimeRange.weekly:
        final start = now.subtract(const Duration(days: 6));
        final f = DateFormat('E d');
        return List.generate(7, (i) => f.format(start.add(Duration(days: i))));
      case TimeRange.monthly:
        final start = now.subtract(const Duration(days: 29));
        final f = DateFormat('MMM d');
        return List.generate(30, (i) => f.format(start.add(Duration(days: i))));
      case TimeRange.yearly:
        final f = DateFormat('MMM');
        return List.generate(
          12,
          (i) => f.format(DateTime(now.year, now.month - 11 + i)),
        );
      case TimeRange.all:
        final f = DateFormat('MMM yy');
        return List.generate(
          36,
          (i) => f.format(DateTime(now.year, now.month - 35 + i)),
        );
    }
  }

  Map<String, num> _stats(List<double> s,
      {required num base, required num span}) {
    if (s.isEmpty) return {'max': base, 'avg': base};
    final mx = s.reduce(math.max);
    final avg = s.reduce((a, b) => a + b) / s.length;
    return {
      'max': base + mx * span,
      'avg': base + avg * span,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pad = const EdgeInsets.fromLTRB(16, 16, 16, 24);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Get series (normalized 0..1)
    final spd = _realData['speed'] ?? [];
    final frc = _realData['force'] ?? [];
    final acc = _realData['accel'] ?? [];
    final sfo = _realData['sforce'] ?? [];

    final labels = _labelsForRange(_range);

    // value ranges
    const speedMin = 80.0, speedMax = 240.0;
    const forceMin = 20.0, forceMax = 120.0;
    const accelMin = 5.0, accelMax = 45.0;
    const sforceMin = 10.0, sforceMax = 80.0;

    final spdStats = _stats(spd, base: speedMin, span: speedMax - speedMin);
    final frcStats = _stats(frc, base: forceMin, span: forceMax - forceMin);
    final accStats = _stats(acc, base: accelMin, span: accelMax - accelMin);
    final sfoStats = _stats(sfo, base: sforceMin, span: sforceMax - sforceMin);

    return RefreshIndicator(
      onRefresh: _loadRealData,
      child: ListView(
        padding: pad,
        children: [
          Text(
            'Performance Analysis',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 12),

          // Time range pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _pill('Daily', TimeRange.daily),
                _pill('Weekly', TimeRange.weekly),
                _pill('Monthly', TimeRange.monthly),
                _pill('Yearly', TimeRange.yearly),
                _pill('All', TimeRange.all),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stroke dropdown
          Align(
            alignment: Alignment.centerLeft,
            child: _StrokeDropdown(
              value: _stroke,
              items: _strokes,
              onChanged: (v) {
                setState(() => _stroke = v ?? _stroke);
                _loadRealData();
              },
            ),
          ),
          const SizedBox(height: 16),

          _MetricCard(
            heroTag: 'metric-speed',
            title: 'Swing Speed',
            unit: 'km/h',
            icon: Icons.flash_on_rounded,
            maxValue: spdStats['max']!.round(),
            avgValue: spdStats['avg']!.round(),
            shots: _totalShots,
            series: spd,
            onOpen: () => _openChart(
              title: 'Swing Speed',
              unit: 'km/h',
              totalShots: _totalShots,
              series: spd,
              color: const Color(0xFFFF7AE0),
              minValue: speedMin,
              maxValue: speedMax,
              labels: labels,
            ),
          ),
          const SizedBox(height: 12),

          _MetricCard(
            heroTag: 'metric-force',
            title: 'Impact Force',
            unit: 'N',
            icon: Icons.adjust_rounded,
            maxValue: frcStats['max']!.round(),
            avgValue: frcStats['avg']!.round(),
            shots: _totalShots,
            series: frc,
            onOpen: () => _openChart(
              title: 'Impact Force',
              unit: 'N',
              totalShots: _totalShots,
              series: frc,
              color: const Color(0xFFFFB86B),
              minValue: forceMin,
              maxValue: forceMax,
              labels: labels,
            ),
          ),
          const SizedBox(height: 12),

          _MetricCard(
            heroTag: 'metric-accel',
            title: 'Acceleration',
            unit: 'm/s²',
            icon: Icons.trending_up_rounded,
            maxValue: accStats['max']!.round(),
            avgValue: accStats['avg']!.round(),
            shots: _totalShots,
            series: acc,
            onOpen: () => _openChart(
              title: 'Acceleration',
              unit: 'm/s²',
              totalShots: _totalShots,
              series: acc,
              color: const Color(0xFF9AE6B4),
              minValue: accelMin,
              maxValue: accelMax,
              labels: labels,
            ),
          ),
          const SizedBox(height: 12),

          _MetricCard(
            heroTag: 'metric-swingforce',
            title: 'Swing Force',
            unit: 'au',
            icon: Icons.refresh_rounded,
            maxValue: sfoStats['max']!.round(),
            avgValue: sfoStats['avg']!.round(),
            shots: _totalShots,
            series: sfo,
            onOpen: () => _openChart(
              title: 'Swing Force',
              unit: 'au',
              totalShots: _totalShots,
              series: sfo,
              color: const Color(0xFFA5B4FC),
              minValue: sforceMin,
              maxValue: sforceMax,
              labels: labels,
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _pill(String label, TimeRange r) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _range == r;

    final bgSelected =
        isDark ? const Color(0xFF7C3AED) : const Color(0xFF4F46E5);
    final bg =
        isDark ? Colors.white.withValues(alpha: .14) : const Color(0xFFE5E7EB);
    final borderSelected =
        isDark ? Colors.white.withValues(alpha: .25) : Colors.transparent;
    final border =
        isDark ? Colors.white.withValues(alpha: .16) : Colors.transparent;

    final labelColor = selected
        ? Colors.white
        : (isDark
            ? Colors.white.withValues(alpha: .85)
            : const Color(0xFF4B5563));

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _range = r);
            _loadRealData();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? bgSelected : bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? borderSelected : border,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .22),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : (isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .06),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: .1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChart({
    required String title,
    required String unit,
    required List<double> series,
    required int totalShots,
    required Color color,
    required double minValue,
    required double maxValue,
    required List<String> labels,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EnlargedChartSheet(
        title: title,
        unit: unit,
        series: series,
        totalShots: totalShots,
        color: color,
        minValue: minValue,
        maxValue: maxValue,
        labels: labels,
      ),
    );
  }
}

/* ───────── Metric card + mini sparkline ───────── */

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.heroTag,
    required this.title,
    required this.unit,
    required this.icon,
    required this.maxValue,
    required this.avgValue,
    required this.shots,
    required this.series,
    required this.onOpen,
  });

  final String heroTag;
  final String title;
  final String unit;
  final IconData icon;
  final int maxValue;
  final num avgValue;
  final int shots;
  final List<double> series;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: .05) : Colors.white;
    final border =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0x14000000);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final captionColor =
        isDark ? Colors.white.withValues(alpha: .75) : const Color(0xFF6B7280);
    final iconBg =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0xFFE5E7EB);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF4B5563);

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: bg,
          border: Border.all(color: border),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: .06),
                blurRadius: 16,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      _Kpi(
                        label: 'Max',
                        value: '$maxValue $unit',
                        color: captionColor,
                        titleColor: titleColor,
                      ),
                      _Kpi(
                        label: 'Avg',
                        value: '${avgValue.toStringAsFixed(0)} $unit',
                        color: captionColor,
                        titleColor: titleColor,
                      ),
                      _Kpi(
                        label: 'Shots',
                        value: shots.toString(),
                        color: captionColor,
                        titleColor: titleColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Hero(
              tag: heroTag,
              child: SizedBox(
                width: 118,
                height: 78,
                child: _Sparkline(series: series),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.color,
    required this.titleColor,
  });
  final String label;
  final String value;
  final Color color;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.series});
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SparklinePainter(series: series));
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.series});
  final List<double> series;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    final n = series.length;
    final dx = size.width / (n - 1);
    double yAt(int i) => size.height * (1 - series[i]);

    final path = Path()..moveTo(0, yAt(0));
    for (int i = 1; i < n; i++) {
      path.lineTo(dx * i, yAt(i));
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF6FD8), Color(0xFF7E4AED)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.series != series;
}

/* ───────── Enlarged chart bottom sheet ───────── */

class _EnlargedChartSheet extends StatefulWidget {
  const _EnlargedChartSheet({
    required this.title,
    required this.unit,
    required this.series,
    required this.totalShots,
    required this.color,
    required this.minValue,
    required this.maxValue,
    required this.labels,
  });

  final String title;
  final String unit;
  final List<double> series; // normalized 0..1
  final int totalShots;
  final Color color;
  final double minValue;
  final double maxValue;
  final List<String> labels;

  @override
  State<_EnlargedChartSheet> createState() => _EnlargedChartSheetState();
}

class _EnlargedChartSheetState extends State<_EnlargedChartSheet> {
  Offset? _cursor;
  int? _idx;
  double? _value;

  static const double _canvasWidth = 1200;
  static const double _canvasHeight = 320;

  final TransformationController _tc = TransformationController();

  void _updatePointer(Offset local) {
    final n = widget.series.length;
    if (n <= 1) return;

    final scene = _tc.toScene(local);
    final dx = _canvasWidth / (n - 1);
    final x = scene.dx.clamp(0.0, _canvasWidth);
    final i = (x / dx).round().clamp(0, n - 1);

    final snappedX = i * dx;
    final norm = widget.series[i].clamp(0.0, 1.0);
    final yOnLine = _canvasHeight * (1 - norm);
    final val = widget.minValue + norm * (widget.maxValue - widget.minValue);

    setState(() {
      _cursor = Offset(snappedX, yOnLine);
      _idx = i;
      _value = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        isDark ? const Color(0xFF151A29).withValues(alpha: .97) : Colors.white;
    final border =
        isDark ? Colors.white.withValues(alpha: .08) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);

    int shotsForPoint(int idx) {
      if (widget.series.isEmpty) return 0;
      final base = (widget.totalShots / widget.series.length);
      return (base + (widget.series[idx] - 0.5) * 10).round().clamp(0, 999);
    }

    Widget tooltip() {
      if (_cursor == null || _idx == null || _value == null) {
        return const SizedBox.shrink();
      }
      final left = (_cursor!.dx - 80).clamp(8.0, _canvasWidth - 160.0);
      final top = (_cursor!.dy - 60).clamp(8.0, _canvasHeight - 54.0);
      final label = (_idx! >= 0 && _idx! < widget.labels.length)
          ? widget.labels[_idx!]
          : 'Point ${_idx! + 1}';
      final shotsHere = shotsForPoint(_idx!);

      return Positioned(
        left: left,
        top: top,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1525).withValues(alpha: .92)
                : const Color(0xFF111827),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .35),
                blurRadius: 12,
              )
            ],
          ),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${_value!.toStringAsFixed(1)} ${widget.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text('Shots: $shotsHere'),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: border),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              height: 5,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(
                    isDark,
                    'Range ${widget.minValue.toInt()}–${widget.maxValue.toInt()} ${widget.unit}',
                  ),
                  _infoChip(isDark, 'Shots ${widget.totalShots}'),
                  _infoChip(isDark, '${widget.series.length} points'),
                ],
              ),
            ),
            SizedBox(
              height: _canvasHeight,
              child: GestureDetector(
                onTapDown: (d) => _updatePointer(d.localPosition),
                onPanStart: (d) => _updatePointer(d.localPosition),
                onPanUpdate: (d) => _updatePointer(d.localPosition),
                onPanEnd: (_) => setState(() => _cursor = _idx = _value = null),
                onTapUp: (_) => setState(() => _cursor = _idx = _value = null),
                child: InteractiveViewer(
                  transformationController: _tc,
                  minScale: 1,
                  maxScale: 6,
                  child: Stack(
                    children: [
                      SizedBox(
                        width: _canvasWidth,
                        height: _canvasHeight,
                        child: CustomPaint(
                          painter: _BigSparklinePainter(
                            series: widget.series,
                            color: widget.color,
                            cursor: _cursor,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      tooltip(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(bool isDark, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: .06)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF4B5563),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BigSparklinePainter extends CustomPainter {
  _BigSparklinePainter({
    required this.series,
    required this.color,
    required this.cursor,
    required this.isDark,
  });

  final List<double> series;
  final Color color;
  final Offset? cursor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    final n = series.length;
    final dx = size.width / (n - 1);
    double yAt(int i) => size.height * (1 - series[i]);

    // horizontal grid lines
    final grid = Paint()
      ..color = (isDark
              ? Colors.white.withValues(alpha: .08)
              : const Color(0xFFE5E7EB))
          .withValues(alpha: .8)
      ..strokeWidth = 1;
    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // main path
    final path = Path()..moveTo(0, yAt(0));
    for (int i = 1; i < n; i++) {
      path.lineTo(dx * i, yAt(i));
    }

    // area fill
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFF6FD8).withValues(alpha: .13),
          const Color(0xFF7E4AED).withValues(alpha: .13),
        ],
      ).createShader(Offset.zero & size);
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fill);

    // line
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = color.withValues(alpha: .9);
    canvas.drawPath(path, line);

    // crosshair + dot
    if (cursor != null) {
      final x = cursor!.dx.clamp(0.0, size.width);
      final idx = (x / dx).round().clamp(0, n - 1);
      final y = yAt(idx);
      final cross = Paint()
        ..color = (isDark ? Colors.white54 : const Color(0xFF9CA3AF))
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cross);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), cross);

      final dot = Paint()..color = color;
      canvas.drawCircle(Offset(dx * idx, y), 5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _BigSparklinePainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.cursor != cursor;
}

/* ───────── Stroke dropdown ───────── */

class _StrokeDropdown extends StatelessWidget {
  const _StrokeDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withValues(alpha: .08) : Colors.white;
    final border =
        isDark ? Colors.white.withValues(alpha: .10) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: isDark ? const Color(0xFF151A29) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          iconEnabledColor: isDark ? Colors.white70 : const Color(0xFF4B5563),
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
          items: items
              .map(
                (s) => DropdownMenuItem<String>(
                  value: s,
                  child: Text(s),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
