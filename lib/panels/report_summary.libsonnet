// Weekly Report Row 1: Executive Summary KPIs
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local gauge = g.panel.gauge;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    row.new('Executive Summary')
    + row.withGridPos(0),

    // Avg GPU Util %
    stat.new('Avg GPU Util %')
    + stat.panelOptions.withDescription('Average GPU utilization (DCGM_FI_DEV_GPU_UTIL) across all devices')
    + stat.panelOptions.withGridPos(4, 4, 0, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.gpuUtil)
      + prometheus.withLegendFormat('GPU Util %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.compute)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['mean']),

    // Peak GPU Util %
    stat.new('Peak GPU Util %')
    + stat.panelOptions.withDescription('Maximum GPU utilization observed across any device in the period')
    + stat.panelOptions.withGridPos(4, 4, 4, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.peakGpuUtil)
      + prometheus.withLegendFormat('Peak GPU %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.compute)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['max']),

    // Avg VRAM Utilization %
    stat.new('Avg VRAM Util %')
    + stat.panelOptions.withDescription('Average VRAM utilization across all devices')
    + stat.panelOptions.withGridPos(4, 4, 8, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.avgVramUtil)
      + prometheus.withLegendFormat('VRAM %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.memory)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['mean']),

    // Devices GPU > 85%
    stat.new('Devices GPU > 85%')
    + stat.panelOptions.withDescription('Number of devices with GPU utilization above 85% — sustained saturation indicator')
    + stat.panelOptions.withGridPos(4, 4, 12, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.devicesSaturatedCount)
      + prometheus.withLegendFormat('Saturated'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.countWarning)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Idle GPU %
    stat.new('Idle GPU %')
    + stat.panelOptions.withDescription('Percentage of GPUs with GPU_UTIL below 5% — effectively idle, potential waste')
    + stat.panelOptions.withGridPos(4, 4, 16, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.idleGpuPct)
      + prometheus.withLegendFormat('Idle %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.idleGpu)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['mean']),

    // Efficiency Score (gauge)
    gauge.new('Efficiency Score')
    + gauge.panelOptions.withDescription('Composite efficiency: 0.5×GPU_UTIL + 0.3×DRAM_ACTIVE + 0.2×VRAM. <40% underutilized, 40-70% healthy, >80% structural risk')
    + gauge.panelOptions.withGridPos(4, 4, 20, 1)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.efficiencyScore)
      + prometheus.withLegendFormat('Efficiency'),
    ])
    + gauge.standardOptions.withUnit('percent')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(100)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(t.efficiency)
    + gauge.options.withShowThresholdLabels(false)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['mean']),
  ],
}
