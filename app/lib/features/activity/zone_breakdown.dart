import 'package:flutter/material.dart';

import '../../core/zones/zone_times.dart';
import '../../core/zones/zones.dart';

class ZoneBreakdown extends StatelessWidget {
  const ZoneBreakdown({super.key, required this.times, required this.setup});

  final ZoneTimes times;
  final ZoneSetup setup;

  String _fmt(int ms) {
    final totalSec = ms ~/ 1000;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = times.knownMs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Time in zone', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final z in Zone.values)
                    if (times.perZone[z]! > 0)
                      Expanded(
                        flex: times.perZone[z]!,
                        child: Container(color: z.color),
                      ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        for (final z in Zone.values)
          _ZoneRow(
            zone: z,
            ms: times.perZone[z] ?? 0,
            totalMs: total,
            lowerBpm: setup.lowerBpmFor(z),
            fmt: _fmt,
          ),
      ],
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.zone,
    required this.ms,
    required this.totalMs,
    required this.lowerBpm,
    required this.fmt,
  });

  final Zone zone;
  final int ms;
  final int totalMs;
  final int lowerBpm;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = totalMs == 0 ? 0 : (ms * 100 / totalMs).round();
    final muted = ms == 0;
    final color = muted ? theme.colorScheme.onSurfaceVariant : null;
    final subtle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: muted ? zone.color.withValues(alpha: 0.3) : zone.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              zone.shortLabel,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  zone.name,
                  style: theme.textTheme.bodyMedium?.copyWith(color: color),
                ),
                const SizedBox(width: 6),
                Text('($lowerBpm+ bpm)', style: subtle),
              ],
            ),
          ),
          Text(
            fmt(ms),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              ms == 0 ? '—' : '$percent%',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class ZoneLockedPrompt extends StatelessWidget {
  const ZoneLockedPrompt({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: const Text('Zone breakdown is locked'),
        subtitle: const Text(
          'Set both max HR and resting HR in Settings to see time per zone.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
