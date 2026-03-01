# crystal_charts

[![pub package](https://img.shields.io/pub/v/crystal_charts.svg)](https://pub.dev/packages/crystal_charts)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A comprehensive Flutter charting library with rich animations, interactive tooltips, and customizable themes.
Supports 7 chart types for building data visualization dashboards.

## Features

| Chart | Widget | Description |
|---|---|---|
| **Area** | `AreaChart` | Gradient-filled area chart with smooth curve support |
| **Bar** | `BarChart` | Grouped vertical bar chart |
| **Column** | `ColumnChart` | Grouped and stacked column chart |
| **Dual Axes** | `DualAxesChart` | Dual-axis chart with independent left/right Y-axes (line / area / column) |
| **Heatmap** | `HeatmapChart` | Category x category heatmap with color scale legend |
| **Horizontal Bar** | `HorizontalBarChart` | Horizontal bar chart |
| **Sunburst** | `SunburstChart` | Sunburst chart with drill-down support |

### Common Features

- **Hover Tooltips** — Custom builder support
- **Animations** — Smooth enter and transition animations
- **Theming** — `ChartTheme.defaultTheme` / `ChartTheme.darkTheme` + fully customizable properties
- **Value Formatter** — Unit display, scaling (K / 10K), thousands separator
- **Tap Callbacks** — Event notification on element tap
- **Axis Titles & Labels** — Show/hide control

## Installation

```yaml
dependencies:
  crystal_charts: ^0.1.0
```

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:crystal_charts/crystal_charts.dart';

// Area Chart
AreaChart(
  seriesList: [
    ChartSeries(
      name: 'Sales',
      color: Color(0xFF5B8FF9),
      dataPoints: [
        ChartDataPoint(x: 0, y: 1200, label: 'Jan'),
        ChartDataPoint(x: 1, y: 2500, label: 'Feb'),
        ChartDataPoint(x: 2, y: 1800, label: 'Mar'),
      ],
    ),
  ],
  unit: r'$',
  unitPosition: UnitPosition.prefix,
  valueScale: ValueScale.divideBy1000,
  xAxisTitle: 'Month',
  yAxisTitle: 'Revenue',
)
```

## Chart Examples

### Bar Chart

```dart
BarChart(
  seriesList: [
    ChartSeries(
      name: 'Revenue',
      color: Color(0xFFF6BD16),
      dataPoints: [
        ChartDataPoint(x: 0, y: 50000, label: 'Q1'),
        ChartDataPoint(x: 1, y: 72000, label: 'Q2'),
        ChartDataPoint(x: 2, y: 61000, label: 'Q3'),
      ],
    ),
  ],
  unit: r'$',
  unitPosition: UnitPosition.prefix,
  valueScale: ValueScale.divideBy1000,
)
```

### Column Chart (Stacked)

```dart
ColumnChart(
  seriesList: [series1, series2],
  mode: ColumnMode.stacked,
  xAxisTitle: 'Month',
  yAxisTitle: 'Count',
)
```

### Dual Axes Chart

```dart
DualAxesChart(
  leftSeriesList: [countSeries],
  rightSeriesList: [amountSeries],
  leftChartType: DualAxesChartType.column,
  rightChartType: DualAxesChartType.line,
  leftUnit: '',
  rightUnit: r'$',
  rightUnitPosition: UnitPosition.prefix,
  rightValueScale: ValueScale.divideBy1000,
)
```

### Heatmap Chart

```dart
HeatmapChart(
  data: HeatmapData(
    xCategories: ['Category A', 'Category B'],
    yCategories: ['Group 1', 'Group 2'],
    values: [
      [10, 20],
      [15, null],  // null means no data
    ],
  ),
  colorLegendPosition: LegendPosition.right,
)
```

### Sunburst Chart

```dart
SunburstChart(
  data: ChartTreeNode(
    name: 'Root',
    children: [
      ChartTreeNode(name: 'A', value: 30),
      ChartTreeNode(
        name: 'B',
        children: [
          ChartTreeNode(name: 'B-1', value: 20),
          ChartTreeNode(name: 'B-2', value: 10),
        ],
      ),
    ],
  ),
  visibleDepth: 3,
  showLegend: true,
)
```

## Theming

```dart
// Built-in themes
BarChart(theme: ChartTheme.defaultTheme, ...)
BarChart(theme: ChartTheme.darkTheme, ...)

// Custom theme
BarChart(
  theme: ChartTheme(
    backgroundColor: Colors.grey[50]!,
    barBorderRadiusPx: 4.0,
    barDimmedOpacity: 0.3,
    tooltipBackgroundColor: Color(0xE6333333),
  ),
  ...
)
```

## Value Formatting

```dart
// Unit display
BarChart(unit: 'kg', ...)

// Scaling (divide by 1000 for display)
BarChart(valueScale: ValueScale.divideBy1000, ...)

// Prefix unit ($100)
BarChart(unit: r'$', unitPosition: UnitPosition.prefix, ...)

// Disable thousands separator
BarChart(useThousandsSeparator: false, ...)
```

## Known Limitations

- **Calendar Heatmap**: Snap-scroll month navigation is currently disabled. Will be supported in a future release.

## Example

See the [example/](example/) directory for a complete usage demo.

```bash
cd example
flutter run -d chrome
```

## License

MIT License — see [LICENSE](LICENSE) for details.
