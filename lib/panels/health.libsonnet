// Row 2 (new order): Operational Health
// Power and temperature filtered by $hostname; tensor/SM clock are cluster-wide.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local timeSeries = g.panel.timeSeries;
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
    row.new('Operational Health')
    + row.withGridPos(34),

    // Power Usage by Device — filtered by $hostname
    timeSeries.new('Power Usage by Device')
    + timeSeries.panelOptions.withDescription('Power usage over time per device (filtered by selected nodes)')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 35)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.powerByDevice)
      + prometheus.withLegendFormat('{{Hostname}}-GPU{{gpu}}-MIG{{GPU_I_ID}}'),
    ])
    + timeSeries.standardOptions.withUnit('watt')
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

    // Temperature by Device — filtered by $hostname
    timeSeries.new('Temperature by Device')
    + timeSeries.panelOptions.withDescription('Temperature over time per device (filtered by selected nodes)')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 35)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.temperatureByDevice)
      + prometheus.withLegendFormat('{{Hostname}}-GPU{{gpu}}-MIG{{GPU_I_ID}}'),
    ])
    + timeSeries.standardOptions.withUnit('celsius')
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.temperature)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max'])
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),

    // Tensor Utilization by Workload — cluster-wide
    timeSeries.new('Tensor Utilization by Workload')
    + timeSeries.panelOptions.withDescription('Tensor core utilization per workload')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 43)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.tensorUtilByWorkload)
      + prometheus.withLegendFormat('{{exported_pod}}'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
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

    // SM Clock by GPU Model — cluster-wide
    timeSeries.new('SM Clock by GPU Model')
    + timeSeries.panelOptions.withDescription('SM Clock frequency by GPU model')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 43)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.smClockByModel)
      + prometheus.withLegendFormat('{{modelName}}'),
    ])
    + timeSeries.standardOptions.withUnit('none')
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
