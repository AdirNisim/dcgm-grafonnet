// GPU Capacity Planning Dashboard — v0.3.0
// Stack-level ordering: Nodes → Platform → Namespace → Workload → Inference Capacity
// Build: jsonnet -J vendor dashboards/gpu-capacity-planning.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

// Panel sections (each exports { panels: [...] })
// Cluster Overview KPIs removed (v0.2.0).
// vLLM inference capacity layer added (v0.3.0).
// vLLM inference capacity layer removed (v0.4.0)
local deployment = import '../lib/panels/deployment.libsonnet';
local health = import '../lib/panels/health.libsonnet';
local inventory = import '../lib/panels/inventory.libsonnet';
local load = import '../lib/panels/load.libsonnet';
local memory = import '../lib/panels/memory.libsonnet';
local storage = import '../lib/panels/storage.libsonnet';
local workload = import '../lib/panels/workload.libsonnet';

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

// withIncludeAll(false): panel repeat requires individual node selections;
// "All" generates a broken repeated panel instance.
local hostnameVar =
  var.query.new('hostname')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('Hostname', 'DCGM_FI_DEV_FB_USED')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(false)
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
g.dashboard.new('GPU Capacity Planning Dashboard')
+ g.dashboard.withUid('gpu-capacity-planning')
+ g.dashboard.withDescription('AI Workload Capacity Planning — stack-level ordering: Nodes → Platform → Namespace → Workload')
+ g.dashboard.withTags(['gpu', 'capacity-planning', 'mig', 'dcgm', 'ai-workloads', 'memory', 'storage', 'pvc', 'trident'])
+ g.dashboard.withEditable(true)
+ g.dashboard.withLiveNow(true)
+ g.dashboard.time.withFrom('now-6h')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withRefresh('30s')
+ g.dashboard.withTimezone('')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.timepicker.withRefreshIntervals(['10s', '30s', '1m', '5m', '15m', '30m', '1h'])
+ g.dashboard.withVariables([
  datasourceVar,
  namespaceVar,
  hostnameVar,
  gpuModelVar,
])
+ g.dashboard.withPanels(
  // Stack-level order: bottom → top
  inventory.panels  // 1. Nodes     — GPU device inventory, node CPU/RAM, deployments per node
  + health.panels  // 2. Platform  — operational health (power, temp, tensor, SM clock)
  + load.panels  // 3. Platform  — device compute load per node
  + memory.panels  // 4. Memory    — VRAM capacity planning per node + namespace
  + deployment.panels  // 5. Namespace — CPU & RAM by deployment (kube-state-metrics)
  + workload.panels  // 6. Workload  — per-workload GPU usage table + compute over time
  + storage.panels  // 7. Storage   — node disk, PV/PVC usage, Trident backend capacity
)
