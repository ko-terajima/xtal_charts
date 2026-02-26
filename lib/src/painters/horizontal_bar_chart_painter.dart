import 'dart:math';

import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../theme/chart_theme.dart';
import '../utils/value_formatter.dart';
import 'chart_painter.dart';

/// Horizontal padding for the label area (px).
const _labelPaddingPx = 8.0;

/// Gap between the color indicator square and the label (px).
const _indicatorGapPx = 6.0;

/// Gap between the bar's right edge and the value label (px).
const _valueLabelGapPx = 8.0;

/// Vertical padding (px).
const _verticalPaddingPx = 8.0;

/// Painter that renders a horizontal bar chart on a Canvas.
///
/// Each [ChartSeries] is drawn as a single horizontal bar.
/// Layout: color indicator + label on the left, bar in the center, value label on the right.
class HorizontalBarChartPainter extends BaseChartPainter {
  final List<ChartSeries> seriesList;

  /// Reference value for bar scaling (maximum across all bars).
  final double maxValue;

  /// Left-to-right bar growth animation progress (0.0 to 1.0).
  final double animationProgress;

  /// Index of the currently hovered bar (null when not hovering).
  final int? hoveredBarIndex;

  /// Whether to show colored indicator squares to the left of category labels.
  final bool showColorIndicators;

  /// Whether to show value labels to the right of bars.
  final bool showValueLabels;

  /// Formatter for value labels.
  final ValueLabelFormatter? valueLabelFormatter;

  /// Unit string for values (e.g. "%", "USD").
  final String? unit;

  /// Display position of the unit string.
  final UnitPosition unitPosition;

  /// Scaling applied to display values.
  final ValueScale valueScale;

  /// Whether to use thousands separator commas in value labels.
  final bool useThousandsSeparator;

  final Paint _bgPaint = Paint();
  final Paint _barPaint = Paint();
  final Paint _indicatorPaint = Paint();

  HorizontalBarChartPainter({
    required this.seriesList,
    required this.maxValue,
    required super.theme,
    super.baseTextStyle,
    this.animationProgress = 1.0,
    this.hoveredBarIndex,
    this.showColorIndicators = true,
    this.showValueLabels = true,
    this.valueLabelFormatter,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    _bgPaint.color = theme.backgroundColor;
    canvas.drawRect(Offset.zero & size, _bgPaint);

    if (seriesList.isEmpty || maxValue <= 0) return;

    final barCount = seriesList.length;
    final layout = _computeLayout(size, barCount);

    for (var i = 0; i < barCount; i++) {
      final series = seriesList[i];
      final value = series.dataPoints.isNotEmpty ? series.dataPoints.first.y : 0.0;
      final (barTop, barHeight) = computeHorizontalBarGeometry(
        barIndex: i,
        barCount: barCount,
        plotArea: layout.barArea,
        theme: theme,
      );

      _drawRow(
        canvas: canvas,
        layout: layout,
        barIndex: i,
        barTop: barTop,
        barHeight: barHeight,
        value: value,
        color: series.color,
        label: series.name,
      );
    }
  }

  /// Draws a single row (indicator + label + bar + value label).
  void _drawRow({
    required Canvas canvas,
    required HorizontalBarLayout layout,
    required int barIndex,
    required double barTop,
    required double barHeight,
    required double value,
    required Color color,
    required String label,
  }) {
    final rowCenterY = barTop + barHeight / 2;
    final barColor = _resolveBarColor(color, barIndex);

    // --- Color indicator square ---
    if (showColorIndicators) {
      final indicatorSize = theme.horizontalBarIndicatorSizePx;
      _indicatorPaint.color = barColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              _labelPaddingPx + indicatorSize / 2,
              rowCenterY,
            ),
            width: indicatorSize,
            height: indicatorSize,
          ),
          const Radius.circular(2),
        ),
        _indicatorPaint,
      );
    }

    // --- Category label ---
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: resolveStyle(theme.labelStyle)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: layout.labelWidth);
    labelPainter.paint(
      canvas,
      Offset(layout.labelLeft, rowCenterY - labelPainter.height / 2),
    );

    // --- Horizontal bar ---
    final barWidth = (value / maxValue) * layout.barArea.width * animationProgress;
    if (barWidth > 0) {
      final barRRect = RRect.fromLTRBAndCorners(
        layout.barArea.left,
        barTop,
        layout.barArea.left + barWidth,
        barTop + barHeight,
        topRight: Radius.circular(theme.horizontalBarBorderRadiusPx),
        bottomRight: Radius.circular(theme.horizontalBarBorderRadiusPx),
      );
      _barPaint.color = barColor;
      canvas.drawRRect(barRRect, _barPaint);
    }

    // --- Value label ---
    if (showValueLabels) {
      final valueText = valueLabelFormatter != null
          ? valueLabelFormatter!(value)
          : formatChartValue(value, unit: unit, unitPosition: unitPosition, valueScale: valueScale, useThousandsSeparator: useThousandsSeparator);
      final valuePainter = TextPainter(
        text: TextSpan(
          text: valueText,
          style: resolveStyle(theme.horizontalBarValueLabelStyle),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      valuePainter.paint(
        canvas,
        Offset(
          layout.barArea.left + barWidth + _valueLabelGapPx,
          rowCenterY - valuePainter.height / 2,
        ),
      );
    }
  }

  /// Returns the bar color adjusted for hover state.
  Color _resolveBarColor(Color baseColor, int barIndex) {
    if (hoveredBarIndex == null) return baseColor;
    if (barIndex == hoveredBarIndex) {
      return _brighten(baseColor, theme.horizontalBarHoverBrightnessBoost);
    }
    return baseColor.withValues(alpha: theme.horizontalBarDimmedOpacity);
  }

  /// Increases HSL lightness and returns a brighter color.
  Color _brighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Computes layout information (label area and bar area).
  HorizontalBarLayout _computeLayout(Size size, int barCount) {
    return computeHorizontalBarLayout(
      size: size,
      seriesList: seriesList,
      theme: theme,
      showColorIndicators: showColorIndicators,
      showValueLabels: showValueLabels,
      valueLabelFormatter: valueLabelFormatter,
      maxValue: maxValue,
      resolvedLabelStyle: resolveStyle(theme.labelStyle),
      resolvedValueLabelStyle: resolveStyle(theme.horizontalBarValueLabelStyle),
    );
  }

  @override
  bool shouldRepaint(covariant HorizontalBarChartPainter oldDelegate) {
    return baseTextStyle != oldDelegate.baseTextStyle ||
        seriesList != oldDelegate.seriesList ||
        maxValue != oldDelegate.maxValue ||
        animationProgress != oldDelegate.animationProgress ||
        hoveredBarIndex != oldDelegate.hoveredBarIndex ||
        showColorIndicators != oldDelegate.showColorIndicators ||
        showValueLabels != oldDelegate.showValueLabels ||
        unit != oldDelegate.unit ||
        unitPosition != oldDelegate.unitPosition ||
        valueScale != oldDelegate.valueScale;
  }
}

// --- Layout calculation (shared by Painter and hitTest) ---

/// Layout information for the horizontal bar chart.
class HorizontalBarLayout {
  /// X coordinate for drawing label text.
  final double labelLeft;

  /// Maximum width for label text.
  final double labelWidth;

  /// Bar drawing area (left = bar start X, right = bar max width).
  final Rect barArea;

  const HorizontalBarLayout({
    required this.labelLeft,
    required this.labelWidth,
    required this.barArea,
  });
}

/// Computes layout information. Used by both Painter and hitTest.
HorizontalBarLayout computeHorizontalBarLayout({
  required Size size,
  required List<ChartSeries> seriesList,
  required ChartTheme theme,
  required bool showColorIndicators,
  required bool showValueLabels,
  ValueLabelFormatter? valueLabelFormatter,
  required double maxValue,
  TextStyle? resolvedLabelStyle,
  TextStyle? resolvedValueLabelStyle,
}) {
  // Measure label widths
  var maxLabelWidth = 0.0;
  for (final series in seriesList) {
    final painter = TextPainter(
      text: TextSpan(text: series.name, style: resolvedLabelStyle ?? theme.labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    maxLabelWidth = max(maxLabelWidth, painter.width);
  }

  // Measure value label widths
  var maxValueLabelWidth = 0.0;
  if (showValueLabels) {
    for (final series in seriesList) {
      final value = series.dataPoints.isNotEmpty
          ? series.dataPoints.first.y
          : 0.0;
      final valueText = valueLabelFormatter != null
          ? valueLabelFormatter(value)
          : _defaultFormat(value);
      final painter = TextPainter(
        text: TextSpan(
          text: valueText,
          style: resolvedValueLabelStyle ?? theme.horizontalBarValueLabelStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      maxValueLabelWidth = max(maxValueLabelWidth, painter.width);
    }
  }

  // Left margin = padding + indicator + gap + label width + padding
  final indicatorSpace = showColorIndicators
      ? theme.horizontalBarIndicatorSizePx + _indicatorGapPx
      : 0.0;
  final labelLeft = _labelPaddingPx + indicatorSpace;
  final labelAreaRight = labelLeft + maxLabelWidth + _labelPaddingPx;

  // Right margin = value label width + gap + padding
  final rightMargin = showValueLabels
      ? maxValueLabelWidth + _valueLabelGapPx + _labelPaddingPx
      : _labelPaddingPx;

  final barArea = Rect.fromLTRB(
    labelAreaRight,
    _verticalPaddingPx,
    size.width - rightMargin,
    size.height - _verticalPaddingPx,
  );

  return HorizontalBarLayout(
    labelLeft: labelLeft,
    labelWidth: maxLabelWidth,
    barArea: barArea,
  );
}

String _defaultFormat(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

// --- Bar geometry calculation (shared by Painter and hitTest) ---

/// Computes the top Y coordinate and height of a horizontal bar.
(double barTop, double barHeight) computeHorizontalBarGeometry({
  required int barIndex,
  required int barCount,
  required Rect plotArea,
  required ChartTheme theme,
}) {
  final slotHeight = plotArea.height / barCount;
  final barHeight = (slotHeight * (1 - theme.horizontalBarRowGapRatio))
      .clamp(1.0, theme.horizontalBarMaxHeightPx);
  final slotCenterY = plotArea.top + slotHeight * (barIndex + 0.5);
  final barTop = slotCenterY - barHeight / 2;
  return (barTop, barHeight);
}

// --- Hit testing ---

/// Returns the horizontal bar index at the given hover position.
/// Returns null if outside the plot area.
int? hitTestHorizontalBarChart({
  required Offset localPosition,
  required Size size,
  required List<ChartSeries> seriesList,
  required ChartTheme theme,
  required double maxValue,
  required bool showColorIndicators,
  required bool showValueLabels,
  ValueLabelFormatter? valueLabelFormatter,
  TextStyle? resolvedLabelStyle,
  TextStyle? resolvedValueLabelStyle,
}) {
  if (seriesList.isEmpty || maxValue <= 0) return null;

  final layout = computeHorizontalBarLayout(
    size: size,
    seriesList: seriesList,
    theme: theme,
    showColorIndicators: showColorIndicators,
    showValueLabels: showValueLabels,
    valueLabelFormatter: valueLabelFormatter,
    maxValue: maxValue,
    resolvedLabelStyle: resolvedLabelStyle,
    resolvedValueLabelStyle: resolvedValueLabelStyle,
  );

  // Check if within the bar area's Y range
  if (localPosition.dy < layout.barArea.top ||
      localPosition.dy > layout.barArea.bottom) {
    return null;
  }

  final barCount = seriesList.length;
  for (var i = 0; i < barCount; i++) {
    final (barTop, barHeight) = computeHorizontalBarGeometry(
      barIndex: i,
      barCount: barCount,
      plotArea: layout.barArea,
      theme: theme,
    );

    // Check if the Y coordinate falls within this row slot
    if (localPosition.dy >= barTop && localPosition.dy <= barTop + barHeight) {
      return i;
    }
  }

  return null;
}
