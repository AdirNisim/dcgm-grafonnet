// Row 3: MIG Fragmentation Analysis
// Shows MIG slice counts (total/active/free) by profile, and utilization per profile.
// Fragmentation = free slices exist but may not match pending workload requests.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../intel_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local barGauge = g.panel.barGauge;
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
    row.new('MIG Fragmentation Analysis')
    + row.withGridPos(36),

    // MIG Idle % cluster-wide — headline stat
    stat.new('MIG Idle %')
    + stat.panelOptions.withDescription('% of MIG slices with no workload. High idle % = fragmentation or over-provisioning.')
    + stat.panelOptions.withGridPos(4, 4, 0, 37)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.migIdlePct)
      + prometheus.withLegendFormat('MIG Idle %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.riskPct)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Total MIG Slices by Profile (shows partitioning strategy)
    barGauge.new('MIG Slices by Profile')
    + barGauge.panelOptions.withDescription('Total MIG slice count per profile. Reveals the partitioning strategy of the cluster.')
    + barGauge.panelOptions.withGridPos(8, 10, 4, 37)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.migSlicesByProfile)
      + prometheus.withLegendFormat('{{GPU_I_PROFILE}}'),
    ])
    + barGauge.standardOptions.withUnit('short')
    + barGauge.standardOptions.color.withMode('palette-classic')
    + barGauge.options.withDisplayMode('basic')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true),

    // Free MIG Slices by Profile (scheduling headroom)
    barGauge.new('Free MIG Slices by Profile')
    + barGauge.panelOptions.withDescription('Unallocated slices per profile. A profile with zero free slices cannot accept new workloads of that size — even if other profiles are idle.')
    + barGauge.panelOptions.withGridPos(8, 10, 14, 37)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.migFreeSlicesByProfile)
      + prometheus.withLegendFormat('{{GPU_I_PROFILE}}'),
    ])
    + barGauge.standardOptions.withUnit('short')
    + barGauge.standardOptions.color.withMode('palette-classic')
    + barGauge.options.withDisplayMode('basic')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true),

    // MIG Compute utilization by profile
    barGauge.new('MIG Compute % by Profile')
    + barGauge.panelOptions.withDescription('Average GR engine active % across all slices of each MIG profile')
    + barGauge.panelOptions.withGridPos(8, 8, 0, 46)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.migComputeByProfile)
      + prometheus.withLegendFormat('{{GPU_I_PROFILE}}'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.withMin(0)
    + barGauge.standardOptions.withMax(100)
    + barGauge.standardOptions.color.withMode('thresholds')
    + barGauge.standardOptions.thresholds.withSteps(t.compute)
    + barGauge.options.withDisplayMode('gradient')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true),

    // MIG VRAM utilization by profile
    barGauge.new('MIG VRAM % by Profile')
    + barGauge.panelOptions.withDescription('Average VRAM utilization % across all slices of each MIG profile')
    + barGauge.panelOptions.withGridPos(8, 8, 8, 46)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.migVramByProfile)
      + prometheus.withLegendFormat('{{GPU_I_PROFILE}}'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.withMin(0)
    + barGauge.standardOptions.withMax(100)
    + barGauge.standardOptions.color.withMode('thresholds')
    + barGauge.standardOptions.thresholds.withSteps(t.memory)
    + barGauge.options.withDisplayMode('gradient')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true),

    // Free slices by profile over time — detect fragmentation building up
    timeSeries.new('Free MIG Slices Over Time')
    + timeSeries.panelOptions.withDescription('Free slice count per profile over time. Sustained zero free slices for a profile = that profile is a scheduling bottleneck.')
    + timeSeries.panelOptions.withGridPos(8, 8, 16, 46)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.migFreeSlicesByProfile)
      + prometheus.withLegendFormat('Free {{GPU_I_PROFILE}}'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['last', 'min'])
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),
  ],
}
