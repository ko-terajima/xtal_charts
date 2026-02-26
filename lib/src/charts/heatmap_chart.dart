import 'package:flutter/material.dart';

import '../models/heatmap_data.dart';
import '../models/legend_position.dart';
import '../painters/heatmap_painter.dart';
import '../theme/chart_theme.dart';
import '../utils/color_scale.dart';
import '../utils/value_formatter.dart';

/// Custom builder type for tooltips.
/// [xCategory] is the X-axis label, [yCategory] is the Y-axis label,
/// [value] is the cell value, [cellColor] is the cell color.
typedef HeatmapTooltipBuilder =
    Widget Function(
      BuildContext context,
      String xCategory,
      String yCategory,
      double value,
      Color cellColor,
    );

/// Callback type for element taps.
/// [xIndex] / [yIndex] are the cell indices,
/// [xCategory] / [yCategory] are the category labels, [value] is the value, [cellColor] is the cell color.
typedef HeatmapElementTapCallback =
    void Function(
      int xIndex,
      int yIndex,
      String xCategory,
      String yCategory,
      double value,
      Color cellColor,
    );

/// A heatmap chart widget inspired by Ant Design Charts.
///
/// A grid chart where both X/Y axes are categories and values are represented by color intensity.
/// Supports hover tooltips, fade-in animation, and a color legend.
///
/// ```dart
/// HeatmapChart(
///   data: HeatmapData(
///     xCategories: ['Jan', 'Feb', 'Mar'],
///     yCategories: ['2023', '2024'],
///     values: [
///       [10, 20, 30],
///       [15, null, 25],
///     ],
///   ),
/// )
/// ```
class HeatmapChart extends StatefulWidget {
  final HeatmapData data;
  final ChartTheme theme;

  /// Whether to show a tooltip on hover.
  final bool showTooltip;

  /// Custom tooltip builder.
  final HeatmapTooltipBuilder? tooltipBuilder;

  /// Callback when an element is tapped.
  final HeatmapElementTapCallback? onElementTap;

  /// Animation duration.
  final Duration animationDuration;

  /// Animation curve.
  final Curve animationCurve;

  /// Color scale (null to auto-generate from the theme's gradient colors).
  final HeatmapColorScale? colorScale;

  /// Minimum value for normalization (null for auto-calculation).
  final double? valueMin;

  /// Maximum value for normalization (null for auto-calculation).
  final double? valueMax;

  /// Display position for the color legend.
  final LegendPosition colorLegendPosition;

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

  /// Minimum value displayed on the legend bar (null defaults to 0).
  /// Does not affect color normalization (display only).
  final double? legendDisplayMinValue;

  /// Base text style. Takes priority over the theme's textStyle.
  final TextStyle? textStyle;

  const HeatmapChart({
    super.key,
    required this.data,
    this.theme = ChartTheme.defaultTheme,
    this.showTooltip = true,
    this.tooltipBuilder,
    this.onElementTap,
    this.animationDuration = const Duration(milliseconds: 600),
    this.animationCurve = Curves.easeOut,
    this.colorScale,
    this.valueMin,
    this.valueMax,
    this.colorLegendPosition = LegendPosition.bottom,
    this.xAxisTitle,
    this.yAxisTitle,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
    this.legendDisplayMinValue,
    this.textStyle,
  });

  @override
  State<HeatmapChart> createState() => _HeatmapChartState();
}

class _HeatmapChartState extends State<HeatmapChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  /// Fade-in animation (0 to 1).
  late Animation<double> _fadeAnimation;

  int? _hoveredXIndex;
  int? _hoveredYIndex;
  OverlayEntry? _tooltipOverlayEntry;
  Offset _mouseGlobalPosition = Offset.zero;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 1.0, curve: widget.animationCurve),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(HeatmapChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
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

  HeatmapColorScale get _effectiveColorScale {
    if (widget.colorScale != null) return widget.colorScale!;
    final colors = widget.theme.heatmapGradientColors;
    if (colors.length < 2) {
      return HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );
    }
    // Generate evenly spaced stops from the theme's gradient colors
    final stops = <(double, Color)>[];
    for (var i = 0; i < colors.length; i++) {
      stops.add((i / (colors.length - 1), colors[i]));
    }
    return HeatmapColorScale(colorStops: stops);
  }

  double get _effectiveValueMin => widget.valueMin ?? widget.data.minValue;
  double get _effectiveValueMax => widget.valueMax ?? widget.data.maxValue;

  // --- Hover handling ---

  void _handleHover(Offset localPosition, Size size) {
    final hitResult = hitTestHeatmap(
      localPosition: localPosition,
      size: size,
      data: widget.data,
      theme: widget.theme,
      colorLegendPosition: widget.colorLegendPosition,
      xAxisTitle: widget.xAxisTitle,
      yAxisTitle: widget.yAxisTitle,
    );

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _mouseGlobalPosition = renderBox.localToGlobal(localPosition);
    }

    final newXIdx = hitResult?.xIndex;
    final newYIdx = hitResult?.yIndex;

    if (newXIdx != _hoveredXIndex || newYIdx != _hoveredYIndex) {
      setState(() {
        _hoveredXIndex = newXIdx;
        _hoveredYIndex = newYIdx;
      });

      if (widget.showTooltip) {
        if (newXIdx != null && newYIdx != null) {
          _showTooltip(xIndex: newXIdx, yIndex: newYIdx);
        } else {
          _removeTooltip();
        }
      }
    } else if (widget.showTooltip && newXIdx != null) {
      _updateTooltipPosition();
    }
  }

  void _handleMouseExit() {
    setState(() {
      _hoveredXIndex = null;
      _hoveredYIndex = null;
    });
    _removeTooltip();
  }

  // --- Tap handling ---

  void _handleTapDown(TapDownDetails details, Size size) {
    if (widget.onElementTap == null) return;

    final hitResult = hitTestHeatmap(
      localPosition: details.localPosition,
      size: size,
      data: widget.data,
      theme: widget.theme,
      colorLegendPosition: widget.colorLegendPosition,
      xAxisTitle: widget.xAxisTitle,
      yAxisTitle: widget.yAxisTitle,
    );
    if (hitResult == null) return;

    final xIdx = hitResult.xIndex;
    final yIdx = hitResult.yIndex;
    final value = widget.data.values[yIdx][xIdx];
    if (value == null) return;

    final colorScale = _effectiveColorScale;
    final vMin = _effectiveValueMin;
    final vMax = _effectiveValueMax;
    final range = vMax - vMin;
    final normalizedValue = range > 0 ? (value - vMin) / range : 0.5;
    final cellColor = colorScale.colorAt(normalizedValue);

    widget.onElementTap!(
      xIdx,
      yIdx,
      widget.data.xCategories[xIdx],
      widget.data.yCategories[yIdx],
      value,
      cellColor,
    );
  }

  // --- Tooltip ---

  void _showTooltip({required int xIndex, required int yIndex}) {
    _removeTooltip();

    final value = widget.data.values[yIndex][xIndex];
    if (value == null) return;

    final colorScale = _effectiveColorScale;
    final vMin = _effectiveValueMin;
    final vMax = _effectiveValueMax;
    final range = vMax - vMin;
    final normalizedValue = range > 0 ? (value - vMin) / range : 0.5;
    final cellColor = colorScale.colorAt(normalizedValue);

    _tooltipOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _HeatmapTooltipPositioner(
          mouseGlobalPosition: _mouseGlobalPosition,
          child: widget.tooltipBuilder != null
              ? widget.tooltipBuilder!(
                  overlayContext,
                  widget.data.xCategories[xIndex],
                  widget.data.yCategories[yIndex],
                  value,
                  cellColor,
                )
              : _DefaultHeatmapTooltip(
                  xCategory: widget.data.xCategories[xIndex],
                  yCategory: widget.data.yCategories[yIndex],
                  value: value,
                  cellColor: cellColor,
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

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    if (widget.data.xCount == 0 || widget.data.yCount == 0) {
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
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onHover: (event) => _handleHover(event.localPosition, size),
              onExit: (_) => _handleMouseExit(),
              child: GestureDetector(
                onTapDown: (details) => _handleTapDown(details, size),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: size,
                      painter: HeatmapPainter(
                        data: widget.data,
                        colorScale: _effectiveColorScale,
                        valueMin: _effectiveValueMin,
                        valueMax: _effectiveValueMax,
                        theme: widget.theme,
                        baseTextStyle: widget.textStyle,
                        animationProgress: _fadeAnimation.value,
                        hoveredXIndex: _hoveredXIndex,
                        hoveredYIndex: _hoveredYIndex,
                        colorLegendPosition: widget.colorLegendPosition,
                        xAxisTitle: widget.xAxisTitle,
                        yAxisTitle: widget.yAxisTitle,
                        unit: widget.unit,
                        unitPosition: widget.unitPosition,
                        valueScale: widget.valueScale,
                        useThousandsSeparator: widget.useThousandsSeparator,
                        displayMinValue: widget.legendDisplayMinValue ?? 0.0,
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
class _HeatmapTooltipPositioner extends StatelessWidget {
  final Offset mouseGlobalPosition;
  final Widget child;

  static const _cursorOffsetX = 12.0;
  static const _cursorOffsetY = 16.0;

  const _HeatmapTooltipPositioner({
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
/// Displays Y/X category labels with a colored square and the value.
class _DefaultHeatmapTooltip extends StatelessWidget {
  final String xCategory;
  final String yCategory;
  final double value;
  final Color cellColor;
  final ChartTheme theme;
  final String? unit;
  final UnitPosition unitPosition;
  final ValueScale valueScale;
  final bool useThousandsSeparator;
  final TextStyle? baseTextStyle;

  const _DefaultHeatmapTooltip({
    required this.xCategory,
    required this.yCategory,
    required this.value,
    required this.cellColor,
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
          Text('$yCategory / $xCategory', style: _resolveStyle(theme.tooltipLabelStyle)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                formatChartValue(
                  value,
                  unit: unit,
                  unitPosition: unitPosition,
                  valueScale: valueScale,
                  decimalPlaces: 1,
                  useThousandsSeparator: useThousandsSeparator,
                ),
                style: _resolveStyle(theme.tooltipValueStyle).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
