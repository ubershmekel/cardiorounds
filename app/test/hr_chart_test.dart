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
  });
}
