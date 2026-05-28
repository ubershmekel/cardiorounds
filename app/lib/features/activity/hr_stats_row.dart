import 'package:flutter/material.dart';

import 'hr_stats.dart';

/// A compact min / avg / max readout, shared by the recording and review
/// screens.
class HrStatsRow extends StatelessWidget {
  const HrStatsRow({super.key, required this.stats});

  final HrStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Stat(label: 'min', value: stats.min),
        _Stat(label: 'avg', value: stats.avg),
        _Stat(label: 'max', value: stats.max),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value?.toString() ?? '--',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
