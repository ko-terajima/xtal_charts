import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../painters/column_chart_painter.dart';
import '../theme/chart_theme.dart';
import '../utils/nice_numbers.dart';
import '../utils/value_formatter.dart';

/// Custom builder type for tooltips.
/// [categoryLabel] is the category label, [seriesValues] is a map of series name to (value, color),
/// [hoveredSeriesName] is the hovered series name (used for highlighting in stacked mode).
typedef ColumnTooltipBuilder =
    Widget Function(
      BuildContext context,
      String categoryLabel,
      Map<String, (double value, Color color)> seriesValues, {
      String? hoveredSeriesName,
    });

/// Callback type for element taps.
/// [categoryIndex] / [seriesIndex] are the indices of the tapped bar,
/// [categoryLabel] is the category label, [seriesName] is the series name, [value] is the value.
typedef ColumnElementTapCallback =
    void Function(
      int categoryIndex,
      int seriesIndex,
      String categoryLabel,
      String seriesName,
      double value,
    );

/// A column chart widget inspired by Ant Design Charts.
///
/// [ColumnMode.grouped] arranges series side by side,
/// [ColumnMode.stacked] stacks series vertically.
/// Supports hover tooltips and bottom-to-top growth animation.
///
/// ```dart
/// ColumnChart(
///   seriesList: [
///     ChartSeries(name: '2023', color: Colors.blue, dataPoints: [...]),
///     ChartSeries(name: '2024', color: Colors.green, dataPoints: [...]),
///   ],
///   mode: ColumnMode.stacked,
/// )
/// ```
class ColumnChart extends StatefulWidget {
  final List<ChartSeries> seriesList;
  final ColumnMode mode;
  final ChartTheme theme;

  /// Whether to show a tooltip on hover.
  final bool showTooltip;

  /// Custom tooltip builder.
  final ColumnTooltipBuilder? tooltipBuilder;

  /// Callback when an element is tapped.
  final ColumnElementTapCallback? onElementTap;

  /// Animation duration.
  final Duration animationDuration;

  /// Animation curve.
  final Curve animationCurve;

  /// Y-axis minimum value (null for auto-calculation).
  final double? yMin;

  /// Y-axis maximum value (null for auto-calculation).
  final double? yMax;

  /// X-axis title text.
  final String? xAxisTitle;

  /// Y-axis title text.
  final String? yAxisTitle;

  /// Unit string for values (e.g., "%"). Hidden when null.
  final String? unit;

  /// Display position for the unit.
  final UnitPosition unitPosition;

  /// Scaling for display values.
  final ValueScale valueScale;

  /// Whether to use thousands separator commas.
  final bool useThousandsSeparator;

  /// Base text style. Takes priority over the theme's textStyle.
  final TextStyle? textStyle;

  const ColumnChart({
    super.key,
    required this.seriesList,
    this.mode = ColumnMode.grouped,
    this.theme = ChartTheme.defaultTheme,
    this.showTooltip = true,
    this.tooltipBuilder,
    this.onElementTap,
    this.animationDuration = const Duration(milliseconds: 800),
    this.animationCurve = Curves.easeOutCubic,
    this.yMin,
    this.yMax,
    this.xAxisTitle,
    this.yAxisTitle,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
    this.textStyle,
  });

  @override
  State<ColumnChart> createState() => _ColumnChartState();
}

class _ColumnChartState extends State<ColumnChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  /// Animation for bars growing from bottom to top.
  late Animation<double> _barGrowAnimation;

  NiceScale? _yScale;
  int? _hoveredCategoryIndex;
  int? _hoveredSeriesIndex;
  OverlayEntry? _tooltipOverlayEntry;
  Offset _mouseGlobalPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _yScale = _computeYScale();

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _barGrowAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 1.0, curve: widget.animationCurve),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(ColumnChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesList != widget.seriesList ||
        oldWidget.mode != widget.mode ||
        oldWidget.yMin != widget.yMin ||
        oldWidget.yMax != widget.yMax) {
      _yScale = _computeYScale();
      _animationController.forward(from: 0);
      _removeTooltip();
    }
  }

  @override
  void dispose() {
    _removeTooltip();
    _animationController.dispose();
    super.dispose();
  }

  NiceScale _computeYScale() {
    if (widget.seriesList.isEmpty) {
      return calculateNiceScale(minValue: 0, maxValue: 1);
    }

    switch (widget.mode) {
      case ColumnMode.grouped:
        return _computeGroupedYScale();
      case ColumnMode.stacked:
        return _computeStackedYScale();
    }
  }

  /// Grouped: computes NiceScale from the min/max of all data points.
  NiceScale _computeGroupedYScale() {
    var minY = widget.yMin ?? double.infinity;
    var maxY = widget.yMax ?? double.negativeInfinity;

    for (final series in widget.seriesList) {
      for (final point in series.dataPoints) {
        if (widget.yMin == null && point.y < minY) minY = point.y;
        if (widget.yMax == null && point.y > maxY) maxY = point.y;
      }
    }

    // Bar charts typically start at 0
    if (minY > 0) minY = 0;

    // Fallback when data points are empty
    if (!maxY.isFinite) maxY = minY == 0 ? 1 : minY.abs();
    if (!minY.isFinite) minY = 0;

    return calculateNiceScale(minValue: minY, maxValue: maxY);
  }

  /// Stacked: computes NiceScale from the maximum cumulative total per category.
  NiceScale _computeStackedYScale() {
    final categoryCount = widget.seriesList.first.dataPoints.length;
    var maxCumulativeY = widget.yMax ?? double.negativeInfinity;

    for (var catIdx = 0; catIdx < categoryCount; catIdx++) {
      var cumulativeY = 0.0;
      for (final series in widget.seriesList) {
        if (catIdx < series.dataPoints.length) {
          cumulativeY += series.dataPoints[catIdx].y;
        }
      }
      if (widget.yMax == null && cumulativeY > maxCumulativeY) {
        maxCumulativeY = cumulativeY;
      }
    }

    // Fallback when data points are empty
    if (!maxCumulativeY.isFinite) maxCumulativeY = 1;

    final minY = widget.yMin ?? 0.0;
    return calculateNiceScale(minValue: minY, maxValue: maxCumulativeY);
  }

  // --- Hover handling ---

  void _handleHover(Offset localPosition, Size size, Offset globalPosition) {
    if (_yScale == null) return;

    final hitResult = hitTestColumnChart(
      localPosition: localPosition,
      size: size,
      seriesList: widget.seriesList,
      theme: widget.theme,
      mode: widget.mode,
      yScale: _yScale!,
      xAxisTitle: widget.xAxisTitle,
      yAxisTitle: widget.yAxisTitle,
    );

    final renderBox = context.findRenderObject() as RenderBox?;
    _mouseGlobalPosition = renderBox != null
        ? renderBox.localToGlobal(localPosition)
        : globalPosition;

    final newCatIdx = hitResult?.categoryIndex;
    final newSerIdx = hitResult?.seriesIndex;

    if (newCatIdx != _hoveredCategoryIndex ||
        newSerIdx != _hoveredSeriesIndex) {
      setState(() {
        _hoveredCategoryIndex = newCatIdx;
        _hoveredSeriesIndex = newSerIdx;
      });

      if (widget.showTooltip) {
        if (newCatIdx != null) {
          _showTooltip(newCatIdx);
        } else {
          _removeTooltip();
        }
      }
    } else if (widget.showTooltip && newCatIdx != null) {
      _updateTooltipPosition();
    }
  }

  void _handleMouseExit() {
    setState(() {
      _hoveredCategoryIndex = null;
      _hoveredSeriesIndex = null;
    });
    _removeTooltip();
  }

  // --- Tap handling ---

  void _handleTapDown(TapDownDetails details, Size size) {
    if (_yScale == null || widget.onElementTap == null) return;

    final hitResult = hitTestColumnChart(
      localPosition: details.localPosition,
      size: size,
      seriesList: widget.seriesList,
      theme: widget.theme,
      mode: widget.mode,
      yScale: _yScale!,
      xAxisTitle: widget.xAxisTitle,
      yAxisTitle: widget.yAxisTitle,
    );
    if (hitResult == null) return;

    final catIdx = hitResult.categoryIndex;
    final serIdx = hitResult.seriesIndex;
    final series = widget.seriesList[serIdx];

    widget.onElementTap!(
      catIdx,
      serIdx,
      _categoryLabelAt(catIdx),
      series.name,
      series.dataPoints[catIdx].y,
    );
  }

  // --- Tooltip ---

  void _showTooltip(int categoryIndex) {
    _removeTooltip();

    _tooltipOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final hoveredSeriesName =
            _hoveredSeriesIndex != null &&
                _hoveredSeriesIndex! < widget.seriesList.length
            ? widget.seriesList[_hoveredSeriesIndex!].name
            : null;

        return _ColumnTooltipPositioner(
          mouseGlobalPosition: _mouseGlobalPosition,
          child: widget.tooltipBuilder != null
              ? widget.tooltipBuilder!(
                  overlayContext,
                  _categoryLabelAt(categoryIndex),
                  _seriesValuesAt(categoryIndex),
                  hoveredSeriesName: hoveredSeriesName,
                )
              : _DefaultColumnTooltip(
                  categoryLabel: _categoryLabelAt(categoryIndex),
                  seriesValues: _seriesValuesAt(categoryIndex),
                  hoveredSeriesName: hoveredSeriesName,
                  theme: widget.theme,
                  unit: widget.unit,
                  unitPosition: widget.unitPosition,
                  valueScale: widget.valueScale,
                  useThousandsSeparator: widget.useThousandsSeparator,
                  baseTextStyle: widget.textStyle,
                ),
        );
      },
    );

    Overlay.of(context).insert(_tooltipOverlayEntry!);
  }

  void _updateTooltipPosition() {
    _tooltipOverlayEntry?.markNeedsBuild();
  }

  void _removeTooltip() {
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
  }

  String _categoryLabelAt(int index) {
    final point = widget.seriesList.first.dataPoints[index];
    return point.label ?? point.x.toString();
  }

  /// Returns a map of series name to (value, color). In stacked mode, entries are reversed (top to bottom).
  Map<String, (double, Color)> _seriesValuesAt(int index) {
    final entries = {
      for (final series in widget.seriesList)
        series.name: (series.dataPoints[index].y, series.color),
    };

    if (widget.mode == ColumnMode.stacked) {
      return Map.fromEntries(entries.entries.toList().reversed);
    }
    return entries;
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    if (_yScale == null || widget.seriesList.isEmpty) {
      return Container(color: widget.theme.backgroundColor);
    }

    return RepaintBoundary(
      child: Container(
        color: widget.theme.backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return MouseRegion(
              cursor: _hoveredCategoryIndex != null
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onHover: (event) =>
                  _handleHover(event.localPosition, size, event.position),
              onExit: (_) => _handleMouseExit(),
              child: GestureDetector(
                onTapDown: (details) => _handleTapDown(details, size),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: size,
                      painter: ColumnChartPainter(
                        seriesList: widget.seriesList,
                        yScale: _yScale!,
                        theme: widget.theme,
                        baseTextStyle: widget.textStyle,
                        mode: widget.mode,
                        animationProgress: _barGrowAnimation.value,
                        hoveredCategoryIndex: _hoveredCategoryIndex,
                        hoveredSeriesIndex: _hoveredSeriesIndex,
                        xAxisTitle: widget.xAxisTitle,
                        yAxisTitle: widget.yAxisTitle,
                        unit: widget.unit,
                        unitPosition: widget.unitPosition,
                        valueScale: widget.valueScale,
                        useThousandsSeparator: widget.useThousandsSeparator,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- Tooltip positioning ---

/// An overlay widget that positions a tooltip at the mouse cursor location.
class _ColumnTooltipPositioner extends StatelessWidget {
  final Offset mouseGlobalPosition;
  final Widget child;

  static const _cursorOffsetX = 12.0;
  static const _cursorOffsetY = 16.0;

  const _ColumnTooltipPositioner({
    required this.mouseGlobalPosition,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return CustomSingleChildLayout(
      delegate: _TooltipLayoutDelegate(
        mousePosition: mouseGlobalPosition,
        cursorOffsetX: _cursorOffsetX,
        cursorOffsetY: _cursorOffsetY,
        screenSize: screenSize,
      ),
      child: child,
    );
  }
}

class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset mousePosition;
  final double cursorOffsetX;
  final double cursorOffsetY;
  final Size screenSize;

  _TooltipLayoutDelegate({
    required this.mousePosition,
    required this.cursorOffsetX,
    required this.cursorOffsetY,
    required this.screenSize,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: screenSize.width * 0.4,
      maxHeight: screenSize.height * 0.4,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = mousePosition.dx + cursorOffsetX;
    var top = mousePosition.dy + cursorOffsetY;

    if (left + childSize.width > screenSize.width - 8) {
      left = mousePosition.dx - cursorOffsetX - childSize.width;
    }
    if (top + childSize.height > screenSize.height - 8) {
      top = mousePosition.dy - cursorOffsetY - childSize.height;
    }

    left = left.clamp(
      8.0,
      (screenSize.width - childSize.width - 8).clamp(8.0, double.infinity),
    );
    top = top.clamp(
      8.0,
      (screenSize.height - childSize.height - 8).clamp(8.0, double.infinity),
    );

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate oldDelegate) {
    return mousePosition != oldDelegate.mousePosition ||
        screenSize != oldDelegate.screenSize;
  }
}

// --- Default tooltip ---

/// Default tooltip inspired by Ant Design Charts.
/// Displays the category label with a colored dot, name, and value for each series.
/// In stacked mode, the hovered series is highlighted in bold.
class _DefaultColumnTooltip extends StatelessWidget {
  final String categoryLabel;
  final Map<String, (double value, Color color)> seriesValues;
  final String? hoveredSeriesName;
  final ChartTheme theme;
  final String? unit;
  final UnitPosition unitPosition;
  final ValueScale valueScale;
  final bool useThousandsSeparator;
  final TextStyle? baseTextStyle;

  const _DefaultColumnTooltip({
    required this.categoryLabel,
    required this.seriesValues,
    this.hoveredSeriesName,
    required this.theme,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
    this.baseTextStyle,
  });

  TextStyle _resolveStyle(TextStyle s) =>
      baseTextStyle == null ? s : baseTextStyle!.merge(s);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: theme.tooltipPadding,
      decoration: BoxDecoration(
        color: theme.tooltipBackgroundColor,
        borderRadius: BorderRadius.circular(theme.tooltipBorderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(categoryLabel, style: _resolveStyle(theme.tooltipLabelStyle)),
          const SizedBox(height: 4),
          for (final entry in seriesValues.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entry.value.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${entry.key}: ', style: _resolveStyle(theme.tooltipValueStyle)),
                  Text(
                    formatChartValue(
                      entry.value.$1,
                      unit: unit,
                      unitPosition: unitPosition,
                      valueScale: valueScale,
                      decimalPlaces: 2,
                      useThousandsSeparator: useThousandsSeparator,
                    ),
                    style: _resolveStyle(theme.tooltipValueStyle).copyWith(
                      fontWeight: entry.key == hoveredSeriesName
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
