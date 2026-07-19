import 'package:flutter/material.dart';

import 'hr_stats.dart';

/// A compact min / avg / max readout, shared by the recording and review
/// screens.
class HrStatsRow extends StatelessWidget {
  const HrStatsRow({
    super.key,
    required this.stats,
    this.extraStats = const [],
  });

  final HrStats stats;
  final List<Widget> extraStats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(
          label: 'min',
          value: stats.min,
          tooltip: 'Minimum heart rate during the workout',
        ),
        _Stat(
          label: 'avg',
          value: stats.avg,
          tooltip: 'Average heart rate during the workout',
        ),
        _Stat(
          label: 'max',
          value: stats.max,
          tooltip: 'Maximum heart rate during the workout',
        ),
        ...extraStats,
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.tooltip});

  final String label;
  final int? value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Column(
      children: [
        Text(
          value?.toString() ?? '--',
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
