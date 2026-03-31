// Row 6 (new order): Workload Analysis
// Table: removed GPU#, replaced Memory%+MemGB with VRAM Used/Total (MiB), added Node + GPU Model.
// Load-over-time replaced with pure compute % repeated per node.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local table = g.panel.table;
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
    row.new('Workload Analysis')
    + row.withGridPos(128),

    // Workload GPU Usage table
    // Columns: Workload | Namespace | Node | GPU Model | MIG ID | Compute % | VRAM Used (MiB) | VRAM Total (MiB)
    // GPU# removed; Memory% removed; MemGB replaced by MiB Used + MiB Total
    table.new('Workload GPU Usage')
    + table.panelOptions.withDescription('Per-workload GPU usage. VRAM shown as Used/Total (MiB). GPU column removed; Node and GPU Model added.')
    + table.panelOptions.withGridPos(10, 24, 0, 129)
    + table.queryOptions.withTargets([
      // A: Compute % — group-by includes Hostname + modelName
      prometheus.new(ds, q.workloadComputePct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      // B: VRAM used (MiB)
      prometheus.new(ds, q.workloadVramUsed)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      // C: VRAM total (MiB)
      prometheus.new(ds, q.workloadVramTotal)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Compute %' }])
    + table.standardOptions.withOverrides([
      // Compute % — gradient gauge
      table.standardOptions.override.byName.new('Compute %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('gradient-gauge')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.compute)
        + table.fieldConfig.defaults.custom.withWidth(150)
      ),
      // VRAM Used (MiB)
      table.standardOptions.override.byName.new('VRAM Used (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      // VRAM Total (MiB)
      table.standardOptions.override.byName.new('VRAM Total (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      // Workload
      table.standardOptions.override.byName.new('Workload')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(260)
      ),
      // Namespace
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(180)
      ),
      // Node
      table.standardOptions.override.byName.new('Node')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(160)
      ),
      // GPU Model
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
            // Hide gpu (GPU#) and Time
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

    // Workload Compute % Over Time — repeated per node
    // Pure GR engine active %; composite load formula removed.
    timeSeries.new('Workload Compute % — $hostname')
    + timeSeries.panelOptions.withDescription('GPU compute activity per workload on this node (GR engine active %)')
    + timeSeries.panelOptions.withGridPos(8, 24, 0, 140)
    + timeSeries.panelOptions.withRepeat('hostname')
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.workloadComputeOverTime)
      + prometheus.withLegendFormat('{{exported_namespace}}/{{exported_pod}} ({{GPU_I_PROFILE}})'),
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
    + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
    + timeSeries.options.legend.withSortBy('Last')
    + timeSeries.options.legend.withSortDesc(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),
  ],
}
