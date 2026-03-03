import 'package:flutter/material.dart';

import '../layout/sunburst_layout.dart';
import '../models/chart_tree_node.dart';
import '../models/legend_position.dart';
import '../painters/sunburst_painter.dart';
import '../theme/chart_theme.dart';

/// Callback type for segment tap events.
typedef SunburstSegmentTapCallback =
    void Function(ChartTreeNode node, int depth);

/// Custom builder type for tooltips.
/// Receives the segment's node and hierarchy depth, and returns an arbitrary Widget.
typedef SunburstTooltipBuilder =
    Widget Function(BuildContext context, ChartTreeNode node, int depth);

/// Sunburst chart widget.
///
/// Displays hierarchical data as concentric arcs.
/// Tapping a segment drills down into its children,
/// and tapping the center navigates back to the parent level.
///
/// ```dart
/// SunburstChart(
///   data: ChartTreeNode(name: 'root', children: [...]),
///   showTooltip: true,
/// )
/// ```
class SunburstChart extends StatefulWidget {
  final ChartTreeNode data;
  final ChartTheme theme;

  /// Number of rings to display at once (hierarchy depth).
  final int visibleDepth;

  /// Radius ratio of the center hollow circle (0.0 to 1.0).
  final double innerRadiusRatio;

  /// Callback for segment tap events. Called after drill-down processing.
  final SunburstSegmentTapCallback? onSegmentTap;

  /// Whether to show a tooltip on hover.
  final bool showTooltip;

  /// Custom tooltip builder.
  /// If not specified, a default tooltip (name and value) is displayed.
  final SunburstTooltipBuilder? tooltipBuilder;

  /// Whether to show the legend.
  final bool showLegend;

  /// Display position of the legend.
  final LegendPosition legendPosition;

  /// Base text style. Takes priority over the theme's textStyle.
  final TextStyle? textStyle;

  const SunburstChart({
    super.key,
    required this.data,
    this.theme = ChartTheme.defaultTheme,
    this.visibleDepth = 3,
    this.innerRadiusRatio = 0.2,
    this.onSegmentTap,
    this.showTooltip = true,
    this.tooltipBuilder,
    this.showLegend = false,
    this.legendPosition = LegendPosition.bottom,
    this.textStyle,
  });

  @override
  State<SunburstChart> createState() => _SunburstChartState();
}

class _SunburstChartState extends State<SunburstChart>
    with SingleTickerProviderStateMixin {
  /// The root node currently displayed via drill-down.
  /// Initially the same as widget.data.
  late ChartTreeNode _currentRoot;

  /// Drill-down history stack. Tapping the center navigates back one level.
  final List<ChartTreeNode> _drillDownStack = [];

  late List<SunburstSegment> _segments;
  int? _highlightedIndex;

  /// Whether the center circle is being hovered.
  bool _isCenterHovered = false;

  late AnimationController _animationController;
  late Animation<double> _animation;

  /// OverlayEntry for tooltip display.
  OverlayEntry? _tooltipOverlayEntry;

  /// Current mouse position (global coordinates).
  Offset _mouseGlobalPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentRoot = widget.data;
    _segments = _computeSegments();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(SunburstChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _currentRoot = widget.data;
      _drillDownStack.clear();
      _segments = _computeSegments();
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

  List<SunburstSegment> _computeSegments() {
    return computeSunburstLayout(
      rootNode: _currentRoot,
      maxDepth: widget.visibleDepth,
    );
  }

  void _handleTapDown(TapDownDetails details, Size size) {
    final index = hitTestSunburst(
      tapPosition: details.localPosition,
      size: size,
      segments: _segments,
      maxVisibleDepth: widget.visibleDepth,
      innerRadiusRatio: widget.innerRadiusRatio,
    );

    if (index == null) {
      if (_highlightedIndex != null || _isCenterHovered) {
        setState(() {
          _highlightedIndex = null;
          _isCenterHovered = false;
        });
        _removeTooltip();
      }
      return;
    }

    if (index == -1) {
      _drillUp();
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _mouseGlobalPosition = renderBox.localToGlobal(details.localPosition);
    }

    if (index != _highlightedIndex) {
      setState(() {
        _highlightedIndex = index;
        _isCenterHovered = false;
      });

      if (widget.showTooltip) {
        _showTooltip(_segments[index]);
      }
    }

    final tappedSegment = _segments[index];
    widget.onSegmentTap?.call(tappedSegment.node, tappedSegment.depth);

    if (tappedSegment.hasChildren) {
      _drillDown(tappedSegment.node);
    }
  }

  void _drillDown(ChartTreeNode node) {
    setState(() {
      _drillDownStack.add(_currentRoot);
      _currentRoot = node;
      _segments = _computeSegments();
      _highlightedIndex = null;
      _animationController.forward(from: 0);
    });
    _removeTooltip();
  }

  void _drillUp() {
    if (_drillDownStack.isEmpty) return;
    setState(() {
      _currentRoot = _drillDownStack.removeLast();
      _segments = _computeSegments();
      _highlightedIndex = null;
      _animationController.forward(from: 0);
    });
    _removeTooltip();
  }

  void _handleHover(Offset localPosition, Size size, Offset globalPosition) {
    final index = hitTestSunburst(
      tapPosition: localPosition,
      size: size,
      segments: _segments,
      maxVisibleDepth: widget.visibleDepth,
      innerRadiusRatio: widget.innerRadiusRatio,
    );

    final newIndex = (index != null && index >= 0) ? index : null;
    // Determine if the center circle is hovered
    final newCenterHovered = index == -1 && _drillDownStack.isNotEmpty;

    // Use RenderBox to obtain accurate global coordinates
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _mouseGlobalPosition = renderBox.localToGlobal(localPosition);
    } else {
      _mouseGlobalPosition = globalPosition;
    }

    if (newIndex != _highlightedIndex || newCenterHovered != _isCenterHovered) {
      setState(() {
        _highlightedIndex = newIndex;
        _isCenterHovered = newCenterHovered;
      });

      if (widget.showTooltip) {
        if (newIndex != null) {
          _showTooltip(_segments[newIndex]);
        } else {
          _removeTooltip();
        }
      }
    } else if (widget.showTooltip && newIndex != null) {
      // Mouse moved within the same segment; update position only
      _updateTooltipPosition();
    }
  }

  void _handleMouseExit() {
    setState(() {
      _highlightedIndex = null;
      _isCenterHovered = false;
    });
    _removeTooltip();
  }

  /// Creates and displays the tooltip OverlayEntry.
  void _showTooltip(SunburstSegment segment) {
    _removeTooltip();

    _tooltipOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _SunburstTooltipPositioner(
          mouseGlobalPosition: _mouseGlobalPosition,
          child: widget.tooltipBuilder != null
              ? widget.tooltipBuilder!(
                  overlayContext,
                  segment.node,
                  segment.depth,
                )
              : _DefaultSunburstTooltip(
                  segment: segment,
                  theme: widget.theme,
                  baseTextStyle: widget.textStyle,
                ),
        );
      },
    );

    Overlay.of(context).insert(_tooltipOverlayEntry!);
  }

  /// Updates the tooltip position.
  void _updateTooltipPosition() {
    _tooltipOverlayEntry?.markNeedsBuild();
  }

  /// Removes the tooltip OverlayEntry.
  void _removeTooltip() {
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final chartWidget = _buildChart();

    if (!widget.showLegend) return chartWidget;

    final legendWidget = _SunburstLegend(
      segments: _segments,
      theme: widget.theme,
      position: widget.legendPosition,
      baseTextStyle: widget.textStyle,
    );

    final isHorizontal =
        widget.legendPosition == LegendPosition.left ||
        widget.legendPosition == LegendPosition.right;

    if (isHorizontal) {
      return RepaintBoundary(
        child: Row(
          children: widget.legendPosition == LegendPosition.left
              ? [legendWidget, Expanded(child: chartWidget)]
              : [Expanded(child: chartWidget), legendWidget],
        ),
      );
    }

    return RepaintBoundary(
      child: Column(
        children: widget.legendPosition == LegendPosition.top
            ? [legendWidget, Expanded(child: chartWidget)]
            : [Expanded(child: chartWidget), legendWidget],
      ),
    );
  }

  Widget _buildChart() {
    // Show pointer cursor when hovering over center circle or a segment
    final showPointerCursor = _highlightedIndex != null || _isCenterHovered;

    final chart = Container(
      color: widget.theme.backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return MouseRegion(
            cursor: showPointerCursor
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onHover: (event) =>
                _handleHover(event.localPosition, size, event.position),
            onExit: (_) => _handleMouseExit(),
            child: GestureDetector(
              onTapDown: (details) => _handleTapDown(details, size),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return CustomPaint(
                    size: size,
                    painter: SunburstPainter(
                      segments: _segments,
                      maxVisibleDepth: widget.visibleDepth,
                      theme: widget.theme,
                      baseTextStyle: widget.textStyle,
                      innerRadiusRatio: widget.innerRadiusRatio,
                      highlightedIndex: _highlightedIndex,
                      animationProgress: _animation.value,
                      canDrillUp: _drillDownStack.isNotEmpty,
                      currentRootName: _currentRoot.name,
                      currentRootTotalValue: _currentRoot.totalValue,
                      isCenterHovered: _isCenterHovered,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );

    // Wrap chart directly with RepaintBoundary when no legend is shown
    if (!widget.showLegend) return RepaintBoundary(child: chart);
    return chart;
  }
}

/// Overlay widget that positions a tooltip at the mouse cursor location.
/// Automatically adjusts to prevent overflow at screen edges.
class _SunburstTooltipPositioner extends StatelessWidget {
  final Offset mouseGlobalPosition;
  final Widget child;

  /// Offset from the mouse cursor.
  static const _cursorOffsetX = 12.0;
  static const _cursorOffsetY = 16.0;

  const _SunburstTooltipPositioner({
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

/// Layout delegate that calculates tooltip positioning.
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
    // Default position: bottom-right of cursor
    var left = mousePosition.dx + cursorOffsetX;
    var top = mousePosition.dy + cursorOffsetY;

    // Prevent overflow at right edge: show to the left of cursor
    if (left + childSize.width > screenSize.width - 8) {
      left = mousePosition.dx - cursorOffsetX - childSize.width;
    }

    // Prevent overflow at bottom edge: show above cursor
    if (top + childSize.height > screenSize.height - 8) {
      top = mousePosition.dy - cursorOffsetY - childSize.height;
    }

    // Guard against top and left edge overflow
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

/// Built-in default tooltip UI.
/// Displays the segment's name and value.
class _DefaultSunburstTooltip extends StatelessWidget {
  final SunburstSegment segment;
  final ChartTheme theme;
  final TextStyle? baseTextStyle;

  const _DefaultSunburstTooltip({
    required this.segment,
    required this.theme,
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
          Text(segment.node.name, style: _resolveStyle(theme.tooltipLabelStyle)),
          const SizedBox(height: 2),
          Text('${segment.node.totalValue}', style: _resolveStyle(theme.tooltipValueStyle)),
        ],
      ),
    );
  }
}

/// Legend widget for the sunburst chart.
/// Displays color swatches + names for depth=1 (top-level) segments.
class _SunburstLegend extends StatelessWidget {
  final List<SunburstSegment> segments;
  final ChartTheme theme;
  final LegendPosition position;
  final TextStyle? baseTextStyle;

  const _SunburstLegend({
    required this.segments,
    required this.theme,
    required this.position,
    this.baseTextStyle,
  });

  TextStyle _resolveStyle(TextStyle s) =>
      baseTextStyle == null ? s : baseTextStyle!.merge(s);

  @override
  Widget build(BuildContext context) {
    final topLevelSegments = segments.where((s) => s.depth == 1).toList();

    final items = topLevelSegments.map((segment) {
      final color = sunburstSegmentColor(segment, segments);
      return _LegendItem(
        color: color,
        label: segment.node.name,
        labelStyle: _resolveStyle(theme.labelStyle),
      );
    }).toList();

    final isVertical =
        position == LegendPosition.left || position == LegendPosition.right;

    if (isVertical) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: items,
      ),
    );
  }
}

/// A single legend item (color swatch + label).
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final TextStyle labelStyle;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: labelStyle),
        ],
      ),
    );
  }
}
