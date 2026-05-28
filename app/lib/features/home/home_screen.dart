import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';

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
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodyMedium),
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

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.list});

  final List<Activity> list;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Start recording'),
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

class _ActivityRow extends StatelessWidget {
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
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle =
        '${_formatDate(activity.startedAtMs)} · ${_formatDuration(activity.durationMs)}';
    return ListTile(
      title: Text(activity.name ?? activity.sportType ?? 'Workout'),
      subtitle: Text(subtitle),
      onTap: () => context.go('/activity/${activity.id}'),
    );
  }
}
