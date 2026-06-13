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
    required this.points,
    required this.axis,
    this.windowStartMs,
    this.windowEndMs,
    this.lineColor,
    this.workoutStartMs,
    this.workoutEndMs,
    this.showHandles = false,
    this.activeHandle,
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
  final HrActiveHandle? activeHandle;

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

    return _SelectableHrChart(
      points: points,
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
    );
  }
}

class HrChartSelection {
  const HrChartSelection({required this.tMs, required this.hr});

  final int tMs;
  final int hr;
}

class _SelectableHrChart extends StatefulWidget {
  const _SelectableHrChart({
    required this.points,
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
  });

  final List<HrChartPoint> points;
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

  @override
  State<_SelectableHrChart> createState() => _SelectableHrChartState();
}

class _SelectableHrChartState extends State<_SelectableHrChart> {
  static const double _selectionLabelWidth = 74;
  static const double _selectionLabelHeight = 28;

  HrChartSelection? _selection;

  @override
  void didUpdateWidget(_SelectableHrChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selection = _selection;
    if (selection == null) return;
    final hr = _hrAtT(selection.tMs);
    _selection = hr == null
        ? null
        : HrChartSelection(tMs: selection.tMs, hr: hr);
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
    final hr = _hrAtT(tMs);
    if (hr == null) return;
    setState(() => _selection = HrChartSelection(tMs: tMs, hr: hr));
  }

  int? _hrAtT(int tMs) {
    if (tMs < widget.startMs || tMs > widget.endMs) return null;

    HrChartPoint? previous;
    for (final point in widget.points) {
      if (point.tMs < widget.startMs || point.tMs > widget.endMs) {
        previous = null;
        continue;
      }

      final hr = point.hr;
      if (hr == null) {
        previous = null;
        continue;
      }

      if (point.tMs == tMs) return hr;

      final prev = previous;
      if (prev != null && prev.tMs <= tMs && tMs <= point.tMs) {
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
    required this.onDismissed,
  });

  final HrChartSelection selection;
  final HrChartGeometry geometry;
  final Color backgroundColor;
  final Color borderColor;
  final TextStyle textStyle;
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

    return Positioned(
      left: left,
      top: 0,
      width: width,
      height: _SelectableHrChartState._selectionLabelHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismissed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '${selection.hr} bpm',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: textStyle,
            ),
          ),
        ),
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
    this.activeHandle,
    this.zoneSetup,
    this.selection,
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
    _paintSelection(canvas, g);
  }

  void _paintSelection(Canvas canvas, HrChartGeometry g) {
    final s = selection;
    if (s == null || s.tMs < startMs || s.tMs > endMs) return;

    final x = g.xForT(s.tMs);
    final linePaint = Paint()
      ..color = gridColor.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, g.plotTop), Offset(x, g.plotBottom), linePaint);

    final pointPaint = Paint()..color = lineColor;
    canvas.drawCircle(Offset(x, g.yForHr(s.hr)), 3, pointPaint);
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
    canvas.drawLine(Offset(xs, g.plotTop), Offset(xs, g.plotBottom), handlePaint);
    canvas.drawCircle(
      Offset(xs, g.plotTop + 6),
      activeHandle == HrActiveHandle.start ? 10.0 : 7.0,
      handlePaint,
    );
    canvas.drawLine(Offset(xe, g.plotTop), Offset(xe, g.plotBottom), handlePaint);
    canvas.drawCircle(
      Offset(xe, g.plotTop + 6),
      activeHandle == HrActiveHandle.end ? 10.0 : 7.0,
      handlePaint,
    );
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
        old.activeHandle != activeHandle ||
        old.zoneSetup != zoneSetup ||
        old.selection?.tMs != selection?.tMs ||
        old.selection?.hr != selection?.hr;
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
    this.initialStartMs,
    this.initialEndMs,
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
  final int? initialStartMs;
  final int? initialEndMs;
  final Color? lineColor;
  final int? workoutStartMs;
  final int? workoutEndMs;
  final int minSpanMs;
  final ZoneSetup? zoneSetup;

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

/// Wraps [HrChart] with pinch-to-zoom for a live, trailing time window. Used
/// while recording so the newest sample stays pinned to the right edge while
/// the user chooses how much history to show.
class TrailingZoomableHrChart extends StatefulWidget {
  const TrailingZoomableHrChart({
    super.key,
    required this.points,
    required this.axis,
    required this.fullStartMs,
    required this.fullEndMs,
    required this.initialSpanMs,
    this.lineColor,
    this.minSpanMs = 5000,
    this.zoneSetup,
  });

  final List<HrChartPoint> points;
  final HrAxisRange axis;
  final int fullStartMs;
  final int fullEndMs;
  final int initialSpanMs;
  final Color? lineColor;
  final int minSpanMs;
  final ZoneSetup? zoneSetup;

  @override
  State<TrailingZoomableHrChart> createState() =>
      _TrailingZoomableHrChartState();
}

class _TrailingZoomableHrChartState extends State<TrailingZoomableHrChart> {
  late int _spanMs = widget.initialSpanMs;
  int? _g0SpanMs;

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
    _g0SpanMs = _clampSpan(_spanMs);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final startSpan = _g0SpanMs;
    if (startSpan == null || d.scale <= 0) return;
    setState(() => _spanMs = _clampSpan((startSpan / d.scale).round()));
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _g0SpanMs = null;
  }

  @override
  Widget build(BuildContext context) {
    final span = _clampSpan(_spanMs);
    final rawStart = widget.fullEndMs - span;
    final windowStart = rawStart < widget.fullStartMs
        ? widget.fullStartMs
        : rawStart;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: HrChart(
        points: widget.points,
        axis: widget.axis,
        windowStartMs: windowStart,
        windowEndMs: widget.fullEndMs,
        lineColor: widget.lineColor,
        zoneSetup: widget.zoneSetup,
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

class _EditableHrChartState extends State<EditableHrChart> {
  late int _start = widget.workoutStartMs;
  late int _end = widget.workoutEndMs;
  HrActiveHandle? _active;

  // Zoom/pan window — subset of [widget.windowStartMs, widget.windowEndMs].
  late int _winStart = widget.windowStartMs;
  late int _winEnd = widget.windowEndMs;

  // Snapshot at the start of a scale gesture for cumulative scale math.
  int? _g0WinStart;
  int? _g0WinEnd;
  double? _g0FocalT;

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

  void _onScaleStart(ScaleStartDetails d, Size size) {
    _g0WinStart = null;
    _g0WinEnd = null;
    _g0FocalT = null;

    if (d.pointerCount == 1) {
      // Check if the finger landed on a handle.
      final g = _geometry(size);
      final x = d.localFocalPoint.dx;
      final dStart = (x - g.xForT(_start)).abs();
      final dEnd = (x - g.xForT(_end)).abs();
      final nearest = dStart <= dEnd ? HrActiveHandle.start : HrActiveHandle.end;
      if ((nearest == HrActiveHandle.start ? dStart : dEnd) <= _handleHitSlop) {
        setState(() => _active = nearest);
        return;
      }
    }

    // No handle hit, or multi-finger — pan/zoom the view window.
    _active = null;
    final g = _geometry(size);
    _g0WinStart = _winStart;
    _g0WinEnd = _winEnd;
    _g0FocalT = g.tForX(d.localFocalPoint.dx).toDouble();
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size size) {
    if (_active != null) {
      final g = _geometry(size);
      final t = g.tForX(d.localFocalPoint.dx);
      setState(() {
        if (_active == HrActiveHandle.start) {
          _start = t.clamp(widget.windowStartMs, _end - widget.minSpanMs);
        } else {
          _end = t.clamp(_start + widget.minSpanMs, widget.windowEndMs);
        }
      });
      return;
    }

    if (_g0WinStart == null || d.scale <= 0) return;
    final fullSpan = widget.windowEndMs - widget.windowStartMs;
    if (fullSpan <= 0) return;

    final oldSpan = _g0WinEnd! - _g0WinStart!;
    final newSpan = (oldSpan / d.scale).round().clamp(widget.minSpanMs, fullSpan);

    final g = HrChartGeometry(
      size: size,
      startMs: _g0WinStart!,
      endMs: _g0WinEnd!,
      axis: widget.axis,
    );
    if (g.plotWidth <= 0) return;

    // Keep the time under the focal point pinned as scale changes.
    final desiredStart = _g0FocalT! -
        (d.localFocalPoint.dx - g.plotLeft) * newSpan / g.plotWidth;
    final clampedStart = desiredStart
        .round()
        .clamp(widget.windowStartMs, widget.windowEndMs - newSpan);

    setState(() {
      _winStart = clampedStart;
      _winEnd = clampedStart + newSpan;
    });
  }

  void _onScaleEnd(ScaleEndDetails _) {
    if (_active != null) {
      setState(() => _active = null);
      widget.onChanged(_start, _end);
    }
    _g0WinStart = null;
    _g0WinEnd = null;
    _g0FocalT = null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
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
          ),
        );
      },
    );
  }
}
