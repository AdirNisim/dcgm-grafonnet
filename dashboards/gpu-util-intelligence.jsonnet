// GPU Utilization Intelligence Dashboard
// Answers capacity planning questions, not just operational state visibility:
//   - Are GPUs being used efficiently?
//   - Are workloads memory-bound or compute-bound?
//   - Is MIG partitioning wasting capacity?
//   - Which teams consume most GPU time?
//   - How much headroom does the cluster actually have?
//
// Default time range: 7d. Switch to 30d for capacity planning reviews.
// Build: jsonnet -J vendor dashboards/gpu-util-intelligence.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local fleet = import '../lib/panels/intel_fleet.libsonnet';
local character = import '../lib/panels/intel_character.libsonnet';
local mig = import '../lib/panels/intel_mig.libsonnet';
local namespace = import '../lib/panels/intel_namespace.libsonnet';
local efficiency = import '../lib/panels/intel_efficiency.libsonnet';
local trends = import '../lib/panels/intel_trends.libsonnet';
local consumers = import '../lib/panels/intel_consumers.libsonnet';
local balance = import '../lib/panels/intel_balance.libsonnet';

// --- Variables ---
local var = g.dashboard.variable;

local datasourceVar =
  var.datasource.new('datasource', 'prometheus');

local namespaceVar =
  var.query.new('namespace')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('exported_namespace', 'DCGM_FI_DEV_FB_USED{exported_namespace!=""}')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

local hostnameVar =
  var.query.new('hostname')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('Hostname', 'DCGM_FI_DEV_FB_USED')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

local gpuModelVar =
  var.query.new('gpu_model')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('modelName', 'DCGM_FI_DEV_FB_USED')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

// --- Dashboard ---
g.dashboard.new('GPU Utilization Intelligence')
+ g.dashboard.withUid('gpu-util-intelligence')
+ g.dashboard.withDescription('GPU capacity intelligence: fleet state, workload character, MIG fragmentation, namespace compute share, allocation efficiency, long-term trends, and node balance. Use 7d-30d time range.')
+ g.dashboard.withTags(['gpu', 'capacity-planning', 'intelligence', 'efficiency', 'mig', 'dcgm'])
+ g.dashboard.withEditable(true)
+ g.dashboard.withLiveNow(false)
+ g.dashboard.time.withFrom('now-7d')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withRefresh('5m')
+ g.dashboard.withTimezone('')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.timepicker.withRefreshIntervals(['5m', '15m', '30m', '1h', '6h'])
+ g.dashboard.withVariables([
  datasourceVar,
  namespaceVar,
  hostnameVar,
  gpuModelVar,
])
+ g.dashboard.withPanels(
  fleet.panels       // 1. Fleet Intelligence: state distribution, efficiency gauge, KPIs
  + character.panels // 2. Workload Character: DRAM active, FP16/Tensor pipe, memory vs compute table
  + mig.panels       // 3. MIG Fragmentation: slice counts, free slices, utilization by profile
  + namespace.panels // 4. Namespace Compute Share: current + range-avg bar gauges, trend timeseries
  + efficiency.panels // 5. Allocation Efficiency: idle-allocated trend, reclaim candidates table
  + trends.panels    // 6. Long-Term Trends: 7d-30d compute/VRAM/idle trends + percentile stats
  + consumers.panels // 7. Top Consumers: top 10 VRAM + top 10 compute workloads
  + balance.panels   // 8. Node Balance: imbalance stat, per-node gauges, timeseries
)
