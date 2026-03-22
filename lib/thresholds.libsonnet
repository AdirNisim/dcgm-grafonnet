// Reusable threshold step configurations.
// Each is an array of {color, value} objects for standardOptions.thresholds.withSteps().
{
  // Single-color (no threshold transitions)
  singleColor(color):: [{ color: color, value: null }],

  // Memory utilization: green -> yellow@70 -> red@85
  memory: [
    { color: 'green', value: null },
    { color: '#EAB839', value: 70 },
    { color: 'red', value: 85 },
  ],

  // Compute utilization: green -> yellow@60 -> red@85
  compute: [
    { color: 'green', value: null },
    { color: '#EAB839', value: 60 },
    { color: 'red', value: 85 },
  ],

  // Temperature: green -> yellow@70 -> red@80
  temperature: [
    { color: 'green', value: null },
    { color: '#EAB839', value: 70 },
    { color: 'red', value: 80 },
  ],

  // Inverted load gauge (low = red, mid = yellow, high = green)
  loadGaugeInverted: [
    { color: 'red', value: null },
    { color: '#EAB839', value: 40 },
    { color: 'green', value: 60 },
  ],

  // Count-based warnings: green -> yellow@1 -> red@3
  countWarning: [
    { color: 'green', value: null },
    { color: '#EAB839', value: 1 },
    { color: 'red', value: 3 },
  ],

  // Count-based warnings: green -> yellow@3 -> red@5
  countWarningHigh: [
    { color: 'green', value: null },
    { color: '#EAB839', value: 3 },
    { color: 'red', value: 5 },
  ],

  // Percentage risk: green -> yellow@20 -> red@40
  riskPct: [
    { color: 'green', value: null },
    { color: '#EAB839', value: 20 },
    { color: 'red', value: 40 },
  ],

  // Efficiency score: red=underutilized, green=healthy, yellow/red=saturated
  efficiency: [
    { color: 'red', value: null },
    { color: 'green', value: 40 },
    { color: '#EAB839', value: 70 },
    { color: 'red', value: 85 },
  ],

  // Idle GPU %: green=low idle (good), yellow/red=high idle (wasteful)
  idleGpu: [
    { color: 'green', value: null },
    { color: '#EAB839', value: 20 },
    { color: 'red', value: 40 },
  ],

  // MIG idle %: green=low idle, red=high idle (fragmentation risk)
  migIdle: [
    { color: 'green', value: null },
    { color: '#EAB839', value: 25 },
    { color: 'red', value: 50 },
  ],

  // Device workload status: blue = idle (0), green = active (1)
  deviceStatus: [
    { color: 'blue', value: null },
    { color: 'green', value: 1 },
  ],

  // Storage utilization: green -> yellow@75 -> red@90
  storage: [
    { color: 'green', value: null },
    { color: '#EAB839', value: 75 },
    { color: 'red', value: 90 },
  ],

  // Subtle background thresholds for table cells (storage)
  tableBgStorage: [
    { color: 'rgba(50, 172, 45, 0.2)', value: null },
    { color: 'rgba(237, 129, 40, 0.2)', value: 75 },
    { color: 'rgba(245, 54, 54, 0.2)', value: 90 },
  ],

  // Subtle background thresholds for table cells (memory)
  tableBgMemory: [
    { color: 'rgba(50, 172, 45, 0.2)', value: null },
    { color: 'rgba(237, 129, 40, 0.2)', value: 70 },
    { color: 'rgba(245, 54, 54, 0.2)', value: 85 },
  ],

  // Subtle background thresholds for table cells (compute)
  tableBgCompute: [
    { color: 'rgba(50, 172, 45, 0.2)', value: null },
    { color: 'rgba(237, 129, 40, 0.2)', value: 70 },
    { color: 'rgba(245, 54, 54, 0.2)', value: 90 },
  ],

  // Subtle background thresholds for table cells (temperature)
  tableBgTemperature: [
    { color: 'rgba(50, 172, 45, 0.2)', value: null },
    { color: 'rgba(237, 129, 40, 0.2)', value: 70 },
    { color: 'rgba(245, 54, 54, 0.2)', value: 80 },
  ],
}
