// Row 3: Request Latency
// TTFT and TPOT percentile stats, TTFT over time, E2E latency over time, TPOT over time.
// TTFT = prefill latency signal. TPOT = decode throughput signal. E2E = user-perceived latency.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../vllm_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local timeSeries = g.panel.timeSeries;
local row = g.panel.row;

local ds = '${datasource}';

local tsDefaults =
  timeSeries.fieldConfig.defaults.custom.withDrawStyle('line')
  + timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth')
  + timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + timeSeries.fieldConfig.defaults.custom.withFillOpacity(8)
  + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
  + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('none');

// TTFT thresholds: green < 1s, yellow < 5s, red >= 5s
local ttftThresholds = [
  { color: 'green', value: null },
  { color: '#EAB839', value: 1 },
  { color: 'red', value: 5 },
];

// TPOT thresholds: green < 0.05s (20 tok/s+), yellow < 0.1s, red >= 0.1s
local tpotThresholds = [
  { color: 'green', value: null },
  { color: '#EAB839', value: 0.05 },
  { color: 'red', value: 0.1 },
];

// E2E thresholds: green < 10s, yellow < 30s, red >= 30s
local e2eThresholds = [
  { color: 'green', value: null },
  { color: '#EAB839', value: 10 },
  { color: 'red', value: 30 },
];

{
  panels: [
    row.new('Request Latency')
    + row.withGridPos(16),

    // --- TTFT stat row ---
    stat.new('TTFT P50')
    + stat.panelOptions.withDescription('Median Time to First Token — typical prefill latency')
    + stat.panelOptions.withGridPos(4, 4, 0, 17)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.ttftP50)
      + prometheus.withLegendFormat('P50'),
    ])
    + stat.standardOptions.withUnit('s')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(ttftThresholds)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('TTFT P95')
    + stat.panelOptions.withDescription('95th percentile TTFT — tail latency for prefill')
    + stat.panelOptions.withGridPos(4, 4, 4, 17)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.ttftP95)
      + prometheus.withLegendFormat('P95'),
    ])
    + stat.standardOptions.withUnit('s')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(ttftThresholds)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('TTFT P99')
    + stat.panelOptions.withDescription('99th percentile TTFT — worst-case prefill latency')
    + stat.panelOptions.withGridPos(4, 4, 8, 17)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.ttftP99)
      + prometheus.withLegendFormat('P99'),
    ])
    + stat.standardOptions.withUnit('s')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(ttftThresholds)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // --- TPOT stat row ---
    stat.new('TPOT P50')
    + stat.panelOptions.withDescription('Median Time per Output Token — P50 decode speed. Lower is faster.')
    + stat.panelOptions.withGridPos(4, 4, 12, 17)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.tpotP50)
      + prometheus.withLegendFormat('P50'),
    ])
    + stat.standardOptions.withUnit('s')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(tpotThresholds)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('TPOT P95')
    + stat.panelOptions.withDescription('95th percentile TPOT — tail decode latency per token')
    + stat.panelOptions.withGridPos(4, 4, 16, 17)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.tpotP95)
      + prometheus.withLegendFormat('P95'),
    ])
    + stat.standardOptions.withUnit('s')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(tpotThresholds)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('TPOT P99')
    + stat.panelOptions.withDescription('99th percentile TPOT — worst-case decode speed per token')
    + stat.panelOptions.withGridPos(4, 4, 20, 17)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.tpotP99)
      + prometheus.withLegendFormat('P99'),
    ])
    + stat.standardOptions.withUnit('s')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(tpotThresholds)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // TTFT over time — P50 / P95 / P99 per model
    timeSeries.new('Time to First Token Over Time')
    + timeSeries.panelOptions.withDescription('TTFT percentiles over time. Spikes indicate compute-heavy prefill (long prompts, heavy load). Sustained elevation = need more GPU capacity or shorter context limits.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 22)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.ttftP50OverTime)
      + prometheus.withLegendFormat('P50 {{model_name}}'),
      prometheus.new(ds, q.ttftP95OverTime)
      + prometheus.withLegendFormat('P95 {{model_name}}'),
      prometheus.new(ds, q.ttftP99OverTime)
      + prometheus.withLegendFormat('P99 {{model_name}}'),
    ])
    + timeSeries.standardOptions.withUnit('s')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(ttftThresholds)
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

    // E2E latency over time — P50 / P95 / P99 per model
    timeSeries.new('End-to-End Request Duration Over Time')
    + timeSeries.panelOptions.withDescription('Full request duration (queue wait + prefill + decode). P99 is the user-perceived worst case. Growing P99 with stable TTFT = decode bottleneck.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 22)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.e2eP50OverTime)
      + prometheus.withLegendFormat('P50 {{model_name}}'),
      prometheus.new(ds, q.e2eP95OverTime)
      + prometheus.withLegendFormat('P95 {{model_name}}'),
      prometheus.new(ds, q.e2eP99OverTime)
      + prometheus.withLegendFormat('P99 {{model_name}}'),
    ])
    + timeSeries.standardOptions.withUnit('s')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(e2eThresholds)
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

    // TPOT over time — P50 / P99 per model
    timeSeries.new('Time per Output Token Over Time')
    + timeSeries.panelOptions.withDescription('TPOT percentiles over time. Rising TPOT = decode is slower, fewer concurrent batches possible. Correlate with requests_running.')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 31)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.tpotP50OverTime)
      + prometheus.withLegendFormat('P50 {{model_name}}'),
      prometheus.new(ds, q.tpotP99OverTime)
      + prometheus.withLegendFormat('P99 {{model_name}}'),
    ])
    + timeSeries.standardOptions.withUnit('s')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(tpotThresholds)
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
