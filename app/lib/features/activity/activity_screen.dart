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
  bool _controllersInitialized = false;
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _nameFocus = FocusNode();
  final _noteFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // FocusNodes let us (1) save to DB when the user taps away (hasFocus → false)
    // and (2) jump focus from name to note on Enter (see onNameSubmitted).
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _save(name: _nameController.text);
    });
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _save(note: _noteController.text);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _nameFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _save({String? name, String? note}) {
    ref.read(databaseProvider).updateActivity(
      activityId: widget.activityId,
      name: name,
      note: note,
    );
  }

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

    activity.whenData((a) {
      if (!_controllersInitialized) {
        _controllersInitialized = true;
        _nameController.text = a.name ?? '';
        _noteController.text = a.note ?? '';
      }
    });

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
            nameController: _nameController,
            nameFocusNode: _nameFocus,
            noteController: _noteController,
            noteFocusNode: _noteFocus,
            onNameSubmitted: (_) => _noteFocus.requestFocus(),
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
    required this.nameController,
    required this.nameFocusNode,
    required this.noteController,
    required this.noteFocusNode,
    required this.onNameSubmitted,
    required this.onOpenSettings,
    required this.onWorkoutChanged,
  });

  final Activity activity;
  final List<SampleRow> rows;
  final Marker? workoutMarker;
  final bool editing;
  final ZoneSetup? zoneSetup;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final TextEditingController noteController;
  final FocusNode noteFocusNode;
  final ValueChanged<String> onNameSubmitted;
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

    final timedHeartRates = rows.map((r) => (tMs: r.tMs, hr: r.hr));
    final stats = HrStats.fromTimedHeartRates(
      timedHeartRates,
      windowStartMs: workoutStart,
      windowEndMs: workoutEnd,
    );
    final chartStats = HrStats.fromHeartRates(rows.map((r) => r.hr));
    final axis = HrAxisRange.forStats(
      minHr: chartStats.min,
      maxHr: chartStats.max,
    );
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
              TextField(
                controller: nameController,
                focusNode: nameFocusNode,
                onSubmitted: onNameSubmitted,
                textInputAction: TextInputAction.next,
                style: theme.textTheme.titleLarge,
                decoration: InputDecoration(
                  hintText: 'Add a name…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              TextField(
                controller: noteController,
                focusNode: noteFocusNode,
                maxLines: null,
                textInputAction: TextInputAction.done,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a note…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 4),
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
                        initialStartMs: workoutStart,
                        initialEndMs: workoutEnd,
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
