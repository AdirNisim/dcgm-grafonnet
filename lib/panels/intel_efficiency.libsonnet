// Row 5: GPU Allocation Efficiency — Idle Detection
// Surfaces workloads holding GPU resources without doing useful work.
// This single section often identifies the most actionable waste in a cluster.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../intel_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local table = g.panel.table;
local timeSeries = g.panel.timeSeries;
local stat = g.panel.stat;
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

// Thresholds for workload compute % column — emphasise low values as critical
local computeEfficiencyBg = [
  { color: 'rgba(245, 54, 54, 0.3)', value: null },
  { color: 'rgba(237, 129, 40, 0.2)', value: 10 },
  { color: 'rgba(50, 172, 45, 0.15)', value: 30 },
];

{
  panels: [
    row.new('GPU Allocation Efficiency — Idle Detection')
    + row.withGridPos(74),

    // Idle-allocated count stat (repeated from fleet for quick reference)
    stat.new('Idle-Allocated GPUs Now')
    + stat.panelOptions.withDescription('GPUs with VRAM in use but compute < 5%. These are the primary waste candidates.')
    + stat.panelOptions.withGridPos(4, 4, 0, 75)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.idleAllocatedGPUs)
      + prometheus.withLegendFormat('Idle-Allocated'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: '#EAB839', value: 1 },
      { color: 'red', value: 5 },
    ])
    + stat.options.withColorMode('background')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Idle-allocated GPUs over time
    timeSeries.new('Idle-Allocated GPU Count Over Time')
    + timeSeries.panelOptions.withDescription('Number of GPUs holding VRAM but below 5% compute activity. Sustained non-zero values indicate workloads should be scaled down or idle pods reclaimed.')
    + timeSeries.panelOptions.withGridPos(8, 20, 4, 75)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.idleAllocatedOverTime)
      + prometheus.withLegendFormat('Idle-Allocated'),
    ])
    + timeSeries.standardOptions.withUnit('short')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('fixed')
    + timeSeries.standardOptions.thresholds.withSteps([
      { color: 'green', value: null },
      { color: '#EAB839', value: 1 },
    ])
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + {
      fieldConfig+: {
        defaults+: {
          color: { fixedColor: '#EAB839', mode: 'fixed' },
        },
      },
    }
    + timeSeries.options.legend.withDisplayMode('list')
    + timeSeries.options.legend.withShowLegend(false)
    + timeSeries.options.tooltip.withMode('single'),

    // Workload Efficiency Table — all active workloads sorted by compute ASC
    // Low compute + high VRAM = idle-allocated candidates
    // Provides actionable list: these workloads are reclaim candidates.
    table.new('Workload Efficiency — Reclaim Candidates')
    + table.panelOptions.withDescription('All GPU-holding workloads sorted by Compute % ASC. Rows with low Compute % and high VRAM are reclaim candidates. Threshold: Compute < 10% = critical waste.')
    + table.panelOptions.withGridPos(12, 24, 0, 84)
    + table.queryOptions.withTargets([
      // A: Compute %
      prometheus.new(ds, q.idleDetectCompute)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      // B: VRAM used (MiB)
      prometheus.new(ds, q.idleDetectVramUsed)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      // C: VRAM total (MiB)
      prometheus.new(ds, q.idleDetectVramTotal)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: false, displayName: 'Compute %' }])
    + table.standardOptions.withOverrides([
      // Compute % — aggressive color highlight
      table.standardOptions.override.byName.new('Compute %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(computeEfficiencyBg)
        + table.standardOptions.withDecimals(1)
        + table.fieldConfig.defaults.custom.withWidth(150)
      ),
      // VRAM Used
      table.standardOptions.override.byName.new('VRAM Used (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      // VRAM Total
      table.standardOptions.override.byName.new('VRAM Total (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('Workload')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(260)
      ),
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(180)
      ),
      table.standardOptions.override.byName.new('Node')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(160)
      ),
      table.standardOptions.override.byName.new('GPU Model')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(100)
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
              'Value #B': 'VRAM Used (MiB)',
              'Value #C': 'VRAM Total (MiB)',
            },
          },
        },
      ],
    },
  ],
}
