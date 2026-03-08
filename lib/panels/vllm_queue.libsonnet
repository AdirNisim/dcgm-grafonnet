// Row 5: Queue & Scheduler
// Queue depth over time (running/waiting/swapped), preemption rate, per-pod replica view.
// Queue growth = saturation. Preemptions = KV cache thrashing.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../vllm_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local timeSeries = g.panel.timeSeries;
local stat = g.panel.stat;
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

local tsStackedDefaults =
  timeSeries.fieldConfig.defaults.custom.withDrawStyle('line')
  + timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth')
  + timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + timeSeries.fieldConfig.defaults.custom.withFillOpacity(20)
  + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
  + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal');

// Preemption rate thresholds: green = 0, yellow = any, red = sustained
local preemptThresholds = [
  { color: 'green', value: null },
  { color: 'red', value: 0.01 },
];

{
  panels: [
    row.new('Queue & Scheduler')
    + row.withGridPos(59),

    // Request queue depth over time — stacked running / waiting / swapped
    timeSeries.new('Request Queue Depth Over Time')
    + timeSeries.panelOptions.withDescription('Running (being decoded) / Waiting (queue) / Swapped (CPU offload) per model. Waiting growth = saturation. Swapped > 0 = KV cache full, preemptions imminent.')
    + timeSeries.panelOptions.withGridPos(8, 14, 0, 60)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.queueRunningOverTime)
      + prometheus.withLegendFormat('Running {{model_name}}'),
      prometheus.new(ds, q.queueWaitingOverTime)
      + prometheus.withLegendFormat('Waiting {{model_name}}'),
      prometheus.new(ds, q.queueSwappedOverTime)
      + prometheus.withLegendFormat('Swapped {{model_name}}'),
    ])
    + timeSeries.standardOptions.withUnit('short')
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

    // Preemption rate over time
    timeSeries.new('Preemption Rate')
    + timeSeries.panelOptions.withDescription('KV cache preemptions per second. Any sustained preemption rate degrades latency — it means requests are being evicted from GPU cache and re-computed.')
    + timeSeries.panelOptions.withGridPos(8, 10, 14, 60)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.preemptionRate)
      + prometheus.withLegendFormat('{{model_name}}'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(preemptThresholds)
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

    // Per-pod running requests — replica distribution
    timeSeries.new('Running Requests per Pod')
    + timeSeries.panelOptions.withDescription('Active requests per replica. Even distribution = healthy load balancing. Skew = sticky sessions or readiness probe issues on some replicas.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 69)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.runningByPod)
      + prometheus.withLegendFormat('{{pod}}'),
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

    // Per-pod waiting requests — queue distribution
    timeSeries.new('Waiting Requests per Pod')
    + timeSeries.panelOptions.withDescription('Queue depth per replica. Any pod consistently non-zero while others are idle = load balancer not distributing evenly.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 69)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.waitingByPod)
      + prometheus.withLegendFormat('{{pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(preemptThresholds)
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
