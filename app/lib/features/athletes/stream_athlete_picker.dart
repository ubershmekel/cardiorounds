import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';

/// A display label for an athlete in a picker: their name, or a positional
/// "Athlete N" fallback when the name is blank (multiple people can share the
/// app before anyone bothers naming themselves).
String athleteLabel(Athlete athlete, int index) {
  final name = athlete.name.trim();
  return name.isEmpty ? 'Athlete ${index + 1}' : name;
}

/// Per-stream "who wore this strap" dropdown. Writes the chosen athlete onto the
/// stream's `athlete_id` (or clears it). Renders **nothing** until more than one
/// athlete exists, so a solo user never sees attribution UI. See
/// docs/design/multi-athlete.md.
class StreamAthletePicker extends ConsumerWidget {
  const StreamAthletePicker({super.key, required this.setId});

  final int setId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athletes = ref.watch(athletesProvider).valueOrNull ?? const [];
    if (athletes.length < 2) return const SizedBox.shrink();

    final current = ref.watch(streamAthleteProvider(setId)).valueOrNull;
    // Guard against a stale id whose athlete was deleted: fall back to null so
    // the dropdown has a valid selection rather than asserting.
    final value = athletes.any((a) => a.id == current) ? current : null;

    return DropdownButton<int?>(
      value: value,
      isDense: true,
      icon: const Icon(Icons.expand_more, size: 20),
      underline: const SizedBox.shrink(),
      items: [
        const DropdownMenuItem(value: null, child: Text('Unassigned')),
        for (var i = 0; i < athletes.length; i++)
          DropdownMenuItem(
            value: athletes[i].id,
            child: Text(athleteLabel(athletes[i], i)),
          ),
      ],
      onChanged: (id) => ref
          .read(databaseProvider)
          .setStreamAthlete(setId: setId, athleteId: id),
    );
  }
}

/// A device-name + attribution-picker row for the **single-stream** case, where
/// there is no per-device block to hang the picker on. Placed where the
/// multi-stream blocks sit so the control doesn't jump when a second strap
/// appears. Like [StreamAthletePicker], renders nothing for a solo user.
class StreamAttributionRow extends ConsumerWidget {
  const StreamAttributionRow({
    super.key,
    required this.setId,
    required this.deviceName,
  });

  final int setId;
  final String deviceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athletes = ref.watch(athletesProvider).valueOrNull ?? const [];
    // Collapse to nothing (including surrounding spacing) for a solo user, so
    // the row can be dropped in unconditionally without leaving a gap.
    if (athletes.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.favorite_border,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              deviceName,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          StreamAthletePicker(setId: setId),
        ],
      ),
    );
  }
}
