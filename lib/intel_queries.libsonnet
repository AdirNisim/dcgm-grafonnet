// PromQL queries for GPU Utilization Intelligence dashboard.
// Focused on capacity planning signals: efficiency, workload character,
// MIG fragmentation, namespace share, trends, and scheduling pressure.
{
  // -------------------------------------------------------------------------
  // Fleet-level state counts
  // -------------------------------------------------------------------------

  // Total GPU devices (whole + MIG)
  totalDevices:
    'count(count by (gpu, GPU_I_ID, UUID) (DCGM_FI_DEV_FB_USED))',

  // Busy: compute > 5%
  busyGPUs: |||
    count(
      avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100) > 5
    ) or vector(0)
  |||,

  // Idle-allocated: VRAM in use but compute < 5% — model loaded, not serving
  idleAllocatedGPUs: |||
    count(
      (avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_DEV_FB_USED) > 0)
      unless
      (avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100) > 5)
    ) or vector(0)
  |||,

  // Unused: no VRAM, no compute — truly free devices
  unusedGPUs: |||
    count(
      avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_DEV_FB_USED) == 0
    ) or vector(0)
  |||,

  // Cluster-wide compute utilization %
  clusterComputePct:
    'avg(DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)',

  // Cluster-wide VRAM utilization %
  clusterVramPct: |||
    avg(
      DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100
    )
  |||,

  // GPU Pressure Index: demand signal combining compute + VRAM pressure.
  // Not a true "load" measure — use to gauge overall cluster saturation.
  gpuPressureIndex: |||
    avg(
      (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100 * 0.6)
      + (DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100 * 0.4)
    )
  |||,

  // GPU Allocation Efficiency: busy / allocated (has VRAM)
  allocationEfficiencyPct: |||
    (
      count(avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100) > 5)
      /
      count(avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_DEV_FB_USED) > 0)
    ) * 100 or vector(0)
  |||,

  // Pending GPU pods (scheduling pressure)
  pendingGpuPods: |||
    count(
      kube_pod_status_phase{phase="Pending"}
      * on(pod, namespace) group_left()
      kube_pod_container_resource_requests{resource="nvidia.com/gpu"}
    ) or vector(0)
  |||,

  // GPU state over time — three separate queries for stacked timeseries
  // (use with RefId A/B/C and legend Busy / Idle-Allocated / Unused)
  stateOverTimeBusy: |||
    count(
      avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100) > 5
    ) or vector(0)
  |||,

  stateOverTimeIdleAllocated: |||
    count(
      (avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_DEV_FB_USED) > 0)
      unless
      (avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100) > 5)
    ) or vector(0)
  |||,

  stateOverTimeUnused: |||
    count(
      avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_DEV_FB_USED) == 0
    ) or vector(0)
  |||,

  // -------------------------------------------------------------------------
  // Workload character: memory-bound vs compute-bound
  // -------------------------------------------------------------------------

  // DRAM Active % per device — memory bus utilization
  // High DRAM + low compute = memory-bandwidth bound (inference, attention layers)
  // High DRAM + high compute = healthy ML training
  dramActiveByDevice: |||
    avg by (gpu, GPU_I_ID, Hostname, modelName, UUID) (
      DCGM_FI_PROF_DRAM_ACTIVE{Hostname=~"$hostname"} * 100
    )
  |||,

  // Compute % per device (for side-by-side with DRAM active)
  computeByDeviceIntel: |||
    avg by (gpu, GPU_I_ID, Hostname, modelName, UUID) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{Hostname=~"$hostname"} * 100
    )
  |||,

  // FP16 pipe active per device — indicates mixed-precision usage
  fp16PipeByDevice: |||
    avg by (gpu, GPU_I_ID, Hostname, modelName, UUID) (
      DCGM_FI_PROF_PIPE_FP16_ACTIVE{Hostname=~"$hostname"} * 100
    )
  |||,

  // Tensor pipe active per device — indicates tensor core usage
  tensorPipeByDevice: |||
    avg by (gpu, GPU_I_ID, Hostname, modelName, UUID) (
      DCGM_FI_PROF_PIPE_TENSOR_ACTIVE{Hostname=~"$hostname"} * 100
    )
  |||,

  // Workload VRAM % — for character table
  workloadVramPct: |||
    avg by (exported_pod, exported_namespace, Hostname, modelName, GPU_I_ID) (
      DCGM_FI_DEV_FB_USED{exported_pod!=""}
      / (DCGM_FI_DEV_FB_USED{exported_pod!=""} + DCGM_FI_DEV_FB_FREE{exported_pod!=""}) * 100
    )
  |||,

  // Workload compute % — for character table (paired with VRAM %)
  workloadComputePctIntel: |||
    avg by (exported_pod, exported_namespace, Hostname, modelName, GPU_I_ID) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100
    )
  |||,

  // Workload DRAM active % — third dimension for character table
  workloadDramActivePct: |||
    avg by (exported_pod, exported_namespace, Hostname, modelName, GPU_I_ID) (
      DCGM_FI_PROF_DRAM_ACTIVE{exported_pod!=""} * 100
    )
  |||,

  // -------------------------------------------------------------------------
  // MIG fragmentation
  // -------------------------------------------------------------------------

  // Total MIG slices by profile
  migSlicesByProfile: |||
    count by (GPU_I_PROFILE) (DCGM_FI_DEV_FB_USED{GPU_I_ID!=""})
  |||,

  // Active MIG slices (have a workload) by profile
  migActiveSlicesByProfile: |||
    count by (GPU_I_PROFILE) (
      DCGM_FI_DEV_FB_USED{GPU_I_ID!="", exported_pod!=""}
    ) or vector(0)
  |||,

  // Free MIG slices by profile: total - active
  migFreeSlicesByProfile: |||
    (
      count by (GPU_I_PROFILE) (DCGM_FI_DEV_FB_USED{GPU_I_ID!=""})
      - (count by (GPU_I_PROFILE) (DCGM_FI_DEV_FB_USED{GPU_I_ID!="", exported_pod!=""}) or vector(0))
    )
  |||,

  // MIG compute utilization by profile
  migComputeByProfile: |||
    avg by (GPU_I_PROFILE) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{GPU_I_ID!=""} * 100
    )
  |||,

  // MIG VRAM utilization by profile
  migVramByProfile: |||
    avg by (GPU_I_PROFILE) (
      DCGM_FI_DEV_FB_USED{GPU_I_ID!=""}
      / (DCGM_FI_DEV_FB_USED{GPU_I_ID!=""} + DCGM_FI_DEV_FB_FREE{GPU_I_ID!=""}) * 100
    )
  |||,

  // MIG idle % cluster-wide (fragmentation risk)
  migIdlePct: |||
    (
      count(DCGM_FI_DEV_FB_USED{GPU_I_ID!=""})
      - (count(DCGM_FI_DEV_FB_USED{GPU_I_ID!="", exported_pod!=""}) or vector(0))
    ) / count(DCGM_FI_DEV_FB_USED{GPU_I_ID!=""}) * 100 or vector(0)
  |||,

  // -------------------------------------------------------------------------
  // Namespace compute share
  // -------------------------------------------------------------------------

  // Current compute share by namespace (sum of GR engine active across all devices)
  computeShareByNamespace: |||
    sum by (exported_namespace) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100
    )
  |||,

  // VRAM used by namespace
  vramShareByNamespace:
    'sum by (exported_namespace) (DCGM_FI_DEV_FB_USED{exported_pod!=""})',

  // Average compute share over the selected time range (for 7d / 30d view)
  computeShareByNamespaceAvg: |||
    avg_over_time(
      sum by (exported_namespace) (
        DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100
      )[$__range:]
    )
  |||,

  // -------------------------------------------------------------------------
  // GPU allocation efficiency — idle detection
  // -------------------------------------------------------------------------

  // All active workloads with compute % + VRAM % — used to identify idle allocations.
  // Sort by compute ASC in panel to surface inefficient workloads at top.
  idleDetectCompute: |||
    avg by (exported_pod, exported_namespace, Hostname, modelName, GPU_I_ID) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100
    )
  |||,

  idleDetectVramUsed: |||
    avg by (exported_pod, exported_namespace, Hostname, modelName, GPU_I_ID) (
      DCGM_FI_DEV_FB_USED{exported_pod!=""}
    )
  |||,

  idleDetectVramTotal: |||
    avg by (exported_pod, exported_namespace, Hostname, modelName, GPU_I_ID) (
      DCGM_FI_DEV_FB_USED{exported_pod!=""} + DCGM_FI_DEV_FB_FREE{exported_pod!=""}
    )
  |||,

  // Idle-allocated GPU count over time (for trend timeseries in efficiency section)
  idleAllocatedOverTime: |||
    count(
      (avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_DEV_FB_USED) > 0)
      unless
      (avg by (gpu, GPU_I_ID, UUID) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100) > 5)
    ) or vector(0)
  |||,

  // Workload pod age in seconds (requires kube_pod_start_time)
  workloadPodAgeSec: |||
    time()
    - (
        kube_pod_start_time{}
        * on(pod, namespace) group_left()
        kube_pod_container_resource_requests{resource="nvidia.com/gpu"}
      )
  |||,

  // -------------------------------------------------------------------------
  // Long-term capacity trends
  // -------------------------------------------------------------------------

  // Cluster average compute over time (use 30d time range in dashboard)
  trendClusterCompute:
    'avg(DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)',

  // Cluster average VRAM utilization over time
  trendClusterVram: |||
    avg(
      DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100
    )
  |||,

  // Cluster total VRAM in use (GB) over time — shows absolute growth
  trendClusterVramUsedGB:
    'sum(DCGM_FI_DEV_FB_USED) / 1024',

  // Idle GPU % over time (useful for efficiency trend)
  trendIdleGpuPct: |||
    (
      count(DCGM_FI_DEV_GPU_UTIL < 5)
      / count(DCGM_FI_DEV_GPU_UTIL)
    ) * 100 or vector(0)
  |||,

  // P50 / P90 / P95 of cluster compute over selected range
  trendComputeP50:
    'quantile_over_time(0.50, avg(DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)[$__range:])',
  trendComputeP90:
    'quantile_over_time(0.90, avg(DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)[$__range:])',
  trendComputeP95:
    'quantile_over_time(0.95, avg(DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)[$__range:])',

  // -------------------------------------------------------------------------
  // Top consumers
  // -------------------------------------------------------------------------

  // Top 10 VRAM-consuming workloads
  topVramWorkloads: |||
    topk(10,
      sum by (exported_pod, exported_namespace, Hostname, modelName) (
        DCGM_FI_DEV_FB_USED{exported_pod!=""}
      )
    )
  |||,

  // Top 10 compute-consuming workloads
  topComputeWorkloads: |||
    topk(10,
      avg by (exported_pod, exported_namespace, Hostname, modelName) (
        DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100
      )
    )
  |||,

  // -------------------------------------------------------------------------
  // Node GPU balance
  // -------------------------------------------------------------------------

  // Average compute per node
  computePerNode: |||
    avg by (Hostname) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)
  |||,

  // Average VRAM utilization per node
  vramPerNode: |||
    avg by (Hostname) (
      DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) * 100
    )
  |||,

  // Compute imbalance: difference between most and least loaded node
  computeImbalance: |||
    max(avg by (Hostname) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100))
    - min(avg by (Hostname) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100))
  |||,

  // Compute per node over time (timeseries, one line per node)
  computePerNodeOverTime: |||
    avg by (Hostname) (DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)
  |||,
}
