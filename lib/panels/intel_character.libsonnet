// Row 2: Workload Character — Memory-Bound vs Compute-Bound
// DRAM Active % reveals memory bandwidth saturation.
// FP16/Tensor pipe shows whether hardware is being used for its intended purpose.
// Workload character table: sort by Compute % ASC to surface memory-bound workloads.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../intel_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local timeSeries = g.panel.timeSeries;
local table = g.panel.table;
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

// DRAM Active thresholds: low = underutilizing memory bus, high = bandwidth-bound
local dramThresholds = [
  { color: 'blue', value: null },
  { color: 'green', value: 20 },
  { color: '#EAB839', value: 60 },
  { color: 'red', value: 85 },
];

{
  panels: [
    row.new('Workload Character — Memory-Bound vs Compute-Bound')
    + row.withGridPos(15),

    // DRAM Active % per device — memory bandwidth utilization
    // Read this together with Compute %:
    //   High DRAM + High Compute = healthy training (memory-compute balanced)
    //   High DRAM + Low Compute  = memory-bandwidth bound (inference, attention)
    //   Low DRAM  + High Compute = compute-bound (unlikely for LLMs)
    //   Low DRAM  + Low Compute  = idle / waiting
    timeSeries.new('DRAM Active % by Device')
    + timeSeries.panelOptions.withDescription('Memory bus utilization per device. Compare with Compute %: high DRAM + low compute = memory-bandwidth bound workload (common in LLM inference).')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 16)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.dramActiveByDevice)
      + prometheus.withLegendFormat('{{Hostname}} GPU{{gpu}} {{GPU_I_PROFILE}}'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + timeSeries.standardOptions.thresholds.withSteps(dramThresholds)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
    + timeSeries.options.legend.withSortBy('Last')
    + timeSeries.options.legend.withSortDesc(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),

    // FP16 + Tensor pipe active per device
    timeSeries.new('FP16 & Tensor Pipe Active % by Device')
    + timeSeries.panelOptions.withDescription('FP16 pipe (mixed precision) and Tensor core utilization. Low FP16/Tensor on GPU designed for it = suboptimal workload configuration.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 16)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.fp16PipeByDevice)
      + prometheus.withLegendFormat('FP16 {{Hostname}} GPU{{gpu}}'),
      prometheus.new(ds, q.tensorPipeByDevice)
      + prometheus.withLegendFormat('Tensor {{Hostname}} GPU{{gpu}}'),
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
    + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
    + timeSeries.options.legend.withSortBy('Last')
    + timeSeries.options.legend.withSortDesc(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),

    // Workload Character Table
    // Sort by Compute % ASC: memory-bound workloads (low compute, high VRAM) float to top.
    // High VRAM % + Low Compute % + Low DRAM Active % = model loaded, not serving traffic.
    table.new('Workload Character Table')
    + table.panelOptions.withDescription('Sort by Compute % ASC to find memory-bound workloads. Pattern: high VRAM% + low Compute% + low DRAM% = idle inference server with model loaded.')
    + table.panelOptions.withGridPos(10, 24, 0, 25)
    + table.queryOptions.withTargets([
      // A: Compute %
      prometheus.new(ds, q.workloadComputePctIntel)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      // B: VRAM %
      prometheus.new(ds, q.workloadVramPct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      // C: DRAM Active %
      prometheus.new(ds, q.workloadDramActivePct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: false, displayName: 'Compute %' }])
    + table.standardOptions.withOverrides([
      // Compute % — color background (low = bad)
      table.standardOptions.override.byName.new('Compute %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps([
          { color: 'rgba(245, 54, 54, 0.25)', value: null },
          { color: 'rgba(237, 129, 40, 0.25)', value: 10 },
          { color: 'rgba(50, 172, 45, 0.25)', value: 30 },
        ])
        + table.fieldConfig.defaults.custom.withWidth(150)
      ),
      // VRAM % — color background
      table.standardOptions.override.byName.new('VRAM %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.tableBgMemory)
        + table.fieldConfig.defaults.custom.withWidth(130)
      ),
      // DRAM Active % — gradient gauge
      table.standardOptions.override.byName.new('DRAM Active %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('gradient-gauge')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.singleColor('blue'))
        + table.fieldConfig.defaults.custom.withWidth(150)
      ),
      // Workload column
      table.standardOptions.override.byName.new('Workload')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(260)
      ),
      // Namespace column
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(180)
      ),
      // Node column
      table.standardOptions.override.byName.new('Node')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(160)
      ),
    ])
    + {
      transformations: [
        { id: 'merge', options: {} },
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, gpu: true },
            indexByName: {
              exported_pod: 1,
              exported_namespace: 2,
              Hostname: 3,
              modelName: 4,
              GPU_I_ID: 5,
              'Value #A': 6,
              'Value #B': 7,
              'Value #C': 8,
            },
            renameByName: {
              exported_pod: 'Workload',
              exported_namespace: 'Namespace',
              Hostname: 'Node',
              modelName: 'GPU Model',
              GPU_I_ID: 'MIG ID',
              'Value #A': 'Compute %',
              'Value #B': 'VRAM %',
              'Value #C': 'DRAM Active %',
            },
          },
        },
      ],
    },
  ],
}
