// Row 6: Long-Term Capacity Trends
// Set dashboard time range to 7d or 30d for meaningful planning signals.
// Percentile stats give the distribution shape over the selected range.
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local q = import '../intel_queries.libsonnet';
local t = import '../thresholds.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
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
    row.new('Long-Term Capacity Trends')
    + row.withGridPos(97),

    // Compute % trend
    timeSeries.new('Cluster Compute % Trend')
    + timeSeries.panelOptions.withDescription('Average cluster compute utilization over time. Use 7d-30d range. Consistent growth toward 70%+ signals need for more capacity.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 98)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.trendClusterCompute)
      + prometheus.withLegendFormat('Compute %'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('fixed')
    + timeSeries.standardOptions.thresholds.withSteps(t.compute)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + {
      fieldConfig+: {
        defaults+: {
          color: { fixedColor: 'green', mode: 'fixed' },
        },
      },
    }
    + timeSeries.options.legend.withDisplayMode('list')
    + timeSeries.options.legend.withShowLegend(false)
    + timeSeries.options.tooltip.withMode('single'),

    // VRAM % trend
    timeSeries.new('Cluster VRAM % Trend')
    + timeSeries.panelOptions.withDescription('Average cluster VRAM utilization over time. VRAM trending toward 85%+ while compute stays low = over-provisioned models or idle inference servers.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 98)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.trendClusterVram)
      + prometheus.withLegendFormat('VRAM %'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('fixed')
    + timeSeries.standardOptions.thresholds.withSteps(t.memory)
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('line')
    + {
      fieldConfig+: {
        defaults+: {
          color: { fixedColor: 'purple', mode: 'fixed' },
        },
      },
    }
    + timeSeries.options.legend.withDisplayMode('list')
    + timeSeries.options.legend.withShowLegend(false)
    + timeSeries.options.tooltip.withMode('single'),

    // Total VRAM in use (GB) — absolute growth signal
    timeSeries.new('Total VRAM In Use (GB) Trend')
    + timeSeries.panelOptions.withDescription('Absolute VRAM consumption in GB over time. Growing steadily = organic demand growth. Sharp drops = workloads evicted or completed.')
    + timeSeries.panelOptions.withGridPos(8, 12, 0, 107)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.trendClusterVramUsedGB)
      + prometheus.withLegendFormat('VRAM Used (GB)'),
    ])
    + timeSeries.standardOptions.withUnit('decgbytes')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.color.withMode('fixed')
    + timeSeries.standardOptions.thresholds.withSteps(t.singleColor('purple'))
    + tsDefaults
    + timeSeries.fieldConfig.defaults.custom.thresholdsStyle.withMode('off')
    + {
      fieldConfig+: {
        defaults+: {
          color: { fixedColor: 'purple', mode: 'fixed' },
        },
      },
    }
    + timeSeries.options.legend.withDisplayMode('list')
    + timeSeries.options.legend.withShowLegend(false)
    + timeSeries.options.tooltip.withMode('single'),

    // Idle GPU % trend — efficiency of the fleet over time
    timeSeries.new('Idle GPU % Trend')
    + timeSeries.panelOptions.withDescription('% of GPUs with GPU_UTIL < 5% over time. Increasing idle % with constant device count = efficiency degradation.')
    + timeSeries.panelOptions.withGridPos(8, 12, 12, 107)
    + timeSeries.queryOptions.withTargets([
      prometheus.new(ds, q.trendIdleGpuPct)
      + prometheus.withLegendFormat('Idle GPU %'),
    ])
    + timeSeries.standardOptions.withUnit('percent')
    + timeSeries.standardOptions.withMin(0)
    + timeSeries.standardOptions.withMax(100)
    + timeSeries.standardOptions.color.withMode('fixed')
    + timeSeries.standardOptions.thresholds.withSteps(t.riskPct)
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

    // Compute percentile stats over the selected time range
    stat.new('Compute P50 (Range)')
    + stat.panelOptions.withDescription('Median cluster compute % over selected time range')
    + stat.panelOptions.withGridPos(4, 4, 0, 116)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.trendComputeP50)
      + prometheus.withLegendFormat('P50'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.compute)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Compute P90 (Range)')
    + stat.panelOptions.withDescription('90th percentile cluster compute % over selected time range')
    + stat.panelOptions.withGridPos(4, 4, 4, 116)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.trendComputeP90)
      + prometheus.withLegendFormat('P90'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.compute)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),

    stat.new('Compute P95 (Range)')
    + stat.panelOptions.withDescription('95th percentile cluster compute % — your peak demand signal')
    + stat.panelOptions.withGridPos(4, 4, 8, 116)
    + stat.queryOptions.withTargets([
      prometheus.new(ds, q.trendComputeP95)
      + prometheus.withLegendFormat('P95'),
    ])
    + stat.standardOptions.withUnit('percent')
    + stat.standardOptions.color.withMode('thresholds')
    + stat.standardOptions.thresholds.withSteps(t.compute)
    + stat.options.withColorMode('value')
    + stat.options.withGraphMode('none')
    + stat.options.reduceOptions.withCalcs(['lastNotNull']),
  ],
}
