// Row 1 (new order): Device Inventory & Health
// Per-node repeated tables + node CPU/RAM + deployments per node
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local table = g.panel.table;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    row.new('Device Inventory & Health')
    + row.withGridPos(0),

    // Device Workload Map (at-a-glance: blue=idle, green=active workload)
    table.new('Device Workload Map')
    + table.panelOptions.withDescription('At-a-glance device status: blue = idle, green = has active workload')
    + table.panelOptions.withGridPos(8, 24, 0, 1)
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.deviceWorkloadMap)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: false, displayName: 'Host' }])
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('Status')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(1)
        + table.standardOptions.color.withMode('thresholds')
        + table.standardOptions.thresholds.withSteps(t.deviceStatus)
        + table.fieldConfig.defaults.custom.withWidth(50)
      )
      + {
        properties+: [{
          id: 'mappings',
          value: [{
            type: 'value',
            options: {
              '0': { text: '■', index: 0 },
              '1': { text: '■', index: 1 },
            },
          }],
        }],
      },
      table.standardOptions.override.byName.new('Workload')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(220)
      ),
      table.standardOptions.override.byName.new('Host')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(160)
      ),
      table.standardOptions.override.byName.new('Model')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(120)
      ),
    ])
    + {
      transformations: [
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, UUID: true, GPU_I_ID: true },
            indexByName: {
              Hostname: 0,
              modelName: 1,
              GPU_I_PROFILE: 2,
              gpu: 3,
              'Value #A': 4,
              exported_pod: 5,
            },
            renameByName: {
              Hostname: 'Host',
              modelName: 'Model',
              GPU_I_PROFILE: 'Profile',
              gpu: 'GPU',
              'Value #A': 'Status',
              exported_pod: 'Workload',
            },
          },
        },
      ],
    },

    // Device Inventory & Status — repeated per node
    // Queries filtered by Hostname=~"$hostname"; repeat generates one panel per node.
    // RefIds after removing composite load: A=Compute, B=MemoryPct, C=UsedGB, D=TotalGB, E=Power, F=Temp
    table.new('Device Inventory & Status — $hostname')
    + table.panelOptions.withDescription('Per-node GPU device inventory. Sorted by compute utilization.')
    + table.panelOptions.withGridPos(12, 24, 0, 10)
    + table.panelOptions.withRepeat('hostname')
    + table.queryOptions.withTargets([
      // A: Compute % (also brings modelName + GPU_I_PROFILE into the merge)
      prometheus.new(ds, q.inventoryComputePct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      // B: VRAM %
      prometheus.new(ds, q.inventoryMemoryPct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      // C: VRAM used (GB)
      prometheus.new(ds, q.inventoryUsedGB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),

      // D: VRAM total (GB)
      prometheus.new(ds, q.inventoryTotalGB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('D'),

      // E: Power (W)
      prometheus.new(ds, q.inventoryPower)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('E'),

      // F: Temperature (C)
      prometheus.new(ds, q.inventoryTemp)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('F'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Compute %' }])
    + table.standardOptions.withOverrides([
      // Compute % — color background
      table.standardOptions.override.byName.new('Compute %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.tableBgCompute)
      ),
      // VRAM % — color background
      table.standardOptions.override.byName.new('VRAM %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.tableBgMemory)
      ),
      // VRAM Used (GB)
      table.standardOptions.override.byName.new('VRAM Used (GB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decgbytes')
        + table.standardOptions.withDecimals(1)
      ),
      // VRAM Total (GB)
      table.standardOptions.override.byName.new('VRAM Total (GB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decgbytes')
        + table.standardOptions.withDecimals(1)
      ),
      // Power (W)
      table.standardOptions.override.byName.new('Power (W)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('watt')
        + table.standardOptions.withDecimals(0)
      ),
      // Temp (C) — color background
      table.standardOptions.override.byName.new('Temp (C)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('celsius')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.thresholds.withSteps(t.tableBgTemperature)
      ),
      table.standardOptions.override.byName.new('Model')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(130)
      ),
      table.standardOptions.override.byName.new('Host')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(150)
      ),
    ])
    + {
      transformations: [
        { id: 'merge', options: {} },
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, UUID: true },
            indexByName: {
              Hostname: 0,
              gpu: 1,
              GPU_I_ID: 2,
              GPU_I_PROFILE: 3,
              modelName: 4,
              'Value #A': 5,
              'Value #B': 6,
              'Value #C': 7,
              'Value #D': 8,
              'Value #E': 9,
              'Value #F': 10,
            },
            renameByName: {
              Hostname: 'Host',
              gpu: 'GPU',
              GPU_I_ID: 'MIG ID',
              GPU_I_PROFILE: 'Profile',
              modelName: 'Model',
              'Value #A': 'Compute %',
              'Value #B': 'Memory %',
              'Value #C': 'VRAM Used (GB)',
              'Value #D': 'VRAM Total (GB)',
              'Value #E': 'Power (W)',
              'Value #F': 'Temp (C)',
            },
          },
        },
      ],
    },

    // Node CPU & RAM — repeated per node
    // Note: kube-state-metrics uses "node" label; ensure $hostname values match node names.
    table.new('Node Resources — $hostname')
    + table.panelOptions.withDescription('Node CPU and RAM from kube-state-metrics / cAdvisor. Node label must match $hostname.')
    + table.panelOptions.withGridPos(5, 24, 0, 23)
    + table.panelOptions.withRepeat('hostname')
    + table.queryOptions.withTargets([
      // A: CPU used (cores)
      prometheus.new(ds, q.nodeCpuUsedCores)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      // B: CPU allocatable (cores)
      prometheus.new(ds, q.nodeCpuAllocatable)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      // C: RAM used (MiB)
      prometheus.new(ds, q.nodeRamUsedMiB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),

      // D: RAM total (MiB)
      prometheus.new(ds, q.nodeRamTotalMiB)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('D'),
    ])
    + table.options.withShowHeader(true)
    + table.standardOptions.withOverrides([
      table.standardOptions.override.byName.new('CPU Used (cores)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withDecimals(2)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('CPU Total (cores)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('Node RAM Used (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('Node RAM Total (MiB)')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decmbytes')
        + table.standardOptions.withDecimals(0)
        + table.fieldConfig.defaults.custom.withWidth(140)
      ),
      table.standardOptions.override.byName.new('Node')
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
            excludeByName: {
              Time: true,
              __name__: true,
              container: true,
              endpoint: true,
              job: true,
              namespace: true,
              prometheus: true,
              resource: true,
              service: true,
              unit: true,
            },
            indexByName: {
              node: 0,
              'Value #A': 1,
              'Value #B': 2,
              'Value #C': 3,
              'Value #D': 4,
            },
            renameByName: {
              node: 'Node',
              'Value #A': 'CPU Used (cores)',
              'Value #B': 'CPU Total (cores)',
              'Value #C': 'Node RAM Used (MiB)',
              'Value #D': 'Node RAM Total (MiB)',
            },
          },
        },
      ],
    },

    // Deployments on Node — repeated per node
    table.new('Deployments on Node — $hostname')
    + table.panelOptions.withDescription('Active deployments per node (kube-state-metrics ReplicaSet owner join)')
    + table.panelOptions.withGridPos(8, 24, 0, 29)
    + table.panelOptions.withRepeat('hostname')
    + table.queryOptions.withTargets([
      prometheus.new(ds, q.deploymentsPerNode)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: false, displayName: 'Namespace' }])
    + table.standardOptions.withOverrides([
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
        {
          id: 'organize',
          options: {
            excludeByName: { Time: true, 'Value #A': true },
            indexByName: {
              node: 0,
              namespace: 1,
              deployment: 2,
            },
            renameByName: {
              node: 'Node',
              namespace: 'Namespace',
              deployment: 'Deployment',
            },
          },
        },
      ],
    },
  ],
}
