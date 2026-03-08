// Weekly Report Row 5: Efficiency Score & Saturation
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local timeSeries = g.panel.timeSeries;
local barGauge = g.panel.barGauge;
local row = g.panel.row;

local ds = '${datasource}';

local tsDefaults =
  timeSeries.fieldConfig.defaults.custom.withDrawStyle('line')
  + timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth')
  + timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + timeSeries.fieldConfig.defaults.custom.withFillOpacity(15)
  + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
  + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('none');

{
  panels: [
    row.new('Efficiency Score & Saturation')
    + row.withGridPos(32),

    // Efficiency Score per Device (bar gauge)
    barGauge.new('Efficiency Score by Device')
    + barGauge.panelOptions.withDescription('Composite efficiency per GPU/MIG: 0.5×GPU_UTIL + 0.3×DRAM_ACTIVE + 0.2×VRAM. Red <40% = underutilized, Green 40-70% = healthy, >80% = structural risk')
    + barGauge.panelOptions.withGridPos(8, 12, 0, 33)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.efficiencyByDevice)
      + prometheus.withLegendFormat('{{Hostname}}-GPU{{gpu}}-{{GPU_I_PROFILE}}'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.withMin(0)
    + barGauge.standardOptions.withMax(100)
    + barGauge.standardOptions.color.withMode('thresholds')
    + barGauge.standardOptions.thresholds.withSteps(t.efficiency)
    + barGauge.options.withDisplayMode('gradient')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['mean'])
    + barGauge.options.withShowUnfilled(true)
    + barGauge.options.withMinVizHeight(10)
    + barGauge.options.withMinVizWidth(0),

    // Devices with GPU_UTIL > 85% over time (saturation trend)
    timeSeries.new('Saturated Devices (GPU > 85%) over Time')
    + timeSeries.panelOptions.withDescription('Count of devices with GPU_UTIL > 85% — early warning for capacity exhaustion. Sustained count >0 requires capacity action.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 33)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.devicesSaturatedCount)
      + prometheus.withLegendFormat('Devices GPU >85%'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('thresholds')
    + timeSeries.standardOptions.thresholds.withSteps(t.countWarning)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('area')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
    + timeSeries.options.tooltip.withMode('single'),
  ],
}
