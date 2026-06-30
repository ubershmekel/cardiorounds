import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/zones/zones.dart';
import 'hr_stats.dart';

class HrChartPoint {
  const HrChartPoint({required this.tMs, required this.hr});

  final int tMs;
  final int? hr;

  bool get isValidHr => hr != null && hr! > 0;
}

/// One line on a multi-device chart: a device's points drawn in its identity
/// [color], labelled by device name in the legend.
class HrChartSeries {
  const HrChartSeries({
    required this.points,
    required this.color,
    required this.label,
  });

  final List<HrChartPoint> points;
  final Color color;
  final String label;
}

/// Distinct line colors for multi-device charts, assigned by series order. Kept
/// away from the zone palette (zones.dart) since these denote device identity,
/// not effort. Cycles if there are more devices than colors.
const List<Color> kHrSeriesPalette = [
  Color(0xFF42A5F5), // blue
  Color(0xFFFFA726), // orange
  Color(0xFF66BB6A), // green
  Color(0xFFAB47BC), // purple
  Color(0xFF26C6DA), // cyan
  Color(0xFFEC407A), // pink
];

Color hrSeriesColor(int index) =>
    kHrSeriesPalette[index % kHrSeriesPalette.length];

/// A legend tying each device's name to its chart line color. Used on the
/// activity review screen; the live recording screen's per-device rows serve the
/// same purpose.
class HrChartLegend extends StatelessWidget {
  const HrChartLegend({super.key, required this.series});

  final List<HrChartSeries> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final s in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(s.label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}

// Gaps longer than this between consecutive samples break the chart line,
// so iOS background-suspension periods don't appear as flat interpolated lines.
const int _maxSampleGapMs = 10000;

const double _leftGutter = 36;
const double _bottomGutter = 18;
const double _topPad = 8;
const double _rightPad = 8;
const double _handleHitSlop = 28;
const double _xAxisLabelOffset = 16;

String formatHrChartElapsed(int ms) {
  final totalSec = (ms / 1000).round();
  final m = totalSec ~/ 60;
  final s = totalSec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatHrChartTimeOfDay(int activityStartMs, int tMs) {
  final time = DateTime.fromMillisecondsSinceEpoch(activityStartMs + tMs);
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

enum HrActiveHandle { start, end }

/// Maps between heart-rate sample space (elapsed ms, BPM) and the chart's pixel
/// space. Shared by the painter and the drag handling so they always agree.
class HrChartGeometry {
  HrChartGeometry({
    required this.size,
    required this.startMs,
    required this.endMs,
    required this.axis,
  });

  final Size size;
  final int startMs;
  final int endMs;
  final HrAxisRange axis;

  double get plotLeft => _leftGutter;
  double get plotTop => _topPad;
  double get plotRight => size.width - _rightPad;
  double get plotBottom => size.height - _bottomGutter;
  double get plotWidth => plotRight - plotLeft;
  double get plotHeight => plotBottom - plotTop;

  int get _spanMs => endMs == startMs ? 1 : endMs - startMs;

  double xForT(int tMs) => plotLeft + (tMs - startMs) / _spanMs * plotWidth;

  int tForX(double x) {
    final t = startMs + ((x - plotLeft) / plotWidth) * _spanMs;
    return t.round().clamp(startMs, endMs);
  }

  double yForHr(int hr) =>
      plotTop + (1 - (hr - axis.minY) / axis.span) * plotHeight;
}

/// A heart-rate line chart: elapsed time on X, BPM on Y. The line breaks at
/// NULL samples so signal gaps are visible. Zone coloring arrives later; for
/// now the line is a single neutral color.
///
/// When [workoutStartMs]/[workoutEndMs] are set, the chart dims the region
/// outside that effort window. See [EditableHrChart] for the draggable variant.
class HrChart extends StatelessWidget {
  const HrChart({
    super.key,
    this.points = const [],
    required this.axis,
    this.series,
    this.windowStartMs,
    this.windowEndMs,
    this.lineColor,
    this.workoutStartMs,
    this.workoutEndMs,
    this.showHandles = false,
    this.activeHandle,
    this.zoneSetup,
    this.activityStartMs,
  });

  final List<HrChartPoint> points;
  final HrAxisRange axis;

  /// When non-null and non-empty, the chart draws one line per series in its own
  /// color (zone coloring and tap inspection are disabled). When null, the
  /// single-line [points] behavior applies.
  final List<HrChartSeries>? series;
  final int? windowStartMs;
  final int? windowEndMs;
  final Color? lineColor;
  final int? workoutStartMs;
  final int? workoutEndMs;
  final bool showHandles;
  final HrActiveHandle? activeHandle;
  final int? activityStartMs;

  /// When provided, each line segment is colored by the zone of its starting
  /// sample. When null, the whole line uses [lineColor] (or the theme primary).
  final ZoneSetup? zoneSetup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final series = this.series;
    final hasSeries = series != null && series.isNotEmpty;

    if (!hasSeries && points.isEmpty) {
      return Center(
        child: Text(
          'No heart-rate data',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Default window spans all data; for multi-series, across every line.
    final allPoints = hasSeries
        ? [for (final s in series) ...s.points]
        : points;
    final start =
        windowStartMs ??
        allPoints.map((p) => p.tMs).reduce((a, b) => a < b ? a : b);
    final end =
        windowEndMs ??
        allPoints.map((p) => p.tMs).reduce((a, b) => a > b ? a : b);

    return _SelectableHrChart(
      points: points,
      series: series,
      axis: axis,
      startMs: start,
      endMs: end == start ? start + 1 : end,
      lineColor: lineColor ?? scheme.primary,
      gridColor: scheme.outlineVariant,
      scrimColor: scheme.surface.withValues(alpha: 0.66),
      handleColor: scheme.primary,
      labelBackgroundColor: scheme.surfaceContainerHighest.withValues(
        alpha: 0.92,
      ),
      labelStyle: theme.textTheme.labelSmall!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      workoutStartMs: workoutStartMs,
      workoutEndMs: workoutEndMs,
      showHandles: showHandles,
      activeHandle: activeHandle,
      zoneSetup: zoneSetup,
      activityStartMs: activityStartMs,
    );
  }
}

/// One device's reading at the selected timestamp, drawn as a dot in its line
/// color and listed in the tap label.
class HrSelectionValue {
  const HrSelectionValue({required this.hr, required this.color});

  final int hr;
  final Color color;
}

class HrChartSelection {
  const HrChartSelection({required this.tMs, required this.values});

  final int tMs;
  // One per line that has data at [tMs]; length 1 for a single-device chart.
  final List<HrSelectionValue> values;
}

class _SelectableHrChart extends StatefulWidget {
  const _SelectableHrChart({
    required this.points,
    this.series,
    required this.axis,
    required this.startMs,
    required this.endMs,
    required this.lineColor,
    required this.gridColor,
    required this.scrimColor,
    required this.handleColor,
    required this.labelBackgroundColor,
    required this.labelStyle,
    this.workoutStartMs,
    this.workoutEndMs,
    this.showHandles = false,
    this.activeHandle,
    this.zoneSetup,
    this.activityStartMs,
  });

  final List<HrChartPoint> points;
  final List<HrChartSeries>? series;
  final HrAxisRange axis;
  final int startMs;
  final int endMs;
  final Color lineColor;
  final Color gridColor;
  final Color scrimColor;
  final Color handleColor;
  final Color labelBackgroundColor;
  final TextStyle labelStyle;
  final int? workoutStartMs;
  final int? workoutEndMs;
  final bool showHandles;
  final HrActiveHandle? activeHandle;
  final ZoneSetup? zoneSetup;
  final int? activityStartMs;

  @override
  State<_SelectableHrChart> createState() => _SelectableHrChartState();
}

class _SelectableHrChartState extends State<_SelectableHrChart> {
  static const double _selectionLabelWidth = 82;

  HrChartSelection? _selection;

  @override
  void didUpdateWidget(_SelectableHrChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selection = _selection;
    if (selection == null) return;
    final values = _valuesAtT(selection.tMs);
    _selection = values.isEmpty
        ? null
        : HrChartSelection(tMs: selection.tMs, values: values);
  }

  void _selectAt(Offset position, Size size) {
    final g = HrChartGeometry(
      size: size,
      startMs: widget.startMs,
      endMs: widget.endMs,
      axis: widget.axis,
    );
    if (g.plotWidth <= 0 || g.plotHeight <= 0) return;
    final plotRect = Rect.fromLTRB(
      g.plotLeft,
      g.plotTop,
      g.plotRight,
      g.plotBottom,
    );
    if (!plotRect.contains(position)) return;

    final tMs = g.tForX(position.dx);
    final values = _valuesAtT(tMs);
    if (values.isEmpty) return;
    setState(() => _selection = HrChartSelection(tMs: tMs, values: values));
  }

  /// The reading of each line at [tMs] (one per device with data there). For a
  /// single-device chart this is at most one value in [widget.lineColor].
  List<HrSelectionValue> _valuesAtT(int tMs) {
    final series = widget.series;
    if (series != null) {
      return [
        for (final s in series)
          if (_hrAtTForPoints(s.points, tMs) case final hr?)
            HrSelectionValue(hr: hr, color: s.color),
      ];
    }
    final hr = _hrAtTForPoints(widget.points, tMs);
    return hr == null
        ? const []
        : [HrSelectionValue(hr: hr, color: widget.lineColor)];
  }

  int? _hrAtTForPoints(List<HrChartPoint> points, int tMs) {
    if (tMs < widget.startMs || tMs > widget.endMs) return null;

    HrChartPoint? previous;
    for (final point in points) {
      if (point.tMs < widget.startMs || point.tMs > widget.endMs) {
        previous = null;
        continue;
      }

      if (!point.isValidHr) {
        previous = null;
        continue;
      }
      final hr = point.hr!;

      if (point.tMs == tMs) return hr;

      final prev = previous;
      if (prev != null && prev.tMs <= tMs && tMs <= point.tMs) {
        if (point.tMs - prev.tMs > _maxSampleGapMs) {
          previous = point;
          continue;
        }
        if (prev.tMs == point.tMs) return hr;
        final ratio = (tMs - prev.tMs) / (point.tMs - prev.tMs);
        return (prev.hr! + (hr - prev.hr!) * ratio).round();
      }

      previous = point;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final g = HrChartGeometry(
          size: size,
          startMs: widget.startMs,
          endMs: widget.endMs,
          axis: widget.axis,
        );
        final selection = _selection;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _selectAt(details.localPosition, size),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: HrChartPainter(
                    points: widget.points,
                    series: widget.series,
                    axis: widget.axis,
                    startMs: widget.startMs,
                    endMs: widget.endMs,
                    lineColor: widget.lineColor,
                    gridColor: widget.gridColor,
                    scrimColor: widget.scrimColor,
                    handleColor: widget.handleColor,
                    labelStyle: widget.labelStyle,
                    workoutStartMs: widget.workoutStartMs,
                    workoutEndMs: widget.workoutEndMs,
                    showHandles: widget.showHandles,
                    activeHandle: widget.activeHandle,
                    zoneSetup: widget.zoneSetup,
                    selection: selection,
                  ),
                ),
              ),
            ),
            if (selection != null && g.plotWidth > 0)
              _SelectionLabel(
                selection: selection,
                geometry: g,
                backgroundColor: widget.labelBackgroundColor,
                borderColor: widget.gridColor,
                textStyle: widget.labelStyle,
                activityStartMs: widget.activityStartMs,
                onDismissed: () => setState(() => _selection = null),
              ),
          ],
        );
      },
    );
  }
}

class _SelectionLabel extends StatelessWidget {
  const _SelectionLabel({
    required this.selection,
    required this.geometry,
    required this.backgroundColor,
    required this.borderColor,
    required this.textStyle,
    required this.activityStartMs,
    required this.onDismissed,
  });

  final HrChartSelection selection;
  final HrChartGeometry geometry;
  final Color backgroundColor;
  final Color borderColor;
  final TextStyle textStyle;
  final int? activityStartMs;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final availableWidth = geometry.plotWidth;
    final width = availableWidth < _SelectableHrChartState._selectionLabelWidth
        ? availableWidth
        : _SelectableHrChartState._selectionLabelWidth;
    final left = (geometry.xForT(selection.tMs) - width / 2)
        .clamp(geometry.plotLeft, geometry.plotRight - width)
        .toDouble();
    // One row per device BPM plus the timestamp row; grow with device count.
    final height = 22.0 + selection.values.length * 16.0;
    // Only tint per-device BPM when there's more than one to distinguish.
    final multi = selection.values.length > 1;
    // Highest BPM on top, mirroring the lines' vertical order on the chart.
    final values = [...selection.values]..sort((a, b) => b.hr.compareTo(a.hr));

    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismissed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                activityStartMs == null
                    ? formatHrChartElapsed(selection.tMs)
                    : formatHrChartTimeOfDay(activityStartMs!, selection.tMs),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: textStyle,
              ),
              for (final v in values)
                Text(
                  '${v.hr} bpm',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: multi
                      ? textStyle.copyWith(
                          color: v.color,
                          fontWeight: FontWeight.w600,
                        )
                      : textStyle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HrChartPainter extends CustomPainter {
  HrChartPainter({
    required this.points,
    this.series,
    required this.axis,
    required this.startMs,
    required this.endMs,
    required this.lineColor,
    required this.gridColor,
    required this.scrimColor,
    required this.handleColor,
    required this.labelStyle,
    this.workoutStartMs,
    this.workoutEndMs,
    this.showHandles = false,
    this.activeHandle,
    this.zoneSetup,
    this.selection,
  });

  final List<HrChartPoint> points;
  final List<HrChartSeries>? series;
  final HrAxisRange axis;
  final int startMs;
  final int endMs;
  final Color lineColor;
  final Color gridColor;
  final Color scrimColor;
  final Color handleColor;
  final TextStyle labelStyle;
  final int? workoutStartMs;
  final int? workoutEndMs;
  final bool showHandles;
  final HrActiveHandle? activeHandle;
  final ZoneSetup? zoneSetup;
  final HrChartSelection? selection;

  @override
  void paint(Canvas canvas, Size size) {
    final g = HrChartGeometry(
      size: size,
      startMs: startMs,
      endMs: endMs,
      axis: axis,
    );
    if (g.plotWidth <= 0 || g.plotHeight <= 0) return;

    // Subtle horizontal gridlines every 10 bpm, with sparse Y labels.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 0.75;
    final mid = (((axis.minY + axis.maxY) / 2) / 10).round() * 10;
    final labelBpms = {axis.minY, mid, axis.maxY};
    final firstGridBpm = ((axis.minY + 9) ~/ 10) * 10;
    final lastGridBpm = (axis.maxY ~/ 10) * 10;
    for (var bpm = firstGridBpm; bpm <= lastGridBpm; bpm += 10) {
      final y = g.yForHr(bpm);
      canvas.drawLine(Offset(g.plotLeft, y), Offset(g.plotRight, y), gridPaint);
      if (labelBpms.contains(bpm)) {
        _paintLabel(
          canvas,
          '$bpm',
          Offset(g.plotLeft - 4, y),
          alignRight: true,
        );
      }
    }

    // X labels at the window start and end (elapsed mm:ss from recording start).
    _paintLabel(
      canvas,
      formatHrChartElapsed(startMs),
      Offset(g.plotLeft, g.plotBottom + _xAxisLabelOffset),
      alignRight: false,
    );
    _paintLabel(
      canvas,
      formatHrChartElapsed(endMs),
      Offset(g.plotRight, g.plotBottom + _xAxisLabelOffset),
      alignRight: true,
    );

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(g.plotLeft, g.plotTop, g.plotRight, g.plotBottom),
    );
    _paintLine(canvas, g);
    _paintWorkoutWindow(canvas, g);
    _paintSelection(canvas, g);
    canvas.restore();
  }

  void _paintSelection(Canvas canvas, HrChartGeometry g) {
    final s = selection;
    if (s == null || s.tMs < startMs || s.tMs > endMs) return;

    final x = g.xForT(s.tMs);
    final linePaint = Paint()
      ..color = gridColor.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, g.plotTop), Offset(x, g.plotBottom), linePaint);

    for (final v in s.values) {
      canvas.drawCircle(Offset(x, g.yForHr(v.hr)), 3, Paint()..color = v.color);
    }
  }

  /// Draws one solid-color line through [pts] within the visible window,
  /// breaking the path at NULL samples and long gaps. Used for the single-color
  /// line and for each device line in multi-series mode.
  void _paintSolidLine(
    Canvas canvas,
    HrChartGeometry g,
    List<HrChartPoint> pts,
    Color color,
  ) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    final path = Path();
    var penDown = false;
    int? prevTMs;
    for (final p in pts) {
      if (p.tMs < startMs || p.tMs > endMs || !p.isValidHr) {
        penDown = false;
        prevTMs = null;
        continue;
      }
      if (prevTMs != null && p.tMs - prevTMs > _maxSampleGapMs) {
        penDown = false;
      }
      final offset = Offset(g.xForT(p.tMs), g.yForHr(p.hr!));
      if (penDown) {
        path.lineTo(offset.dx, offset.dy);
      } else {
        path.moveTo(offset.dx, offset.dy);
        penDown = true;
      }
      prevTMs = p.tMs;
    }
    canvas.drawPath(path, paint);
  }

  void _paintLine(Canvas canvas, HrChartGeometry g) {
    // Multi-series: one solid line per device, each in its own color.
    final series = this.series;
    if (series != null) {
      for (final s in series) {
        _paintSolidLine(canvas, g, s.points, s.color);
      }
      return;
    }

    final setup = zoneSetup;
    if (setup == null) {
      // Single-color line: one path, faster to draw.
      _paintSolidLine(canvas, g, points, lineColor);
      return;
    }

    final basePaint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Zone-colored: draw each segment between consecutive non-null samples
    // with the color of its starting sample's zone.
    HrChartPoint? prev;
    for (final p in points) {
      if (p.tMs < startMs || p.tMs > endMs || !p.isValidHr) {
        prev = null;
        continue;
      }
      if (prev != null && prev.isValidHr) {
        if (p.tMs - prev.tMs <= _maxSampleGapMs) {
          final zone = setup.zoneFor(prev.hr);
          basePaint.color = zone?.color ?? lineColor;
          canvas.drawLine(
            Offset(g.xForT(prev.tMs), g.yForHr(prev.hr!)),
            Offset(g.xForT(p.tMs), g.yForHr(p.hr!)),
            basePaint,
          );
        }
      }
      prev = p;
    }
  }

  void _paintWorkoutWindow(Canvas canvas, HrChartGeometry g) {
    final ws = workoutStartMs;
    final we = workoutEndMs;
    if (ws == null || we == null) return;

    final scrimPaint = Paint()..color = scrimColor;
    final xs = g.xForT(ws.clamp(startMs, endMs));
    final xe = g.xForT(we.clamp(startMs, endMs));

    // Dim the plot area outside the effort window.
    if (xs > g.plotLeft) {
      canvas.drawRect(
        Rect.fromLTRB(g.plotLeft, g.plotTop, xs, g.plotBottom),
        scrimPaint,
      );
    }
    if (xe < g.plotRight) {
      canvas.drawRect(
        Rect.fromLTRB(xe, g.plotTop, g.plotRight, g.plotBottom),
        scrimPaint,
      );
    }

    if (!showHandles) return;
    final handlePaint = Paint()
      ..color = handleColor
      ..strokeWidth = 2;
    // Only draw a handle circle+line when the handle is within the visible
    // window. When zoomed in, an off-screen handle shows no marker (the scrim
    // edge already indicates the boundary); the Positioned hit area in
    // _EditableHrChartState is also hidden in that case.
    if (ws >= startMs && ws <= endMs) {
      canvas.drawLine(
        Offset(xs, g.plotTop),
        Offset(xs, g.plotBottom),
        handlePaint,
      );
      canvas.drawCircle(
        Offset(xs, g.plotTop + 6),
        activeHandle == HrActiveHandle.start ? 10.0 : 7.0,
        handlePaint,
      );
    }
    if (we >= startMs && we <= endMs) {
      canvas.drawLine(
        Offset(xe, g.plotTop),
        Offset(xe, g.plotBottom),
        handlePaint,
      );
      canvas.drawCircle(
        Offset(xe, g.plotTop + 6),
        activeHandle == HrActiveHandle.end ? 10.0 : 7.0,
        handlePaint,
      );
    }
  }

  void _paintLabel(
    Canvas canvas,
    String text,
    Offset anchor, {
    required bool alignRight,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? anchor.dx - tp.width : anchor.dx;
    final dy = anchor.dy - tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(HrChartPainter old) {
    return old.points != points ||
        old.series != series ||
        old.startMs != startMs ||
        old.endMs != endMs ||
        old.axis.minY != axis.minY ||
        old.axis.maxY != axis.maxY ||
        old.lineColor != lineColor ||
        old.workoutStartMs != workoutStartMs ||
        old.workoutEndMs != workoutEndMs ||
        old.showHandles != showHandles ||
        old.activeHandle != activeHandle ||
        old.zoneSetup != zoneSetup ||
        old.selection?.tMs != selection?.tMs ||
        !listEquals(
          old.selection?.values.map((v) => v.hr).toList(),
          selection?.values.map((v) => v.hr).toList(),
        );
  }
}

/// Wraps [HrChart] with pinch-to-zoom and one-finger pan. Used on the review
/// screen so the user can drill into a specific part of a long workout.
/// The chart's own painter is unchanged; this widget only adjusts the visible
/// window passed to it.
class ZoomableHrChart extends StatefulWidget {
  const ZoomableHrChart({
    super.key,
    this.points = const [],
    this.series,
    required this.axis,
    required this.fullStartMs,
    required this.fullEndMs,
    this.initialStartMs,
    this.initialEndMs,
    this.lineColor,
    this.workoutStartMs,
    this.workoutEndMs,
    this.minSpanMs = 5000,
    this.zoneSetup,
    this.activityStartMs,
  });

  final List<HrChartPoint> points;
  final List<HrChartSeries>? series;
  final HrAxisRange axis;
  final int fullStartMs;
  final int fullEndMs;
  final int? initialStartMs;
  final int? initialEndMs;
  final Color? lineColor;
  final int? workoutStartMs;
  final int? workoutEndMs;
  final int minSpanMs;
  final ZoneSetup? zoneSetup;
  final int? activityStartMs;

  @override
  State<ZoomableHrChart> createState() => _ZoomableHrChartState();
}

class _ZoomableHrChartState extends State<ZoomableHrChart> {
  late int _start = _initialWindow.start;
  late int _end = _initialWindow.end;

  // Snapshot at the start of a scale gesture so cumulative `scale` is honored.
  int? _g0Start;
  int? _g0End;
  double? _g0FocalT;

  int get _minVisibleSpanMs {
    final fullSpan = widget.fullEndMs - widget.fullStartMs;
    if (fullSpan <= 0) return 1;
    return widget.minSpanMs < fullSpan ? widget.minSpanMs : fullSpan;
  }

  ({int start, int end}) get _initialWindow {
    final fullEnd = widget.fullEndMs <= widget.fullStartMs
        ? widget.fullStartMs + 1
        : widget.fullEndMs;
    final minSpan = _minVisibleSpanMs;
    final end = (widget.initialEndMs ?? fullEnd)
        .clamp(widget.fullStartMs + minSpan, fullEnd)
        .toInt();
    final start = (widget.initialStartMs ?? widget.fullStartMs)
        .clamp(widget.fullStartMs, end - minSpan)
        .toInt();
    return (start: start, end: end);
  }

  @override
  void didUpdateWidget(ZoomableHrChart old) {
    super.didUpdateWidget(old);
    // If the underlying activity or preferred review window changes, reset the
    // visible window.
    if (old.fullStartMs != widget.fullStartMs ||
        old.fullEndMs != widget.fullEndMs ||
        old.initialStartMs != widget.initialStartMs ||
        old.initialEndMs != widget.initialEndMs) {
      final initialWindow = _initialWindow;
      _start = initialWindow.start;
      _end = initialWindow.end;
    }
  }

  HrChartGeometry _geometry(Size size, int startMs, int endMs) =>
      HrChartGeometry(
        size: size,
        startMs: startMs,
        endMs: endMs,
        axis: widget.axis,
      );

  void _onScaleStart(ScaleStartDetails d, Size size) {
    _g0Start = _start;
    _g0End = _end;
    final g = _geometry(size, _start, _end);
    _g0FocalT = g.tForX(d.localFocalPoint.dx).toDouble();
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size size) {
    if (_g0Start == null) return;
    final fullSpan = widget.fullEndMs - widget.fullStartMs;
    if (fullSpan <= 0) return;

    final oldSpan = _g0End! - _g0Start!;
    final newSpanRaw = (oldSpan / d.scale).round();
    final newSpan = newSpanRaw.clamp(_minVisibleSpanMs, fullSpan).toInt();

    final g = _geometry(size, _g0Start!, _g0End!);
    final plotLeft = g.plotLeft;
    final plotWidth = g.plotWidth;
    if (plotWidth <= 0) return;

    // Keep the time that was under the gesture's focal point pinned to the
    // current focal screen position. Works for pinch, pan, and a mix of both.
    final focalT = _g0FocalT!;
    final focalX = d.localFocalPoint.dx;
    final desiredStart = focalT - (focalX - plotLeft) * newSpan / plotWidth;

    final maxStart = widget.fullEndMs - newSpan;
    final clampedStart = desiredStart.round().clamp(
      widget.fullStartMs,
      maxStart,
    );

    setState(() {
      _start = clampedStart;
      _end = clampedStart + newSpan;
    });
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _g0Start = null;
    _g0End = null;
    _g0FocalT = null;
  }

  void _resetZoom() {
    final initialWindow = _initialWindow;
    setState(() {
      _start = initialWindow.start;
      _end = initialWindow.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialWindow = _initialWindow;
    final zoomed = _start != initialWindow.start || _end != initialWindow.end;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (d) => _onScaleStart(d, size),
              onScaleUpdate: (d) => _onScaleUpdate(d, size),
              onScaleEnd: _onScaleEnd,
              onDoubleTap: zoomed ? _resetZoom : null,
              child: HrChart(
                points: widget.points,
                series: widget.series,
                axis: widget.axis,
                windowStartMs: _start,
                windowEndMs: _end,
                lineColor: widget.lineColor,
                workoutStartMs: widget.workoutStartMs,
                workoutEndMs: widget.workoutEndMs,
                zoneSetup: widget.zoneSetup,
                activityStartMs: widget.activityStartMs,
              ),
            ),
            if (zoomed)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  iconSize: 18,
                  tooltip: 'Reset zoom',
                  icon: const Icon(Icons.zoom_out_map),
                  onPressed: _resetZoom,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Wraps [HrChart] with pinch-to-zoom for a live, trailing time window. Used
/// while recording so the newest sample stays pinned to the right edge while
/// the user chooses how much history to show.
class TrailingZoomableHrChart extends StatefulWidget {
  const TrailingZoomableHrChart({
    super.key,
    this.points = const [],
    this.series,
    required this.axis,
    required this.fullStartMs,
    required this.fullEndMs,
    required this.initialSpanMs,
    this.lineColor,
    this.minSpanMs = 5000,
    this.zoneSetup,
    this.activityStartMs,
  });

  final List<HrChartPoint> points;
  final List<HrChartSeries>? series;
  final HrAxisRange axis;
  final int fullStartMs;
  final int fullEndMs;
  final int initialSpanMs;
  final Color? lineColor;
  final int minSpanMs;
  final ZoneSetup? zoneSetup;
  final int? activityStartMs;

  @override
  State<TrailingZoomableHrChart> createState() =>
      _TrailingZoomableHrChartState();
}

class _TrailingZoomableHrChartState extends State<TrailingZoomableHrChart> {
  late int _spanMs = widget.initialSpanMs;
  int? _g0SpanMs;

  // True once the user zooms out to the whole recording. We then track the full
  // span as new samples arrive, rather than reverting to a trailing window (the
  // stored _spanMs would otherwise stop covering the now-longer recording).
  bool _lockedToFullSpan = false;

  int get _fullSpanMs => widget.fullEndMs - widget.fullStartMs;

  int _clampSpan(int spanMs) {
    final fullSpan = _fullSpanMs;
    if (fullSpan <= 0) return 1;
    final minSpan = widget.minSpanMs < fullSpan ? widget.minSpanMs : fullSpan;
    if (spanMs < minSpan) return minSpan;
    if (spanMs > fullSpan) return fullSpan;
    return spanMs;
  }

  @override
  void didUpdateWidget(TrailingZoomableHrChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Do not clamp _spanMs here as new samples arrive. Early in a recording the
    // full span may be only a few seconds, and clamping would permanently shrink
    // the intended default history window. Only reset when the configured
    // default itself changes.
    if (oldWidget.initialSpanMs != widget.initialSpanMs) {
      _spanMs = widget.initialSpanMs;
    }
  }

  void _onScaleStart(ScaleStartDetails _) {
    _g0SpanMs = _clampSpan(_lockedToFullSpan ? _fullSpanMs : _spanMs);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final startSpan = _g0SpanMs;
    if (startSpan == null || d.scale <= 0) return;
    final fullSpan = _fullSpanMs;
    if (fullSpan <= 0) return;
    final requested = (startSpan / d.scale).round();
    setState(() {
      // Lock to the full recording once you zoom out to within ~5% of it.
      // Without the tolerance the lock rarely engages: the live recording keeps
      // extending fullSpan each frame, so `requested` (from the span snapshotted
      // at gesture start) lands just short of full and never trips an exact >=.
      // Pinching back below the threshold releases the lock.
      if (requested >= fullSpan * 0.95) {
        _lockedToFullSpan = true;
      } else {
        _lockedToFullSpan = false;
        _spanMs = _clampSpan(requested);
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _g0SpanMs = null;
  }

  @override
  Widget build(BuildContext context) {
    final int windowStart;
    if (_lockedToFullSpan) {
      windowStart = widget.fullStartMs;
    } else {
      final span = _clampSpan(_spanMs);
      final rawStart = widget.fullEndMs - span;
      windowStart = rawStart < widget.fullStartMs
          ? widget.fullStartMs
          : rawStart;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: HrChart(
        points: widget.points,
        series: widget.series,
        axis: widget.axis,
        windowStartMs: windowStart,
        windowEndMs: widget.fullEndMs,
        lineColor: widget.lineColor,
        zoneSetup: widget.zoneSetup,
        activityStartMs: widget.activityStartMs,
      ),
    );
  }
}

/// Wraps [HrChart] with draggable `workout` span handles. Dragging updates the
/// window locally for responsiveness and reports the final bounds through
/// [onChanged] when the drag ends.
class EditableHrChart extends StatefulWidget {
  const EditableHrChart({
    super.key,
    required this.points,
    required this.axis,
    required this.windowStartMs,
    required this.windowEndMs,
    required this.workoutStartMs,
    required this.workoutEndMs,
    required this.onChanged,
    this.lineColor,
    this.minSpanMs = 5000,
    this.activityStartMs,
  });

  final List<HrChartPoint> points;
  final HrAxisRange axis;
  final int windowStartMs;
  final int windowEndMs;
  final int workoutStartMs;
  final int workoutEndMs;
  final void Function(int startMs, int endMs) onChanged;
  final Color? lineColor;
  final int minSpanMs;
  final int? activityStartMs;

  @override
  State<EditableHrChart> createState() => _EditableHrChartState();
}

class _EditableHrChartState extends State<EditableHrChart> {
  late int _start = widget.workoutStartMs;
  late int _end = widget.workoutEndMs;
  HrActiveHandle? _active;

  // Zoom window — subset of [widget.windowStartMs, widget.windowEndMs].
  late int _winStart = widget.windowStartMs;
  late int _winEnd = widget.windowEndMs;

  // Pinch-zoom snapshot (set at the start of a 2-finger gesture).
  int? _g0WinStart;
  int? _g0WinEnd;
  double? _g0FocalT;

  // Accumulated drag position (chart pixels) during a handle drag.
  double? _handleDragX;

  @override
  void didUpdateWidget(EditableHrChart old) {
    super.didUpdateWidget(old);
    if (_active == null) {
      _start = widget.workoutStartMs;
      _end = widget.workoutEndMs;
    }
  }

  HrChartGeometry _geometry(Size size) => HrChartGeometry(
    size: size,
    startMs: _winStart,
    endMs: _winEnd,
    axis: widget.axis,
  );

  // --- Handle drag (via onHorizontalDrag* on Positioned hit areas) -----------

  void _onHandlePress(HrActiveHandle handle) {
    // Fires on onTapDown — immediately before any arena resolution — so the
    // circle inflates as soon as the finger touches the handle area.
    setState(() => _active = handle);
  }

  void _onHandleDragStart(HrActiveHandle handle, Size size) {
    // onTapCancel fires in the same frame just before this, clearing _active.
    // Re-set it here so the circle stays inflated through the drag.
    setState(() => _active = handle);
    final g = _geometry(size);
    _handleDragX = g
        .xForT(handle == HrActiveHandle.start ? _start : _end)
        .toDouble();
  }

  void _onHandleDragUpdate(HrActiveHandle handle, double dx, Size size) {
    final anchor = _handleDragX;
    if (anchor == null) return;
    _handleDragX = anchor + dx;
    final g = _geometry(size);
    final t = g.tForX(_handleDragX!);
    setState(() {
      if (handle == HrActiveHandle.start) {
        _start = t.clamp(widget.windowStartMs, _end - widget.minSpanMs);
      } else {
        _end = t.clamp(_start + widget.minSpanMs, widget.windowEndMs);
      }
    });
  }

  void _onHandleDragEnd() {
    final wasDragging = _handleDragX != null;
    _handleDragX = null;
    setState(() => _active = null);
    if (wasDragging) widget.onChanged(_start, _end);
  }

  // --- Pinch zoom (via onScale* on the base chart) --------------------------

  // Only activated for 2+ pointer gestures so single-finger touches fall
  // through to the parent scroll view.
  void _onScaleStart(ScaleStartDetails d, Size size) {
    if (d.pointerCount < 2) return;
    final g = _geometry(size);
    _g0WinStart = _winStart;
    _g0WinEnd = _winEnd;
    _g0FocalT = g.tForX(d.localFocalPoint.dx).toDouble();
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size size) {
    if (_g0WinStart == null || d.scale <= 0) return;
    final fullSpan = widget.windowEndMs - widget.windowStartMs;
    if (fullSpan <= 0) return;

    final oldSpan = _g0WinEnd! - _g0WinStart!;
    final newSpan = (oldSpan / d.scale).round().clamp(
      widget.minSpanMs,
      fullSpan,
    );

    final g = HrChartGeometry(
      size: size,
      startMs: _g0WinStart!,
      endMs: _g0WinEnd!,
      axis: widget.axis,
    );
    if (g.plotWidth <= 0) return;

    // Keep the time under the focal point pinned as scale changes.
    final desiredStart =
        _g0FocalT! -
        (d.localFocalPoint.dx - g.plotLeft) * newSpan / g.plotWidth;
    final clampedStart = desiredStart.round().clamp(
      widget.windowStartMs,
      widget.windowEndMs - newSpan,
    );

    setState(() {
      _winStart = clampedStart;
      _winEnd = clampedStart + newSpan;
    });
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _g0WinStart = null;
    _g0WinEnd = null;
    _g0FocalT = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final g = _geometry(size);
        final startX = g.xForT(_start);
        final endX = g.xForT(_end);
        final startVisible = _start >= _winStart && _start <= _winEnd;
        final endVisible = _end >= _winStart && _end <= _winEnd;

        return Stack(
          children: [
            // Chart + pinch-zoom gesture (single-finger falls through to scroll).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) => _onScaleStart(d, size),
                onScaleUpdate: (d) => _onScaleUpdate(d, size),
                onScaleEnd: _onScaleEnd,
                child: HrChart(
                  points: widget.points,
                  axis: widget.axis,
                  windowStartMs: _winStart,
                  windowEndMs: _winEnd,
                  lineColor: widget.lineColor,
                  workoutStartMs: _start,
                  workoutEndMs: _end,
                  showHandles: true,
                  activeHandle: _active,
                  activityStartMs: widget.activityStartMs,
                ),
              ),
            ),
            // Dedicated horizontal-drag hit areas for each handle. Using
            // onHorizontalDrag* lets these win the gesture arena for horizontal
            // movements while vertical swipes still reach the parent scroll view.
            if (startVisible)
              Positioned(
                left: (startX - _handleHitSlop).clamp(
                  0.0,
                  size.width - _handleHitSlop * 2,
                ),
                top: 0,
                bottom: 0,
                width: _handleHitSlop * 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _onHandlePress(HrActiveHandle.start),
                  onTapUp: (_) => _onHandleDragEnd(),
                  onTapCancel: () => setState(() => _active = null),
                  onHorizontalDragStart: (_) =>
                      _onHandleDragStart(HrActiveHandle.start, size),
                  onHorizontalDragUpdate: (d) => _onHandleDragUpdate(
                    HrActiveHandle.start,
                    d.delta.dx,
                    size,
                  ),
                  onHorizontalDragEnd: (_) => _onHandleDragEnd(),
                  onHorizontalDragCancel: _onHandleDragEnd,
                ),
              ),
            if (endVisible)
              Positioned(
                left: (endX - _handleHitSlop).clamp(
                  0.0,
                  size.width - _handleHitSlop * 2,
                ),
                top: 0,
                bottom: 0,
                width: _handleHitSlop * 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _onHandlePress(HrActiveHandle.end),
                  onTapUp: (_) => _onHandleDragEnd(),
                  onTapCancel: () => setState(() => _active = null),
                  onHorizontalDragStart: (_) =>
                      _onHandleDragStart(HrActiveHandle.end, size),
                  onHorizontalDragUpdate: (d) =>
                      _onHandleDragUpdate(HrActiveHandle.end, d.delta.dx, size),
                  onHorizontalDragEnd: (_) => _onHandleDragEnd(),
                  onHorizontalDragCancel: _onHandleDragEnd,
                ),
              ),
          ],
        );
      },
    );
  }
}
