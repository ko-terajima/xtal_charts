import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../painters/dual_axes_painter.dart';
import '../theme/chart_theme.dart';
import '../utils/nice_numbers.dart';
import '../utils/value_formatter.dart';

/// Custom builder type for DualAxes tooltips.
/// [xLabel] is the X-axis label, [leftValues] / [rightValues] are
/// maps of series name to (value, color) for each axis.
typedef DualAxesTooltipBuilder =
    Widget Function(
      BuildContext context,
      String xLabel,
      Map<String, (double value, Color color)> leftValues,
      Map<String, (double value, Color color)> rightValues,
    );

/// Callback type for element taps.
/// [xIndex] is the X-axis index, [xLabel] is the X-axis label,
/// [leftValues] / [rightValues] are maps of series name to (value, color) for each axis.
typedef DualAxesElementTapCallback =
    void Function(
      int xIndex,
      String xLabel,
      Map<String, (double value, Color color)> leftValues,
      Map<String, (double value, Color color)> rightValues,
    );

/// A dual-axes chart widget inspired by Ant Design Charts.
///
/// Has independent Y scales for the left and right axes, and overlays
/// different chart types (line / area / column) on a single chart.
///
/// ```dart
/// DualAxesChart(
///   leftSeriesList: [
///     ChartSeries(name: 'Order Amount', color: Colors.blue, dataPoints: [...]),
///   ],
///   rightSeriesList: [
///     ChartSeries(name: 'Growth Rate', color: Colors.orange, dataPoints: [...]),
///   ],
///   leftChartType: DualAxesChartType.column,
///   rightChartType: DualAxesChartType.line,
/// )
/// ```
class DualAxesChart extends StatefulWidget {
  final List<ChartSeries> leftSeriesList;
  final List<ChartSeries> rightSeriesList;
  final DualAxesChartType leftChartType;
  final DualAxesChartType rightChartType;
  final bool smoothCurve;
  final ChartTheme theme;

  /// Whether to show a tooltip on hover.
  final bool showTooltip;

  /// Custom tooltip builder.
  final DualAxesTooltipBuilder? tooltipBuilder;

  /// Callback when an element is tapped.
  final DualAxesElementTapCallback? onElementTap;

  /// Animation duration.
  final Duration animationDuration;

  /// Animation curve.
  final Curve animationCurve;

  /// Left Y-axis minimum value (null for auto-calculation).
  final double? leftYMin;

  /// Left Y-axis maximum value (null for auto-calculation).
  final double? leftYMax;

  /// Right Y-axis minimum value (null for auto-calculation).
  final double? rightYMin;

  /// Right Y-axis maximum value (null for auto-calculation).
  final double? rightYMax;

  /// X-axis title text.
  final String? xAxisTitle;

  /// Left Y-axis title text.
  final String? leftYAxisTitle;

  /// Right Y-axis title text.
  final String? rightYAxisTitle;

  /// Unit string for left axis values (e.g., "$"). Hidden when null.
  final String? leftUnit;

  /// Display position for the left axis unit.
  final UnitPosition leftUnitPosition;

  /// Scaling for left axis display values.
  final ValueScale leftValueScale;

  /// Unit string for right axis values (e.g., "%"). Hidden when null.
  final String? rightUnit;

  /// Display position for the right axis unit.
  final UnitPosition rightUnitPosition;

  /// Scaling for right axis display values.
  final ValueScale rightValueScale;

  /// Whether to use thousands separator for the left axis.
  final bool leftUseThousandsSeparator;

  /// Whether to use thousands separator for the right axis.
  final bool rightUseThousandsSeparator;

  /// Base text style. Takes priority over the theme's textStyle.
  final TextStyle? textStyle;

  const DualAxesChart({
    super.key,
    required this.leftSeriesList,
    required this.rightSeriesList,
    this.leftChartType = DualAxesChartType.column,
    this.rightChartType = DualAxesChartType.line,
    this.smoothCurve = false,
    this.theme = ChartTheme.defaultTheme,
    this.showTooltip = true,
    this.tooltipBuilder,
    this.onElementTap,
    this.animationDuration = const Duration(milliseconds: 800),
    this.animationCurve = Curves.easeOutCubic,
    this.leftYMin,
    this.leftYMax,
    this.rightYMin,
    this.rightYMax,
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
    this.textStyle,
  });

  @override
  State<DualAxesChart> createState() => _DualAxesChartState();
}

class _DualAxesChartState extends State<DualAxesChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  NiceScale? _leftYScale;
  NiceScale? _rightYScale;
  int? _hoveredXIndex;
  OverlayEntry? _tooltipOverlayEntry;
  Offset _mouseGlobalPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _leftYScale = _computeYScale(
      widget.leftSeriesList,
      widget.leftYMin,
      widget.leftYMax,
    );
    _rightYScale = _computeYScale(
      widget.rightSeriesList,
      widget.rightYMin,
      widget.rightYMax,
    );

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 1.0, curve: widget.animationCurve),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(DualAxesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leftSeriesList != widget.leftSeriesList ||
        oldWidget.rightSeriesList != widget.rightSeriesList ||
        oldWidget.leftChartType != widget.leftChartType ||
        oldWidget.rightChartType != widget.rightChartType ||
        oldWidget.leftYMin != widget.leftYMin ||
        oldWidget.leftYMax != widget.leftYMax ||
        oldWidget.rightYMin != widget.rightYMin ||
        oldWidget.rightYMax != widget.rightYMax) {
      _leftYScale = _computeYScale(
        widget.leftSeriesList,
        widget.leftYMin,
        widget.leftYMax,
      );
      _rightYScale = _computeYScale(
        widget.rightSeriesList,
        widget.rightYMin,
        widget.rightYMax,
      );
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

  /// Computes NiceScale from a series list. Starts from 0.
  NiceScale _computeYScale(
    List<ChartSeries> seriesList,
    double? yMin,
    double? yMax,
  ) {
    if (seriesList.isEmpty) {
      return calculateNiceScale(minValue: 0, maxValue: 1);
    }

    var minY = yMin ?? double.infinity;
    var maxY = yMax ?? double.negativeInfinity;

    for (final series in seriesList) {
      for (final point in series.dataPoints) {
        if (yMin == null && point.y < minY) minY = point.y;
        if (yMax == null && point.y > maxY) maxY = point.y;
      }
    }

    if (minY > 0) minY = 0;

    // Fallback when data points are empty
    if (!maxY.isFinite) maxY = minY == 0 ? 1 : minY.abs();
    if (!minY.isFinite) minY = 0;

    return calculateNiceScale(minValue: minY, maxValue: maxY);
  }

  // --- Hover handling ---

  void _handleHover(Offset localPosition, Size size, Offset globalPosition) {
    final index = hitTestDualAxes(
      localPosition: localPosition,
      size: size,
      leftSeriesList: widget.leftSeriesList,
      rightSeriesList: widget.rightSeriesList,
      theme: widget.theme,
      xAxisTitle: widget.xAxisTitle,
      leftYAxisTitle: widget.leftYAxisTitle,
      rightYAxisTitle: widget.rightYAxisTitle,
    );

    final renderBox = context.findRenderObject() as RenderBox?;
    _mouseGlobalPosition = renderBox != null
        ? renderBox.localToGlobal(localPosition)
        : globalPosition;

    if (index != _hoveredXIndex) {
      setState(() => _hoveredXIndex = index);

      if (widget.showTooltip) {
        if (index != null) {
          _showTooltip(index);
        } else {
          _removeTooltip();
        }
      }
    } else if (widget.showTooltip && index != null) {
      _updateTooltipPosition();
    }
  }

  void _handleMouseExit() {
    setState(() => _hoveredXIndex = null);
    _removeTooltip();
  }

  // --- Tap handling ---

  void _handleTapDown(TapDownDetails details, Size size) {
    final index = hitTestDualAxes(
      localPosition: details.localPosition,
      size: size,
      leftSeriesList: widget.leftSeriesList,
      rightSeriesList: widget.rightSeriesList,
      theme: widget.theme,
      xAxisTitle: widget.xAxisTitle,
      leftYAxisTitle: widget.leftYAxisTitle,
      rightYAxisTitle: widget.rightYAxisTitle,
    );

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _mouseGlobalPosition = renderBox.localToGlobal(details.localPosition);
    }

    if (index != _hoveredXIndex) {
      setState(() => _hoveredXIndex = index);

      if (widget.showTooltip) {
        if (index != null) {
          _showTooltip(index);
        } else {
          _removeTooltip();
        }
      }
    }

    if (index != null) {
      widget.onElementTap?.call(
        index,
        _xLabelAt(index),
        _leftValuesAt(index),
        _rightValuesAt(index),
      );
    }
  }

  // --- Tooltip ---

  void _showTooltip(int xIndex) {
    _removeTooltip();

    _tooltipOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _DualAxesTooltipPositioner(
          mouseGlobalPosition: _mouseGlobalPosition,
          child: widget.tooltipBuilder != null
              ? widget.tooltipBuilder!(
                  overlayContext,
                  _xLabelAt(xIndex),
                  _leftValuesAt(xIndex),
                  _rightValuesAt(xIndex),
                )
              : _DefaultDualAxesTooltip(
                  xLabel: _xLabelAt(xIndex),
                  leftValues: _leftValuesAt(xIndex),
                  rightValues: _rightValuesAt(xIndex),
                  theme: widget.theme,
                  leftUnit: widget.leftUnit,
                  leftUnitPosition: widget.leftUnitPosition,
                  leftValueScale: widget.leftValueScale,
                  rightUnit: widget.rightUnit,
                  rightUnitPosition: widget.rightUnitPosition,
                  rightValueScale: widget.rightValueScale,
                  leftUseThousandsSeparator: widget.leftUseThousandsSeparator,
                  rightUseThousandsSeparator: widget.rightUseThousandsSeparator,
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

  String _xLabelAt(int index) {
    // Prefer the label from column series; fall back to the first left-axis series
    if (widget.leftChartType == DualAxesChartType.column &&
        widget.leftSeriesList.isNotEmpty &&
        index < widget.leftSeriesList.first.dataPoints.length) {
      final point = widget.leftSeriesList.first.dataPoints[index];
      return point.label ?? point.x.toString();
    }
    if (widget.rightChartType == DualAxesChartType.column &&
        widget.rightSeriesList.isNotEmpty &&
        index < widget.rightSeriesList.first.dataPoints.length) {
      final point = widget.rightSeriesList.first.dataPoints[index];
      return point.label ?? point.x.toString();
    }
    if (widget.leftSeriesList.isNotEmpty &&
        index < widget.leftSeriesList.first.dataPoints.length) {
      final point = widget.leftSeriesList.first.dataPoints[index];
      return point.label ?? point.x.toString();
    }
    if (widget.rightSeriesList.isNotEmpty &&
        index < widget.rightSeriesList.first.dataPoints.length) {
      final point = widget.rightSeriesList.first.dataPoints[index];
      return point.label ?? point.x.toString();
    }
    return index.toString();
  }

  Map<String, (double, Color)> _leftValuesAt(int index) {
    return {
      for (final series in widget.leftSeriesList)
        if (index < series.dataPoints.length)
          series.name: (series.dataPoints[index].y, series.color),
    };
  }

  Map<String, (double, Color)> _rightValuesAt(int index) {
    return {
      for (final series in widget.rightSeriesList)
        if (index < series.dataPoints.length)
          series.name: (series.dataPoints[index].y, series.color),
    };
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final hasLeft = widget.leftSeriesList.isNotEmpty;
    final hasRight = widget.rightSeriesList.isNotEmpty;

    if ((!hasLeft && !hasRight) ||
        _leftYScale == null ||
        _rightYScale == null) {
      return Container(color: widget.theme.backgroundColor);
    }

    return RepaintBoundary(
      child: Container(
        color: widget.theme.backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return MouseRegion(
              cursor: _hoveredXIndex != null
                  ? SystemMouseCursors.precise
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
                      painter: DualAxesPainter(
                        leftSeriesList: widget.leftSeriesList,
                        rightSeriesList: widget.rightSeriesList,
                        leftYScale: _leftYScale!,
                        rightYScale: _rightYScale!,
                        leftChartType: widget.leftChartType,
                        baseTextStyle: widget.textStyle,
                        rightChartType: widget.rightChartType,
                        smoothCurve: widget.smoothCurve,
                        theme: widget.theme,
                        animationProgress: _animation.value,
                        hoveredXIndex: _hoveredXIndex,
                        xAxisTitle: widget.xAxisTitle,
                        leftYAxisTitle: widget.leftYAxisTitle,
                        rightYAxisTitle: widget.rightYAxisTitle,
                        leftUnit: widget.leftUnit,
                        leftUnitPosition: widget.leftUnitPosition,
                        leftValueScale: widget.leftValueScale,
                        rightUnit: widget.rightUnit,
                        rightUnitPosition: widget.rightUnitPosition,
                        rightValueScale: widget.rightValueScale,
                        leftUseThousandsSeparator:
                            widget.leftUseThousandsSeparator,
                        rightUseThousandsSeparator:
                            widget.rightUseThousandsSeparator,
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
class _DualAxesTooltipPositioner extends StatelessWidget {
  final Offset mouseGlobalPosition;
  final Widget child;

  static const _cursorOffsetX = 12.0;
  static const _cursorOffsetY = 16.0;

  const _DualAxesTooltipPositioner({
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

/// Default tooltip for the dual-axes chart.
/// Displays the X label, left-axis series values, a divider, and right-axis series values.
class _DefaultDualAxesTooltip extends StatelessWidget {
  final String xLabel;
  final Map<String, (double value, Color color)> leftValues;
  final Map<String, (double value, Color color)> rightValues;
  final ChartTheme theme;
  final String? leftUnit;
  final UnitPosition leftUnitPosition;
  final ValueScale leftValueScale;
  final String? rightUnit;
  final UnitPosition rightUnitPosition;
  final ValueScale rightValueScale;
  final bool leftUseThousandsSeparator;
  final bool rightUseThousandsSeparator;
  final TextStyle? baseTextStyle;

  const _DefaultDualAxesTooltip({
    required this.xLabel,
    required this.leftValues,
    required this.rightValues,
    required this.theme,
    this.leftUnit,
    this.leftUnitPosition = UnitPosition.suffix,
    this.leftValueScale = ValueScale.none,
    this.rightUnit,
    this.rightUnitPosition = UnitPosition.suffix,
    this.rightValueScale = ValueScale.none,
    this.leftUseThousandsSeparator = true,
    this.rightUseThousandsSeparator = true,
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
          Text(xLabel, style: _resolveStyle(theme.tooltipLabelStyle)),
          const SizedBox(height: 4),
          // Left-axis values
          for (final entry in leftValues.entries)
            _buildSeriesRow(
              entry.key,
              entry.value.$1,
              entry.value.$2,
              unit: leftUnit,
              unitPosition: leftUnitPosition,
              valueScale: leftValueScale,
              useThousandsSeparator: leftUseThousandsSeparator,
            ),
          // Divider between left and right axes (only when both have data)
          if (leftValues.isNotEmpty && rightValues.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Container(
                height: 1,
                width: double.infinity,
                color: const Color(0x33FFFFFF),
              ),
            ),
          // Right-axis values
          for (final entry in rightValues.entries)
            _buildSeriesRow(
              entry.key,
              entry.value.$1,
              entry.value.$2,
              unit: rightUnit,
              unitPosition: rightUnitPosition,
              valueScale: rightValueScale,
              useThousandsSeparator: rightUseThousandsSeparator,
            ),
        ],
      ),
    );
  }

  Widget _buildSeriesRow(
    String name,
    double value,
    Color color, {
    String? unit,
    UnitPosition unitPosition = UnitPosition.suffix,
    ValueScale valueScale = ValueScale.none,
    bool useThousandsSeparator = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$name: ', style: _resolveStyle(theme.tooltipValueStyle)),
          Text(
            formatChartValue(
              value,
              unit: unit,
              unitPosition: unitPosition,
              valueScale: valueScale,
              decimalPlaces: 2,
              useThousandsSeparator: useThousandsSeparator,
            ),
            style: _resolveStyle(theme.tooltipValueStyle).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
