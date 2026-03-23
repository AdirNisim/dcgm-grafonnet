// Row 4 (new order): Memory Capacity Planning
// Per-node repeated panels: VRAM util split into whole-GPU vs MIG queries (clean legends).
// Namespace VRAM shown as per-node horizontal bar gauge.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local gauge = g.panel.gauge;
local timeSeries = g.panel.timeSeries;
local barGauge = g.panel.barGauge;
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
    row.new('GPU VRAM Capacity Planning')
    + row.withGridPos(76),

    // --- Cluster-wide summary stats ---
    stat.new('Total VRAM Capacity')
    + stat.panelOptions.withDescription('Total GPU VRAM capacity across all devices')
    + stat.panelOptions.withGridPos(4, 4, 0, 77)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.totalMemoryCapacity)
      + prometheus.withLegendFormat('Total Capacity'),
    ])
    + stat.standardOptions.withUnit('decgbytes')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('VRAM In Use')
    + stat.panelOptions.withDescription('Total GPU VRAM currently in use')
    + stat.panelOptions.withGridPos(4, 4, 4, 77)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.memoryInUse)
      + prometheus.withLegendFormat('Used'),
    ])
    + stat.standardOptions.withUnit('decgbytes')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    gauge.new('Avg VRAM Utilization')
    + gauge.panelOptions.withDescription('Average VRAM utilization across all devices')
    + gauge.panelOptions.withGridPos(4, 4, 8, 77)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.avgMemoryUtil)
      + prometheus.withLegendFormat('Avg VRAM %'),
    ])
    + gauge.standardOptions.withUnit('percent')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(100)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(t.memory)
    + gauge.options.withShowThresholdLabels(false)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('OOM Risk %')
    + stat.panelOptions.withDescription('Percentage of devices at risk of OOM (>85% VRAM)')
    + stat.panelOptions.withGridPos(4, 4, 12, 77)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.oomRiskPct)
      + prometheus.withLegendFormat('OOM Risk %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.riskPct)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Avg Temperature')
    + stat.panelOptions.withDescription('Average temperature across all GPUs')
    + stat.panelOptions.withGridPos(4, 4, 16, 77)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.avgTemperature)
      + prometheus.withLegendFormat('Avg Temp'),
    ])
    + stat.standardOptions.withUnit('celsius')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.temperature)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Avg Power per Device')
    + stat.panelOptions.withDescription('Average power usage per device')
    + stat.panelOptions.withGridPos(4, 4, 20, 77)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.avgPower)
      + prometheus.withLegendFormat('Avg Power'),
    ])
    + stat.standardOptions.withUnit('watt')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('orange'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // --- Per-node VRAM utilization (repeated) ---
    // Two queries: whole GPUs (no MIG ID in legend) + MIG instances (profile in legend)
    timeSeries.new('VRAM Utilization % — $hostname')
    + timeSeries.panelOptions.withDescription('VRAM utilization per device on this node. Whole GPUs and MIG instances shown separately to avoid legend clutter.')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 82)
    + timeSeries.panelOptions.withRepeat('hostname')
    + timeSeries.queryOptions.withTargets([
      // Whole GPUs — legend without MIG noise
      prometheus.new(ds, q.memoryUtilWholeGPU)
      + prometheus.withLegendFormat('{{modelName}} GPU{{gpu}}'),

      // MIG instances — legend with profile
      prometheus.new(ds, q.memoryUtilMIG)
      + prometheus.withLegendFormat('{{modelName}} GPU{{gpu}} MIG{{GPU_I_ID}} ({{GPU_I_PROFILE}})'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.memory)
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

    // --- Per-node VRAM by namespace (repeated) ---
    barGauge.new('VRAM by Namespace — $hostname')
    + barGauge.panelOptions.withDescription('VRAM used per namespace on this node')
    + barGauge.panelOptions.withGridPos(8, 24, 0, 91)
    + barGauge.panelOptions.withRepeat('hostname')
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.memoryByNamespacePerNode)
      + prometheus.withLegendFormat('{{exported_namespace}}'),
    ])
    + barGauge.standardOptions.withUnit('decmbytes')
    + barGauge.standardOptions.color.withMode('palette-classic')
    + barGauge.options.withDisplayMode('basic')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true),

    // --- Workload memory over time (cluster-wide) ---
    timeSeries.new('Workload VRAM Over Time')
    + timeSeries.panelOptions.withDescription('VRAM used by workloads over time')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 100)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.workloadMemoryOverTime)
      + prometheus.withLegendFormat('{{Hostname}} / {{modelName}} / {{exported_pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('decmbytes')
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max'])
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),
  ],
}
