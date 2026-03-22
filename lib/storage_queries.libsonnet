// ============================================================================
// Storage PromQL Queries
// ============================================================================
//
// Storage monitoring queries for the GPU Capacity Planning dashboard.
// Covers three storage layers:
//
//   Layer 1 — Node Storage     (local disk of each Kubernetes node)
//   Layer 2 — PV/PVC Storage   (persistent volumes claimed by pods)
//   Layer 3 — Trident / NetApp (backend storage capacity from NetApp ONTAP)
//
// Exporters required:
//   - Node Storage:  node-exporter          (node_filesystem_*)
//   - PV/PVC:        kubelet built-in       (kubelet_volume_stats_*)
//   - Trident:       Trident CSI metrics    (trident_backend_*, trident_volume_*)
//
// Dashboard variables used:
//   $datasource  — Prometheus datasource
//   $hostname    — Kubernetes node name (filters node storage)
//   $namespace   — Kubernetes namespace  (filters PV/PVC)
//
// ============================================================================
{
  // --------------------------------------------------------------------------
  // Section 1: Node Storage (node-exporter)
  //
  // Local disk of each Kubernetes node. If disk fills up the node enters
  // DiskPressure and kubelet starts evicting pods — including GPU workloads.
  //
  // Common causes of fill-up on GPU nodes:
  //   - Large container images (LLM model layers can be 20-80 GB each)
  //   - Ephemeral storage (pod logs, temp files)
  //   - Container runtime (containerd snapshots, image layers)
  //
  // Metric source: node-exporter
  // Filtered by: $hostname (matched against the "instance" label)
  // --------------------------------------------------------------------------

  // Average disk utilization across selected nodes (percentage)
  nodeStorageUtilPct: |||
    100 - (
      node_filesystem_avail_bytes{mountpoint="/", fstype!="tmpfs", instance=~"$hostname"}
      / node_filesystem_size_bytes{mountpoint="/", fstype!="tmpfs", instance=~"$hostname"}
      * 100
    )
  |||,

  // Total disk capacity per node (GB)
  nodeStorageTotalGB: |||
    node_filesystem_size_bytes{mountpoint="/", fstype!="tmpfs", instance=~"$hostname"}
    / (1024 * 1024 * 1024)
  |||,

  // Disk used per node (GB)
  nodeStorageUsedGB: |||
    (
      node_filesystem_size_bytes{mountpoint="/", fstype!="tmpfs", instance=~"$hostname"}
      - node_filesystem_avail_bytes{mountpoint="/", fstype!="tmpfs", instance=~"$hostname"}
    ) / (1024 * 1024 * 1024)
  |||,

  // Average disk utilization across all selected nodes (single value for stat panel)
  nodeStorageAvgUtilPct: |||
    avg(
      100 - (
        node_filesystem_avail_bytes{mountpoint="/", fstype!="tmpfs", instance=~"$hostname"}
        / node_filesystem_size_bytes{mountpoint="/", fstype!="tmpfs", instance=~"$hostname"}
        * 100
      )
    )
  |||,

  // --------------------------------------------------------------------------
  // Section 2: PV/PVC Storage (kubelet)
  //
  // Persistent Volume Claims — virtual disks attached to pods.
  // GPU workloads use PVCs for: model weights, KV cache swap, training
  // checkpoints, datasets, and inference output logs.
  //
  // When a PVC fills up the pod gets I/O errors or crashes.
  //
  // Metric source: kubelet (built-in, no extra exporter needed)
  // Filtered by: $namespace
  // Labels available: namespace, persistentvolumeclaim
  // --------------------------------------------------------------------------

  // PVC utilization percentage (per PVC)
  pvcUtilPct: |||
    kubelet_volume_stats_used_bytes{namespace=~"$namespace"}
    / kubelet_volume_stats_capacity_bytes{namespace=~"$namespace"}
    * 100
  |||,

  // PVC used bytes (per PVC, for timeseries)
  pvcUsedBytes: |||
    kubelet_volume_stats_used_bytes{namespace=~"$namespace"}
  |||,

  // PVC capacity bytes (per PVC)
  pvcCapacityBytes: |||
    kubelet_volume_stats_capacity_bytes{namespace=~"$namespace"}
  |||,

  // Total PVC count across selected namespaces
  pvcCount:
    'count(kubelet_volume_stats_capacity_bytes{namespace=~"$namespace"}) or vector(0)',

  // PVCs with utilization above 80% (warning threshold)
  pvcCriticalCount: |||
    count(
      kubelet_volume_stats_used_bytes{namespace=~"$namespace"}
      / kubelet_volume_stats_capacity_bytes{namespace=~"$namespace"}
      > 0.80
    ) or vector(0)
  |||,

  // Table queries — instant snapshots for the PVC detail table
  // A: Used % per PVC
  pvcTableUtilPct: |||
    kubelet_volume_stats_used_bytes{namespace=~"$namespace"}
    / kubelet_volume_stats_capacity_bytes{namespace=~"$namespace"}
    * 100
  |||,

  // B: Used bytes per PVC (for table column)
  pvcTableUsed: |||
    kubelet_volume_stats_used_bytes{namespace=~"$namespace"}
  |||,

  // C: Capacity bytes per PVC (for table column)
  pvcTableCapacity: |||
    kubelet_volume_stats_capacity_bytes{namespace=~"$namespace"}
  |||,

  // --------------------------------------------------------------------------
  // Section 3: Trident / NetApp Backend
  //
  // NetApp Trident is a CSI driver that provisions PVs from NetApp storage
  // systems (ONTAP, SolidFire, E-Series). These metrics show the backend
  // capacity — the physical storage pool behind all PVCs.
  //
  // Unlike PVC metrics (per-consumer view), Trident backend metrics show
  // the provider view: how much total capacity remains before new PVCs
  // can no longer be provisioned.
  //
  // No namespace filter — backends are cluster-wide resources.
  //
  // Metric source: Trident CSI metrics exporter (port 8001)
  // Requires: ServiceMonitor targeting trident-controller
  // Labels available: backend_name, backend_type (ontap-nas, ontap-san, etc.)
  // --------------------------------------------------------------------------

  // Backend utilization percentage (per backend)
  tridentBackendUtilPct: |||
    trident_backend_used_bytes
    / trident_backend_total_bytes
    * 100
  |||,

  // Average backend utilization across all backends (single value for stat panel)
  tridentBackendAvgUtilPct: |||
    avg(
      trident_backend_used_bytes
      / trident_backend_total_bytes
      * 100
    )
  |||,

  // Backend total capacity in GB (per backend)
  tridentBackendTotalGB: |||
    trident_backend_total_bytes / (1024 * 1024 * 1024)
  |||,

  // Backend used capacity in GB (per backend)
  tridentBackendUsedGB: |||
    trident_backend_used_bytes / (1024 * 1024 * 1024)
  |||,

  // Total Trident volume count
  tridentVolumeCount:
    'trident_volume_count or vector(0)',
}
