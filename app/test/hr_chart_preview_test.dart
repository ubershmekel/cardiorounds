@Tags(['preview'])
library;

import 'dart:io';

import 'package:cardio/features/activity/hr_chart.dart';
import 'package:cardio/features/activity/hr_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Renders the chart into PNGs under test/previews/ so the gap-breaking line
// algorithm can be eyeballed. These images are gitignored, review-only
// previews (not committed golden baselines); the test is tagged `preview` so
// the normal suite (`task test`) skips it. Regenerate with `task previews`.

// Arial ships on both Windows and macOS; first match wins. If none is found
// the labels just fall back to the Ahem test-font boxes — still fine for
// reviewing the line itself.
const _fontCandidates = [
  '/System/Library/Fonts/Supplemental/Arial.ttf', // macOS
  '/Library/Fonts/Arial.ttf', // macOS (older)
  r'C:\Windows\Fonts\arial.ttf', // Windows
];

/// A continuous 1 Hz heart-rate ramp, no gaps.
List<HrChartPoint> _continuous() => [
  for (var s = 0; s <= 120; s++)
    HrChartPoint(tMs: s * 1000, hr: 120 + (s % 40)),
];

/// Same data but with a 30 s hole (no samples) in the middle — the kind of
/// iOS background-suspension gap the line should break across rather than
/// interpolate as a flat slope.
List<HrChartPoint> _withGap() => [
  for (final p in _continuous())
    if (p.tMs < 40000 || p.tMs > 70000) p,
];

Future<void> _pumpAndCapture(
  WidgetTester tester,
  String name,
  Widget chart,
) async {
  await tester.pumpWidget(
    MaterialApp(
      // Use the loaded Arial so axis labels render as real digits rather than
      // the Ahem test-font boxes.
      theme: ThemeData(fontFamily: 'Arial'),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, height: 220, child: chart),
        ),
      ),
    ),
  );
  await expectLater(
    find.byType(HrChart),
    matchesGoldenFile('previews/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    for (final path in _fontCandidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final loader = FontLoader('Arial')
        ..addFont(
          file.readAsBytes().then((bytes) => bytes.buffer.asByteData()),
        );
      await loader.load();
      break;
    }
  });

  final axis = HrAxisRange.forStats(minHr: 110, maxHr: 165);

  testWidgets('continuous line', (tester) async {
    await _pumpAndCapture(
      tester,
      'hr_chart_continuous',
      HrChart(points: _continuous(), axis: axis),
    );
  });

  testWidgets('line breaks across a long gap', (tester) async {
    await _pumpAndCapture(
      tester,
      'hr_chart_with_gap',
      HrChart(points: _withGap(), axis: axis),
    );
  });
}
