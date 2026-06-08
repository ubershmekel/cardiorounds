import 'package:flutter/material.dart';

import '../../core/zones/zones.dart';
import 'hr_stats.dart';

class HrChartPoint {
  const HrChartPoint({required this.tMs, required this.hr});

  final int tMs;
  final int? hr;
}

const double _leftGutter = 36;
const double _bottomGutter = 18;
const double _topPad = 8;
const double _rightPad = 8;
const double _handleHitSlop = 28;

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
    required this.points,
    required this.axis,
    this.windowStartMs,
    this.windowEndMs,
    this.lineColor,
    this.workoutStartMs,
    this.workoutEndMs,
    this.showHandles = false,
    this.zoneSetup,
  });

  final List<HrChartPoint> points;
  final HrAxisRange axis;
  final int? windowStartMs;
  final int? windowEndMs;
  final Color? lineColor;
  final int? workoutStartMs;
  final int? workoutEndMs;
  final bool showHandles;

  /// When provided, each line segment is colored by the zone of its starting
  /// sample. When null, the whole line uses [lineColor] (or the theme primary).
  final ZoneSetup? zoneSetup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (points.isEmpty) {
      return Center(
        child: Text(
          'No heart-rate data',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final start = windowStartMs ?? points.first.tMs;
    final end = windowEndMs ?? points.last.tMs;

    return CustomPaint(
      size: Size.infinite,
      painter: HrChartPainter(
        points: points,
        axis: axis,
        startMs: start,
        endMs: end == start ? start + 1 : end,
        lineColor: lineColor ?? scheme.primary,
        gridColor: scheme.outlineVariant,
        scrimColor: scheme.surface.withValues(alpha: 0.66),
        handleColor: scheme.primary,
        labelStyle: theme.textTheme.labelSmall!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        workoutStartMs: workoutStartMs,
        workoutEndMs: workoutEndMs,
        showHandles: showHandles,
        zoneSetup: zoneSetup,
      ),
    );
  }
}

class HrChartPainter extends CustomPainter {
  HrChartPainter({
    required this.points,
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
    this.zoneSetup,
  });

  final List<HrChartPoint> points;
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
  final ZoneSetup? zoneSetup;

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
      _elapsed(startMs),
      Offset(g.plotLeft, g.plotBottom + 2),
      alignRight: false,
    );
    _paintLabel(
      canvas,
      _elapsed(endMs),
      Offset(g.plotRight, g.plotBottom + 2),
      alignRight: true,
    );

    _paintLine(canvas, g);
    _paintWorkoutWindow(canvas, g);
  }

  void _paintLine(Canvas canvas, HrChartGeometry g) {
    final basePaint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final setup = zoneSetup;
    if (setup == null) {
      // Single-color line: one path, faster to draw.
      basePaint.color = lineColor;
      final path = Path();
      var penDown = false;
      for (final p in points) {
        if (p.tMs < startMs || p.tMs > endMs) {
          penDown = false;
          continue;
        }
        final hr = p.hr;
        if (hr == null) {
          penDown = false;
          continue;
        }
        final offset = Offset(g.xForT(p.tMs), g.yForHr(hr));
        if (penDown) {
          path.lineTo(offset.dx, offset.dy);
        } else {
          path.moveTo(offset.dx, offset.dy);
          penDown = true;
        }
      }
      canvas.drawPath(path, basePaint);
      return;
    }

    // Zone-colored: draw each segment between consecutive non-null samples
    // with the color of its starting sample's zone.
    HrChartPoint? prev;
    for (final p in points) {
      if (p.tMs < startMs || p.tMs > endMs || p.hr == null) {
        prev = null;
        continue;
      }
      if (prev != null && prev.hr != null) {
        final zone = setup.zoneFor(prev.hr);
        basePaint.color = zone?.color ?? lineColor;
        canvas.drawLine(
          Offset(g.xForT(prev.tMs), g.yForHr(prev.hr!)),
          Offset(g.xForT(p.tMs), g.yForHr(p.hr!)),
          basePaint,
        );
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
    for (final x in [xs, xe]) {
      canvas.drawLine(
        Offset(x, g.plotTop),
        Offset(x, g.plotBottom),
        handlePaint,
      );
      canvas.drawCircle(Offset(x, g.plotTop + 6), 7, handlePaint);
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

  String _elapsed(int ms) {
    final totalSec = (ms / 1000).round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(HrChartPainter old) {
    return old.points != points ||
        old.startMs != startMs ||
        old.endMs != endMs ||
        old.axis.minY != axis.minY ||
        old.axis.maxY != axis.maxY ||
        old.lineColor != lineColor ||
        old.workoutStartMs != workoutStartMs ||
        old.workoutEndMs != workoutEndMs ||
        old.showHandles != showHandles ||
        old.zoneSetup != zoneSetup;
  }
}

/// Wraps [HrChart] with pinch-to-zoom and one-finger pan. Used on the review
/// screen so the user can drill into a specific part of a long workout.
/// The chart's own painter is unchanged; this widget only adjusts the visible
/// window passed to it.
class ZoomableHrChart extends StatefulWidget {
  const ZoomableHrChart({
    super.key,
    required this.points,
    required this.axis,
    required this.fullStartMs,
    required this.fullEndMs,
    this.lineColor,
    this.workoutStartMs,
    this.workoutEndMs,
    this.minSpanMs = 5000,
    this.zoneSetup,
  });

  final List<HrChartPoint> points;
  final HrAxisRange axis;
  final int fullStartMs;
  final int fullEndMs;
  final Color? lineColor;
  final int? workoutStartMs;
  final int? workoutEndMs;
  final int minSpanMs;
  final ZoneSetup? zoneSetup;

  @override
  State<ZoomableHrChart> createState() => _ZoomableHrChartState();
}

class _ZoomableHrChartState extends State<ZoomableHrChart> {
  late int _start = widget.fullStartMs;
  late int _end = widget.fullEndMs;

  // Snapshot at the start of a scale gesture so cumulative `scale` is honored.
  int? _g0Start;
  int? _g0End;
  double? _g0FocalT;

  @override
  void didUpdateWidget(ZoomableHrChart old) {
    super.didUpdateWidget(old);
    // If the underlying activity changes length, reset the visible window.
    if (old.fullStartMs != widget.fullStartMs ||
        old.fullEndMs != widget.fullEndMs) {
      _start = widget.fullStartMs;
      _end = widget.fullEndMs;
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
    final newSpan = newSpanRaw.clamp(widget.minSpanMs, fullSpan);

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
    setState(() {
      _start = widget.fullStartMs;
      _end = widget.fullEndMs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final zoomed = _start != widget.fullStartMs || _end != widget.fullEndMs;
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
                axis: widget.axis,
                windowStartMs: _start,
                windowEndMs: _end,
                lineColor: widget.lineColor,
                workoutStartMs: widget.workoutStartMs,
                workoutEndMs: widget.workoutEndMs,
                zoneSetup: widget.zoneSetup,
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

  @override
  State<EditableHrChart> createState() => _EditableHrChartState();
}

enum _ActiveHandle { start, end }

class _EditableHrChartState extends State<EditableHrChart> {
  late int _start = widget.workoutStartMs;
  late int _end = widget.workoutEndMs;
  _ActiveHandle? _active;

  @override
  void didUpdateWidget(EditableHrChart old) {
    super.didUpdateWidget(old);
    // Pick up persisted values when not mid-drag.
    if (_active == null) {
      _start = widget.workoutStartMs;
      _end = widget.workoutEndMs;
    }
  }

  HrChartGeometry _geometry(Size size) => HrChartGeometry(
    size: size,
    startMs: widget.windowStartMs,
    endMs: widget.windowEndMs,
    axis: widget.axis,
  );

  void _onPanStart(DragStartDetails d, Size size) {
    final g = _geometry(size);
    final x = d.localPosition.dx;
    final dStart = (x - g.xForT(_start)).abs();
    final dEnd = (x - g.xForT(_end)).abs();
    final nearest = dStart <= dEnd ? _ActiveHandle.start : _ActiveHandle.end;
    if ((nearest == _ActiveHandle.start ? dStart : dEnd) > _handleHitSlop) {
      return;
    }
    setState(() => _active = nearest);
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (_active == null) return;
    final g = _geometry(size);
    final t = g.tForX(d.localPosition.dx);
    setState(() {
      if (_active == _ActiveHandle.start) {
        _start = t.clamp(widget.windowStartMs, _end - widget.minSpanMs);
      } else {
        _end = t.clamp(_start + widget.minSpanMs, widget.windowEndMs);
      }
    });
  }

  void _onPanEnd() {
    if (_active == null) return;
    setState(() => _active = null);
    widget.onChanged(_start, _end);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanStart: (d) => _onPanStart(d, size),
          onPanUpdate: (d) => _onPanUpdate(d, size),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: HrChart(
            points: widget.points,
            axis: widget.axis,
            windowStartMs: widget.windowStartMs,
            windowEndMs: widget.windowEndMs,
            lineColor: widget.lineColor,
            workoutStartMs: _start,
            workoutEndMs: _end,
            showHandles: true,
          ),
        );
      },
    );
  }
}
