// Weekly Report Row 3: Workload Classification
// Approximates workload type from GPU_UTIL levels.
// High GPU_UTIL (>60%) → training-like; medium (10-60%) → inference-like; low (<10%) → idle/preloaded.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local barGauge = g.panel.barGauge;
local pieChart = g.panel.pieChart;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    row.new('Workload Classification')
    + row.withGridPos(14),

    // High Compute (Training-like, GPU_UTIL > 60%)
    stat.new('High Compute (GPU > 60%)')
    + stat.panelOptions.withDescription('Devices with GPU_UTIL > 60% — typical of training jobs (high compute + high DRAM)')
    + stat.panelOptions.withGridPos(4, 4, 0, 15)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.highComputeCount)
      + prometheus.withLegendFormat('Training-like'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('red'))
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Medium Compute (Inference-like, GPU_UTIL 10-60%)
    stat.new('Medium Compute (GPU 10-60%)')
    + stat.panelOptions.withDescription('Devices with GPU_UTIL 10-60% — typical of inference services (moderate compute + high FB)')
    + stat.panelOptions.withGridPos(4, 4, 4, 15)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.medComputeCount)
      + prometheus.withLegendFormat('Inference-like'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('orange'))
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Idle / Low Compute (GPU_UTIL ≤ 10%)
    stat.new('Idle / Low Compute (GPU ≤ 10%)')
    + stat.panelOptions.withDescription('Devices with GPU_UTIL ≤ 10% — idle or model preloaded with no active requests')
    + stat.panelOptions.withGridPos(4, 4, 8, 15)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.lowComputeCount)
      + prometheus.withLegendFormat('Idle'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.countWarningHigh)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Compute Distribution by Namespace (pie chart)
    pieChart.new('Compute by Namespace')
    + pieChart.panelOptions.withDescription('GPU compute (GR Engine Active %) distribution across namespaces')
    + pieChart.panelOptions.withGridPos(8, 12, 12, 15)
    + pieChart.queryOptions.withTargets([
      prometheus.new(ds, q.computeByNamespace)
      + prometheus.withLegendFormat('{{exported_namespace}}'),
    ])
    + pieChart.standardOptions.withUnit('percent')
    + pieChart.standardOptions.color.withMode('palette-classic')
    + pieChart.options.withPieType('donut')
    + pieChart.options.withDisplayLabels(['name', 'percent'])
    + pieChart.options.legend.withDisplayMode('table')
    + pieChart.options.legend.withPlacement('right')
    + pieChart.options.legend.withShowLegend(true)
    + pieChart.options.legend.withValues(['value', 'percent'])
    + pieChart.options.tooltip.withMode('single'),

    // Aggregate compute by GPU type / MIG profile
    // Value = sum of GR Engine Active % across all devices of that type.
    // 100% = one full equivalent device in use; 400% = four full equivalents.
    // Two targets keep labels clean: whole GPUs show model name only,
    // MIG slices show "ModelName ProfileName" to distinguish e.g. H100 1g.12gb from L40S 1g.12gb.
    barGauge.new('Compute by GPU Type / Profile')
    + barGauge.panelOptions.withDescription(
      'Total GR Engine Active % summed per GPU model (whole GPUs) and per model+profile (MIG slices). ' +
      '100% = one full device equivalent in use. 400% = four slices/GPUs of that type fully utilised.'
    )
    + barGauge.panelOptions.withGridPos(4, 12, 0, 19)
    + barGauge.queryOptions.withTargets([
      // Whole GPUs — label is the GPU model (H100, B200, L40S …)
      prometheus.new(ds, q.computeByGpuModel)
      + prometheus.withLegendFormat('{{modelName}}')
      + prometheus.withRefId('A'),

      // MIG slices — label combines model and profile (H100 1g.12gb, L40S 2g.24gb …)
      prometheus.new(ds, q.computeByMigProfile)
      + prometheus.withLegendFormat('{{modelName}} {{GPU_I_PROFILE}}')
      + prometheus.withRefId('B'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.withMin(0)
    + barGauge.standardOptions.color.withMode('palette-classic')
    + barGauge.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + barGauge.options.withDisplayMode('gradient')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(false)
    + barGauge.options.withMinVizHeight(10)
    + barGauge.options.withMinVizWidth(0),
  ],
}
