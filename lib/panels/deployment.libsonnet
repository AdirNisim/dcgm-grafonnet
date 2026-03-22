// Row 5 (new order): Deployment-Level Metrics (Node CPU & RAM)
// Uses kube-state-metrics + cAdvisor — NOT DCGM GPU metrics.
// Columns show actual node CPU (millicores) and RAM (MiB), not GPU compute/memory.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local table = g.panel.table;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    row.new('Deployment-Level Metrics (Node CPU & RAM)')
    + row.withGridPos(109),

    // CPU & RAM by Deployment (kube-state-metrics + cAdvisor join)
    // Compute % and Memory % here refer to NODE resources, not GPU.
    table.new('CPU & RAM by Deployment')
    + table.panelOptions.withDescription('Node CPU (millicores) and RAM (MiB) usage per Kubernetes deployment. Source: kube-state-metrics + cAdvisor — not DCGM GPU metrics.')
    + table.panelOptions.withGridPos(10, 24, 0, 110)
    + table.queryOptions.withTargets([
      // A: CPU used (millicores)
      prometheus.new(ds, q.deploymentCpuMillicores)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      // B: CPU requested (millicores)
      prometheus.new(ds, q.deploymentCpuRequested)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      // C: RAM used (MiB)
      prometheus.new(ds, q.deploymentRamMiB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),

      // D: RAM requested (MiB)
      prometheus.new(ds, q.deploymentRamRequestedMiB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('D'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Node RAM Used (MiB)' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('CPU Used (m)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('short')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(130)
      ),
      table.standardOptions.override.byName.new('CPU Requested (m)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('short')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(160)
      ),
      table.standardOptions.override.byName.new('Node RAM Used (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('Node RAM Requested (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(165)
      ),
      table.standardOptions.override.byName.new('Deployment')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(260)
      ),
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(180)
      ),
    ])
    + {
      transformations: [
        { id: 'merge', options: {} },
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true },
            indexByName: {
              deployment: 1,
              namespace: 2,
              'Value #A': 3,
              'Value #B': 4,
              'Value #C': 5,
              'Value #D': 6,
            },
            renameByName: {
              deployment: 'Deployment',
              namespace: 'Namespace',
              'Value #A': 'CPU Used (m)',
              'Value #B': 'CPU Requested (m)',
              'Value #C': 'Node RAM Used (MiB)',
              'Value #D': 'Node RAM Requested (MiB)',
            },
          },
        },
      ],
    },
  ],
}
