import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/zones/zone_times.dart';
import '../../core/zones/zones.dart';
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
    final marker = ref.watch(workoutMarkerProvider(widget.activityId));
    final athlete = ref.watch(defaultAthleteProvider).valueOrNull;
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
            workoutMarker: marker.valueOrNull,
            editing: _editing,
            zoneSetup: zoneSetup,
            onOpenSettings: () => context.go('/settings'),
            onWorkoutChanged: (start, end) {
              ref
                  .read(databaseProvider)
                  .upsertWorkoutMarker(
                    activityId: widget.activityId,
                    tMs: start,
                    durationMs: end - start,
                  );
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
    required this.workoutMarker,
    required this.editing,
    required this.zoneSetup,
    required this.onOpenSettings,
    required this.onWorkoutChanged,
  });

  final Activity activity;
  final List<SampleRow> rows;
  final Marker? workoutMarker;
  final bool editing;
  final ZoneSetup? zoneSetup;
  final VoidCallback onOpenSettings;
  final void Function(int startMs, int endMs) onWorkoutChanged;

  String _formatDuration(int ms) {
    final totalSec = ms ~/ 1000;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final marker = workoutMarker;
    final workoutStart = marker?.tMs;
    final workoutEnd = marker == null
        ? null
        : marker.tMs + (marker.durationMs ?? 0);

    final stats = HrStats.fromHeartRates(rows.map((r) => r.hr));
    final axis = HrAxisRange.forStats(minHr: stats.min, maxHr: stats.max);
    final points = rows.map((r) => HrChartPoint(tMs: r.tMs, hr: r.hr)).toList();
    final zoneTimes = zoneSetup == null
        ? null
        : computeZoneTimes(
            rows,
            zoneSetup!,
            windowStartMs: workoutStart,
            windowEndMs: workoutEnd,
          );

    final meta = [
      _formatDate(activity.startedAtMs),
      _formatDuration(activity.durationMs),
      if (activity.sportType != null) activity.sportType!,
    ].join('  ·  ');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                meta,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: editing
                    ? EditableHrChart(
                        points: points,
                        axis: axis,
                        windowStartMs: 0,
                        windowEndMs: activity.durationMs,
                        workoutStartMs: workoutStart ?? 0,
                        workoutEndMs: workoutEnd ?? activity.durationMs,
                        onChanged: onWorkoutChanged,
                      )
                    : ZoomableHrChart(
                        points: points,
                        axis: axis,
                        fullStartMs: 0,
                        fullEndMs: activity.durationMs,
                        workoutStartMs: workoutStart,
                        workoutEndMs: workoutEnd,
                        zoneSetup: zoneSetup,
                      ),
              ),
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
              HrStatsRow(stats: stats),
              const SizedBox(height: 24),
              if (zoneSetup == null)
                ZoneLockedPrompt(onTap: onOpenSettings)
              else
                ZoneBreakdown(setup: zoneSetup!, times: zoneTimes!),
            ],
          ),
        ),
      ),
    );
  }
}
