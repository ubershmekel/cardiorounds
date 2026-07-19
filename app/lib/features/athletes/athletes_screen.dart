import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import 'athlete_profile_fields.dart';

/// Tucked-away athlete management, reached from Settings → Advanced → Manage
/// athletes. Edits athletes one at a time (a pager, not a list): previous / next
/// to move between them, ＋ to create a blank one, and a per-athlete delete that
/// is disabled at the last remaining athlete. Fields auto-save; see
/// [AthleteProfileFields] and docs/design/multi-athlete.md.
class AthletesScreen extends ConsumerStatefulWidget {
  const AthletesScreen({super.key, this.initialAthleteId});

  final int? initialAthleteId;

  @override
  ConsumerState<AthletesScreen> createState() => _AthletesScreenState();
}

class _AthletesScreenState extends ConsumerState<AthletesScreen> {
  // Track the shown athlete by id, not list index, so it survives the list
  // stream re-emitting after a create or delete.
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialAthleteId;
  }

  @override
  Widget build(BuildContext context) {
    final athletes = ref.watch(athletesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Athletes')),
      body: athletes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load athletes: $e')),
        data: (list) {
          // ensureDefaultAthlete guarantees at least one row; guard anyway.
          if (list.isEmpty) {
            return const Center(child: Text('No athletes'));
          }
          var index = list.indexWhere((a) => a.id == _selectedId);
          if (index < 0) {
            index = 0; // first open, or the selected one was deleted
          }
          final athlete = list[index];
          return _AthletePager(
            athlete: athlete,
            index: index,
            total: list.length,
            onPrevious: index > 0
                ? () => setState(() => _selectedId = list[index - 1].id)
                : null,
            onNext: index < list.length - 1
                ? () => setState(() => _selectedId = list[index + 1].id)
                : null,
            onCreate: _createAthlete,
            onDelete: list.length > 1
                ? () => _confirmDelete(athlete, index, list)
                : null,
          );
        },
      ),
    );
  }

  Future<void> _createAthlete() async {
    final created = await ref.read(databaseProvider).insertAthlete();
    if (!mounted) return;
    setState(() => _selectedId = created.id);
  }

  Future<void> _confirmDelete(
    Athlete athlete,
    int index,
    List<Athlete> list,
  ) async {
    final impact = await ref.read(
      athleteDeletionImpactProvider(athlete.id).future,
    );
    if (!mounted) return;

    final theme = Theme.of(context);
    final label = athlete.name.trim().isEmpty
        ? 'this athlete'
        : athlete.name.trim();
    // Three cases: never recorded (no data lost, gentle), shared streams only
    // (those streams go but the sessions survive), and solo workouts deleted
    // outright. Only the two lossy cases get the error-styled button.
    final String message;
    final bool lossy;
    if (impact.streams == 0) {
      message =
          'This removes $label. They have no recorded heart-rate data, so '
          'nothing else is lost. This can\'t be undone.';
      lossy = false;
    } else if (impact.soloWorkouts == 0) {
      message =
          'This removes $label and their heart-rate streams from shared '
          'sessions. Those sessions keep their other streams. This can\'t be '
          'undone.';
      lossy = true;
    } else {
      final workouts = impact.soloWorkouts == 1
          ? '1 workout'
          : '${impact.soloWorkouts} workouts';
      message =
          'This permanently deletes $workouts recorded solely from $label and '
          'all their heart-rate data. Shared sessions keep their other streams. '
          'This can\'t be undone.';
      lossy = true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $label?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: lossy
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Land on an adjacent athlete once this one is gone.
    final neighbor = list[index > 0 ? index - 1 : index + 1];
    await ref.read(databaseProvider).deleteAthlete(athlete.id);
    if (!mounted) return;
    setState(() => _selectedId = neighbor.id);
  }
}

class _AthletePager extends StatelessWidget {
  const _AthletePager({
    required this.athlete,
    required this.index,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.onCreate,
    required this.onDelete,
  });

  final Athlete athlete;
  final int index;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onCreate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous athlete',
            ),
            Expanded(
              child: Text(
                '${index + 1} of $total',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next athlete',
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Unkeyed on purpose: the fields re-seed via didUpdateWidget when the
        // athlete id changes, flushing the leaving athlete's edits first.
        AthleteProfileFields(athlete: athlete),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add athlete'),
          onPressed: onCreate,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete athlete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          // Disabled at the last athlete: the app requires at least one.
          onPressed: onDelete,
        ),
      ],
    );
  }
}
