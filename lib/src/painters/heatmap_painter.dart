import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/heatmap_data.dart';
import '../models/legend_position.dart';
import '../theme/chart_theme.dart';
import '../utils/color_scale.dart';
import '../utils/value_formatter.dart';
import 'chart_painter.dart';

/// Default padding (px) for heatmap rendering.
/// Extra left padding for category labels, extra bottom padding for the legend.
const _defaultLeftPaddingPx = 64.0;
const _defaultBottomPaddingPx = 48.0;
const _topPaddingPx = 16.0;
const _rightPaddingPx = 16.0;

/// Reduced padding when axis labels are hidden.
/// Wider than other charts because heatmap category labels tend to be long.
const _reducedLeftPaddingPx = 16.0;

/// Reserve space at the bottom for the color legend.
const _reducedBottomPaddingPx = 32.0;

/// Additional padding (px) when axis titles are shown.
const _axisTitlePaddingPx = 20.0;

/// Painter that renders an Ant Design Charts-style heatmap on a Canvas.
///
/// A grid chart where both X and Y axes are categories and values are
/// represented by color intensity. Supports hover highlighting, fade-in
/// animation, and a color legend.
class HeatmapPainter extends BaseChartPainter {
  final HeatmapData data;
  final HeatmapColorScale colorScale;

  /// Minimum value used for normalization.
  final double valueMin;

  /// Maximum value used for normalization.
  final double valueMax;

  /// Fade-in animation progress (0.0 to 1.0).
  final double animationProgress;

  /// X index of the currently hovered cell.
  final int? hoveredXIndex;

  /// Y index of the currently hovered cell.
  final int? hoveredYIndex;

  /// Position of the color legend.
  final LegendPosition colorLegendPosition;

  /// X-axis title text.
  final String? xAxisTitle;

  /// Y-axis title text.
  final String? yAxisTitle;

  /// Unit string for values (e.g. "%", "USD").
  final String? unit;

  /// Display position of the unit string.
  final UnitPosition unitPosition;

  /// Scaling applied to display values.
  final ValueScale valueScale;

  /// Whether to use thousands separator commas.
  final bool useThousandsSeparator;

  /// Minimum value shown on the legend bar.
  final double displayMinValue;

  /// Reusable Paint for the background.
  final Paint _bgPaint = Paint();

  /// Reusable Paint for cell fills.
  final Paint _cellPaint = Paint();

  /// Reusable Paint for hover borders.
  final Paint _borderPaint = Paint()..style = PaintingStyle.stroke;

  HeatmapPainter({
    required this.data,
    required this.colorScale,
    required this.valueMin,
    required this.valueMax,
    required super.theme,
    super.baseTextStyle,
    this.animationProgress = 1.0,
    this.hoveredXIndex,
    this.hoveredYIndex,
    this.colorLegendPosition = LegendPosition.bottom,
    this.xAxisTitle,
    this.yAxisTitle,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
    this.displayMinValue = 0.0,
  });

  /// Whether the X-axis title should be displayed.
  bool get _hasXAxisTitle =>
      theme.showXAxisTitle && xAxisTitle != null && xAxisTitle!.isNotEmpty;

  /// Whether the Y-axis title should be displayed.
  bool get _hasYAxisTitle =>
      theme.showYAxisTitle && yAxisTitle != null && yAxisTitle!.isNotEmpty;

  /// Left padding adjusted based on Y-axis label visibility.
  double get _leftPadding {
    double base =
        theme.showYAxisLabels ? _defaultLeftPaddingPx : _reducedLeftPaddingPx;
    if (colorLegendPosition == LegendPosition.left) base += 32.0;
    if (_hasYAxisTitle) base += _axisTitlePaddingPx;
    return base;
  }

  /// Bottom padding adjusted based on X-axis label visibility.
  double get _bottomPadding {
    double base =
        theme.showXAxisLabels ? _defaultBottomPaddingPx : _reducedBottomPaddingPx;
    // Space for the bottom color legend is already included in base (default placement).
    // When the legend is placed elsewhere, reduce the reserved space.
    if (colorLegendPosition != LegendPosition.bottom) {
      base -= 16.0;
      if (base < 8.0) base = 8.0;
    }
    if (_hasXAxisTitle) base += _axisTitlePaddingPx;
    return base;
  }

  /// Top padding adjusted based on color legend position.
  double get _topPadding =>
      colorLegendPosition == LegendPosition.top ? 40.0 : _topPaddingPx;

  /// Right padding adjusted based on color legend position.
  double get _rightPadding =>
      colorLegendPosition == LegendPosition.right ? 48.0 : _rightPaddingPx;

  @override
  Rect calculatePlotArea(Size canvasSize) {
    return Rect.fromLTRB(
      _leftPadding,
      _topPadding,
      canvasSize.width - _rightPadding,
      canvasSize.height - _bottomPadding,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.xCount == 0 || data.yCount == 0) return;

    final plotArea = calculatePlotArea(size);

    // Background
    _bgPaint.color = theme.backgroundColor;
    canvas.drawRect(Offset.zero & size, _bgPaint);

    _drawCells(canvas, plotArea);
    if (theme.showYAxisLabels) {
      _drawYAxisLabels(canvas, plotArea);
    }
    if (theme.showXAxisLabels) {
      _drawXAxisLabels(canvas, plotArea);
    }
    _drawXAxisTitle(canvas, plotArea);
    _drawYAxisTitle(canvas, plotArea);
    _drawColorLegend(canvas, plotArea);
  }

  /// Draws the cell grid.
  void _drawCells(Canvas canvas, Rect plotArea) {
    final cellWidth = _cellWidth(plotArea);
    final cellHeight = _cellHeight(plotArea);
    final valueRange = valueMax - valueMin;
    final hasHover = hoveredXIndex != null && hoveredYIndex != null;

    for (var yIdx = 0; yIdx < data.yCount; yIdx++) {
      for (var xIdx = 0; xIdx < data.xCount; xIdx++) {
        final value = data.values[yIdx][xIdx];
        if (value == null) continue;

        final left =
            plotArea.left + xIdx * (cellWidth + theme.heatmapCellGapPx);
        final top =
            plotArea.top + yIdx * (cellHeight + theme.heatmapCellGapPx);

        final normalizedValue =
            valueRange > 0 ? (value - valueMin) / valueRange : 0.5;
        final cellColor = colorScale.colorAt(normalizedValue);

        // Animation opacity + hover dimming
        final isHovered = hoveredXIndex == xIdx && hoveredYIndex == yIdx;
        var opacity = animationProgress;
        if (hasHover && !isHovered) {
          opacity *= theme.heatmapDimmedOpacity;
        }

        final cellRRect = RRect.fromLTRBR(
          left,
          top,
          left + cellWidth,
          top + cellHeight,
          Radius.circular(theme.heatmapCellBorderRadiusPx),
        );

        // Cell fill
        _cellPaint.color = cellColor.withValues(alpha: opacity);
        canvas.drawRRect(cellRRect, _cellPaint);

        // Hover border
        if (isHovered) {
          _borderPaint
            ..color = theme.heatmapHoverBorderColor
            ..strokeWidth = theme.heatmapHoverBorderWidthPx;
          canvas.drawRRect(cellRRect, _borderPaint);
        }

        // Cell label (only when the cell is large enough)
        if (theme.showHeatmapCellLabels && cellWidth > 20 && cellHeight > 14) {
          _drawCellLabel(canvas, left, top, cellWidth, cellHeight, value);
        }
      }
    }
  }

  /// Draws a value label inside a cell.
  void _drawCellLabel(
    Canvas canvas,
    double left,
    double top,
    double cellWidth,
    double cellHeight,
    double value,
  ) {
    final text = formatChartValue(value, unit: unit, unitPosition: unitPosition, valueScale: valueScale, useThousandsSeparator: useThousandsSeparator);
    final painter = TextPainter(
      text: TextSpan(text: text, style: resolveStyle(theme.heatmapCellLabelStyle)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: cellWidth);

    painter.paint(
      canvas,
      Offset(
        left + (cellWidth - painter.width) / 2,
        top + (cellHeight - painter.height) / 2,
      ),
    );
  }

  /// Draws Y-axis category labels (left side, vertically centered per row).
  void _drawYAxisLabels(Canvas canvas, Rect plotArea) {
    final cellHeight = _cellHeight(plotArea);

    for (var yIdx = 0; yIdx < data.yCount; yIdx++) {
      final centerY =
          plotArea.top + yIdx * (cellHeight + theme.heatmapCellGapPx) +
              cellHeight / 2;

      final painter = TextPainter(
        text: TextSpan(
          text: data.yCategories[yIdx],
          style: resolveStyle(theme.labelStyle),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout(maxWidth: _defaultLeftPaddingPx - 8);

      painter.paint(
        canvas,
        Offset(_defaultLeftPaddingPx - painter.width - 6, centerY - painter.height / 2),
      );
    }
  }

  /// Draws X-axis category labels (bottom, centered per column, auto-thinned).
  void _drawXAxisLabels(Canvas canvas, Rect plotArea) {
    final cellWidth = _cellWidth(plotArea);

    // Auto-thinning: allocate roughly 40px width per label
    final maxLabels =
        (plotArea.width / 40).floor().clamp(2, data.xCount);
    final step = (data.xCount / maxLabels).ceil().clamp(1, data.xCount);

    for (var xIdx = 0; xIdx < data.xCount; xIdx += step) {
      final centerX =
          plotArea.left + xIdx * (cellWidth + theme.heatmapCellGapPx) +
              cellWidth / 2;

      final painter = TextPainter(
        text: TextSpan(
          text: data.xCategories[xIdx],
          style: resolveStyle(theme.labelStyle),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      painter.paint(
        canvas,
        Offset(centerX - painter.width / 2, plotArea.bottom + 4),
      );
    }
  }

  /// Draws the X-axis title horizontally (below the labels, centered).
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
    canvas.rotate(-3.1415926535 / 2);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  /// Draws the color legend, either horizontally or vertically based on position.
  void _drawColorLegend(Canvas canvas, Rect plotArea) {
    switch (colorLegendPosition) {
      case LegendPosition.bottom:
        _drawHorizontalColorLegend(canvas, plotArea, isTop: false);
      case LegendPosition.top:
        _drawHorizontalColorLegend(canvas, plotArea, isTop: true);
      case LegendPosition.left:
        _drawVerticalColorLegend(canvas, plotArea, isLeft: true);
      case LegendPosition.right:
        _drawVerticalColorLegend(canvas, plotArea, isLeft: false);
    }
  }

  /// Draws a horizontal color legend (top or bottom).
  void _drawHorizontalColorLegend(
    Canvas canvas,
    Rect plotArea, {
    required bool isTop,
  }) {
    final legendHeight = theme.heatmapLegendHeightPx;

    // Calculate label widths first to narrow the bar area
    final minPainter = TextPainter(
      text: TextSpan(
        text: formatChartValue(displayMinValue, unit: unit, unitPosition: unitPosition, valueScale: valueScale, useThousandsSeparator: useThousandsSeparator),
        style: resolveStyle(theme.labelStyle),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final maxPainter = TextPainter(
      text: TextSpan(
        text: formatChartValue(valueMax, unit: unit, unitPosition: unitPosition, valueScale: valueScale, useThousandsSeparator: useThousandsSeparator),
        style: resolveStyle(theme.labelStyle),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const gap = 8.0;
    final barLeft = plotArea.left + minPainter.width + gap;
    final barRight = plotArea.right - maxPainter.width - gap;
    final legendTop = isTop
        ? plotArea.top - legendHeight - 16
        : plotArea.bottom + 8;

    // Gradient bar
    final legendRect = RRect.fromLTRBR(
      barLeft,
      legendTop,
      barRight,
      legendTop + legendHeight,
      Radius.circular(legendHeight / 2),
    );

    final colors = colorScale.colorStops.map((s) => s.$2).toList();
    final stops = colorScale.colorStops.map((s) => s.$1).toList();

    _cellPaint.shader = ui.Gradient.linear(
      Offset(barLeft, 0),
      Offset(barRight, 0),
      colors,
      stops,
    );
    canvas.drawRRect(legendRect, _cellPaint);
    _cellPaint.shader = null;

    // Draw labels on either side of the bar (vertically centered)
    final labelY = legendTop + (legendHeight - minPainter.height) / 2;
    minPainter.paint(canvas, Offset(plotArea.left, labelY));
    maxPainter.paint(canvas, Offset(barRight + gap, labelY));
  }

  /// Draws a vertical color legend (left or right).
  void _drawVerticalColorLegend(
    Canvas canvas,
    Rect plotArea, {
    required bool isLeft,
  }) {
    final legendWidth = theme.heatmapLegendHeightPx;
    final legendLeft = isLeft
        ? plotArea.left - legendWidth - 16
        : plotArea.right + 12;

    // Layout labels first to determine their sizes
    final maxPainter = TextPainter(
      text: TextSpan(text: formatChartValue(valueMax, unit: unit, unitPosition: unitPosition, valueScale: valueScale, useThousandsSeparator: useThousandsSeparator), style: resolveStyle(theme.labelStyle)),
      textDirection: TextDirection.ltr,
    )..layout();
    final minPainter = TextPainter(
      text: TextSpan(text: formatChartValue(displayMinValue, unit: unit, unitPosition: unitPosition, valueScale: valueScale, useThousandsSeparator: useThousandsSeparator), style: resolveStyle(theme.labelStyle)),
      textDirection: TextDirection.ltr,
    )..layout();

    // Shorten the bar to accommodate labels
    const labelGap = 4.0;
    final barTop = plotArea.top + maxPainter.height + labelGap;
    final barBottom = plotArea.bottom - minPainter.height - labelGap;

    final legendRect = RRect.fromLTRBR(
      legendLeft,
      barTop,
      legendLeft + legendWidth,
      barBottom,
      Radius.circular(legendWidth / 2),
    );

    // Vertical gradient (max at top, min at bottom)
    final colors =
        colorScale.colorStops.map((s) => s.$2).toList().reversed.toList();
    final stops = colorScale.colorStops
        .map((s) => 1.0 - s.$1)
        .toList()
        .reversed
        .toList();

    _cellPaint.shader = ui.Gradient.linear(
      Offset(0, barTop),
      Offset(0, barBottom),
      colors,
      stops,
    );
    canvas.drawRRect(legendRect, _cellPaint);
    _cellPaint.shader = null;

    // Place labels above and below the bar, horizontally centered
    final centerX = legendLeft + legendWidth / 2;
    final maxLabelX =
        (centerX - maxPainter.width / 2).clamp(0.0, double.infinity);
    final minLabelX =
        (centerX - minPainter.width / 2).clamp(0.0, double.infinity);

    maxPainter.paint(canvas, Offset(maxLabelX, plotArea.top));
    minPainter.paint(canvas, Offset(minLabelX, barBottom + labelGap));
  }

  double _cellWidth(Rect plotArea) {
    return (plotArea.width - (data.xCount - 1) * theme.heatmapCellGapPx) /
        data.xCount;
  }

  double _cellHeight(Rect plotArea) {
    return (plotArea.height - (data.yCount - 1) * theme.heatmapCellGapPx) /
        data.yCount;
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter oldDelegate) {
    return baseTextStyle != oldDelegate.baseTextStyle ||
        data != oldDelegate.data ||
        animationProgress != oldDelegate.animationProgress ||
        hoveredXIndex != oldDelegate.hoveredXIndex ||
        hoveredYIndex != oldDelegate.hoveredYIndex ||
        colorLegendPosition != oldDelegate.colorLegendPosition ||
        xAxisTitle != oldDelegate.xAxisTitle ||
        yAxisTitle != oldDelegate.yAxisTitle ||
        unit != oldDelegate.unit ||
        unitPosition != oldDelegate.unitPosition ||
        valueScale != oldDelegate.valueScale ||
        useThousandsSeparator != oldDelegate.useThousandsSeparator;
  }
}

// --- Hit testing ---

/// Returns the X/Y cell index at the given hover position.
/// Returns null if outside the plot area, on a gap, or on a null cell.
({int xIndex, int yIndex})? hitTestHeatmap({
  required Offset localPosition,
  required Size size,
  required HeatmapData data,
  required ChartTheme theme,
  LegendPosition colorLegendPosition = LegendPosition.bottom,
  String? xAxisTitle,
  String? yAxisTitle,
}) {
  if (data.xCount == 0 || data.yCount == 0) return null;

  final hasXTitle =
      theme.showXAxisTitle && xAxisTitle != null && xAxisTitle.isNotEmpty;
  final hasYTitle =
      theme.showYAxisTitle && yAxisTitle != null && yAxisTitle.isNotEmpty;

  var leftPadding =
      theme.showYAxisLabels ? _defaultLeftPaddingPx : _reducedLeftPaddingPx;
  if (colorLegendPosition == LegendPosition.left) leftPadding += 32.0;
  if (hasYTitle) leftPadding += _axisTitlePaddingPx;

  var bottomPadding =
      theme.showXAxisLabels ? _defaultBottomPaddingPx : _reducedBottomPaddingPx;
  if (colorLegendPosition != LegendPosition.bottom) {
    bottomPadding -= 16.0;
    if (bottomPadding < 8.0) bottomPadding = 8.0;
  }
  if (hasXTitle) bottomPadding += _axisTitlePaddingPx;

  final topPadding =
      colorLegendPosition == LegendPosition.top ? 40.0 : _topPaddingPx;
  final rightPadding =
      colorLegendPosition == LegendPosition.right ? 48.0 : _rightPaddingPx;

  final plotArea = Rect.fromLTRB(
    leftPadding,
    topPadding,
    size.width - rightPadding,
    size.height - bottomPadding,
  );

  if (!plotArea.contains(localPosition)) return null;

  final cellWidth =
      (plotArea.width - (data.xCount - 1) * theme.heatmapCellGapPx) /
          data.xCount;
  final cellHeight =
      (plotArea.height - (data.yCount - 1) * theme.heatmapCellGapPx) /
          data.yCount;

  final stride = theme.heatmapCellGapPx;
  final xIdx =
      ((localPosition.dx - plotArea.left) / (cellWidth + stride))
          .floor()
          .clamp(0, data.xCount - 1);
  final yIdx =
      ((localPosition.dy - plotArea.top) / (cellHeight + stride))
          .floor()
          .clamp(0, data.yCount - 1);

  // Check if the position is on a gap
  final cellLeft = plotArea.left + xIdx * (cellWidth + stride);
  final cellTop = plotArea.top + yIdx * (cellHeight + stride);

  if (localPosition.dx > cellLeft + cellWidth ||
      localPosition.dy > cellTop + cellHeight) {
    return null;
  }

  // Exclude cells with null values
  if (data.values[yIdx][xIdx] == null) return null;

  return (xIndex: xIdx, yIndex: yIdx);
}
