// PromQL queries for GPU capacity planning dashboard.
// All expressions are strings, referenced by panel definitions.
{
  // --- VRAM summary (cluster-wide) ---
  totalMemoryCapacity:
    'sum(DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE) / 1024',

  memoryInUse:
    'sum(DCGM_FI_DEV_FB_USED) / 1024',

  avgMemoryUtil:
    'avg((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) * 100)',

  oomRiskPct: |||
    (
      count((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) > 0.85)
      /
      count(DCGM_FI_DEV_FB_USED)
    ) * 100 or vector(0)
  |||,

  avgTemperature:
    'avg(DCGM_FI_DEV_GPU_TEMP)',

  avgPower:
    'avg(DCGM_FI_DEV_POWER_USAGE)',

  // --- VRAM by device — per-node panels (Hostname=~"$hostname") ---
  // Whole GPUs only: clean legend without MIG ID noise
  memoryUtilWholeGPU: |||
    avg by (gpu, Hostname, modelName, UUID) (
      DCGM_FI_DEV_FB_USED{GPU_I_ID="", Hostname=~"$hostname"}
      / (DCGM_FI_DEV_FB_USED{GPU_I_ID="", Hostname=~"$hostname"}
         + DCGM_FI_DEV_FB_FREE{GPU_I_ID="", Hostname=~"$hostname"}) * 100
    )
  |||,

  // MIG instances: legend includes profile
  memoryUtilMIG: |||
    avg by (gpu, GPU_I_ID, GPU_I_PROFILE, Hostname, modelName, UUID) (
      DCGM_FI_DEV_FB_USED{GPU_I_ID!="", Hostname=~"$hostname"}
      / (DCGM_FI_DEV_FB_USED{GPU_I_ID!="", Hostname=~"$hostname"}
         + DCGM_FI_DEV_FB_FREE{GPU_I_ID!="", Hostname=~"$hostname"}) * 100
    )
  |||,

  // VRAM used per namespace, filtered to current node
  memoryByNamespacePerNode: |||
    sum by (exported_namespace, Hostname) (
      DCGM_FI_DEV_FB_USED{exported_pod!="", Hostname=~"$hostname"}
    )
  |||,

  workloadMemoryOverTime:
    'sum by (exported_pod, exported_namespace, Hostname, modelName) (DCGM_FI_DEV_FB_USED{exported_pod!=""})',

  // --- Device load ---
  // Top 10 by pure compute % (GR engine active) — no composite formula
  top10DeviceCompute: |||
    topk(10,
      avg by (gpu, GPU_I_ID, GPU_I_PROFILE, Hostname, modelName, UUID) (
        DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100
      )
    )
  |||,

  // Compute % per device, filtered to current node
  computeByDevice: |||
    avg by (gpu, GPU_I_ID, Hostname, modelName, UUID) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{Hostname=~"$hostname"} * 100
    )
  |||,

  // --- Workload analysis ---
  // Compute % with node + model context for table columns
  workloadComputePct: |||
    avg by (exported_pod, exported_namespace, gpu, GPU_I_ID, Hostname, modelName) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100
    )
  |||,

  // VRAM used (MiB) per workload
  workloadVramUsed: |||
    avg by (exported_pod, exported_namespace, gpu, GPU_I_ID, Hostname, modelName) (
      DCGM_FI_DEV_FB_USED{exported_pod!=""}
    )
  |||,

  // VRAM total (MiB) per workload — denominator for Used/Total display
  workloadVramTotal: |||
    avg by (exported_pod, exported_namespace, gpu, GPU_I_ID, Hostname, modelName) (
      DCGM_FI_DEV_FB_USED{exported_pod!=""} + DCGM_FI_DEV_FB_FREE{exported_pod!=""}
    )
  |||,

  // Compute % over time per workload, per node (drives repeated timeseries panels)
  workloadComputeOverTime: |||
    avg by (exported_pod, exported_namespace, Hostname, modelName, GPU_I_PROFILE) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!="", Hostname=~"$hostname"} * 100
    )
  |||,

  // --- Deployment-level (kube-state-metrics + cAdvisor) ---
  // Join: cAdvisor/kube metrics use pod+namespace labels (not exported_*)
  local kubePodJoin = |||
    * on(pod, namespace) group_left(deployment)
    label_replace(
      kube_pod_owner{owner_kind="ReplicaSet"},
      "deployment", "$1", "owner_name", "(.+)-[^-]+"
    )
  |||,

  // CPU used by deployment (millicores) — cAdvisor rate
  deploymentCpuMillicores: |||
    sum by (deployment, namespace) (
      rate(container_cpu_usage_seconds_total{container!="", container!="POD"}[5m]) * 1000
  ||| + kubePodJoin + ')',

  // CPU requested by deployment (millicores)
  deploymentCpuRequested: |||
    sum by (deployment, namespace) (
      kube_pod_container_resource_requests{resource="cpu", container!=""}
      * 1000
  ||| + kubePodJoin + ')',

  // RAM used by deployment (MiB) — working set
  deploymentRamMiB: |||
    sum by (deployment, namespace) (
      container_memory_working_set_bytes{container!="", container!="POD"}
      / (1024 * 1024)
  ||| + kubePodJoin + ')',

  // RAM requested by deployment (MiB)
  deploymentRamRequestedMiB: |||
    sum by (deployment, namespace) (
      kube_pod_container_resource_requests{resource="memory", container!=""}
      / (1024 * 1024)
  ||| + kubePodJoin + ')',

  // --- Device workload map (one row per device: idle=blue, active=green) ---
  deviceWorkloadMap: |||
    (
      clamp_max(
        count by (Hostname, modelName, gpu, GPU_I_ID, GPU_I_PROFILE, UUID, exported_pod) (
          DCGM_FI_DEV_FB_USED{exported_pod!=""}
        ),
        1
      )
    )
    or
    (
      (
        count by (Hostname, modelName, gpu, GPU_I_ID, GPU_I_PROFILE, UUID) (DCGM_FI_DEV_FB_USED)
        unless
        count by (Hostname, modelName, gpu, GPU_I_ID, GPU_I_PROFILE, UUID) (DCGM_FI_DEV_FB_USED{exported_pod!=""})
      ) * 0
    )
  |||,

  // --- Device inventory — per-node filtered (Hostname=~"$hostname") ---
  // Includes modelName + GPU_I_PROFILE so they survive the merge transformation
  inventoryComputePct: |||
    avg by (gpu, GPU_I_ID, GPU_I_PROFILE, Hostname, modelName, UUID) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{Hostname=~"$hostname"} * 100
    )
  |||,

  inventoryMemoryPct: |||
    avg by (gpu, GPU_I_ID, Hostname, UUID) (
      DCGM_FI_DEV_FB_USED{Hostname=~"$hostname"}
      / (DCGM_FI_DEV_FB_USED{Hostname=~"$hostname"} + DCGM_FI_DEV_FB_FREE{Hostname=~"$hostname"}) * 100
    )
  |||,

  inventoryUsedGB: |||
    avg by (gpu, GPU_I_ID, Hostname, UUID) (
      DCGM_FI_DEV_FB_USED{Hostname=~"$hostname"} / 1024
    )
  |||,

  inventoryTotalGB: |||
    avg by (gpu, GPU_I_ID, Hostname, UUID) (
      (DCGM_FI_DEV_FB_USED{Hostname=~"$hostname"} + DCGM_FI_DEV_FB_FREE{Hostname=~"$hostname"}) / 1024
    )
  |||,

  inventoryPower: |||
    avg by (gpu, GPU_I_ID, Hostname, UUID) (
      DCGM_FI_DEV_POWER_USAGE{Hostname=~"$hostname"}
    )
  |||,

  inventoryTemp: |||
    avg by (gpu, GPU_I_ID, Hostname, UUID) (
      DCGM_FI_DEV_GPU_TEMP{Hostname=~"$hostname"}
    )
  |||,

  // --- Node resources (kube-state-metrics + cAdvisor) ---
  // Note: kube uses "node" label; DCGM uses "Hostname". Both filtered by $hostname variable.
  nodeCpuUsedCores: |||
    sum by (node) (
      rate(container_cpu_usage_seconds_total{
        container!="", container!="POD", node=~"$hostname"
      }[5m])
    )
  |||,

  nodeCpuAllocatable:
    'kube_node_status_allocatable{resource="cpu", node=~"$hostname"}',

  nodeRamUsedMiB: |||
    sum by (node) (
      container_memory_working_set_bytes{
        container!="", container!="POD", node=~"$hostname"
      }
    ) / (1024 * 1024)
  |||,

  nodeRamTotalMiB:
    'kube_node_status_allocatable{resource="memory", node=~"$hostname"} / (1024 * 1024)',

  // Deployments running per node (kube-state-metrics join)
  deploymentsPerNode: |||
    count by (node, deployment, namespace) (
      kube_pod_info{node=~"$hostname"}
      * on(pod, namespace) group_left(deployment)
      label_replace(
        kube_pod_owner{owner_kind="ReplicaSet"},
        "deployment", "$1", "owner_name", "(.+)-[^-]+"
      )
    )
  |||,

  // --- Operational health ---
  powerByDevice: |||
    avg by (gpu, GPU_I_ID, Hostname, UUID) (
      DCGM_FI_DEV_POWER_USAGE{Hostname=~"$hostname"}
    )
  |||,

  temperatureByDevice: |||
    avg by (gpu, GPU_I_ID, Hostname, UUID) (
      DCGM_FI_DEV_GPU_TEMP{Hostname=~"$hostname"}
    )
  |||,

  tensorUtilByWorkload:
    'avg by (exported_pod) (DCGM_FI_PROF_PIPE_TENSOR_ACTIVE{exported_pod!=""} * 100)',

  smClockByModel:
    'avg by (modelName) (DCGM_FI_DEV_SM_CLOCK{exported_namespace!=""})',

  // --- Reporting queries (used by gpu-weekly-report.jsonnet) ---
  // Cluster-wide averages used by report_summary / report panels
  migInstances:
    'count(DCGM_FI_DEV_FB_USED{GPU_I_ID!=""})',

  avgGrEngineActivePct:
    'avg(DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)',

  avgVramUtil: |||
    avg(
      sum by (gpu, GPU_I_ID, UUID) (
        (DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) * 100
      )
    )
  |||,

  gpuUtil:
    'avg(DCGM_FI_DEV_GPU_UTIL)',

  peakGpuUtil:
    'max(DCGM_FI_DEV_GPU_UTIL)',

  gpuUtilP50:
    'quantile_over_time(0.50, avg(DCGM_FI_DEV_GPU_UTIL)[$__range:])',
  gpuUtilP90:
    'quantile_over_time(0.90, avg(DCGM_FI_DEV_GPU_UTIL)[$__range:])',
  gpuUtilP95:
    'quantile_over_time(0.95, avg(DCGM_FI_DEV_GPU_UTIL)[$__range:])',
  gpuUtilP99:
    'quantile_over_time(0.99, avg(DCGM_FI_DEV_GPU_UTIL)[$__range:])',

  grEngineP50:
    'quantile_over_time(0.50, avg(DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)[$__range:])',
  grEngineP95:
    'quantile_over_time(0.95, avg(DCGM_FI_PROF_GR_ENGINE_ACTIVE * 100)[$__range:])',

  vramP90: |||
    quantile_over_time(0.90,
      avg(
        (DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) * 100
      )[$__range:]
    )
  |||,

  dramActivePct:
    'avg(DCGM_FI_PROF_DRAM_ACTIVE * 100)',

  idleGpuPct: |||
    (
      count(DCGM_FI_DEV_GPU_UTIL < 5)
      / count(DCGM_FI_DEV_GPU_UTIL)
    ) * 100 or vector(0)
  |||,

  devicesSaturatedCount:
    'count(DCGM_FI_DEV_GPU_UTIL > 85) or vector(0)',

  efficiencyScore: |||
    avg(
      sum by (gpu, GPU_I_ID, UUID) (
        (DCGM_FI_DEV_GPU_UTIL * 0.5)
        + (DCGM_FI_PROF_DRAM_ACTIVE * 100 * 0.3)
        + ((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) * 100 * 0.2)
      )
    )
  |||,

  efficiencyByDevice: |||
    sum by (gpu, GPU_I_ID, GPU_I_PROFILE, Hostname, modelName, UUID) (
      (DCGM_FI_DEV_GPU_UTIL * 0.5)
      + (DCGM_FI_PROF_DRAM_ACTIVE * 100 * 0.3)
      + ((DCGM_FI_DEV_FB_USED / (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)) * 100 * 0.2)
    )
  |||,

  highComputeCount:
    'count(DCGM_FI_DEV_GPU_UTIL > 60) or vector(0)',

  medComputeCount: |||
    count((DCGM_FI_DEV_GPU_UTIL > 10) unless (DCGM_FI_DEV_GPU_UTIL > 60)) or vector(0)
  |||,

  lowComputeCount:
    'count(DCGM_FI_DEV_GPU_UTIL <= 10) or vector(0)',

  computeByNamespace: |||
    sum by (exported_namespace) (
      DCGM_FI_PROF_GR_ENGINE_ACTIVE{exported_pod!=""} * 100
    )
  |||,

  computeByGpuModel:
    'sum by (modelName) (DCGM_FI_PROF_GR_ENGINE_ACTIVE{GPU_I_ID=""} * 100)',

  computeByMigProfile:
    'sum by (modelName, GPU_I_PROFILE) (DCGM_FI_PROF_GR_ENGINE_ACTIVE{GPU_I_ID!=""} * 100)',

  migProfileCount: |||
    count by (GPU_I_PROFILE) (DCGM_FI_DEV_FB_USED{GPU_I_ID!=""})
  |||,

  migActiveByProfile: |||
    count by (GPU_I_PROFILE) (DCGM_FI_DEV_FB_USED{GPU_I_ID!="", exported_pod!=""})
  |||,

  migActiveCount:
    'count(DCGM_FI_DEV_FB_USED{GPU_I_ID!="", exported_pod!=""}) or vector(0)',

  migIdlePct: |||
    (
      count(DCGM_FI_DEV_FB_USED{GPU_I_ID!=""})
      - (count(DCGM_FI_DEV_FB_USED{GPU_I_ID!="", exported_pod!=""}) or vector(0))
    ) / count(DCGM_FI_DEV_FB_USED{GPU_I_ID!=""}) * 100 or vector(0)
  |||,

  // --- vLLM Inference Capacity (used by vllm_capacity.libsonnet) ---
  // $namespace = Kubernetes namespace of the vLLM pods.
  // $model_name = served AI model (vllm label, not DCGM modelName).
  // DCGM cross-layer queries (avgGrEngineActivePct, avgVramUtil) are reused as-is above.

  // Output tokens generated per second
  vllmGenTokenRate: |||
    sum(
      rate(vllm:generation_tokens{namespace=~"$namespace", model_name=~"$model_name"}[5m])
    )
  |||,

  // Requests currently being decoded
  vllmRequestsRunning:
    'sum(vllm:num_requests_running{namespace=~"$namespace", model_name=~"$model_name"})',

  // Requests waiting in the scheduler queue
  vllmRequestsWaiting:
    'sum(vllm:num_requests_waiting{namespace=~"$namespace", model_name=~"$model_name"})',

  // Total concurrent requests (running + waiting) — single load-pressure signal.
  // Replaces the per-version vllm:num_requests_swapped which is not universally exposed.
  vllmTotalRequests: |||
    sum(vllm:num_requests_running{namespace=~"$namespace", model_name=~"$model_name"})
    + sum(vllm:num_requests_waiting{namespace=~"$namespace", model_name=~"$model_name"})
  |||,

  // GPU KV cache utilization as 0–100% (metric native range is 0–1)
  vllmKvCachePct:
    'avg(vllm:kv_cache_usage_perc{namespace=~"$namespace", model_name=~"$model_name"}) * 100',

  // Prefix cache hit rate — safe division, no-data when prefix caching is disabled.
  vllmPrefixCacheHitRate: |||
    sum(
      rate(vllm:prefix_cache_hits{namespace=~"$namespace", model_name=~"$model_name"}[5m])
    )
    /
    (
      sum(
        rate(vllm:prefix_cache_queries{namespace=~"$namespace", model_name=~"$model_name"}[5m])
      ) > 0
    )
  |||,

  // Generation tokens per second divided by active GPU count.
  // DCGM denominator is cluster-wide — GPU devices carry no Kubernetes namespace label.
  vllmTokensPerGpu: |||
    sum(
      rate(vllm:generation_tokens{namespace=~"$namespace", model_name=~"$model_name"}[5m])
    )
    /
    count(DCGM_FI_DEV_FB_USED > 0)
  |||,
}
