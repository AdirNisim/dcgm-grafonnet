// Row 1: Service Health
// KPI stats: active requests, queue depth, token rate, TTFT P99, cache pressure.
// Variables: $namespace, $model_name (multi-select OK), $pod
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../vllm_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local row = g.panel.row;

local ds = '${datasource}';

// Thresholds for queue depth: 0 = healthy, yellow at 10, red at 50
local queueThresholds = [
  { color: 'green', value: null },
  { color: '#EAB839', value: 10 },
  { color: 'red', value: 50 },
];

// Thresholds for TTFT: green < 1s, yellow < 5s, red >= 5s
local ttftThresholds = [
  { color: 'green', value: null },
  { color: '#EAB839', value: 1 },
  { color: 'red', value: 5 },
];

// Thresholds for cache usage: green < 70%, yellow < 90%, red >= 90%
local cacheThresholds = [
  { color: 'green', value: null },
  { color: '#EAB839', value: 0.7 },
  { color: 'red', value: 0.9 },
];

{
  panels: [
    row.new('Service Health')
    + row.withGridPos(0),

    stat.new('Requests Running')
    + stat.panelOptions.withDescription('Requests currently being decoded across all selected replicas.')
    + stat.panelOptions.withGridPos(4, 4, 0, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.requestsRunning)
      + prometheus.withLegendFormat('Running'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Requests Waiting')
    + stat.panelOptions.withDescription('Requests in the scheduler queue waiting for a free slot. Growing queue = capacity pressure.')
    + stat.panelOptions.withGridPos(4, 4, 4, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.requestsWaiting)
      + prometheus.withLegendFormat('Waiting'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(queueThresholds)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Requests Swapped')
    + stat.panelOptions.withDescription('Requests preempted to CPU KV cache. Non-zero = GPU KV cache is under pressure.')
    + stat.panelOptions.withGridPos(4, 4, 8, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.requestsSwapped)
      + prometheus.withLegendFormat('Swapped'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: 'red', value: 1 },
    ])
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Request Throughput')
    + stat.panelOptions.withDescription('Completed requests per second across selected model(s).')
    + stat.panelOptions.withGridPos(4, 4, 12, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.requestThroughput)
      + prometheus.withLegendFormat('req/s'),
    ])
    + stat.standardOptions.withUnit('reqps')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Token Generation Rate')
    + stat.panelOptions.withDescription('Output tokens per second. Primary throughput signal for inference capacity planning.')
    + stat.panelOptions.withGridPos(4, 4, 16, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.tokenGenRate)
      + prometheus.withLegendFormat('tok/s'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('TTFT P99')
    + stat.panelOptions.withDescription('99th percentile Time to First Token. Proxy for prefill latency. >1s impacts perceived responsiveness.')
    + stat.panelOptions.withGridPos(4, 4, 20, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.ttftP99Snapshot)
      + prometheus.withLegendFormat('P99'),
    ])
    + stat.standardOptions.withUnit('s')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(ttftThresholds)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),
  ],
}
