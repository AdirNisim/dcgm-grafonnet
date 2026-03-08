// Row 1: GPU Fleet Intelligence
// KPI stats (total/busy/idle/unused/pending), GPU pressure gauge,
// allocation efficiency gauge, and GPU state distribution over time.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../intel_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local gauge = g.panel.gauge;
local pieChart = g.panel.pieChart;
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
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('normal');

// Thresholds for idle-allocated count: any idle allocation is a warning
local idleAllocThresholds = [
  { color: 'green', value: null },
  { color: '#EAB839', value: 1 },
  { color: 'red', value: 5 },
];

// Thresholds for allocation efficiency: want high values (inverted concern)
local efficiencyThresholds = [
  { color: 'red', value: null },
  { color: '#EAB839', value: 50 },
  { color: 'green', value: 80 },
];

{
  panels: [
    row.new('GPU Fleet Intelligence')
    + row.withGridPos(0),

    // --- KPI stat row ---
    stat.new('Total Devices')
    + stat.panelOptions.withDescription('Total GPU and MIG slice count')
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

    stat.new('Busy GPUs')
    + stat.panelOptions.withDescription('Devices with compute > 5%')
    + stat.panelOptions.withGridPos(4, 3, 3, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.busyGPUs)
      + prometheus.withLegendFormat('Busy'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Idle-Allocated GPUs')
    + stat.panelOptions.withDescription('VRAM in use but compute < 5% — model loaded, not working. Key waste signal.')
    + stat.panelOptions.withGridPos(4, 3, 6, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.idleAllocatedGPUs)
      + prometheus.withLegendFormat('Idle-Allocated'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(idleAllocThresholds)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Unused GPUs')
    + stat.panelOptions.withDescription('No VRAM, no compute — fully free devices')
    + stat.panelOptions.withGridPos(4, 3, 9, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.unusedGPUs)
      + prometheus.withLegendFormat('Unused'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Cluster Compute %')
    + stat.panelOptions.withDescription('Average GR engine active across all devices')
    + stat.panelOptions.withGridPos(4, 3, 12, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.clusterComputePct)
      + prometheus.withLegendFormat('Compute %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.compute)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Cluster VRAM %')
    + stat.panelOptions.withDescription('Average VRAM utilization across all devices')
    + stat.panelOptions.withGridPos(4, 3, 15, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.clusterVramPct)
      + prometheus.withLegendFormat('VRAM %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.memory)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Pending GPU Pods')
    + stat.panelOptions.withDescription('Pods waiting for GPU resources — scheduling pressure signal')
    + stat.panelOptions.withGridPos(4, 3, 18, 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.pendingGpuPods)
      + prometheus.withLegendFormat('Pending'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(idleAllocThresholds)
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // GPU Pressure Index gauge
    gauge.new('GPU Pressure Index')
    + gauge.panelOptions.withDescription('Demand signal: 0.6 × compute% + 0.4 × VRAM%. Indicates cluster saturation trend, not a true utilization measure.')
    + gauge.panelOptions.withGridPos(4, 3, 21, 1)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.gpuPressureIndex)
      + prometheus.withLegendFormat('Pressure'),
    ])
    + gauge.standardOptions.withUnit('percent')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(100)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(t.memory)
    + gauge.options.withShowThresholdLabels(false)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['lastNotNull']),

    // --- Second row: efficiency gauge + pie + state timeseries ---

    // Allocation Efficiency gauge
    gauge.new('Allocation Efficiency')
    + gauge.panelOptions.withDescription('Busy GPUs / Allocated GPUs × 100. Low value = many GPUs holding VRAM but not computing.')
    + gauge.panelOptions.withGridPos(8, 4, 0, 6)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.allocationEfficiencyPct)
      + prometheus.withLegendFormat('Efficiency %'),
    ])
    + gauge.standardOptions.withUnit('percent')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(100)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(efficiencyThresholds)
    + gauge.options.withShowThresholdLabels(false)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['lastNotNull']),

    // GPU State Distribution pie chart
    pieChart.new('GPU State Distribution')
    + pieChart.panelOptions.withDescription('Current snapshot: Busy (compute>5%) / Idle-Allocated (VRAM>0, compute<5%) / Unused')
    + pieChart.panelOptions.withGridPos(8, 8, 4, 6)
    + pieChart.queryOptions.withTargets([
      prometheus.new(ds, q.stateOverTimeBusy)
      + prometheus.withLegendFormat('Busy'),
      prometheus.new(ds, q.stateOverTimeIdleAllocated)
      + prometheus.withLegendFormat('Idle-Allocated'),
      prometheus.new(ds, q.stateOverTimeUnused)
      + prometheus.withLegendFormat('Unused'),
    ])
    + pieChart.standardOptions.withUnit('short')
    + pieChart.standardOptions.color.withMode('fixed')
    + pieChart.options.withPieType('donut')
    + pieChart.options.withDisplayLabels(['name', 'percent'])
    + pieChart.options.legend.withDisplayMode('table')
    + pieChart.options.legend.withPlacement('right')
    + pieChart.options.legend.withShowLegend(true)
    + pieChart.options.legend.withValues(['value', 'percent'])
    + pieChart.options.tooltip.withMode('single')
    + {
      fieldConfig+: {
        overrides: [
          {
            matcher: { id: 'byName', options: 'Busy' },
            properties: [{ id: 'color', value: { fixedColor: 'green', mode: 'fixed' } }],
          },
          {
            matcher: { id: 'byName', options: 'Idle-Allocated' },
            properties: [{ id: 'color', value: { fixedColor: '#EAB839', mode: 'fixed' } }],
          },
          {
            matcher: { id: 'byName', options: 'Unused' },
            properties: [{ id: 'color', value: { fixedColor: 'blue', mode: 'fixed' } }],
          },
        ],
      },
    },

    // GPU State Over Time stacked timeseries
    timeSeries.new('GPU State Over Time')
    + timeSeries.panelOptions.withDescription('Stacked count of Busy / Idle-Allocated / Unused GPUs over time. Idle-Allocated growth signals efficiency degradation.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 6)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.stateOverTimeBusy)
      + prometheus.withLegendFormat('Busy'),
      prometheus.new(ds, q.stateOverTimeIdleAllocated)
      + prometheus.withLegendFormat('Idle-Allocated'),
      prometheus.new(ds, q.stateOverTimeUnused)
      + prometheus.withLegendFormat('Unused'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('fixed')
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['last'])
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc')
    + {
      fieldConfig+: {
        overrides: [
          {
            matcher: { id: 'byName', options: 'Busy' },
            properties: [{ id: 'color', value: { fixedColor: 'green', mode: 'fixed' } }],
          },
          {
            matcher: { id: 'byName', options: 'Idle-Allocated' },
            properties: [{ id: 'color', value: { fixedColor: '#EAB839', mode: 'fixed' } }],
          },
          {
            matcher: { id: 'byName', options: 'Unused' },
            properties: [{ id: 'color', value: { fixedColor: 'blue', mode: 'fixed' } }],
          },
        ],
      },
    },
  ],
}
