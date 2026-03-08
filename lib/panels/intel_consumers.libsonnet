// Row 7: Top GPU Consumers
// Top 10 workloads by VRAM and compute — spotting the heaviest users and optimization targets.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../intel_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local barGauge = g.panel.barGauge;
local row = g.panel.row;

local ds = '${datasource}';

{
  panels: [
    row.new('Top GPU Consumers')
    + row.withGridPos(121),

    // Top 10 by VRAM (absolute consumption — model footprint)
    barGauge.new('Top 10 VRAM-Consuming Workloads')
    + barGauge.panelOptions.withDescription('Workloads consuming the most VRAM. Large footprints limit co-location and MIG scheduling options.')
    + barGauge.panelOptions.withGridPos(10, 12, 0, 122)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.topVramWorkloads)
      + prometheus.withLegendFormat('{{exported_namespace}}/{{exported_pod}} ({{Hostname}})'),
    ])
    + barGauge.standardOptions.withUnit('decmbytes')
    + barGauge.standardOptions.withMin(0)
    + barGauge.standardOptions.color.withMode('palette-classic')
    + barGauge.options.withDisplayMode('basic')
    + barGauge.options.withOrientation('horizontal')
    + barGauge.options.reduceOptions.withCalcs(['lastNotNull'])
    + barGauge.options.withShowUnfilled(false),

    // Top 10 by compute (active GPU time — highest compute consumers)
    barGauge.new('Top 10 Compute-Consuming Workloads')
    + barGauge.panelOptions.withDescription('Workloads consuming the most GPU compute. These are the heaviest compute users — optimization here has the highest impact.')
    + barGauge.panelOptions.withGridPos(10, 12, 12, 122)
    + barGauge.queryOptions.withTargets([
      prometheus.new(ds, q.topComputeWorkloads)
      + prometheus.withLegendFormat('{{exported_namespace}}/{{exported_pod}} ({{Hostname}})'),
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
  ],
}
