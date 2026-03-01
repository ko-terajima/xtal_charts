import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../theme/chart_theme.dart';
import '../utils/monotone_spline.dart';
import '../utils/nice_numbers.dart';
import '../utils/value_formatter.dart';
import 'chart_painter.dart';
import 'column_chart_painter.dart';

/// Chart type assigned to each axis in a DualAxes chart.
enum DualAxesChartType {
  /// Line chart.
  line,

  /// Area chart (fill + line).
  area,

  /// Column (vertical bar) chart.
  column,
}

/// Padding for DualAxes chart rendering (px).
const _defaultLeftPaddingPx = 48.0;
const _defaultBottomPaddingPx = 32.0;
const _topPaddingPx = 16.0;
const _defaultRightPaddingPx = 48.0; // Enlarged for right Y axis labels

/// Reduced padding when axis labels are hidden (px).
const _reducedLeftPaddingPx = 12.0;
const _reducedBottomPaddingPx = 8.0;
const _reducedRightPaddingPx = 12.0;

/// Additional padding when axis titles are shown (px).
const _axisTitlePaddingPx = 20.0;

/// Painter that draws an Ant Design Charts style dual-axis chart on Canvas.
///
/// The left and right axes have independent Y scales, and different chart types
/// (line / area / column) are overlaid on a single chart.
class DualAxesPainter extends BaseChartPainter {
  final List<ChartSeries> leftSeriesList;
  final List<ChartSeries> rightSeriesList;
  final NiceScale leftYScale;
  final NiceScale rightYScale;
  final DualAxesChartType leftChartType;
  final DualAxesChartType rightChartType;
  final bool smoothCurve;

  /// Animation progress (0.0 to 1.0).
  final double animationProgress;

  /// Hovered X index (shared across both axes).
  final int? hoveredXIndex;

  /// X axis title text.
  final String? xAxisTitle;

  /// Left Y axis title text.
  final String? leftYAxisTitle;

  /// Right Y axis title text.
  final String? rightYAxisTitle;

  /// Unit string for left axis values.
  final String? leftUnit;

  /// Display position of the left axis unit.
  final UnitPosition leftUnitPosition;

  /// Value scaling for left axis display.
  final ValueScale leftValueScale;

  /// Unit string for right axis values.
  final String? rightUnit;

  /// Display position of the right axis unit.
  final UnitPosition rightUnitPosition;

  /// Value scaling for right axis display.
  final ValueScale rightValueScale;

  /// Whether to use thousands separator for the left axis.
  final bool leftUseThousandsSeparator;

  /// Whether to use thousands separator for the right axis.
  final bool rightUseThousandsSeparator;

  /// Reusable Paint for background.
  final Paint _bgPaint = Paint();

  /// Reusable Paint for axis lines.
  final Paint _axisPaint = Paint();

  /// Reusable Paint for bar / cell fill.
  final Paint _fillPaint = Paint();

  /// Reusable Paint for area fill.
  final Paint _areaFillPaint = Paint();

  /// Reusable Paint for line drawing.
  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Reusable Paint for crosshair.
  final Paint _crosshairPaint = Paint();

  /// Reusable Paint for dot fill.
  final Paint _dotFillPaint = Paint();

  /// Reusable Paint for dot border.
  final Paint _dotStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  DualAxesPainter({
    required this.leftSeriesList,
    required this.rightSeriesList,
    required this.leftYScale,
    required this.rightYScale,
    required super.theme,
    super.baseTextStyle,
    this.leftChartType = DualAxesChartType.column,
    this.rightChartType = DualAxesChartType.line,
    this.smoothCurve = true,
    this.animationProgress = 1.0,
    this.hoveredXIndex,
    this.xAxisTitle,
    this.leftYAxisTitle,
    this.rightYAxisTitle,
    this.leftUnit,
    this.leftUnitPosition = UnitPosition.suffix,
    this.leftValueScale = ValueScale.none,
    this.rightUnit,
    this.rightUnitPosition = UnitPosition.suffix,
    this.rightValueScale = ValueScale.none,
    this.leftUseThousandsSeparator = true,
    this.rightUseThousandsSeparator = true,
  });

  /// Whether the X axis title should be displayed.
  bool get _hasXAxisTitle =>
      theme.showXAxisTitle && xAxisTitle != null && xAxisTitle!.isNotEmpty;

  /// Whether the left Y axis title should be displayed.
  bool get _hasLeftYAxisTitle =>
      theme.showYAxisTitle && leftYAxisTitle != null && leftYAxisTitle!.isNotEmpty;

  /// Whether the right Y axis title should be displayed.
  bool get _hasRightYAxisTitle =>
      theme.showYAxisTitle && rightYAxisTitle != null && rightYAxisTitle!.isNotEmpty;

  /// Left padding based on theme settings.
  double get _leftPadding {
    double base =
        theme.showYAxisLabels ? _defaultLeftPaddingPx : _reducedLeftPaddingPx;
    if (_hasLeftYAxisTitle) base += _axisTitlePaddingPx;
    return base;
  }

  /// Bottom padding based on theme settings.
  double get _bottomPadding {
    double base =
        theme.showXAxisLabels ? _defaultBottomPaddingPx : _reducedBottomPaddingPx;
    if (_hasXAxisTitle) base += _axisTitlePaddingPx;
    return base;
  }

  /// Right padding based on theme settings.
  double get _rightPadding {
    double base =
        theme.showYAxisLabels ? _defaultRightPaddingPx : _reducedRightPaddingPx;
    if (_hasRightYAxisTitle) base += _axisTitlePaddingPx;
    return base;
  }

  @override
  Rect calculatePlotArea(Size canvasSize) {
    return Rect.fromLTRB(
      _leftPadding,
      _topPaddingPx,
      canvasSize.width - _rightPadding,
      canvasSize.height - _bottomPadding,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final hasLeftData = leftSeriesList.isNotEmpty &&
        leftSeriesList.first.dataPoints.isNotEmpty;
    final hasRightData = rightSeriesList.isNotEmpty &&
        rightSeriesList.first.dataPoints.isNotEmpty;
    if (!hasLeftData && !hasRightData) return;

    final plotArea = calculatePlotArea(size);
    final categoryCount = _categoryCount;
    if (categoryCount == 0) return;

    // 1. Background
    _bgPaint.color = theme.backgroundColor;
    canvas.drawRect(Offset.zero & size, _bgPaint);

    // 2. Dashed grid lines (based on left Y axis)
    final gridLineCount = leftYScale.tickCount - 1;
    if (gridLineCount > 0) {
      drawDashedGridLines(canvas, plotArea, gridLineCount);
    }

    // 3-4. Y axis labels
    if (theme.showYAxisLabels) {
      _drawLeftYAxisLabels(canvas, plotArea);
      _drawRightYAxisLabels(canvas, plotArea);
    }

    // 5. X axis labels
    if (theme.showXAxisLabels) {
      _drawXAxisLabels(canvas, plotArea, categoryCount);
    }

    // 6. Axis titles
    _drawXAxisTitle(canvas, plotArea);
    _drawLeftYAxisTitle(canvas, plotArea);
    _drawRightYAxisTitle(canvas, plotArea);

    // 7. Axis lines (left Y + bottom X + right Y)
    _drawAxes(canvas, plotArea);

    // 7-9. Data rendering (column -> area -> line order)
    _drawDataLayers(canvas, plotArea, categoryCount);

    // 10. Crosshair + dots on hover
    if (hoveredXIndex != null && animationProgress > 0.9) {
      _drawCrosshair(canvas, plotArea, categoryCount);
      _drawHoverDots(canvas, plotArea, categoryCount);
    }
  }

  /// Uses the larger data point count from both axes as the category count.
  int get _categoryCount {
    final leftCount = leftSeriesList.isNotEmpty
        ? leftSeriesList.first.dataPoints.length
        : 0;
    final rightCount = rightSeriesList.isNotEmpty
        ? rightSeriesList.first.dataPoints.length
        : 0;
    return max(leftCount, rightCount);
  }

  // --- Y axis labels ---

  void _drawLeftYAxisLabels(Canvas canvas, Rect plotArea) {
    final yRange = leftYScale.niceMax - leftYScale.niceMin;
    if (yRange <= 0) return;

    for (final tick in leftYScale.ticks) {
      final y = plotArea.bottom -
          (tick - leftYScale.niceMin) / yRange * plotArea.height;

      final text = formatChartValue(tick, unit: leftUnit, unitPosition: leftUnitPosition, valueScale: leftValueScale, useThousandsSeparator: leftUseThousandsSeparator);
      final painter = TextPainter(
        text: TextSpan(text: text, style: resolveStyle(theme.labelStyle)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout(maxWidth: _defaultLeftPaddingPx - 8);

      painter.paint(
        canvas,
        Offset(_leftPadding - painter.width - 6, y - painter.height / 2),
      );
    }
  }

  void _drawRightYAxisLabels(Canvas canvas, Rect plotArea) {
    final yRange = rightYScale.niceMax - rightYScale.niceMin;
    if (yRange <= 0) return;

    for (final tick in rightYScale.ticks) {
      final y = plotArea.bottom -
          (tick - rightYScale.niceMin) / yRange * plotArea.height;

      final text = formatChartValue(tick, unit: rightUnit, unitPosition: rightUnitPosition, valueScale: rightValueScale, useThousandsSeparator: rightUseThousandsSeparator);
      final painter = TextPainter(
        text: TextSpan(text: text, style: resolveStyle(theme.labelStyle)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      )..layout(maxWidth: _defaultRightPaddingPx - 8);

      painter.paint(
        canvas,
        Offset(plotArea.right + 6, y - painter.height / 2),
      );
    }
  }

  // --- X axis labels ---

  void _drawXAxisLabels(Canvas canvas, Rect plotArea, int categoryCount) {
    // Prefer column series as label source; otherwise use the first left axis series
    final labelSource = _labelSourcePoints;
    if (labelSource.isEmpty) return;

    final slotWidth = plotArea.width / categoryCount;
    final maxLabels =
        (plotArea.width / 60).floor().clamp(2, categoryCount);
    final step =
        (categoryCount / maxLabels).ceil().clamp(1, categoryCount);

    for (var i = 0; i < categoryCount; i += step) {
      if (i >= labelSource.length) break;
      final label = labelSource[i].label ?? labelSource[i].x.toString();
      final centerX = plotArea.left + slotWidth * (i + 0.5);

      final painter = TextPainter(
        text: TextSpan(text: label, style: resolveStyle(theme.labelStyle)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      painter.paint(
        canvas,
        Offset(centerX - painter.width / 2, plotArea.bottom + 6),
      );
    }
  }

  /// Source for X axis labels. Prefers column series if available.
  List<ChartDataPoint> get _labelSourcePoints {
    if (leftChartType == DualAxesChartType.column &&
        leftSeriesList.isNotEmpty) {
      return leftSeriesList.first.dataPoints;
    }
    if (rightChartType == DualAxesChartType.column &&
        rightSeriesList.isNotEmpty) {
      return rightSeriesList.first.dataPoints;
    }
    if (leftSeriesList.isNotEmpty) return leftSeriesList.first.dataPoints;
    if (rightSeriesList.isNotEmpty) return rightSeriesList.first.dataPoints;
    return const [];
  }

  // --- Axis lines ---

  void _drawAxes(Canvas canvas, Rect plotArea) {
    _axisPaint
      ..color = theme.axisColor
      ..strokeWidth = theme.axisLineWidthPx;

    // Left Y axis
    canvas.drawLine(
      Offset(plotArea.left, plotArea.top),
      Offset(plotArea.left, plotArea.bottom),
      _axisPaint,
    );
    // Bottom X axis
    canvas.drawLine(
      Offset(plotArea.left, plotArea.bottom),
      Offset(plotArea.right, plotArea.bottom),
      _axisPaint,
    );
    // Right Y axis
    canvas.drawLine(
      Offset(plotArea.right, plotArea.top),
      Offset(plotArea.right, plotArea.bottom),
      _axisPaint,
    );
  }

  // --- Data rendering ---

  /// Draws data for each axis in order: column -> area -> line.
  void _drawDataLayers(Canvas canvas, Rect plotArea, int categoryCount) {
    // Draw column bars at the back
    if (leftChartType == DualAxesChartType.column) {
      _drawColumnSeries(
        canvas, plotArea, categoryCount, leftSeriesList, leftYScale,
      );
    }
    if (rightChartType == DualAxesChartType.column) {
      _drawColumnSeries(
        canvas, plotArea, categoryCount, rightSeriesList, rightYScale,
      );
    }

    // Draw area fill in the middle
    if (leftChartType == DualAxesChartType.area) {
      _drawAreaSeries(
        canvas, plotArea, categoryCount, leftSeriesList, leftYScale,
      );
    }
    if (rightChartType == DualAxesChartType.area) {
      _drawAreaSeries(
        canvas, plotArea, categoryCount, rightSeriesList, rightYScale,
      );
    }

    // Draw lines at the front
    if (leftChartType == DualAxesChartType.line) {
      _drawLineSeries(
        canvas, plotArea, categoryCount, leftSeriesList, leftYScale,
      );
    }
    if (rightChartType == DualAxesChartType.line) {
      _drawLineSeries(
        canvas, plotArea, categoryCount, rightSeriesList, rightYScale,
      );
    }

    // Lines for area type (drawn on top of area fill)
    if (leftChartType == DualAxesChartType.area) {
      _drawLineSeries(
        canvas, plotArea, categoryCount, leftSeriesList, leftYScale,
      );
    }
    if (rightChartType == DualAxesChartType.area) {
      _drawLineSeries(
        canvas, plotArea, categoryCount, rightSeriesList, rightYScale,
      );
    }
  }

  /// Draws column bars.
  void _drawColumnSeries(
    Canvas canvas,
    Rect plotArea,
    int categoryCount,
    List<ChartSeries> seriesList,
    NiceScale yScale,
  ) {
    if (seriesList.isEmpty) return;

    final seriesCount = seriesList.length;
    final yRange = yScale.niceMax - yScale.niceMin;
    if (yRange <= 0) return;

    for (var catIdx = 0; catIdx < categoryCount; catIdx++) {
      for (var sIdx = 0; sIdx < seriesCount; sIdx++) {
        final series = seriesList[sIdx];
        if (catIdx >= series.dataPoints.length) continue;

        final value = series.dataPoints[catIdx].y;
        final (barLeft, barWidth) = computeColumnGeometry(
          categoryIndex: catIdx,
          seriesIndex: sIdx,
          seriesCount: seriesCount,
          plotArea: plotArea,
          categoryCount: categoryCount,
          theme: theme,
        );

        final fullHeight =
            ((value - yScale.niceMin) / yRange) * plotArea.height;
        final animatedHeight = fullHeight * animationProgress;
        final barTop = plotArea.bottom - animatedHeight;

        final barRRect = RRect.fromLTRBAndCorners(
          barLeft,
          barTop,
          barLeft + barWidth,
          plotArea.bottom,
          topLeft: Radius.circular(theme.barBorderRadiusPx),
          topRight: Radius.circular(theme.barBorderRadiusPx),
        );

        _fillPaint.color = _columnBarColor(series.color, catIdx);
        canvas.drawRRect(barRRect, _fillPaint);
      }
    }
  }

  /// Returns column bar color based on hover state.
  Color _columnBarColor(Color baseColor, int categoryIndex) {
    if (hoveredXIndex == null) return baseColor;
    if (categoryIndex == hoveredXIndex) return baseColor;
    return baseColor.withValues(alpha: theme.barDimmedOpacity);
  }

  /// Draws area fill (does not include the line).
  void _drawAreaSeries(
    Canvas canvas,
    Rect plotArea,
    int categoryCount,
    List<ChartSeries> seriesList,
    NiceScale yScale,
  ) {
    // Animation clip (left-to-right reveal)
    canvas.save();
    final clipRight = plotArea.left + plotArea.width * animationProgress;
    canvas.clipRect(
      Rect.fromLTRB(
        plotArea.left, plotArea.top - 1, clipRight, plotArea.bottom + 1,
      ),
    );

    for (final series in seriesList.reversed) {
      final pixels = _seriesToPixels(series, plotArea, categoryCount, yScale);
      if (pixels.length < 2) continue;

      final upperPath = smoothCurve
          ? buildMonotoneCubicPath(pixels)
          : buildLinearPath(pixels);

      final areaPath = Path()
        ..addPath(upperPath, Offset.zero)
        ..lineTo(pixels.last.dx, plotArea.bottom)
        ..lineTo(pixels.first.dx, plotArea.bottom)
        ..close();

      _areaFillPaint.shader = ui.Gradient.linear(
        Offset(0, plotArea.top),
        Offset(0, plotArea.bottom),
        [
          series.color.withValues(alpha: theme.areaFillOpacity),
          series.color.withValues(alpha: 0.0),
        ],
      );

      canvas.drawPath(areaPath, _areaFillPaint);
    }

    canvas.restore();
  }

  /// Draws lines only (no fill).
  void _drawLineSeries(
    Canvas canvas,
    Rect plotArea,
    int categoryCount,
    List<ChartSeries> seriesList,
    NiceScale yScale,
  ) {
    // Animation clip (left-to-right reveal)
    canvas.save();
    final clipRight = plotArea.left + plotArea.width * animationProgress;
    canvas.clipRect(
      Rect.fromLTRB(
        plotArea.left, plotArea.top - 1, clipRight, plotArea.bottom + 1,
      ),
    );

    for (final series in seriesList) {
      final pixels = _seriesToPixels(series, plotArea, categoryCount, yScale);
      if (pixels.length < 2) continue;

      final linePath = smoothCurve
          ? buildMonotoneCubicPath(pixels)
          : buildLinearPath(pixels);

      _linePaint
        ..color = series.color
        ..strokeWidth = theme.areaLineWidthPx;

      canvas.drawPath(linePath, _linePaint);
    }

    canvas.restore();
  }

  // --- Coordinate conversion ---

  /// Converts series data points to pixel coordinates.
  /// X coordinates are placed at the center of each category slot.
  List<Offset> _seriesToPixels(
    ChartSeries series,
    Rect plotArea,
    int categoryCount,
    NiceScale yScale,
  ) {
    final slotWidth = plotArea.width / categoryCount;
    final yRange = yScale.niceMax - yScale.niceMin;
    if (yRange <= 0) return const [];

    return [
      for (var i = 0; i < series.dataPoints.length; i++)
        Offset(
          plotArea.left + slotWidth * (i + 0.5),
          plotArea.bottom -
              (series.dataPoints[i].y - yScale.niceMin) /
                  yRange *
                  plotArea.height,
        ),
    ];
  }

  // --- Hover rendering ---

  void _drawCrosshair(Canvas canvas, Rect plotArea, int categoryCount) {
    final slotWidth = plotArea.width / categoryCount;
    final x = plotArea.left + slotWidth * (hoveredXIndex! + 0.5);

    _crosshairPaint
      ..color = theme.areaCrosshairColor
      ..strokeWidth = theme.areaCrosshairWidthPx;

    const dashPx = 4.0;
    const gapPx = 4.0;
    var y = plotArea.top;
    while (y < plotArea.bottom) {
      final endY = min(y + dashPx, plotArea.bottom);
      canvas.drawLine(Offset(x, y), Offset(x, endY), _crosshairPaint);
      y += dashPx + gapPx;
    }
  }

  void _drawHoverDots(Canvas canvas, Rect plotArea, int categoryCount) {
    // Dots for left axis series (line / area only)
    if (leftChartType != DualAxesChartType.column) {
      _drawDotsForSeries(
        canvas, plotArea, categoryCount, leftSeriesList, leftYScale,
      );
    }
    // Dots for right axis series (line / area only)
    if (rightChartType != DualAxesChartType.column) {
      _drawDotsForSeries(
        canvas, plotArea, categoryCount, rightSeriesList, rightYScale,
      );
    }
  }

  void _drawDotsForSeries(
    Canvas canvas,
    Rect plotArea,
    int categoryCount,
    List<ChartSeries> seriesList,
    NiceScale yScale,
  ) {
    for (final series in seriesList) {
      if (hoveredXIndex! >= series.dataPoints.length) continue;

      final pixels = _seriesToPixels(series, plotArea, categoryCount, yScale);
      final pixel = pixels[hoveredXIndex!];
      final radius = theme.areaPointHoverRadiusPx;

      _dotFillPaint.color = Colors.white;
      canvas.drawCircle(pixel, radius, _dotFillPaint);
      _dotStrokePaint.color = series.color;
      canvas.drawCircle(pixel, radius, _dotStrokePaint);
    }
  }

  /// Draws the X axis title horizontally (below labels, centered).
  void _drawXAxisTitle(Canvas canvas, Rect plotArea) {
    if (!_hasXAxisTitle) return;

    final painter = TextPainter(
      text: TextSpan(text: xAxisTitle!, style: resolveStyle(theme.axisTitleStyle)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final x = plotArea.left + (plotArea.width - painter.width) / 2;
    final y = plotArea.bottom + (theme.showXAxisLabels ? 22.0 : 4.0);
    painter.paint(canvas, Offset(x, y));
  }

  /// Draws the left Y axis title rotated -90 degrees.
  /// If series exist, displays a chart-type-specific color indicator before the text.
  void _drawLeftYAxisTitle(Canvas canvas, Rect plotArea) {
    if (!_hasLeftYAxisTitle) return;

    final textPainter = TextPainter(
      text: TextSpan(text: leftYAxisTitle!, style: resolveStyle(theme.axisTitleStyle)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final hasIndicator = leftSeriesList.isNotEmpty;
    final indicatorWidth = hasIndicator ? _indicatorWidthFor(leftChartType) : 0.0;
    final gap = hasIndicator ? 4.0 : 0.0;
    final totalWidth = indicatorWidth + gap + textPainter.width;

    canvas.save();
    final centerY = plotArea.top + plotArea.height / 2;
    canvas.translate(textPainter.height / 2 + 2, centerY);
    canvas.rotate(-pi / 2);

    final startX = -totalWidth / 2;
    if (hasIndicator) {
      _drawChartTypeIndicator(
        canvas, startX, 0, leftChartType, leftSeriesList.first.color,
      );
    }
    textPainter.paint(
      canvas, Offset(startX + indicatorWidth + gap, -textPainter.height / 2),
    );
    canvas.restore();
  }

  /// Draws the right Y axis title rotated +90 degrees.
  /// If series exist, displays a chart-type-specific color indicator before the text.
  void _drawRightYAxisTitle(Canvas canvas, Rect plotArea) {
    if (!_hasRightYAxisTitle) return;

    final textPainter = TextPainter(
      text: TextSpan(text: rightYAxisTitle!, style: resolveStyle(theme.axisTitleStyle)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final hasIndicator = rightSeriesList.isNotEmpty;
    final indicatorWidth = hasIndicator ? _indicatorWidthFor(rightChartType) : 0.0;
    final gap = hasIndicator ? 4.0 : 0.0;
    final totalWidth = indicatorWidth + gap + textPainter.width;

    canvas.save();
    final centerY = plotArea.top + plotArea.height / 2;
    final basePadding =
        theme.showYAxisLabels ? _defaultRightPaddingPx : _reducedRightPaddingPx;
    final titleX = plotArea.right + basePadding - 2;
    canvas.translate(titleX, centerY);
    canvas.rotate(pi / 2);

    final startX = -totalWidth / 2;
    if (hasIndicator) {
      _drawChartTypeIndicator(
        canvas, startX, 0, rightChartType, rightSeriesList.first.color,
      );
    }
    textPainter.paint(
      canvas, Offset(startX + indicatorWidth + gap, -textPainter.height / 2),
    );
    canvas.restore();
  }

  /// Returns indicator width based on chart type.
  double _indicatorWidthFor(DualAxesChartType type) {
    return type == DualAxesChartType.line ? 12.0 : 8.0;
  }

  /// Draws a chart-type-specific color indicator.
  /// [centerY] is the vertical center in rotated Canvas coordinates.
  void _drawChartTypeIndicator(
    Canvas canvas,
    double x,
    double centerY,
    DualAxesChartType type,
    Color color,
  ) {
    switch (type) {
      case DualAxesChartType.line:
        // Short horizontal line (12px wide, 2.0 stroke)
        canvas.drawLine(
          Offset(x, centerY),
          Offset(x + 12.0, centerY),
          Paint()
            ..color = color
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      case DualAxesChartType.column:
      case DualAxesChartType.area:
        // Filled rectangle (8x6px)
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x + 4.0, centerY), width: 8.0, height: 6.0),
          Paint()..color = color,
        );
    }
  }

  @override
  bool shouldRepaint(covariant DualAxesPainter oldDelegate) {
    return baseTextStyle != oldDelegate.baseTextStyle ||
        leftSeriesList != oldDelegate.leftSeriesList ||
        rightSeriesList != oldDelegate.rightSeriesList ||
        leftYScale != oldDelegate.leftYScale ||
        rightYScale != oldDelegate.rightYScale ||
        leftChartType != oldDelegate.leftChartType ||
        rightChartType != oldDelegate.rightChartType ||
        smoothCurve != oldDelegate.smoothCurve ||
        animationProgress != oldDelegate.animationProgress ||
        hoveredXIndex != oldDelegate.hoveredXIndex ||
        xAxisTitle != oldDelegate.xAxisTitle ||
        leftYAxisTitle != oldDelegate.leftYAxisTitle ||
        rightYAxisTitle != oldDelegate.rightYAxisTitle ||
        leftUnit != oldDelegate.leftUnit ||
        leftUnitPosition != oldDelegate.leftUnitPosition ||
        leftValueScale != oldDelegate.leftValueScale ||
        rightUnit != oldDelegate.rightUnit ||
        rightUnitPosition != oldDelegate.rightUnitPosition ||
        rightValueScale != oldDelegate.rightValueScale ||
        leftUseThousandsSeparator != oldDelegate.leftUseThousandsSeparator ||
        rightUseThousandsSeparator != oldDelegate.rightUseThousandsSeparator;
  }
}

// --- Hit testing ---

/// Returns the nearest X index from the hover position.
/// Returns null if outside the plot area.
int? hitTestDualAxes({
  required Offset localPosition,
  required Size size,
  required List<ChartSeries> leftSeriesList,
  required List<ChartSeries> rightSeriesList,
  ChartTheme? theme,
  String? xAxisTitle,
  String? leftYAxisTitle,
  String? rightYAxisTitle,
}) {
  final hasXTitle = (theme?.showXAxisTitle ?? false) &&
      xAxisTitle != null &&
      xAxisTitle.isNotEmpty;
  final hasLeftYTitle = (theme?.showYAxisTitle ?? false) &&
      leftYAxisTitle != null &&
      leftYAxisTitle.isNotEmpty;
  final hasRightYTitle = (theme?.showYAxisTitle ?? false) &&
      rightYAxisTitle != null &&
      rightYAxisTitle.isNotEmpty;

  double leftPadding =
      theme?.showYAxisLabels ?? true ? _defaultLeftPaddingPx : _reducedLeftPaddingPx;
  if (hasLeftYTitle) leftPadding += _axisTitlePaddingPx;
  double bottomPadding =
      theme?.showXAxisLabels ?? true ? _defaultBottomPaddingPx : _reducedBottomPaddingPx;
  if (hasXTitle) bottomPadding += _axisTitlePaddingPx;
  double rightPadding =
      theme?.showYAxisLabels ?? true ? _defaultRightPaddingPx : _reducedRightPaddingPx;
  if (hasRightYTitle) rightPadding += _axisTitlePaddingPx;

  final plotArea = Rect.fromLTRB(
    leftPadding,
    _topPaddingPx,
    size.width - rightPadding,
    size.height - bottomPadding,
  );

  if (!plotArea.contains(localPosition)) return null;

  final leftCount = leftSeriesList.isNotEmpty
      ? leftSeriesList.first.dataPoints.length
      : 0;
  final rightCount = rightSeriesList.isNotEmpty
      ? rightSeriesList.first.dataPoints.length
      : 0;
  final categoryCount = max(leftCount, rightCount);
  if (categoryCount == 0) return null;

  final slotWidth = plotArea.width / categoryCount;
  return ((localPosition.dx - plotArea.left) / slotWidth)
      .floor()
      .clamp(0, categoryCount - 1);
}
