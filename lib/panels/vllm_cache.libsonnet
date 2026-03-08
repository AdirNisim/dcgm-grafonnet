// Row 2: KV Cache
// GPU cache utilization gauge, hit rate gauge, cache usage over time timeseries.
// High cache = pressure → preemptions; low hit rate = no prefix reuse benefit.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../vllm_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local gauge = g.panel.gauge;
local stat = g.panel.stat;
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

// Cache utilization: green < 70%, yellow < 90%, red >= 90%
local cacheThresholds = [
  { color: 'green', value: null },
  { color: '#EAB839', value: 0.7 },
  { color: 'red', value: 0.9 },
];

// Hit rate: inverted — low hit rate is a concern
local hitRateThresholds = [
  { color: '#EAB839', value: null },
  { color: 'green', value: 0.5 },
];

{
  panels: [
    row.new('KV Cache')
    + row.withGridPos(6),

    // GPU KV cache utilization gauge
    gauge.new('GPU KV Cache Usage')
    + gauge.panelOptions.withDescription('GPU KV cache utilization (0–1). Above 0.9 = preemption risk. Values are per-engine; averaged across replicas here.')
    + gauge.panelOptions.withGridPos(8, 6, 0, 7)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.gpuCacheUsage)
      + prometheus.withLegendFormat('GPU Cache'),
    ])
    + gauge.standardOptions.withUnit('percentunit')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(1)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(cacheThresholds)
    + gauge.options.withShowThresholdLabels(false)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['lastNotNull']),

    // CPU KV cache utilization gauge
    gauge.new('CPU KV Cache Usage')
    + gauge.panelOptions.withDescription('CPU KV cache utilization (0–1). Only meaningful when CPU offloading is enabled. Non-zero = GPU cache has been full at least once.')
    + gauge.panelOptions.withGridPos(8, 6, 6, 7)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.cpuCacheUsage)
      + prometheus.withLegendFormat('CPU Cache'),
    ])
    + gauge.standardOptions.withUnit('percentunit')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(1)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(cacheThresholds)
    + gauge.options.withShowThresholdLabels(false)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['lastNotNull']),

    // Prefix cache hit rate stat (v0.14+)
    stat.new('Prefix Cache Hit Rate')
    + stat.panelOptions.withDescription('Fraction of prompt tokens served from prefix cache. High hit rate = cost savings on repeated prefixes. Requires v0.14+.')
    + stat.panelOptions.withGridPos(8, 6, 12, 7)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.cacheHitRate)
      + prometheus.withLegendFormat('Hit Rate'),
    ])
    + stat.standardOptions.withUnit('percentunit')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(hitRateThresholds)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // KV cache usage over time — per pod for replica comparison
    timeSeries.new('GPU KV Cache Usage Over Time')
    + timeSeries.panelOptions.withDescription('GPU KV cache utilization per pod over time. Pods consistently at >0.85 will experience preemptions and latency spikes.')
    + timeSeries.panelOptions.withGridPos(8, 6, 18, 7)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.gpuCacheOverTime)
      + prometheus.withLegendFormat('{{pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('percentunit')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(1)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(cacheThresholds)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
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
