## 0.2.0

* Add tap-based tooltip and highlight for all chart types on iOS/touch devices.
* Fix BarChart hit test accuracy by passing full layout parameters (yScale, unit, valueScale, etc.).
* Add `TextDecoration.none` to tooltip text styles to prevent unwanted underlines on iOS.

## 0.1.3

* Add dynamic axis label sizing and X-axis label rotation for BarChart.

## 0.1.2

* Change calendar heatmap month selector labels from English abbreviations (Jan–Dec) to numeric (1–12).

## 0.1.1

* Fix axis title and axis label overlap on all chart types.
* Fix axis labels wrapping to multiple lines (enforce single-line rendering).
* Fix DualAxes right Y-axis title overlapping with labels.
* Increase axis title padding (20px → 24px) and X-axis title offset (22px → 26px).

## 0.1.0

* Initial release.
* **Area Chart** — Gradient-filled area chart with smooth curve support.
* **Bar Chart** — Grouped vertical bar chart.
* **Column Chart** — Column chart with grouping and stacking support.
* **Dual Axes Chart** — Dual-axis chart with independent left/right Y axes (line / area / column).
* **Heatmap Chart** — Category-by-category heatmap with color scale legend.
* **Horizontal Bar Chart** — Horizontal bar chart.
* **Sunburst Chart** — Sunburst chart with drill-down support.
* **Calendar Heatmap** — High-performance calendar heatmap based on Canvas (`CustomPainter`).
* **Common features**: Hover tooltips, animations, customizable themes (light/dark), value formatter (unit, scaling, thousands separator).
