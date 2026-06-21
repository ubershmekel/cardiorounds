import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/zones/zone_times.dart';
import '../../core/zones/zones.dart';
import '../recording/sport_type_options.dart';
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
  bool _controllersInitialized = false;
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  final _sportTypeController = TextEditingController();
  final _nameFocus = FocusNode();
  final _noteFocus = FocusNode();
  final _sportTypeFocus = FocusNode();
  List<String> _pastSportTypes = const [];

  @override
  void initState() {
    super.initState();
    _loadPastSportTypes();
    // FocusNodes let us (1) save to DB when the user taps away (hasFocus → false)
    // and (2) jump focus from name to note on Enter (see onNameSubmitted).
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _save(name: _nameController.text);
    });
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _save(note: _noteController.text);
    });
    _sportTypeFocus.addListener(() {
      if (!_sportTypeFocus.hasFocus) {
        _save(sportType: _sportTypeController.text);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _sportTypeController.dispose();
    _nameFocus.dispose();
    _noteFocus.dispose();
    _sportTypeFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPastSportTypes() async {
    final types = await ref.read(databaseProvider).distinctSportTypes();
    if (mounted) setState(() => _pastSportTypes = types);
  }

  void _save({String? name, String? note, String? sportType}) {
    ref
        .read(databaseProvider)
        .updateActivity(
          activityId: widget.activityId,
          name: name,
          note: note,
          sportType: sportType,
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
        _sportTypeController.text = a.sportType ?? '';
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
            restingHr: athlete?.restingHeartrate,
            nameController: _nameController,
            nameFocusNode: _nameFocus,
            noteController: _noteController,
            noteFocusNode: _noteFocus,
            sportTypeController: _sportTypeController,
            sportTypeFocusNode: _sportTypeFocus,
            pastSportTypes: _pastSportTypes,
            onNameSubmitted: (_) => _noteFocus.requestFocus(),
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
    required this.workoutMarker,
    required this.editing,
    required this.zoneSetup,
    this.restingHr,
    required this.nameController,
    required this.nameFocusNode,
    required this.noteController,
    required this.noteFocusNode,
    required this.sportTypeController,
    required this.sportTypeFocusNode,
    required this.pastSportTypes,
    required this.onNameSubmitted,
    required this.onOpenSettings,
    required this.onWorkoutChanged,
    required this.onDelete,
  });

  final Activity activity;
  final List<SampleRow> rows;
  final Marker? workoutMarker;
  final bool editing;
  final ZoneSetup? zoneSetup;
  final int? restingHr;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;
  final TextEditingController noteController;
  final FocusNode noteFocusNode;
  final TextEditingController sportTypeController;
  final FocusNode sportTypeFocusNode;
  final List<String> pastSportTypes;
  final ValueChanged<String> onNameSubmitted;
  final VoidCallback onOpenSettings;
  final void Function(int startMs, int endMs) onWorkoutChanged;
  final VoidCallback onDelete;

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
              TextField(
                controller: nameController,
                focusNode: nameFocusNode,
                onTapOutside: (_) => nameFocusNode.unfocus(),
                onSubmitted: onNameSubmitted,
                textCapitalization: TextCapitalization.sentences,
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
                onTapOutside: (_) => noteFocusNode.unfocus(),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
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
              RawAutocomplete<String>(
                textEditingController: sportTypeController,
                focusNode: sportTypeFocusNode,
                optionsBuilder: (_) => pastSportTypes.take(5),
                optionsViewBuilder: (context, onSelected, options) => TapRegion(
                  groupId: sportTypeFocusNode,
                  child: SportTypeOptions(
                    options: options,
                    onSelected: onSelected,
                  ),
                ),
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      // Grouped with the overlay above so a tap outside both
                      // drops focus.
                      return TapRegion(
                        groupId: sportTypeFocusNode,
                        onTapOutside: (_) => focusNode.unfocus(),
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Sport type…',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      );
                    },
              ),
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
                        points: points,
                        axis: axis,
                        fullStartMs: 0,
                        fullEndMs: activity.durationMs,
                        initialStartMs: workoutStart,
                        initialEndMs: workoutEnd,
                        workoutStartMs: workoutStart,
                        workoutEndMs: workoutEnd,
                        zoneSetup: zoneSetup,
                        activityStartMs: activity.startedAtMs,
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
              if (zoneSetup == null)
                ZoneLockedPrompt(onTap: onOpenSettings)
              else
                ZoneBreakdown(setup: zoneSetup!, times: zoneTimes!),
              const SizedBox(height: 24),
              Text('Heart rate stats', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              HrStatsRow(stats: stats),
              const SizedBox(height: 16),
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
