import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/zones/zones.dart';
import '../activity/activity_duration.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(activitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cardio Rounds')),
      body: activities.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load activities: $e')),
        data: (list) =>
            list.isEmpty ? const _EmptyState() : _ActivityList(list: list),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HeroCard(
            icon: Icons.fiber_manual_record,
            iconColor: scheme.error,
            title: 'Start recording',
            subtitle:
                'Connect a heart-rate strap and start your first workout.',
            onTap: () => context.go('/record'),
          ),
          const SizedBox(height: 16),
          _HeroCard(
            icon: Icons.person_outline,
            iconColor: scheme.primary,
            title: 'Set up your profile',
            subtitle: 'Name, max HR, and resting HR for zone analysis.',
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 36, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityList extends ConsumerWidget {
  const _ActivityList({required this.list});

  final List<Activity> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref.watch(activeRecordingIdProvider) != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.fiber_manual_record),
              label: Text(isRecording ? 'Recording' : 'Start recording'),
              // /record redirects to the live screen if a recording is active.
              onPressed: () => context.go('/record'),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) => _ActivityRow(activity: list[i]),
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  const _ActivityRow({required this.activity});

  final Activity activity;

  String _formatDuration(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final secs = s % 60;
    if (m == 0) return '${secs}s';
    return '${m}m ${secs.toString().padLeft(2, '0')}s';
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $hh:$min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRecordingId = ref.watch(activeRecordingIdProvider);
    final isRecording = activity.id == activeRecordingId;
    final marker = ref.watch(workoutMarkerProvider(activity.id)).valueOrNull;
    final athlete = ref.watch(defaultAthleteProvider).valueOrNull;
    final zoneSetup = zoneSetupFor(
      maxHr: athlete?.maxHeartrate,
      restingHr: athlete?.restingHeartrate,
    );
    final durationMs = effectiveActivityDurationMs(
      activityDurationMs: activity.durationMs,
      workoutStartMs: marker?.tMs,
      workoutDurationMs: marker?.durationMs,
    );
    final dateStr = _formatDate(activity.startedAtMs);
    final subtitle = isRecording
        ? dateStr
        : '$dateStr · ${_formatDuration(durationMs)}';
    final shapeBlocks = zoneSetup != null && !isRecording
        ? _buildShapeBlocks(zoneSetup)
        : null;
    return ListTile(
      title: Text(activity.name ?? activity.sportType ?? 'Workout'),
      subtitle: Text(subtitle),
      trailing: isRecording ? const _RecordingChip() : shapeBlocks,
      onTap: () => isRecording
          ? context.go('/record/recording/${activity.id}')
          : context.push('/activity/${activity.id}'),
    );
  }

  Widget? _buildShapeBlocks(ZoneSetup zoneSetup) {
    final vals = [activity.shapeStart, activity.shapeMid, activity.shapeEnd];
    if (vals.every((v) => v == null)) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: vals.map((bpm) {
        final zone = bpm != null ? zoneSetup.zoneFor(bpm) : null;
        return Container(
          width: 10,
          height: 28,
          decoration: BoxDecoration(
            color:
                zone?.color.withValues(alpha: 0.85) ??
                const Color(0xFF9090A8).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }).toList(),
    );
  }
}

class _RecordingChip extends StatelessWidget {
  const _RecordingChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Icon(Icons.fiber_manual_record, size: 10, color: scheme.error),
        Text(
          'Live',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
