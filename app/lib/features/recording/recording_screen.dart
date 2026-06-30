import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/hr/hr_source.dart';
import '../../core/zones/zone_times.dart';
import '../../core/zones/zones.dart';
import '../activity/hr_chart.dart';
import '../activity/hr_stats.dart';
import '../activity/hr_stats_row.dart';
import '../activity/zone_breakdown.dart';
import 'recording_controller.dart';
import 'activity_meta_fields.dart';

const int _liveWindowMs = 15 * 60 * 1000;

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key, required this.activityId});

  final int activityId;

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  String _formatSignalAge(Duration d) {
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  String _signalTitle(DeviceRecordingState device) {
    return switch (device.sourceStatus) {
      HrSourceStatusKind.reconnecting => 'Reconnecting to strap',
      HrSourceStatusKind.disconnected => 'Heart-rate signal lost',
      HrSourceStatusKind.disposed => 'Heart-rate source closed',
      HrSourceStatusKind.connected => 'Heart-rate signal connected',
    };
  }

  String _signalSubtitle(DeviceRecordingState device, DateTime now) {
    final attempt = device.reconnectAttempt;
    final age = _formatSignalAge(device.sourceStatusAge(now));
    if (device.sourceStatus == HrSourceStatusKind.reconnecting) {
      return attempt == null
          ? 'Signal missing for $age'
          : 'Attempt $attempt; signal missing for $age';
    }
    final message = device.sourceStatusMessage;
    return message == null ? 'Signal missing for $age' : '$message; $age ago';
  }

  Future<void> _onStop(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop recording?'),
        content: const Text('This ends the workout and saves it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep recording'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final activityId = widget.activityId;
    await ref.read(recordingControllerProvider(activityId).notifier).stop();
    if (!context.mounted) return;
    ref.read(activeRecordingIdProvider.notifier).state = null;
    context.go('/activity/$activityId');
  }

  @override
  Widget build(BuildContext context) {
    final activityId = widget.activityId;
    final state = ref.watch(recordingControllerProvider(activityId));
    final athlete = ref.watch(defaultAthleteProvider).valueOrNull;
    final zoneSetup = zoneSetupFor(
      maxHr: athlete?.maxHeartrate,
      restingHr: athlete?.restingHeartrate,
    );
    final multi = state.devices.length > 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(multi ? 'Recording' : state.primary.deviceName),
        automaticallyImplyLeading: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final chartHeight = (constraints.maxHeight * 0.36).clamp(220.0, 320.0);
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: multi
                      ? _buildMulti(context, state, zoneSetup, chartHeight)
                      : _buildSingle(context, state, zoneSetup, chartHeight),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- Single-device layout (unchanged hero view) --------------------------

  Widget _buildSingle(
    BuildContext context,
    RecordingState state,
    ZoneSetup? zoneSetup,
    double chartHeight,
  ) {
    final activityId = widget.activityId;
    final device = state.primary;
    final samples = ref.watch(samplesProvider(activityId)).valueOrNull ?? [];
    final scheme = Theme.of(context).colorScheme;
    final bpmText = device.currentBpm?.toString() ?? '--';
    final currentZone = zoneSetup?.zoneFor(device.currentBpm);
    final bpmColor = currentZone?.color ?? scheme.primary;

    final stats = HrStats.fromHeartRates(samples.map((r) => r.hr));
    final axis = HrAxisRange.forStats(minHr: stats.min, maxHr: stats.max);
    final points = samples
        .map((r) => HrChartPoint(tMs: r.tMs, hr: r.hr))
        .toList();
    final zoneTimes = zoneSetup == null
        ? null
        : computeZoneTimes(samples, zoneSetup);
    final latestMs = points.isEmpty ? 0 : points.last.tMs;
    final firstMs = points.isEmpty ? 0 : points.first.tMs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              bpmText,
              style: TextStyle(
                fontSize: 88,
                fontWeight: FontWeight.w600,
                color: bpmColor,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Text('bpm', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        Center(
          child: Text(
            _formatElapsed(state.elapsed),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        if (device.sourceStatus != HrSourceStatusKind.connected)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _SignalStatusBanner(
              title: _signalTitle(device),
              subtitle: _signalSubtitle(device, state.now),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          height: chartHeight,
          child: TrailingZoomableHrChart(
            points: points,
            axis: axis,
            fullStartMs: firstMs,
            fullEndMs: latestMs,
            initialSpanMs: _liveWindowMs,
            lineColor: scheme.primary,
            zoneSetup: zoneSetup,
            activityStartMs: state.startedAt.millisecondsSinceEpoch,
          ),
        ),
        const SizedBox(height: 16),
        HrStatsRow(stats: stats),
        if (zoneSetup != null) ...[
          const SizedBox(height: 24),
          ZoneBreakdown(setup: zoneSetup, times: zoneTimes!),
        ],
        const SizedBox(height: 16),
        _stopButton(context, state),
        const SizedBox(height: 24),
        // The field sits low in the scroll view, so open the sport-type overlay
        // upward to clear the keyboard.
        ActivityMetaFields(
          activityId: activityId,
          sportTypeOpenDirection: OptionsViewOpenDirection.up,
        ),
      ],
    );
  }

  // ---- Multi-device layout (per-device blocks + shared chart) --------------

  Widget _buildMulti(
    BuildContext context,
    RecordingState state,
    ZoneSetup? zoneSetup,
    double chartHeight,
  ) {
    final activityId = widget.activityId;
    final scheme = Theme.of(context).colorScheme;
    final allSeries = ref.watch(hrSeriesProvider(activityId)).valueOrNull ?? [];
    final samplesBySet = {for (final s in allSeries) s.setId: s.samples};

    // One palette color per device, keyed by set id so the device block dot and
    // its chart line always match.
    final colorForSet = <int, Color>{
      for (var i = 0; i < state.devices.length; i++)
        state.devices[i].setId: hrSeriesColor(i),
    };

    final chartSeries = [
      for (final device in state.devices)
        HrChartSeries(
          points: [
            for (final r in samplesBySet[device.setId] ?? const [])
              HrChartPoint(tMs: r.tMs, hr: r.hr),
          ],
          color: colorForSet[device.setId]!,
          label: device.deviceName,
        ),
    ];
    final allHr = [
      for (final s in allSeries) ...s.samples.map((r) => r.hr),
    ];
    final stats = HrStats.fromHeartRates(allHr);
    final axis = HrAxisRange.forStats(minHr: stats.min, maxHr: stats.max);
    final allTs = [for (final s in allSeries) ...s.samples.map((r) => r.tMs)];
    final firstMs = allTs.isEmpty ? 0 : allTs.reduce((a, b) => a < b ? a : b);
    final latestMs = allTs.isEmpty ? 0 : allTs.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            _formatElapsed(state.elapsed),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 16),
        for (final device in state.devices) ...[
          _DeviceBlock(
            color: colorForSet[device.setId]!,
            device: device,
            samples: samplesBySet[device.setId] ?? const [],
            zoneSetup: zoneSetup,
            now: state.now,
            signalTitle: _signalTitle(device),
            signalSubtitle: _signalSubtitle(device, state.now),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: chartHeight,
          child: chartSeries.every((s) => s.points.isEmpty)
              ? Center(
                  child: Text(
                    'Waiting for heart-rate data…',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : TrailingZoomableHrChart(
                  series: chartSeries,
                  axis: axis,
                  fullStartMs: firstMs,
                  fullEndMs: latestMs,
                  initialSpanMs: _liveWindowMs,
                  activityStartMs: state.startedAt.millisecondsSinceEpoch,
                ),
        ),
        const SizedBox(height: 16),
        _stopButton(context, state),
        const SizedBox(height: 24),
        ActivityMetaFields(
          activityId: activityId,
          sportTypeOpenDirection: OptionsViewOpenDirection.up,
        ),
      ],
    );
  }

  Widget _stopButton(BuildContext context, RecordingState state) {
    return FilledButton.tonalIcon(
      onPressed: state.stopped ? null : () => _onStop(context),
      icon: const Icon(Icons.stop_circle_outlined),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          state.stopped ? 'Stopping…' : 'Stop',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

/// One device's live readout in the multi-device layout: a color swatch tying it
/// to its chart line, current BPM in zone color, signal status, and its own
/// stats + zone breakdown.
class _DeviceBlock extends StatelessWidget {
  const _DeviceBlock({
    required this.color,
    required this.device,
    required this.samples,
    required this.zoneSetup,
    required this.now,
    required this.signalTitle,
    required this.signalSubtitle,
  });

  final Color color;
  final DeviceRecordingState device;
  final List<HrSampleRow> samples;
  final ZoneSetup? zoneSetup;
  final DateTime now;
  final String signalTitle;
  final String signalSubtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = HrStats.fromHeartRates(samples.map((r) => r.hr));
    final zoneTimes = zoneSetup == null
        ? null
        : computeZoneTimes(samples, zoneSetup!);
    final bpm = device.currentBpm;
    final bpmColor = zoneSetup?.zoneFor(bpm)?.color ?? scheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device.deviceName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  bpm?.toString() ?? '--',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: bpmColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text('bpm', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (device.sourceStatus != HrSourceStatusKind.connected) ...[
              const SizedBox(height: 12),
              _SignalStatusBanner(title: signalTitle, subtitle: signalSubtitle),
            ],
            const SizedBox(height: 12),
            HrStatsRow(stats: stats),
            if (zoneSetup != null) ...[
              const SizedBox(height: 16),
              ZoneBreakdown(setup: zoneSetup!, times: zoneTimes!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignalStatusBanner extends StatelessWidget {
  const _SignalStatusBanner({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.bluetooth_searching, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
