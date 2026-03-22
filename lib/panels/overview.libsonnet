// Row 1: Cluster Overview - KPIs
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
    row.new('Cluster Overview - KPIs')
    + row.withGridPos(0),

    // Total Devices
    stat.new('Total Devices')
    + stat.panelOptions.withDescription('Total count of GPU devices and MIG instances')
    + stat.panelOptions.withGridPos(4, 3, 0, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.totalDevices)
      + prometheus.withLegendFormat('Total'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Whole GPUs
    stat.new('Whole GPUs')
    + stat.panelOptions.withDescription('Count of whole GPU devices (non-MIG)')
    + stat.panelOptions.withGridPos(4, 3, 3, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.wholeGPUs)
      + prometheus.withLegendFormat('Whole GPUs'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // MIG Instances
    stat.new('MIG Instances')
    + stat.panelOptions.withDescription('Count of MIG instances')
    + stat.panelOptions.withGridPos(4, 3, 6, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.migInstances)
      + prometheus.withLegendFormat('MIG Instances'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('purple'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Active Workloads
    stat.new('Active Workloads')
    + stat.panelOptions.withDescription('Count of active GPU deployments')
    + stat.panelOptions.withGridPos(4, 3, 9, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.activeWorkloads)
      + prometheus.withLegendFormat('Workloads'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('orange'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Avg Device Load (gauge)
    gauge.new('Avg Device Load')
    + gauge.panelOptions.withDescription('Average composite load across all devices (60% compute + 40% VRAM)')
    + gauge.panelOptions.withGridPos(4, 4, 12, 1)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.avgDeviceLoad)
      + prometheus.withLegendFormat('Avg Load'),
    ])
    + gauge.standardOptions.withUnit('percent')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(100)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(t.loadGaugeInverted)
    + gauge.options.withShowThresholdLabels(false)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['lastNotNull']),

    // Memory Saturated (>85%)
    stat.new('VRAM Saturated (>85%)')
    + stat.panelOptions.withDescription('Devices with VRAM utilization over 85%')
    + stat.panelOptions.withGridPos(4, 4, 16, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.memorySaturated)
      + prometheus.withLegendFormat('Saturated'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.countWarning)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Underutilized (<20%)
    stat.new('Underutilized (<20%)')
    + stat.panelOptions.withDescription('Devices with less than 20% composite load')
    + stat.panelOptions.withGridPos(4, 4, 20, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.underutilized)
      + prometheus.withLegendFormat('Underutilized'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.countWarningHigh)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),
  ],
}
