import 'package:cardio/features/activity/hr_chart.dart';
import 'package:cardio/features/activity/hr_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tap selection shows time of day and bpm', (tester) async {
    final activityStart = DateTime(
      2026,
      1,
      1,
      13,
      44,
      45,
    ).millisecondsSinceEpoch;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: HrChart(
              // Samples every 5 s (within _maxSampleGapMs) ramping 120->150,
              // so a tap mid-chart interpolates a real value rather than
              // landing in a broken gap.
              points: [
                for (var s = 0; s <= 12; s++)
                  HrChartPoint(tMs: s * 5000, hr: 120 + s * 25 ~/ 10),
              ],
              axis: HrAxisRange.forStats(minHr: 120, maxHr: 150),
              activityStartMs: activityStart,
            ),
          ),
        ),
      ),
    );

    final chartTopLeft = tester.getTopLeft(find.byType(HrChart));
    await tester.tapAt(chartTopLeft + const Offset(164, 90));
    await tester.pump();

    expect(find.text('13:45'), findsOneWidget);
    expect(find.text('135 bpm'), findsOneWidget);

    final label = find.ancestor(
      of: find.text('135 bpm'),
      matching: find.byType(DecoratedBox),
    );
    final labelRect = tester.getRect(label);
    expect(labelRect.bottom, closeTo(chartTopLeft.dy + 182, 0.1));

    await tester.drag(label, const Offset(60, 0));
    await tester.pump();

    expect(find.text('135 bpm'), findsNothing);
    final updatedBpm = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .singleWhere((text) => text.endsWith(' bpm'));
    final movedLabel = find.ancestor(
      of: find.text(updatedBpm),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getTopLeft(movedLabel).dx, greaterThan(labelRect.left));
  });

  Future<Offset> pumpRampChart(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: HrChart(
              // 0..60 s ramping 120 -> 150 bpm, so the edges read 120 and 150.
              points: [
                for (var s = 0; s <= 12; s++)
                  HrChartPoint(tMs: s * 5000, hr: 120 + s * 25 ~/ 10),
              ],
              axis: HrAxisRange.forStats(minHr: 120, maxHr: 150),
            ),
          ),
        ),
      ),
    );
    final chartTopLeft = tester.getTopLeft(find.byType(HrChart));
    await tester.tapAt(chartTopLeft + const Offset(164, 90));
    await tester.pump();
    expect(find.text('135 bpm'), findsOneWidget);
    return chartTopLeft;
  }

  testWidgets('dragging the label scrubs all the way to the plot edge', (
    tester,
  ) async {
    await pumpRampChart(tester);
    final label = find.ancestor(
      of: find.text('135 bpm'),
      matching: find.byType(DecoratedBox),
    );

    // Past the right edge: the label stops at the edge but the cursor reaches
    // the last sample.
    await tester.drag(label, const Offset(250, 0));
    await tester.pump();
    expect(find.text('150 bpm'), findsOneWidget);
  });

  testWidgets('dragging the cursor line scrubs to the plot edge', (
    tester,
  ) async {
    final chartTopLeft = await pumpRampChart(tester);

    // Grab the line above the bottom-anchored label.
    await tester.dragFrom(
      chartTopLeft + const Offset(164, 40),
      const Offset(-250, 0),
    );
    await tester.pump();
    expect(find.text('120 bpm'), findsOneWidget);
  });
}
