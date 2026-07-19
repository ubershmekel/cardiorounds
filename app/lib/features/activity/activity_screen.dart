import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/zones/zone_times.dart';
import '../../core/zones/zones.dart';
import '../athletes/stream_athlete_picker.dart';
import '../recording/activity_meta_fields.dart';
import 'activity_duration.dart';
import 'hr_chart.dart';
import 'hr_stats.dart';
import 'hr_stats_row.dart';
import 'zone_breakdown.dart';

/// Read-only review of a completed activity: full HR chart and summary stats.
/// Tapping "edit" makes the `workout` span handles draggable on the chart.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, required this.activityId});

  final int activityId;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final activity = ref.watch(activityProvider(widget.activityId));
    final samples = ref.watch(samplesProvider(widget.activityId));
    final series =
        ref.watch(hrSeriesProvider(widget.activityId)).valueOrNull ?? const [];
    final marker = ref.watch(workoutMarkerProvider(widget.activityId));
    final athlete = ref.watch(defaultAthleteProvider).valueOrNull;
    // All athletes, so each HR stream can be scored against its own athlete's
    // zones (a shared multi-device session may hold several people's straps).
    final athletes =
        ref.watch(athletesProvider).valueOrNull ?? const <Athlete>[];
    final zoneSetup = zoneSetupFor(
      maxHr: athlete?.maxHeartrate,
      restingHr: athlete?.restingHeartrate,
    );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/home')),
        title: Text(
          activity.maybeWhen(
            data: (a) => a.name ?? a.sportType ?? 'Workout',
            orElse: () => 'Workout',
          ),
        ),
        actions: [
          IconButton(
            tooltip: _editing ? 'Done' : 'Edit workout window',
            icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ],
      ),
      body: activity.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load activity: $e')),
        data: (a) => samples.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load samples: $e')),
          data: (rows) => _ActivityBody(
            activity: a,
            rows: rows,
            series: series,
            workoutMarker: marker.valueOrNull,
            editing: _editing,
            zoneSetup: zoneSetup,
            athletes: athletes,
            restingHr: athlete?.restingHeartrate,
            onOpenSettings: () => context.go('/settings'),
            onWorkoutChanged: (start, end) async {
              final db = ref.read(databaseProvider);
              await db.upsertWorkoutMarker(
                activityId: widget.activityId,
                tMs: start,
                durationMs: end - start,
              );
              await db.computeAndSaveShape(widget.activityId);
            },
            onDelete: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete activity?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await ref
                    .read(databaseProvider)
                    .deleteActivity(widget.activityId);
                if (context.mounted) context.go('/home');
              }
            },
          ),
        ),
      ),
    );
  }
}

class _ActivityBody extends StatelessWidget {
  const _ActivityBody({
    required this.activity,
    required this.rows,
    required this.series,
    required this.workoutMarker,
    required this.editing,
    required this.zoneSetup,
    required this.athletes,
    this.restingHr,
    required this.onOpenSettings,
    required this.onWorkoutChanged,
    required this.onDelete,
  });

  final Activity activity;
  final List<HrSampleRow> rows;

  /// All HR streams for the activity. More than one means a multi-device session:
  /// the chart draws a line per device and stats are shown per device. With one
  /// stream the screen is identical to the single-device review.
  final List<HrSeries> series;
  final Marker? workoutMarker;
  final bool editing;

  /// The default athlete's zones. Used for the single-stream view and as the
  /// fallback for any stream that isn't attributed to a specific athlete.
  final ZoneSetup? zoneSetup;

  /// Every athlete, so each stream can be scored against its own attributed
  /// athlete's zones. See [_zoneSetupForSeries].
  final List<Athlete> athletes;
  final int? restingHr;
  final VoidCallback onOpenSettings;
  final void Function(int startMs, int endMs) onWorkoutChanged;
  final VoidCallback onDelete;

  /// The zones a single stream should be scored against: its attributed
  /// athlete's, falling back to the default athlete's ([zoneSetup]) when the
  /// stream is unattributed or that athlete is gone.
  ZoneSetup? _zoneSetupForSeries(HrSeries s) {
    final id = s.athleteId;
    if (id == null) return zoneSetup;
    for (final a in athletes) {
      if (a.id == id) {
        return zoneSetupFor(
          maxHr: a.maxHeartrate,
          restingHr: a.restingHeartrate,
        );
      }
    }
    return zoneSetup;
  }

  String _formatDuration(int ms) {
    final totalSec = ms ~/ 1000;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m ${ss}s';
    if (m > 0) return '${m}m ${ss}s';
    return '${s}s';
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} $hh:$min';
  }

  /// Max HR for each time-third of the workout window.
  List<int?> _computeThirds(int? startMs, int? endMs) {
    final filtered = rows.where((r) {
      if (startMs != null && r.tMs < startMs) return false;
      if (endMs != null && r.tMs > endMs) return false;
      return true;
    }).toList();
    if (filtered.length < 3) return [null, null, null];
    final t0 = filtered.first.tMs;
    final t1 = filtered.last.tMs;
    if (t0 == t1) return [null, null, null];
    final span = (t1 - t0) / 3;
    return List.generate(3, (i) {
      final lo = t0 + (span * i).round();
      final hi = t0 + (span * (i + 1)).round();
      return HrStats.fromHeartRates(
        filtered.where((r) => r.tMs >= lo && r.tMs < hi).map((r) => r.hr),
      ).max;
    });
  }

  /// Total extra beats above resting HR, integrated over workout window.
  /// Units: beats (bpm × minutes = beats).
  int? _computeExtraBeats(int? startMs, int? endMs) {
    final resting = restingHr;
    if (resting == null) return null;
    final filtered = rows.where((r) {
      if (startMs != null && r.tMs < startMs) return false;
      if (endMs != null && r.tMs > endMs) return false;
      return r.hr != null && r.hr! > 0;
    }).toList();
    if (filtered.length < 2) return null;
    double extra = 0;
    for (int i = 0; i < filtered.length - 1; i++) {
      final hr = filtered[i].hr;
      if (hr == null || hr <= 0) continue;
      final dtMin = (filtered[i + 1].tMs - filtered[i].tMs) / 60000;
      extra += (hr - resting).clamp(0, 9999) * dtMin;
    }
    return extra.round();
  }

  String _formatBeats(int beats) {
    if (beats >= 1000) return '${(beats / 1000).toStringAsFixed(1)}K';
    return beats.toString();
  }

  /// Per-third max HR plus the load score — the workout's shape and intensity.
  /// Computed from the primary set; shared by the single- and multi-device views.
  Widget _shapeStats(BuildContext context, List<int?> thirds, int? extraBeats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _TrendStat(
              label: '1st third',
              value: thirds[0],
              tooltip: 'Max HR in the first third of the workout',
            ),
            _TrendStat(
              label: '2nd third',
              value: thirds[1],
              tooltip: 'Max HR in the second third of the workout',
            ),
            _TrendStat(
              label: '3rd third',
              value: thirds[2],
              tooltip: 'Max HR in the final third of the workout',
            ),
          ],
        ),
        if (extraBeats != null) ...[
          const SizedBox(height: 16),
          Center(
            child: _TrendStat(
              label: 'extra beats',
              valueText: _formatBeats(extraBeats),
              tooltip:
                  'Total beats above resting HR during the workout ((bpm - rest_bpm) × minutes)',
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final marker = workoutMarker;
    final workoutStart = marker?.tMs;
    final workoutEnd = marker == null
        ? null
        : marker.tMs + (marker.durationMs ?? 0);
    final displayDurationMs = effectiveActivityDurationMs(
      activityDurationMs: activity.durationMs,
      workoutStartMs: workoutStart,
      workoutDurationMs: marker?.durationMs,
    );

    final chartStats = HrStats.fromHeartRates(rows.map((r) => r.hr));
    final axis = HrAxisRange.forStats(
      minHr: chartStats.min,
      maxHr: chartStats.max,
    );
    final points = rows.map((r) => HrChartPoint(tMs: r.tMs, hr: r.hr)).toList();

    // The top overview chart zone-colors the primary stream against its
    // attributed athlete's zones (falling back to the default athlete). Each
    // per-stream block below resolves zones the same way via [_zoneSetupForSeries].
    final primaryZoneSetup = series.isNotEmpty
        ? _zoneSetupForSeries(series.first)
        : zoneSetup;

    // Multi-device: one line per device, colored by set order, plus per-device
    // stats below. Single-device review is unchanged.
    final multi = series.length > 1;
    final chartSeries = [
      for (var i = 0; i < series.length; i++)
        HrChartSeries(
          points: [
            for (final r in series[i].samples)
              HrChartPoint(tMs: r.tMs, hr: r.hr),
          ],
          color: hrSeriesColor(i),
          label: series[i].deviceName ?? 'Device ${i + 1}',
        ),
    ];
    final chartAxis = multi
        ? HrAxisRange.forStats(
            minHr: HrStats.fromHeartRates(
              chartSeries.expand((s) => s.points).map((p) => p.hr),
            ).min,
            maxHr: HrStats.fromHeartRates(
              chartSeries.expand((s) => s.points).map((p) => p.hr),
            ).max,
          )
        : axis;

    final meta = [
      _formatDate(activity.startedAtMs),
      _formatDuration(displayDurationMs),
    ].join('  ·  ');

    final thirds = _computeThirds(workoutStart, workoutEnd);
    final extraBeats = _computeExtraBeats(workoutStart, workoutEnd);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ActivityMetaFields(activityId: activity.id),
              const SizedBox(height: 4),
              Text(
                meta,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: editing
                    ? EditableHrChart(
                        points: points,
                        axis: axis,
                        windowStartMs: 0,
                        windowEndMs: activity.durationMs,
                        workoutStartMs: workoutStart ?? 0,
                        workoutEndMs: workoutEnd ?? activity.durationMs,
                        activityStartMs: activity.startedAtMs,
                        onChanged: onWorkoutChanged,
                      )
                    : ZoomableHrChart(
                        points: multi ? const [] : points,
                        series: multi ? chartSeries : null,
                        axis: chartAxis,
                        fullStartMs: 0,
                        fullEndMs: activity.durationMs,
                        initialStartMs: workoutStart,
                        initialEndMs: workoutEnd,
                        workoutStartMs: workoutStart,
                        workoutEndMs: workoutEnd,
                        zoneSetup: multi ? null : primaryZoneSetup,
                        activityStartMs: activity.startedAtMs,
                      ),
              ),
              // Editing trims the workout window on the single primary line; the
              // multi-line comparison view returns when editing ends.
              if (multi && !editing) ...[
                const SizedBox(height: 8),
                HrChartLegend(series: chartSeries),
              ],
              if (editing)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Drag the handles to set the workout window.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // One block per HR stream. A solo activity is just the
              // single-iteration case of this loop, so the two layouts can't
              // drift apart (the divergence that once left zones locked after
              // re-attribution). A future location stream is another block
              // here — present or not — not a parallel layout.
              for (var i = 0; i < series.length; i++) ...[
                _StreamStatsBlock(
                  index: i,
                  multi: multi,
                  series: series[i],
                  zoneSetup: _zoneSetupForSeries(series[i]),
                  axis: chartAxis,
                  fullEndMs: activity.durationMs,
                  activityStartMs: activity.startedAtMs,
                  windowStartMs: workoutStart,
                  windowEndMs: workoutEnd,
                  onOpenSettings: onOpenSettings,
                ),
                const SizedBox(height: 16),
              ],
              // Shape and load are single-athlete analysis, so they reflect the
              // primary (first) stream.
              if (series.isNotEmpty) ...[
                Text(
                  multi
                      ? 'Workout shape · ${series.first.deviceName ?? 'Device 1'}'
                      : 'Workout shape',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _shapeStats(context, thirds, extraBeats),
              ],
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                label: Text(
                  'Delete activity',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One HR stream's review: a name header, the attribution picker, its min/avg/max
/// over the workout window, and its time-in-zone breakdown (or a locked prompt
/// when its athlete has no zones). Stats and breakdown are scored against
/// [zoneSetup] — this stream's attributed athlete's zones.
///
/// A solo activity renders exactly one of these, so it never diverges from the
/// multi-stream view. [multi] adds only the comparison chrome the multi view
/// needs and the solo view doesn't: the color dot, the card wrapper, and this
/// block's own chart (redundant with the top overview chart when there's one
/// stream).
class _StreamStatsBlock extends StatelessWidget {
  const _StreamStatsBlock({
    required this.index,
    required this.multi,
    required this.series,
    required this.zoneSetup,
    required this.axis,
    required this.fullEndMs,
    required this.activityStartMs,
    required this.windowStartMs,
    required this.windowEndMs,
    required this.onOpenSettings,
  });

  final int index;
  final bool multi;
  final HrSeries series;
  final ZoneSetup? zoneSetup;
  final HrAxisRange axis;
  final int fullEndMs;
  final int activityStartMs;
  final int? windowStartMs;
  final int? windowEndMs;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hrSeriesColor(index);
    final name = series.deviceName ?? 'Device ${index + 1}';
    final samples = series.samples;
    final setup = zoneSetup;

    final stats = HrStats.fromTimedHeartRates(
      samples.map((r) => (tMs: r.tMs, hr: r.hr)),
      windowStartMs: windowStartMs,
      windowEndMs: windowEndMs,
    );
    final zoneTimes = setup == null
        ? null
        : computeZoneTimes(
            samples,
            setup,
            windowStartMs: windowStartMs,
            windowEndMs: windowEndMs,
          );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // The chart-line color, only meaningful when there are lines to
            // tell apart.
            if (multi) ...[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                name,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Re-attribute this stream. Self-hides unless >1 athlete exists.
        Align(
          alignment: Alignment.centerLeft,
          child: StreamAthletePicker(setId: series.setId),
        ),
        // A solo stream is already drawn by the top overview chart; only the
        // multi-stream comparison view needs a per-stream chart here. The line
        // is zone-colored, falling back to the device color; lineColor also
        // tints signal-gap breaks.
        if (multi) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ZoomableHrChart(
              points: [
                for (final r in samples) HrChartPoint(tMs: r.tMs, hr: r.hr),
              ],
              axis: axis,
              fullStartMs: 0,
              fullEndMs: fullEndMs,
              initialStartMs: windowStartMs,
              initialEndMs: windowEndMs,
              workoutStartMs: windowStartMs,
              workoutEndMs: windowEndMs,
              lineColor: color,
              zoneSetup: setup,
              activityStartMs: activityStartMs,
            ),
          ),
        ],
        const SizedBox(height: 12),
        HrStatsRow(stats: stats),
        const SizedBox(height: 16),
        if (setup == null)
          ZoneLockedPrompt(onTap: onOpenSettings)
        else
          ZoneBreakdown(setup: setup, times: zoneTimes!),
      ],
    );

    // The card visually groups a stream against its neighbors; a solo stream has
    // no neighbors, so it reads cleaner flat.
    if (!multi) return content;
    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}

class _TrendStat extends StatelessWidget {
  const _TrendStat({
    required this.label,
    this.value,
    this.valueText,
    this.tooltip,
  });

  final String label;
  final int? value;
  final String? valueText;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Column(
      children: [
        Text(
          valueText ?? value?.toString() ?? '--',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (tooltip == null) return child;
    return Tooltip(
      message: tooltip!,
      triggerMode: TooltipTriggerMode.tap,
      child: child,
    );
  }
}
