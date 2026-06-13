import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/providers.dart';
import '../../core/hr/hr_source.dart';
import '../../core/zones/zone_times.dart';
import '../../core/zones/zones.dart';
import '../activity/hr_chart.dart';
import '../activity/hr_stats.dart';
import '../activity/hr_stats_row.dart';
import '../activity/zone_breakdown.dart';
import 'recording_controller.dart';

const int _liveWindowMs = 15 * 60 * 1000;

class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key, required this.activityId});

  final int activityId;

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

  String _signalTitle(RecordingState state) {
    return switch (state.sourceStatus) {
      HrSourceStatusKind.reconnecting => 'Reconnecting to strap',
      HrSourceStatusKind.disconnected => 'Heart-rate signal lost',
      HrSourceStatusKind.disposed => 'Heart-rate source closed',
      HrSourceStatusKind.connected => 'Heart-rate signal connected',
    };
  }

  String _signalSubtitle(RecordingState state) {
    final attempt = state.reconnectAttempt;
    final age = _formatSignalAge(state.sourceStatusAge);
    if (state.sourceStatus == HrSourceStatusKind.reconnecting) {
      return attempt == null
          ? 'Signal missing for $age'
          : 'Attempt $attempt; signal missing for $age';
    }
    final message = state.sourceStatusMessage;
    return message == null ? 'Signal missing for $age' : '$message; $age ago';
  }

  Future<void> _onStop(BuildContext context, WidgetRef ref) async {
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
    await ref.read(recordingControllerProvider(activityId).notifier).stop();
    if (!context.mounted) return;
    context.go('/activity/$activityId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider(activityId));
    final samples = ref.watch(samplesProvider(activityId)).valueOrNull ?? [];
    final athlete = ref.watch(defaultAthleteProvider).valueOrNull;
    final zoneSetup = zoneSetupFor(
      maxHr: athlete?.maxHeartrate,
      restingHr: athlete?.restingHeartrate,
    );
    final scheme = Theme.of(context).colorScheme;
    final bpmText = state.currentBpm?.toString() ?? '--';
    final currentZone = zoneSetup?.zoneFor(state.currentBpm);
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.deviceName),
          automaticallyImplyLeading: false,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final chartHeight = (constraints.maxHeight * 0.36).clamp(
              220.0,
              320.0,
            );

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
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
                            Text(
                              'bpm',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        Center(
                          child: Text(
                            _formatElapsed(state.elapsed),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        if (state.sourceStatus != HrSourceStatusKind.connected)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _SignalStatusBanner(
                              title: _signalTitle(state),
                              subtitle: _signalSubtitle(state),
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
                          ),
                        ),
                        const SizedBox(height: 16),
                        HrStatsRow(stats: stats),
                        if (zoneSetup != null) ...[
                          const SizedBox(height: 24),
                          ZoneBreakdown(setup: zoneSetup, times: zoneTimes!),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: state.stopped
                              ? null
                              : () => _onStop(context, ref),
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              state.stopped ? 'Stopping…' : 'Stop',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
