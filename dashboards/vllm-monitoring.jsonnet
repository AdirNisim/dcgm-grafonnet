// vLLM Monitoring Dashboard
// Covers: service health KPIs, KV cache pressure, request latency (TTFT / TPOT / E2E),
// token throughput, prompt/output length distributions, queue depth, and per-replica balance.
//
// Compatible with vLLM v0.10.x – v0.15.x on OpenShift.
// Metrics scraped via ServiceMonitor targeting port 8000 (/metrics).
// Metric prefix: vllm:
//
// Variable hierarchy: datasource → namespace → model_name → pod
// Use model_name as the primary deployment selector — survives pod restarts.
//
// Default time range: 1h (operational view). Switch to 6h–24h for trend analysis.
// Build: jsonnet -J vendor dashboards/vllm-monitoring.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local overview = import '../lib/panels/vllm_overview.libsonnet';
local cache = import '../lib/panels/vllm_cache.libsonnet';
local latency = import '../lib/panels/vllm_latency.libsonnet';
local throughput = import '../lib/panels/vllm_throughput.libsonnet';
local queue = import '../lib/panels/vllm_queue.libsonnet';

// --- Variables ---
local var = g.dashboard.variable;

local datasourceVar =
  var.datasource.new('datasource', 'prometheus')
  + var.datasource.withRegex('');

local namespaceVar =
  var.query.new('namespace')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('namespace', 'vllm:num_requests_running')
  + var.query.selectionOptions.withMulti(false)
  + var.query.selectionOptions.withIncludeAll(false)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

local modelNameVar =
  var.query.new('model_name')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('model_name', 'vllm:num_requests_running{namespace="$namespace"}')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

local podVar =
  var.query.new('pod')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('pod', 'vllm:num_requests_running{namespace="$namespace", model_name=~"$model_name"}')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

// --- Dashboard ---
g.dashboard.new('vLLM Monitoring')
+ g.dashboard.withUid('vllm-monitoring')
+ g.dashboard.withDescription('vLLM v0.10–v0.15 operational metrics: KV cache pressure, TTFT/TPOT latency, token throughput, queue depth, and per-replica balance. Filter by namespace → model → pod.')
+ g.dashboard.withTags(['vllm', 'llm', 'inference', 'latency', 'kv-cache', 'openshift'])
+ g.dashboard.withEditable(true)
+ g.dashboard.withLiveNow(false)
+ g.dashboard.time.withFrom('now-1h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withTimezone('')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.timepicker.withRefreshIntervals(['30s', '1m', '5m', '15m', '1h'])
+ g.dashboard.withVariables([
  datasourceVar,
  namespaceVar,
  modelNameVar,
  podVar,
])
+ g.dashboard.withPanels(
  overview.panels    // 1. Service Health:  running / waiting / swapped KPIs, TTFT P99, token rate
  + cache.panels     // 2. KV Cache:        GPU/CPU cache gauges, hit rate, cache over time per pod
  + latency.panels   // 3. Request Latency: TTFT/TPOT stats, TTFT/E2E/TPOT timeseries
  + throughput.panels // 4. Throughput:     gen/prompt token rates, request rate, length distributions
  + queue.panels     // 5. Queue:           queue depth, preemptions, per-pod running/waiting
)
