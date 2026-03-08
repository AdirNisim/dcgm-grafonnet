// GPU Weekly Capacity Planning Report Dashboard
// Based on TASK-REPORTING.md — designed for weekly review across three audiences:
//   ML engineers (performance), Platform/DevOps (capacity), Management/FinOps (utilization)
//
// Build: jsonnet -J vendor dashboards/gpu-weekly-report.jsonnet
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local reportSummary = import '../lib/panels/report_summary.libsonnet';
local reportPercentiles = import '../lib/panels/report_percentiles.libsonnet';
local reportWorkload = import '../lib/panels/report_workload.libsonnet';
local reportMig = import '../lib/panels/report_mig.libsonnet';
local reportEfficiency = import '../lib/panels/report_efficiency.libsonnet';
local reportTrends = import '../lib/panels/report_trends.libsonnet';

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

local gpuModelVar =
  var.query.new('gpu_model')
  + var.query.withDatasource('prometheus', '${datasource}')
  + var.query.queryTypes.withLabelValues('modelName', 'DCGM_FI_DEV_FB_USED')
  + var.query.selectionOptions.withMulti(true)
  + var.query.selectionOptions.withIncludeAll(true)
  + var.query.withSort(1)
  + var.query.refresh.onTime();

// --- Dashboard ---
g.dashboard.new('GPU Weekly Capacity Planning Report')
+ g.dashboard.withUid('gpu-weekly-report')
+ g.dashboard.withDescription('Weekly GPU capacity planning report — Executive Summary, Utilization Percentiles, Workload Classification, MIG Fragmentation, Efficiency Score, and Growth Trends')
+ g.dashboard.withTags(['gpu', 'weekly-report', 'capacity-planning', 'mig', 'dcgm', 'efficiency', 'finops'])
+ g.dashboard.withEditable(true)
+ g.dashboard.withLiveNow(false)
+ g.dashboard.time.withFrom('now-7d')
+ g.dashboard.time.withTo('now')
+ g.dashboard.withRefresh('1h')
+ g.dashboard.withTimezone('')
+ g.dashboard.graphTooltip.withSharedCrosshair()
+ g.dashboard.timepicker.withRefreshIntervals(['5m', '15m', '30m', '1h', '6h', '12h'])
+ g.dashboard.withVariables([
  datasourceVar,
  namespaceVar,
  gpuModelVar,
])
+ g.dashboard.withPanels(
  reportSummary.panels
  + reportPercentiles.panels
  + reportWorkload.panels
  + reportMig.panels
  + reportEfficiency.panels
  + reportTrends.panels
)
