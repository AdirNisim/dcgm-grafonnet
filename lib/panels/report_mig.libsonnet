// Weekly Report Row 4: MIG Fragmentation Analysis
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local gauge = g.panel.gauge;
local table = g.panel.table;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    row.new('MIG Fragmentation Analysis')
    + row.withGridPos(23),

    // MIG Profile Distribution table (Total vs Active per profile)
    table.new('MIG Profile Distribution')
    + table.panelOptions.withDescription('MIG slice inventory by profile — Total allocated vs Active (has workload)')
    + table.panelOptions.withGridPos(8, 12, 0, 24)
    + table.queryOptions.withTargets([
      // A: Total MIG slices per profile
      prometheus.new(ds, q.migProfileCount)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      // B: Active MIG slices per profile (has workload pod)
      prometheus.new(ds, q.migActiveByProfile)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Total' }])
    + table.standardOptions.withNoValue('0')
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('Total')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps(t.singleColor('blue'))
        + table.fieldConfig.defaults.custom.withWidth(80)
      ),
      table.standardOptions.override.byName.new('Active')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps(t.singleColor('green'))
        + table.fieldConfig.defaults.custom.withWidth(80)
      ),
      table.standardOptions.override.byName.new('Idle')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps(t.countWarning)
        + table.fieldConfig.defaults.custom.withWidth(80)
      ),
      table.standardOptions.override.byName.new('Profile')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(140)
      ),
    ])
    + {
      transformations: [
        { id: 'merge', options: {} },
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true },
            indexByName: { GPU_I_PROFILE: 0, 'Value #A': 1, 'Value #B': 2 },
            renameByName: {
              GPU_I_PROFILE: 'Profile',
              'Value #A': 'Total',
              'Value #B': 'Active',
            },
          },
        },
        {
          id: 'calculateField',
          options: {
            alias: 'Idle',
            mode: 'binaryOperation',
            binary: { left: 'Total', right: 'Active', operator: '-' },
          },
        },
      ],
    },

    // MIG Idle % gauge
    gauge.new('MIG Idle %')
    + gauge.panelOptions.withDescription('Percentage of MIG slices with no active workload pod — fragmentation risk indicator')
    + gauge.panelOptions.withGridPos(8, 6, 12, 24)
    + gauge.queryOptions.withTargets([
      prometheus.new(ds, q.migIdlePct)
      + prometheus.withLegendFormat('Idle %'),
    ])
    + gauge.standardOptions.withUnit('percent')
    + gauge.standardOptions.withMin(0)
    + gauge.standardOptions.withMax(100)
    + gauge.standardOptions.color.withMode('thresholds')
    + gauge.standardOptions.thresholds.withSteps(t.migIdle)
    + gauge.options.withShowThresholdLabels(true)
    + gauge.options.withShowThresholdMarkers(true)
    + gauge.options.reduceOptions.withCalcs(['lastNotNull']),

    // Total MIG instances
    stat.new('Total MIG Instances')
    + stat.panelOptions.withDescription('Total MIG slices provisioned across all nodes')
    + stat.panelOptions.withGridPos(4, 6, 18, 24)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.migInstances)
      + prometheus.withLegendFormat('Total MIG'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('purple'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // Active MIG instances (have workload)
    stat.new('Active MIG Instances')
    + stat.panelOptions.withDescription('MIG slices currently assigned to a workload pod')
    + stat.panelOptions.withGridPos(4, 6, 18, 28)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.migActiveCount)
      + prometheus.withLegendFormat('Active MIG'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('green'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),
  ],
}
