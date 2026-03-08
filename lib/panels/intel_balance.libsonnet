// Row 8: Node GPU Balance
// Detect scheduling imbalance across nodes. Uneven load indicates affinity issues,
// device faults, or taint/toleration misconfigurations.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../intel_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local barGauge = g.panel.barGauge;
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

// Imbalance thresholds: > 20% spread is notable, > 40% is a problem
local imbalanceThresholds = [
  { color: 'green', value: null },
  { color: '#EAB839', value: 20 },
  { color: 'red', value: 40 },
];

{
  panels: [
    row.new('Node GPU Balance')
    + row.withGridPos(133),

    // Compute imbalance stat
    stat.new('Compute Imbalance')
    + stat.panelOptions.withDescription('Max node compute % minus min node compute %. >20% = scheduling skew worth investigating.')
    + stat.panelOptions.withGridPos(4, 4, 0, 134)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.computeImbalance)
      + prometheus.withLegendFormat('Imbalance'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(imbalanceThresholds)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Compute per node — current snapshot
    barGauge.new('Compute % per Node')
    + barGauge.panelOptions.withDescription('Average GR engine active % per node. Large gaps between nodes indicate scheduling imbalance.')
    + barGauge.panelOptions.withGridPos(8, 10, 4, 134)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.computePerNode)
      + prometheus.withLegendFormat('{{Hostname}}'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.withMin(0)
    + barGauge.standardOptions.withMax(100)
    + barGauge.standardOptions.color.withMode('thresholds')
    + barGauge.standardOptions.thresholds.withSteps(t.compute)
    + barGauge.options.withDisplayMode('gradient')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true),

    // VRAM per node — current snapshot
    barGauge.new('VRAM % per Node')
    + barGauge.panelOptions.withDescription('Average VRAM utilization % per node. Cross with compute: node with high VRAM + low compute = idle models sitting on that node.')
    + barGauge.panelOptions.withGridPos(8, 10, 14, 134)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.vramPerNode)
      + prometheus.withLegendFormat('{{Hostname}}'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.withMin(0)
    + barGauge.standardOptions.withMax(100)
    + barGauge.standardOptions.color.withMode('thresholds')
    + barGauge.standardOptions.thresholds.withSteps(t.memory)
    + barGauge.options.withDisplayMode('gradient')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true),

    // Compute per node over time — detect drift and spikes
    timeSeries.new('Compute % per Node Over Time')
    + timeSeries.panelOptions.withDescription('Per-node compute % over time. Nodes that consistently run hotter than others may have affinity rules concentrating workloads, or devices that are not exporting metrics correctly.')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 143)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.computePerNodeOverTime)
      + prometheus.withLegendFormat('{{Hostname}}'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.compute)
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
