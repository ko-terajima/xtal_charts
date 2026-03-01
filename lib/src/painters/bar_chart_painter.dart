import 'dart:math';

import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../theme/chart_theme.dart';
import '../utils/nice_numbers.dart';
import 'chart_painter.dart';
import '../utils/value_formatter.dart';

/// Padding for bar chart rendering (px).
const _defaultLeftPaddingPx = 48.0;
const _reducedLeftPaddingPx = 12.0;
const _reducedBottomPaddingPx = 8.0;
const _topPaddingPx = 16.0;
const _rightPaddingPx = 16.0;

// --- Shared label measurement helpers ---

/// Measures the rendered line height of a text style.
double measureTextHeight(TextStyle style, {TextStyle? baseTextStyle}) {
  final resolved = baseTextStyle?.merge(style) ?? style;
  final p = TextPainter(
    text: TextSpan(text: 'X', style: resolved),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return p.height;
}

/// Measures the maximum rendered width of Y-axis tick labels.
/// Used by both [BarChartPainter] and [hitTestBarChart] to compute
/// consistent left padding.
double measureMaxYAxisLabelWidth({
  required NiceScale yScale,
  required ChartTheme theme,
  TextStyle? baseTextStyle,
  String? unit,
  UnitPosition unitPosition = UnitPosition.suffix,
  ValueScale valueScale = ValueScale.none,
  bool useThousandsSeparator = true,
}) {
  final style = baseTextStyle?.merge(theme.labelStyle) ?? theme.labelStyle;
  double maxWidth = 0;
  for (final tick in yScale.ticks) {
    final text = formatChartValue(
      tick,
      unit: unit,
      unitPosition: unitPosition,
      valueScale: valueScale,
      useThousandsSeparator: useThousandsSeparator,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    maxWidth = max(maxWidth, painter.width);
  }
  return maxWidth;
}

/// Measures the maximum rendered width of X-axis category labels.
/// Used when labels are rotated to compute bottom padding.
double measureMaxXAxisLabelWidth({
  required List<ChartSeries> seriesList,
  required ChartTheme theme,
  TextStyle? baseTextStyle,
}) {
  if (seriesList.isEmpty) return 0;
  final style = baseTextStyle?.merge(theme.labelStyle) ?? theme.labelStyle;
  final dataPoints = seriesList.first.dataPoints;
  double maxWidth = 0;
  for (final dp in dataPoints) {
    final text = dp.label ?? dp.x.toString();
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    maxWidth = max(maxWidth, painter.width);
  }
  return maxWidth;
}

/// Painter that renders an Ant Design Charts style bar chart on the Canvas.
///
/// Draws grouped vertical bars for each series.
/// Supports rounded top corners, hover highlight, and bottom-to-top growth animation.
class BarChartPainter extends BaseChartPainter {
  final List<ChartSeries> seriesList;
  final NiceScale yScale;

  /// Progress of the bottom-to-top bar growth animation (0.0 to 1.0).
  final double animationProgress;

  /// X index of the hovered category.
  final int? hoveredCategoryIndex;

  /// Hovered series index (which bar within the group).
  final int? hoveredSeriesIndex;

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

  /// Whether to rotate X-axis labels vertically (-90 degrees).
  final bool rotateXAxisLabels;

  /// Reusable Paint (for background).
  final Paint _bgPaint = Paint();

  /// Reusable Paint (for bar fill).
  final Paint _fillPaint = Paint();

  /// Cached maximum Y-axis label width.
  late final double _maxYLabelWidth = _computeMaxYLabelWidth();

  /// Cached maximum X-axis label width (for rotated labels).
  late final double _maxXLabelWidth = _computeMaxXLabelWidth();

  /// Cached label text line height.
  late final double _labelTextHeight =
      measureTextHeight(theme.labelStyle, baseTextStyle: baseTextStyle);

  /// Cached axis title text line height (= visual width when rotated for Y-axis).
  late final double _axisTitleTextHeight =
      measureTextHeight(theme.axisTitleStyle, baseTextStyle: baseTextStyle);

  BarChartPainter({
    required this.seriesList,
    required this.yScale,
    required super.theme,
    super.baseTextStyle,
    this.animationProgress = 1.0,
    this.hoveredCategoryIndex,
    this.hoveredSeriesIndex,
    this.xAxisTitle,
    this.yAxisTitle,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
    this.rotateXAxisLabels = false,
  });

  double _computeMaxYLabelWidth() {
    if (!theme.showYAxisLabels) return 0;
    return measureMaxYAxisLabelWidth(
      yScale: yScale,
      theme: theme,
      baseTextStyle: baseTextStyle,
      unit: unit,
      unitPosition: unitPosition,
      valueScale: valueScale,
      useThousandsSeparator: useThousandsSeparator,
    );
  }

  double _computeMaxXLabelWidth() {
    if (!theme.showXAxisLabels || !rotateXAxisLabels) return 0;
    return measureMaxXAxisLabelWidth(
      seriesList: seriesList,
      theme: theme,
      baseTextStyle: baseTextStyle,
    );
  }

  /// Whether the X-axis title display condition is met.
  bool get _hasXAxisTitle =>
      theme.showXAxisTitle && xAxisTitle != null && xAxisTitle!.isNotEmpty;

  /// Whether the Y-axis title display condition is met.
  bool get _hasYAxisTitle =>
      theme.showYAxisTitle && yAxisTitle != null && yAxisTitle!.isNotEmpty;

  /// Right edge of the Y-axis label area.
  /// When Y title is shown, includes title width so that the gap between
  /// the title right edge and the widest label left edge is exactly 4px.
  ///
  /// Layout (left to right):
  ///   [2px margin][title (height=_axisTitleTextHeight)][4px gap][labels][6px margin to axis]
  double get _yLabelAreaRight {
    if (!theme.showYAxisLabels) return _reducedLeftPaddingPx;
    double base = _maxYLabelWidth + 12; // 6px left margin + label + 6px right margin
    if (_hasYAxisTitle) base += _axisTitleTextHeight; // shift labels right by title width
    return base;
  }

  double get _leftPadding => _yLabelAreaRight;

  /// Bottom padding computed from actual text measurements.
  ///
  /// Layout (top to bottom from plotArea.bottom):
  ///   [6px gap][labels][4px gap][title][4px bottom margin]
  double get _bottomPadding {
    double height = 4; // bottom margin
    if (_hasXAxisTitle) {
      height += _axisTitleTextHeight + 4; // title height + 4px gap above
    }
    if (theme.showXAxisLabels) {
      height += 6; // gap from axis line to labels
      height += rotateXAxisLabels ? _maxXLabelWidth : _labelTextHeight;
    }
    return max(height, _reducedBottomPaddingPx);
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
    final categoryCount = seriesList.first.dataPoints.length;
    if (categoryCount == 0) return;

    // Background
    _bgPaint.color = theme.backgroundColor;
    canvas.drawRect(Offset.zero & size, _bgPaint);

    // Dashed grid lines
    final gridLineCount = yScale.tickCount - 1;
    if (gridLineCount > 0) {
      drawDashedGridLines(canvas, plotArea, gridLineCount);
    }

    if (theme.showYAxisLabels) {
      _drawYAxisLabels(canvas, plotArea);
    }
    if (theme.showXAxisLabels) {
      _drawXAxisLabels(canvas, plotArea, categoryCount);
    }
    _drawXAxisTitle(canvas, plotArea);
    _drawYAxisTitle(canvas, plotArea);
    drawAxes(canvas, plotArea);
    _drawBars(canvas, plotArea, categoryCount);
  }

  /// Draws the bars.
  void _drawBars(Canvas canvas, Rect plotArea, int categoryCount) {
    final seriesCount = seriesList.length;
    final yRange = yScale.niceMax - yScale.niceMin;
    if (yRange <= 0) return;

    for (var catIdx = 0; catIdx < categoryCount; catIdx++) {
      for (var sIdx = 0; sIdx < seriesCount; sIdx++) {
        final series = seriesList[sIdx];
        if (catIdx >= series.dataPoints.length) continue;

        final value = series.dataPoints[catIdx].y;
        final (barLeft, barWidth) = _barGeometry(
          categoryIndex: catIdx,
          seriesIndex: sIdx,
          seriesCount: seriesCount,
          plotArea: plotArea,
          categoryCount: categoryCount,
        );

        // Animation: grow upward from baseline
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

        _fillPaint.color = _barColor(series.color, catIdx, sIdx);
        canvas.drawRRect(barRRect, _fillPaint);
      }
    }
  }

  /// Returns the bar color based on hover state.
  Color _barColor(Color baseColor, int categoryIndex, int seriesIndex) {
    if (hoveredCategoryIndex == null) return baseColor;

    if (categoryIndex == hoveredCategoryIndex &&
        seriesIndex == hoveredSeriesIndex) {
      return _brighten(baseColor, theme.barHoverBrightnessBoost);
    }
    if (categoryIndex == hoveredCategoryIndex) return baseColor;

    // Dim bars in other categories
    return baseColor.withValues(alpha: theme.barDimmedOpacity);
  }

  /// Returns a brighter color by increasing HSL lightness.
  Color _brighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Computes the left X coordinate and width of an individual bar within a category.
  (double barLeft, double barWidth) _barGeometry({
    required int categoryIndex,
    required int seriesIndex,
    required int seriesCount,
    required Rect plotArea,
    required int categoryCount,
  }) {
    return computeBarGeometry(
      categoryIndex: categoryIndex,
      seriesIndex: seriesIndex,
      seriesCount: seriesCount,
      plotArea: plotArea,
      categoryCount: categoryCount,
      theme: theme,
    );
  }

  /// Draws Y-axis tick labels.
  void _drawYAxisLabels(Canvas canvas, Rect plotArea) {
    for (final tick in yScale.ticks) {
      final y = plotArea.bottom -
          (tick - yScale.niceMin) /
              (yScale.niceMax - yScale.niceMin) *
              plotArea.height;

      final text = formatChartValue(tick, unit: unit, unitPosition: unitPosition, valueScale: valueScale, useThousandsSeparator: useThousandsSeparator);
      final painter = TextPainter(
        text: TextSpan(text: text, style: resolveStyle(theme.labelStyle)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        maxLines: 1,
      )..layout();

      painter.paint(
        canvas,
        Offset(_yLabelAreaRight - painter.width - 6, y - painter.height / 2),
      );
    }
  }

  /// Draws X-axis category labels. Automatically thins them out to avoid overlap.
  void _drawXAxisLabels(Canvas canvas, Rect plotArea, int categoryCount) {
    final dataPoints = seriesList.first.dataPoints;
    if (dataPoints.isEmpty) return;

    final slotWidth = plotArea.width / categoryCount;

    if (rotateXAxisLabels) {
      // Rotated labels: use text height as horizontal footprint
      final labelStyle = resolveStyle(theme.labelStyle);
      final labelHeight = _labelTextHeight;

      // Thin out based on text height (rotated label horizontal width)
      final maxLabels =
          (plotArea.width / (labelHeight + 4)).floor().clamp(2, categoryCount);
      final step =
          (categoryCount / maxLabels).ceil().clamp(1, categoryCount);

      for (var i = 0; i < categoryCount; i += step) {
        final label = dataPoints[i].label ?? dataPoints[i].x.toString();
        final centerX = plotArea.left + slotWidth * (i + 0.5);

        final painter = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        canvas.save();
        canvas.translate(centerX, plotArea.bottom + 6);
        canvas.rotate(-pi / 2);
        painter.paint(canvas, Offset(-painter.width, -painter.height / 2));
        canvas.restore();
      }
    } else {
      // Horizontal labels (default)
      // Thin out labels, allocating about 60px width per label
      final maxLabels =
          (plotArea.width / 60).floor().clamp(2, categoryCount);
      final step =
          (categoryCount / maxLabels).ceil().clamp(1, categoryCount);

      for (var i = 0; i < categoryCount; i += step) {
        final label = dataPoints[i].label ?? dataPoints[i].x.toString();
        final centerX = plotArea.left + slotWidth * (i + 0.5);

        final painter = TextPainter(
          text: TextSpan(text: label, style: resolveStyle(theme.labelStyle)),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
        )..layout();

        painter.paint(
          canvas,
          Offset(centerX - painter.width / 2, plotArea.bottom + 6),
        );
      }
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
    final double labelOffset;
    if (theme.showXAxisLabels) {
      final xLabelHeight = rotateXAxisLabels ? _maxXLabelWidth : _labelTextHeight;
      labelOffset = 6 + xLabelHeight + 4; // 6px axis gap + label height + 4px gap
    } else {
      labelOffset = 4.0;
    }
    final y = plotArea.bottom + labelOffset;
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
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return baseTextStyle != oldDelegate.baseTextStyle ||
        seriesList != oldDelegate.seriesList ||
        yScale != oldDelegate.yScale ||
        animationProgress != oldDelegate.animationProgress ||
        hoveredCategoryIndex != oldDelegate.hoveredCategoryIndex ||
        hoveredSeriesIndex != oldDelegate.hoveredSeriesIndex ||
        xAxisTitle != oldDelegate.xAxisTitle ||
        yAxisTitle != oldDelegate.yAxisTitle ||
        unit != oldDelegate.unit ||
        unitPosition != oldDelegate.unitPosition ||
        valueScale != oldDelegate.valueScale ||
        useThousandsSeparator != oldDelegate.useThousandsSeparator ||
        rotateXAxisLabels != oldDelegate.rotateXAxisLabels;
  }
}

// --- Bar layout calculation (shared by Painter and hitTest) ---

/// Computes the left X coordinate and width of an individual bar within a category.
/// Uses the same logic for both Painter and hitTest.
(double barLeft, double barWidth) computeBarGeometry({
  required int categoryIndex,
  required int seriesIndex,
  required int seriesCount,
  required Rect plotArea,
  required int categoryCount,
  required ChartTheme theme,
}) {
  final slotWidth = plotArea.width / categoryCount;
  final groupWidth = slotWidth * (1 - theme.barCategoryGapRatio);
  final totalGaps = max(0, seriesCount - 1) * theme.barGroupGapPx;
  var barWidth = (groupWidth - totalGaps) / seriesCount;
  barWidth = barWidth.clamp(1.0, theme.barMaxWidthPx);

  final actualGroupWidth = barWidth * seriesCount + totalGaps;
  final slotCenterX = plotArea.left + slotWidth * (categoryIndex + 0.5);
  final groupLeft = slotCenterX - actualGroupWidth / 2;
  final barLeft = groupLeft + seriesIndex * (barWidth + theme.barGroupGapPx);

  return (barLeft, barWidth);
}

// --- Hit test ---

/// Returns the category index and series index of the bar at the hover position.
/// Returns null if outside the plot area.
({int categoryIndex, int seriesIndex})? hitTestBarChart({
  required Offset localPosition,
  required Size size,
  required List<ChartSeries> seriesList,
  required ChartTheme theme,
  String? xAxisTitle,
  String? yAxisTitle,
  NiceScale? yScale,
  TextStyle? baseTextStyle,
  String? unit,
  UnitPosition unitPosition = UnitPosition.suffix,
  ValueScale valueScale = ValueScale.none,
  bool useThousandsSeparator = true,
  bool rotateXAxisLabels = false,
}) {
  if (seriesList.isEmpty) return null;

  final hasXTitle = theme.showXAxisTitle &&
      xAxisTitle != null &&
      xAxisTitle.isNotEmpty;
  final hasYTitle = theme.showYAxisTitle &&
      yAxisTitle != null &&
      yAxisTitle.isNotEmpty;

  final labelH = measureTextHeight(theme.labelStyle, baseTextStyle: baseTextStyle);
  final titleH = measureTextHeight(theme.axisTitleStyle, baseTextStyle: baseTextStyle);

  // Dynamic left padding matching BarChartPainter._leftPadding
  double leftPadding;
  if (!theme.showYAxisLabels) {
    leftPadding = _reducedLeftPaddingPx;
  } else if (yScale != null) {
    final maxLabelWidth = measureMaxYAxisLabelWidth(
      yScale: yScale,
      theme: theme,
      baseTextStyle: baseTextStyle,
      unit: unit,
      unitPosition: unitPosition,
      valueScale: valueScale,
      useThousandsSeparator: useThousandsSeparator,
    );
    leftPadding = maxLabelWidth + 12;
    if (hasYTitle) leftPadding += titleH;
  } else {
    leftPadding = _defaultLeftPaddingPx;
  }

  // Dynamic bottom padding matching BarChartPainter._bottomPadding
  double bottomPadding = 4; // bottom margin
  if (hasXTitle) {
    bottomPadding += titleH + 4;
  }
  if (theme.showXAxisLabels) {
    bottomPadding += 6; // gap from axis line to labels
    if (rotateXAxisLabels) {
      bottomPadding += measureMaxXAxisLabelWidth(
        seriesList: seriesList,
        theme: theme,
        baseTextStyle: baseTextStyle,
      );
    } else {
      bottomPadding += labelH;
    }
  }
  bottomPadding = max(bottomPadding, _reducedBottomPaddingPx);

  final plotArea = Rect.fromLTRB(
    leftPadding,
    _topPaddingPx,
    size.width - _rightPaddingPx,
    size.height - bottomPadding,
  );

  if (!plotArea.contains(localPosition)) return null;

  final categoryCount = seriesList.first.dataPoints.length;
  if (categoryCount == 0) return null;

  final seriesCount = seriesList.length;
  final slotWidth = plotArea.width / categoryCount;

  // Determine which category slot the cursor is in
  final categoryIndex =
      ((localPosition.dx - plotArea.left) / slotWidth).floor().clamp(
            0,
            categoryCount - 1,
          );

  // Check each bar boundary within the slot
  for (var sIdx = 0; sIdx < seriesCount; sIdx++) {
    final (barLeft, barWidth) = computeBarGeometry(
      categoryIndex: categoryIndex,
      seriesIndex: sIdx,
      seriesCount: seriesCount,
      plotArea: plotArea,
      categoryCount: categoryCount,
      theme: theme,
    );

    if (localPosition.dx >= barLeft &&
        localPosition.dx <= barLeft + barWidth) {
      return (categoryIndex: categoryIndex, seriesIndex: sIdx);
    }
  }

  // In the gap between bars but within the same category slot; return nearest series
  return (
    categoryIndex: categoryIndex,
    seriesIndex: _nearestSeriesIndex(
      localPosition.dx,
      categoryIndex,
      seriesCount,
      plotArea,
      categoryCount,
      theme,
    ),
  );
}

/// Returns the series index closest to the cursor X coordinate.
int _nearestSeriesIndex(
  double cursorX,
  int categoryIndex,
  int seriesCount,
  Rect plotArea,
  int categoryCount,
  ChartTheme theme,
) {
  var nearestIdx = 0;
  var minDist = double.infinity;

  for (var sIdx = 0; sIdx < seriesCount; sIdx++) {
    final (barLeft, barWidth) = computeBarGeometry(
      categoryIndex: categoryIndex,
      seriesIndex: sIdx,
      seriesCount: seriesCount,
      plotArea: plotArea,
      categoryCount: categoryCount,
      theme: theme,
    );
    final barCenter = barLeft + barWidth / 2;
    final dist = (cursorX - barCenter).abs();
    if (dist < minDist) {
      minDist = dist;
      nearestIdx = sIdx;
    }
  }

  return nearestIdx;
}
