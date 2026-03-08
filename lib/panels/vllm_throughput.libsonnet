// Row 4: Token Throughput
// Generation rate, prompt rate, request rate over time.
// Prompt/output length distributions (P50 / P95) for capacity sizing.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../vllm_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
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
    row.new('Token Throughput')
    + row.withGridPos(40),

    // Token generation rate over time — per model
    timeSeries.new('Token Generation Rate')
    + timeSeries.panelOptions.withDescription('Output tokens per second per model. Primary capacity metric — size GPU fleet to sustain this rate at target latency.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 41)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.genTokenRateOverTime)
      + prometheus.withLegendFormat('Gen {{model_name}}'),
      prometheus.new(ds, q.promptTokenRateOverTime)
      + prometheus.withLegendFormat('Prompt {{model_name}}'),
    ])
    + timeSeries.standardOptions.withUnit('short')
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

    // Request throughput over time
    timeSeries.new('Request Throughput')
    + timeSeries.panelOptions.withDescription('Successful requests per second per model. Combine with token rate to understand avg response length trends.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 41)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.requestThroughputOverTime)
      + prometheus.withLegendFormat('{{model_name}}'),
    ])
    + timeSeries.standardOptions.withUnit('reqps')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('blue'))
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

    // Prompt length distribution over time
    timeSeries.new('Prompt Length Distribution (tokens)')
    + timeSeries.panelOptions.withDescription('P50 / P95 prompt token count. Long prompts drive higher TTFT and VRAM usage. Growing P95 = context is getting longer over time.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 50)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.promptLenP50)
      + prometheus.withLegendFormat('P50 {{model_name}}'),
      prometheus.new(ds, q.promptLenP95)
      + prometheus.withLegendFormat('P95 {{model_name}}'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('purple'))
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

    // Output length distribution over time
    timeSeries.new('Output Length Distribution (tokens)')
    + timeSeries.panelOptions.withDescription('P50 / P95 output token count. Drives TPOT and total GPU time per request. Growing P95 = users triggering longer generation.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 50)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.outputLenP50)
      + prometheus.withLegendFormat('P50 {{model_name}}'),
      prometheus.new(ds, q.outputLenP95)
      + prometheus.withLegendFormat('P95 {{model_name}}'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('orange'))
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
