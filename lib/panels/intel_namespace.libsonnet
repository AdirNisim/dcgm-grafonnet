// Row 4: Namespace GPU Compute Share
// Who is consuming GPU time? Compute share (not just VRAM) is the billing-relevant signal.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../intel_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local barGauge = g.panel.barGauge;
local pieChart = g.panel.pieChart;
local timeSeries = g.panel.timeSeries;
local row = g.panel.row;

local ds = '${datasource}';

local tsDefaults =
  timeSeries.fieldConfig.defaults.custom.withDrawStyle('line')
  + timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth')
  + timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
  + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('none');

{
  panels: [
    row.new('Namespace GPU Compute & VRAM Share')
    + row.withGridPos(55),

    // Compute Share — current snapshot bar gauge
    barGauge.new('GPU Compute Share by Namespace (Current)')
    + barGauge.panelOptions.withDescription('Sum of GR engine active % across all devices per namespace. This is GPU compute time consumed, not VRAM — the billing-relevant signal.')
    + barGauge.panelOptions.withGridPos(8, 8, 0, 56)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.computeShareByNamespace)
      + prometheus.withLegendFormat('{{exported_namespace}}'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.color.withMode('palette-classic')
    + barGauge.options.withDisplayMode('basic')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(false),

    // Compute Share — time-range average bar gauge (capacity planning view)
    barGauge.new('GPU Compute Share by Namespace (Range Avg)')
    + barGauge.panelOptions.withDescription('Average compute share per namespace over the selected time range. Use 7d or 30d for capacity planning and chargeback decisions.')
    + barGauge.panelOptions.withGridPos(8, 8, 8, 56)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.computeShareByNamespaceAvg)
      + prometheus.withLegendFormat('{{exported_namespace}}'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.color.withMode('palette-classic')
    + barGauge.options.withDisplayMode('basic')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(false),

    // VRAM share pie — shows allocation, not compute time
    pieChart.new('VRAM Share by Namespace')
    + pieChart.panelOptions.withDescription('VRAM consumed per namespace. Compare with compute share: a namespace with high VRAM but low compute share has idle models loaded.')
    + pieChart.panelOptions.withGridPos(8, 8, 16, 56)
    + pieChart.queryOptions.withTargets([
      prometheus.new(ds, q.vramShareByNamespace)
      + prometheus.withLegendFormat('{{exported_namespace}}'),
    ])
    + pieChart.standardOptions.withUnit('decmbytes')
    + pieChart.standardOptions.color.withMode('palette-classic')
    + pieChart.options.withPieType('donut')
    + pieChart.options.withDisplayLabels(['name', 'percent'])
    + pieChart.options.legend.withDisplayMode('table')
    + pieChart.options.legend.withPlacement('right')
    + pieChart.options.legend.withShowLegend(true)
    + pieChart.options.legend.withValues(['value', 'percent'])
    + pieChart.options.tooltip.withMode('single'),

    // Compute share by namespace over time — trend view
    timeSeries.new('GPU Compute Share by Namespace Over Time')
    + timeSeries.panelOptions.withDescription('Compute share per namespace over time. Use with 7-30d range. Growing lines = teams ramping up; flat lines with high VRAM = idle allocations.')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 65)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.computeShareByNamespace)
      + prometheus.withLegendFormat('{{exported_namespace}}'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
    + timeSeries.options.legend.withSortBy('Last')
    + timeSeries.options.legend.withSortDesc(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),
  ],
}
