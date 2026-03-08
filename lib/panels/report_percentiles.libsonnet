// Weekly Report Row 2: Utilization Percentiles
//
// All percentile values are computed in PromQL via quantile_over_time() subqueries,
// NOT via Grafana client-side reduce functions (which would only compute a percentile
// of a single avg() time series — i.e. a percentile of a mean, not a true distribution).
//
// Formula:  quantile_over_time(q, avg(metric)[$__range:])
//   - avg(metric)       : cluster-wide mean at each scrape step
//   - [$__range:]        : subquery over the full dashboard time window (e.g. 7d)
//   - quantile_over_time : Nth percentile of those samples across the window
//
// Example interpretation: GPU Util P95 = 92% with Avg = 60%
//   → The cluster experiences real saturation windows 5% of the time.
//
// Row 2a (y=6) : GPU_UTIL P50 / P90 / P95 / P99
// Row 2b (y=10): GR_ENGINE P50 / GR_ENGINE P95 / DRAM Active (mean) / VRAM P90
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local row = g.panel.row;

local ds = '${datasource}';

// Shared stat builder for a single-value percentile panel.
// Each panel carries its own dedicated query — reduce is lastNotNull.
local pctStat(title, desc, query, thresholds, x, y) =
  stat.new(title)
  + stat.panelOptions.withDescription(desc)
  + stat.panelOptions.withGridPos(4, 6, x, y)
  + stat.queryOptions.withTargets([
    prometheus.new(ds, query)
    + prometheus.withLegendFormat(title),
  ])
  + stat.standardOptions.withUnit('percent')
  + stat.standardOptions.withMin(0)
  + stat.standardOptions.withMax(100)
  + stat.standardOptions.color.withMode('thresholds')
  + stat.standardOptions.thresholds.withSteps(thresholds)
  + stat.options.withColorMode('value')
  + stat.options.withGraphMode('none')
  + stat.options.reduceOptions.withCalcs(['lastNotNull']);

{
  panels: [
    row.new('Utilization Percentiles')
    + row.withGridPos(5),

    // --- Row 2a: GPU_UTIL Percentiles ---
    pctStat(
      'GPU Util P50',
      'Median GPU utilization across the time window — half of all cluster-average samples were below this value',
      q.gpuUtilP50, t.compute, 0, 6
    ),
    pctStat(
      'GPU Util P90',
      '90th percentile GPU utilization — 90% of cluster-average samples were below this. Rising P90 signals structural load growth.',
      q.gpuUtilP90, t.compute, 6, 6
    ),
    pctStat(
      'GPU Util P95',
      '95th percentile GPU utilization — reveals peak saturation windows. If avg=60% and P95=92%, the cluster saturates 5% of the time.',
      q.gpuUtilP95, t.compute, 12, 6
    ),
    pctStat(
      'GPU Util P99',
      '99th percentile GPU utilization — worst-case saturation tail. Relevant for SLA-sensitive inference workloads.',
      q.gpuUtilP99, t.compute, 18, 6
    ),

    // --- Row 2b: GR_ENGINE_ACTIVE Percentiles + DRAM + VRAM ---
    pctStat(
      'GR Engine P50',
      'Median GR_ENGINE_ACTIVE — cross-reference with GPU_UTIL P50. A large gap means GPU_UTIL is inflated by non-compute activity (memory copy, context switches).',
      q.grEngineP50, t.compute, 0, 10
    ),
    pctStat(
      'GR Engine P95',
      '95th percentile GR_ENGINE_ACTIVE — confirms whether GPU_UTIL P95 peaks are compute-bound. High GR_ENGINE P95 = real compute saturation.',
      q.grEngineP95, t.compute, 6, 10
    ),

    // DRAM Active % (mean — no percentile variant needed; sustained mean >80% is the key signal)
    stat.new('DRAM Active % (mean)')
    + stat.panelOptions.withDescription('Mean DRAM bus activity over the window. >80% sustained indicates memory bandwidth bottleneck — common during training on B200/H100.')
    + stat.panelOptions.withGridPos(4, 6, 12, 10)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.dramActivePct)
      + prometheus.withLegendFormat('DRAM %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.compute)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['mean']),

    // VRAM P90 — PromQL quantile_over_time
    pctStat(
      'VRAM P90',
      '90th percentile VRAM utilization over the window. In LLM clusters, VRAM saturation typically precedes compute saturation as models grow.',
      q.vramP90, t.memory, 18, 10
    ),
  ],
}
