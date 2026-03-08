// Weekly Report Row 6: Trends & Growth
// Shows time-series trends for GPU_UTIL, VRAM, GR_ENGINE_ACTIVE, and efficiency score.
// Use a 30d range to assess 4-week growth and project time-to-capacity-exhaustion.
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
  + timeSeries.fieldConfig.defaults.custom.withFillOpacity(15)
  + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
  + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('none');

{
  panels: [
    row.new('Trends & Growth Forecast')
    + row.withGridPos(41),

    // GPU_UTIL trend
    timeSeries.new('GPU Util % Trend')
    + timeSeries.panelOptions.withDescription('Average GPU_UTIL over time. Upward trend signals growing compute demand. At +4%/week → 85% saturation in ~5 weeks. Switch to 30d range to see 4-week growth.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 42)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.gpuUtil)
      + prometheus.withLegendFormat('Avg GPU Util %'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.compute)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['min', 'mean', 'max', 'last'])
    + timeSeries.options.tooltip.withMode('single'),

    // VRAM % trend
    timeSeries.new('VRAM Utilization % Trend')
    + timeSeries.panelOptions.withDescription('Average VRAM utilization over time. Rising average signals model scaling (larger models being served). VRAM saturation often precedes compute saturation in LLM clusters.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 42)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.avgVramUtil)
      + prometheus.withLegendFormat('Avg VRAM %'),
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
    + timeSeries.options.legend.withCalcs(['min', 'mean', 'max', 'last'])
    + timeSeries.options.tooltip.withMode('single'),

    // GR_ENGINE_ACTIVE trend
    timeSeries.new('GR Engine Active % Trend')
    + timeSeries.panelOptions.withDescription('Average GR_ENGINE_ACTIVE over time. Cross-reference with GPU_UTIL trend: divergence indicates memory-copy or other non-compute activity inflating GPU_UTIL.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 50)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.avgGrEngineActivePct)
      + prometheus.withLegendFormat('Avg GR Engine %'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.compute)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['min', 'mean', 'max', 'last'])
    + timeSeries.options.tooltip.withMode('single'),

    // Efficiency Score trend (full width)
    timeSeries.new('Efficiency Score Trend')
    + timeSeries.panelOptions.withDescription('Composite efficiency trend (0.5×GPU_UTIL + 0.3×DRAM_ACTIVE + 0.2×VRAM). Healthy band: 40-70%. Sustained >80% requires capacity action.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 50)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.efficiencyScore)
      + prometheus.withLegendFormat('Efficiency Score'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.efficiency)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('area')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['min', 'mean', 'max', 'last'])
    + timeSeries.options.tooltip.withMode('single'),
  ],
}
