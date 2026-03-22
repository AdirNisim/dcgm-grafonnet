// ============================================================================
// Row 7: Node & PV/PVC Storage
// ============================================================================
//
// Storage monitoring panels for the GPU Capacity Planning dashboard.
// Three sub-sections:
//   1. KPI stats     — quick-glance utilization numbers
//   2. Node storage  — local disk per node (repeated)
//   3. PVC detail    — table + timeseries for persistent volumes
//   4. Trident       — NetApp backend capacity bar gauge
//
// Query source: ../storage_queries.libsonnet
// ============================================================================
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local sq = import '../storage_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local timeSeries = g.panel.timeSeries;
local table = g.panel.table;
local barGauge = g.panel.barGauge;
local row = g.panel.row;

local ds = '${datasource}';

// Timeseries defaults (consistent with other panel files)
local tsDefaults =
  timeSeries.fieldConfig.defaults.custom.withDrawStyle('line')
  + timeSeries.fieldConfig.defaults.custom.withLineInterpolation('smooth')
  + timeSeries.fieldConfig.defaults.custom.withLineWidth(2)
  + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
  + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
  + timeSeries.fieldConfig.defaults.custom.withSpanNulls(false)
  + timeSeries.fieldConfig.defaults.custom.stacking.withMode('none');

// Base Y offset — placed after Workload Analysis (row 6 ends at y=141)
local baseY = 142;

{
  panels: [

    // ========================================================================
    // Section header
    // ========================================================================
    row.new('Node & PV/PVC Storage')
    + row.withGridPos(baseY),

    // ========================================================================
    // KPI stat panels — top row overview
    // ========================================================================

    // 1. Average Node Disk Used %
    stat.new('Avg Node Disk Used %')
    + stat.panelOptions.withDescription(
      'Average local disk utilization across selected nodes. '
      + 'Source: node-exporter (node_filesystem_*). '
      + 'High values risk DiskPressure and pod eviction.'
    )
    + stat.panelOptions.withGridPos(4, 6, 0, baseY + 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, sq.nodeStorageAvgUtilPct)
      + prometheus.withLegendFormat('Avg Disk %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.storage)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // 2. Total PVC count
    stat.new('Total PVCs')
    + stat.panelOptions.withDescription(
      'Number of Persistent Volume Claims in selected namespaces. '
      + 'Source: kubelet (kubelet_volume_stats_*).'
    )
    + stat.panelOptions.withGridPos(4, 6, 6, baseY + 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, sq.pvcCount)
      + prometheus.withLegendFormat('PVCs'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.singleColor('blue'))
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // 3. PVCs above 80% utilization
    stat.new('PVCs > 80%')
    + stat.panelOptions.withDescription(
      'PVCs with storage utilization above 80%. '
      + 'These are at risk of running out of space — investigate or expand.'
    )
    + stat.panelOptions.withGridPos(4, 6, 12, baseY + 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, sq.pvcCriticalCount)
      + prometheus.withLegendFormat('Critical'),
    ])
    + stat.standardOptions.withUnit('short')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.countWarning)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // 4. Trident Backend Used %
    stat.new('Trident Backend Used %')
    + stat.panelOptions.withDescription(
      'Average NetApp Trident backend storage utilization. '
      + 'Source: Trident CSI metrics (trident_backend_*). '
      + 'Shows "No data" if Trident is not installed.'
    )
    + stat.panelOptions.withGridPos(4, 6, 18, baseY + 1)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, sq.tridentBackendAvgUtilPct)
      + prometheus.withLegendFormat('Backend %'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.withMin(0)
    + stat.standardOptions.withMax(100)
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.storage)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('area')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    // ========================================================================
    // Node disk utilization — repeated per node
    // ========================================================================
    timeSeries.new('Node Disk Usage — $hostname')
    + timeSeries.panelOptions.withDescription(
      'Local disk utilization over time for this node. '
      + 'Source: node-exporter. Mountpoint: /.'
    )
    + timeSeries.panelOptions.withGridPos(8, 24, 0, baseY + 6)
    + timeSeries.panelOptions.withRepeat('hostname')
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, sq.nodeStorageUtilPct)
      + prometheus.withLegendFormat('Disk Used %'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('thresholds')
    + timeSeries.standardOptions.thresholds.withSteps(t.storage)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + timeSeries.options.legend.withDisplayMode('list')
    + timeSeries.options.legend.withPlacement('bottom')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),

    // ========================================================================
    // PVC detail table — all PVCs in selected namespaces
    // ========================================================================
    table.new('PVC Usage by Namespace')
    + table.panelOptions.withDescription(
      'Persistent Volume Claim utilization per namespace. '
      + 'Source: kubelet (kubelet_volume_stats_*). '
      + 'Sorted by Used % descending to surface full PVCs.'
    )
    + table.panelOptions.withGridPos(10, 24, 0, baseY + 15)
    + table.queryOptions.withTargets([
      // A: Used %
      prometheus.new(ds, sq.pvcTableUtilPct)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('A'),

      // B: Used bytes
      prometheus.new(ds, sq.pvcTableUsed)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('B'),

      // C: Capacity bytes
      prometheus.new(ds, sq.pvcTableCapacity)
      + prometheus.withFormat('table')
      + prometheus.withInstant(true)
      + prometheus.withRefId('C'),
    ])
    + table.options.withShowHeader(true)
    + table.options.withSortBy([{ desc: true, displayName: 'Used %' }])
    + table.standardOptions.withOverrides([
      // Used % — color background
      table.standardOptions.override.byName.new('Used %')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withDisplayMode('color-background')
        + table.standardOptions.withMin(0)
        + table.standardOptions.withMax(100)
        + table.standardOptions.thresholds.withSteps(t.tableBgStorage)
        + table.standardOptions.withUnit('percent')
        + table.standardOptions.withDecimals(1)
        + table.fieldConfig.defaults.custom.withWidth(120)
      ),
      // Used — bytes
      table.standardOptions.override.byName.new('Used')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decbytes')
        + table.standardOptions.withDecimals(1)
        + table.fieldConfig.defaults.custom.withWidth(120)
      ),
      // Capacity — bytes
      table.standardOptions.override.byName.new('Capacity')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.standardOptions.withUnit('decbytes')
        + table.standardOptions.withDecimals(1)
        + table.fieldConfig.defaults.custom.withWidth(120)
      ),
      // Namespace
      table.standardOptions.override.byName.new('Namespace')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(200)
      ),
      // PVC
      table.standardOptions.override.byName.new('PVC')
      + table.standardOptions.override.byName.withPropertiesFromOptions(
        table.fieldConfig.defaults.custom.withWidth(300)
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
              instance: true,
              job: true,
              metrics_path: true,
              node: true,
              prometheus: true,
              service: true,
              uid: true,
            },
            indexByName: {
              namespace: 0,
              persistentvolumeclaim: 1,
              'Value #A': 2,
              'Value #B': 3,
              'Value #C': 4,
            },
            renameByName: {
              namespace: 'Namespace',
              persistentvolumeclaim: 'PVC',
              'Value #A': 'Used %',
              'Value #B': 'Used',
              'Value #C': 'Capacity',
            },
          },
        },
      ],
    },

    // ========================================================================
    // PVC usage over time — timeseries
    // ========================================================================
    timeSeries.new('PVC Usage Over Time')
    + timeSeries.panelOptions.withDescription(
      'Persistent Volume usage in bytes over time per PVC. '
      + 'Source: kubelet (kubelet_volume_stats_used_bytes).'
    )
    + timeSeries.panelOptions.withGridPos(8, 24, 0, baseY + 26)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, sq.pvcUsedBytes)
      + prometheus.withLegendFormat('{{namespace}}/{{persistentvolumeclaim}}'),
    ])
    + timeSeries.standardOptions.withUnit('decbytes')
    + timeSeries.standardOptions.color.withMode('palette-classic')
    + tsDefaults
    + timeSeries.options.legend.withDisplayMode('table')
    + timeSeries.options.legend.withPlacement('right')
    + timeSeries.options.legend.withShowLegend(true)
    + timeSeries.options.legend.withCalcs(['mean', 'max', 'last'])
    + timeSeries.options.legend.withSortBy('Last')
    + timeSeries.options.legend.withSortDesc(true)
    + timeSeries.options.tooltip.withMode('multi')
    + timeSeries.options.tooltip.withSort('desc'),

    // ========================================================================
    // Trident / NetApp backend capacity — bar gauge
    // ========================================================================
    barGauge.new('Trident Backend Capacity')
    + barGauge.panelOptions.withDescription(
      'NetApp Trident backend storage utilization per backend. '
      + 'Source: Trident CSI metrics (trident_backend_*). '
      + 'Shows "No data" if Trident is not installed or metrics are not scraped.'
    )
    + barGauge.panelOptions.withGridPos(6, 24, 0, baseY + 35)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, sq.tridentBackendUtilPct)
      + prometheus.withLegendFormat('{{backend_name}} ({{backend_type}})'),
    ])
    + barGauge.standardOptions.withUnit('percent')
    + barGauge.standardOptions.withMin(0)
    + barGauge.standardOptions.withMax(100)
    + barGauge.standardOptions.color.withMode('thresholds')
    + barGauge.standardOptions.thresholds.withSteps(t.storage)
    + barGauge.options.withDisplayMode('basic')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(true),
  ],
}
