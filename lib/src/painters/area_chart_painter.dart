import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../utils/monotone_spline.dart';
import '../utils/nice_numbers.dart';
import 'chart_painter.dart';
import '../theme/chart_theme.dart';
import '../utils/value_formatter.dart';

/// Padding for area chart rendering (px).
const _defaultLeftPaddingPx = 48.0;
const _defaultBottomPaddingPx = 32.0;
const _topPaddingPx = 16.0;
const _rightPaddingPx = 16.0;

/// Reduced padding when axis labels are hidden (px).
const _reducedLeftPaddingPx = 12.0;
const _reducedBottomPaddingPx = 8.0;

/// Additional padding when axis titles are shown (px).
const _axisTitlePaddingPx = 24.0;

/// Painter that renders an area chart on the Canvas.
///
/// Draws a gradient-filled area and line for each series.
/// Follows the Ant Design Charts style.
class AreaChartPainter extends BaseChartPainter {
  final List<ChartSeries> seriesList;
  final NiceScale yScale;
  final bool smoothCurve;

  /// Progress of the left-to-right reveal animation (0.0 to 1.0).
  final double animationProgress;

  /// Opacity animation for the area fill (0.0 to 1.0).
  final double areaOpacity;

  /// X index of the hovered data point (shared across all series).
  final int? hoveredXIndex;

  /// X-axis title text.
  final String? xAxisTitle;

  /// Y-axis title text.
  final String? yAxisTitle;

  /// Unit string for values (e.g. "%", "USD").
  final String? unit;

  /// Display position of the unit.
  final UnitPosition unitPosition;

  /// Scaling for displayed values.
  final ValueScale valueScale;

  /// Whether to use thousands separator commas.
  final bool useThousandsSeparator;

  /// Reusable Paint (for background).
  final Paint _bgPaint = Paint();

  /// Reusable Paint (for area fill).
  final Paint _fillPaint = Paint();

  /// Reusable Paint (for line drawing).
  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Reusable Paint (for crosshair).
  final Paint _crosshairPaint = Paint();

  /// Reusable Paint (for dot fill).
  final Paint _dotFillPaint = Paint();

  /// Reusable Paint (for dot border).
  final Paint _dotStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  AreaChartPainter({
    required this.seriesList,
    required this.yScale,
    required super.theme,
    super.baseTextStyle,
    this.smoothCurve = true,
    this.animationProgress = 1.0,
    this.areaOpacity = 1.0,
    this.hoveredXIndex,
    this.xAxisTitle,
    this.yAxisTitle,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
  });

  /// Whether the X-axis title display condition is met.
  bool get _hasXAxisTitle =>
      theme.showXAxisTitle && xAxisTitle != null && xAxisTitle!.isNotEmpty;

  /// Whether the Y-axis title display condition is met.
  bool get _hasYAxisTitle =>
      theme.showYAxisTitle && yAxisTitle != null && yAxisTitle!.isNotEmpty;

  /// Returns left padding based on theme settings.
  double get _leftPadding {
    double base =
        theme.showYAxisLabels ? _defaultLeftPaddingPx : _reducedLeftPaddingPx;
    if (_hasYAxisTitle) base += _axisTitlePaddingPx;
    return base;
  }

  /// Returns bottom padding based on theme settings.
  double get _bottomPadding {
    double base =
        theme.showXAxisLabels ? _defaultBottomPaddingPx : _reducedBottomPaddingPx;
    if (_hasXAxisTitle) base += _axisTitlePaddingPx;
    return base;
  }

  @override
  Rect calculatePlotArea(Size canvasSize) {
    return Rect.fromLTRB(
      _leftPadding,
      _topPaddingPx,
      canvasSize.width - _rightPaddingPx,
      canvasSize.height - _bottomPadding,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (seriesList.isEmpty) return;

    final plotArea = calculatePlotArea(size);
    final (xMin, xMax) = _computeXRange();

    // Background
    _bgPaint.color = theme.backgroundColor;
    canvas.drawRect(Offset.zero & size, _bgPaint);

    // Dashed grid lines + axes
    final gridLineCount = yScale.tickCount - 1;
    if (gridLineCount > 0) {
      drawDashedGridLines(canvas, plotArea, gridLineCount);
    }
    if (theme.showYAxisLabels) {
      _drawYAxisLabels(canvas, plotArea);
    }
    if (theme.showXAxisLabels) {
      _drawXAxisLabels(canvas, plotArea, xMin, xMax);
    }
    _drawXAxisTitle(canvas, plotArea);
    _drawYAxisTitle(canvas, plotArea);
    drawAxes(canvas, plotArea);

    // Clip for animation (left-to-right reveal)
    canvas.save();
    final clipRight = plotArea.left + plotArea.width * animationProgress;
    canvas.clipRect(
      Rect.fromLTRB(plotArea.left, plotArea.top - 1, clipRight, plotArea.bottom + 1),
    );

    // Area fill (draw from last series so the first series appears on top)
    for (final series in seriesList.reversed) {
      _drawAreaFill(canvas, series, plotArea, xMin, xMax);
    }

    // Lines (drawn on top of the area)
    for (final series in seriesList) {
      _drawLine(canvas, series, plotArea, xMin, xMax);
    }

    canvas.restore();

    // Crosshair and dots on hover (drawn outside the clip)
    if (hoveredXIndex != null && animationProgress > 0.9) {
      _drawCrosshair(canvas, plotArea, xMin, xMax);
      _drawHoverDots(canvas, plotArea, xMin, xMax);
    }
  }

  /// Computes the X-value range across all series.
  (double, double) _computeXRange() {
    var xMin = double.infinity;
    var xMax = double.negativeInfinity;
    for (final series in seriesList) {
      for (final point in series.dataPoints) {
        xMin = min(xMin, point.x);
        xMax = max(xMax, point.x);
      }
    }
    // Fallback when all X values are identical
    if (xMin == xMax) {
      xMin -= 1;
      xMax += 1;
    }
    return (xMin, xMax);
  }

  /// Converts data coordinates to pixel coordinates.
  Offset _dataToPixel(
    double x,
    double y,
    Rect plotArea,
    double xMin,
    double xMax,
  ) {
    final px =
        plotArea.left + (x - xMin) / (xMax - xMin) * plotArea.width;
    final py = plotArea.bottom -
        (y - yScale.niceMin) /
            (yScale.niceMax - yScale.niceMin) *
            plotArea.height;
    return Offset(px, py);
  }

  /// Generates a list of pixel coordinates for a series.
  List<Offset> _seriesToPixels(
    ChartSeries series,
    Rect plotArea,
    double xMin,
    double xMax,
  ) {
    return series.dataPoints
        .map((p) => _dataToPixel(p.x, p.y, plotArea, xMin, xMax))
        .toList();
  }

  /// Draws the gradient-filled area.
  /// Vertical gradient from series color (top) to transparent (bottom).
  void _drawAreaFill(
    Canvas canvas,
    ChartSeries series,
    Rect plotArea,
    double xMin,
    double xMax,
  ) {
    final pixels = _seriesToPixels(series, plotArea, xMin, xMax);
    if (pixels.length < 2) return;

    final upperPath =
        smoothCurve ? buildMonotoneCubicPath(pixels) : buildLinearPath(pixels);

    // Close the upper path at the baseline to form the area
    final areaPath = Path()
      ..addPath(upperPath, Offset.zero)
      ..lineTo(pixels.last.dx, plotArea.bottom)
      ..lineTo(pixels.first.dx, plotArea.bottom)
      ..close();

    _fillPaint.shader = ui.Gradient.linear(
      Offset(0, plotArea.top),
      Offset(0, plotArea.bottom),
      [
        series.color
            .withValues(alpha: theme.areaFillOpacity * areaOpacity),
        series.color.withValues(alpha: 0.0),
      ],
    );

    canvas.drawPath(areaPath, _fillPaint);
  }

  /// Draws the line for a series.
  void _drawLine(
    Canvas canvas,
    ChartSeries series,
    Rect plotArea,
    double xMin,
    double xMax,
  ) {
    final pixels = _seriesToPixels(series, plotArea, xMin, xMax);
    if (pixels.length < 2) return;

    final linePath =
        smoothCurve ? buildMonotoneCubicPath(pixels) : buildLinearPath(pixels);

    _linePaint
      ..color = series.color
      ..strokeWidth = theme.areaLineWidthPx;

    canvas.drawPath(linePath, _linePaint);
  }

  /// Draws Y-axis tick labels.
  void _drawYAxisLabels(Canvas canvas, Rect plotArea) {
    for (final tick in yScale.ticks) {
      final y = plotArea.bottom -
          (tick - yScale.niceMin) /
              (yScale.niceMax - yScale.niceMin) *
              plotArea.height;

      final text = formatChartValue(tick, unit: unit, unitPosition: unitPosition, valueScale: valueScale, useThousandsSeparator: useThousandsSeparator);
      final labelAreaWidth =
          theme.showYAxisLabels ? _defaultLeftPaddingPx : _reducedLeftPaddingPx;
      final painter = TextPainter(
        text: TextSpan(text: text, style: resolveStyle(theme.labelStyle)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        maxLines: 1,
        ellipsis: '\u2026',
      )..layout(maxWidth: labelAreaWidth - 8);

      painter.paint(
        canvas,
        Offset(_leftPadding - painter.width - 6, y - painter.height / 2),
      );
    }
  }

  /// Draws X-axis labels. Automatically thins them out to avoid overlap.
  void _drawXAxisLabels(
    Canvas canvas,
    Rect plotArea,
    double xMin,
    double xMax,
  ) {
    final dataPoints = seriesList.first.dataPoints;
    if (dataPoints.isEmpty) return;

    // Thin out labels, allocating about 60px width per label
    final maxLabels = (plotArea.width / 60).floor().clamp(2, dataPoints.length);
    final step = (dataPoints.length / maxLabels).ceil().clamp(1, dataPoints.length);

    for (var i = 0; i < dataPoints.length; i += step) {
      final point = dataPoints[i];
      final x = _dataToPixel(point.x, 0, plotArea, xMin, xMax).dx;
      final label = point.label ?? point.x.toString();

      final painter = TextPainter(
        text: TextSpan(text: label, style: resolveStyle(theme.labelStyle)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout();

      painter.paint(
        canvas,
        Offset(x - painter.width / 2, plotArea.bottom + 6),
      );
    }
  }

  /// Draws a vertical dashed crosshair line on hover.
  void _drawCrosshair(
    Canvas canvas,
    Rect plotArea,
    double xMin,
    double xMax,
  ) {
    final xValue = seriesList.first.dataPoints[hoveredXIndex!].x;
    final x = _dataToPixel(xValue, 0, plotArea, xMin, xMax).dx;

    _crosshairPaint
      ..color = theme.areaCrosshairColor
      ..strokeWidth = theme.areaCrosshairWidthPx;

    // Draw vertical dashed line
    const dashPx = 4.0;
    const gapPx = 4.0;
    var y = plotArea.top;
    while (y < plotArea.bottom) {
      final endY = min(y + dashPx, plotArea.bottom);
      canvas.drawLine(Offset(x, y), Offset(x, endY), _crosshairPaint);
      y += dashPx + gapPx;
    }
  }

  /// Draws dots (white fill + series-colored border) at hovered data points.
  void _drawHoverDots(
    Canvas canvas,
    Rect plotArea,
    double xMin,
    double xMax,
  ) {
    for (final series in seriesList) {
      if (hoveredXIndex! >= series.dataPoints.length) continue;

      final point = series.dataPoints[hoveredXIndex!];
      final pixel = _dataToPixel(point.x, point.y, plotArea, xMin, xMax);
      final radius = theme.areaPointHoverRadiusPx;

      // White fill
      _dotFillPaint.color = Colors.white;
      canvas.drawCircle(pixel, radius, _dotFillPaint);

      // Series-colored border
      _dotStrokePaint.color = series.color;
      canvas.drawCircle(pixel, radius, _dotStrokePaint);
    }
  }

  /// Draws the X-axis title horizontally (below labels, centered).
  void _drawXAxisTitle(Canvas canvas, Rect plotArea) {
    if (!_hasXAxisTitle) return;

    final painter = TextPainter(
      text: TextSpan(text: xAxisTitle!, style: resolveStyle(theme.axisTitleStyle)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final x = plotArea.left + (plotArea.width - painter.width) / 2;
    final y = plotArea.bottom + (theme.showXAxisLabels ? 26.0 : 4.0);
    painter.paint(canvas, Offset(x, y));
  }

  /// Draws the Y-axis title rotated -90 degrees (left of labels, centered).
  void _drawYAxisTitle(Canvas canvas, Rect plotArea) {
    if (!_hasYAxisTitle) return;

    final painter = TextPainter(
      text: TextSpan(text: yAxisTitle!, style: resolveStyle(theme.axisTitleStyle)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    canvas.save();
    final centerY = plotArea.top + plotArea.height / 2;
    canvas.translate(painter.height / 2 + 2, centerY);
    canvas.rotate(-pi / 2);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AreaChartPainter oldDelegate) {
    return baseTextStyle != oldDelegate.baseTextStyle ||
        seriesList != oldDelegate.seriesList ||
        yScale != oldDelegate.yScale ||
        smoothCurve != oldDelegate.smoothCurve ||
        animationProgress != oldDelegate.animationProgress ||
        areaOpacity != oldDelegate.areaOpacity ||
        hoveredXIndex != oldDelegate.hoveredXIndex ||
        xAxisTitle != oldDelegate.xAxisTitle ||
        yAxisTitle != oldDelegate.yAxisTitle ||
        unit != oldDelegate.unit ||
        unitPosition != oldDelegate.unitPosition ||
        valueScale != oldDelegate.valueScale ||
        useThousandsSeparator != oldDelegate.useThousandsSeparator;
  }
}

/// Returns the X index of the nearest data point to the hover position.
/// Returns null if outside the plot area.
int? hitTestAreaChart({
  required Offset localPosition,
  required Size size,
  required List<ChartSeries> seriesList,
  ChartTheme? theme,
  String? xAxisTitle,
  String? yAxisTitle,
}) {
  if (seriesList.isEmpty) return null;

  final effectiveTheme = theme ?? const ChartTheme();
  final hasXTitle = effectiveTheme.showXAxisTitle &&
      xAxisTitle != null &&
      xAxisTitle.isNotEmpty;
  final hasYTitle = effectiveTheme.showYAxisTitle &&
      yAxisTitle != null &&
      yAxisTitle.isNotEmpty;

  var leftPadding =
      effectiveTheme.showYAxisLabels ? _defaultLeftPaddingPx : _reducedLeftPaddingPx;
  if (hasYTitle) leftPadding += _axisTitlePaddingPx;
  var bottomPadding =
      effectiveTheme.showXAxisLabels ? _defaultBottomPaddingPx : _reducedBottomPaddingPx;
  if (hasXTitle) bottomPadding += _axisTitlePaddingPx;

  final plotArea = Rect.fromLTRB(
    leftPadding,
    _topPaddingPx,
    size.width - _rightPaddingPx,
    size.height - bottomPadding,
  );

  if (!plotArea.contains(localPosition)) return null;

  final dataPoints = seriesList.first.dataPoints;
  if (dataPoints.isEmpty) return null;

  final xMin = dataPoints.first.x;
  final xMax = dataPoints.last.x;
  if (xMax == xMin) return 0;

  // Convert pixel X to data X and find the nearest index
  final dataX =
      xMin + (localPosition.dx - plotArea.left) / plotArea.width * (xMax - xMin);

  var nearestIndex = 0;
  var minDistance = double.infinity;
  for (var i = 0; i < dataPoints.length; i++) {
    final distance = (dataPoints[i].x - dataX).abs();
    if (distance < minDistance) {
      minDistance = distance;
      nearestIndex = i;
    }
  }

  return nearestIndex;
}
