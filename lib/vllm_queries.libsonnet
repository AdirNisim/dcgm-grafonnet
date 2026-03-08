// PromQL queries for vLLM monitoring dashboard.
// Compatible with vLLM v0.10.x – v0.15.x. All metrics use the vllm: prefix.
// Primary selectors: namespace, model_name (per-deployment), pod (per-replica).
// Histogram metrics: _bucket suffix for quantile_over_time / histogram_quantile patterns.
// Note: gpu_cache_hit_rate, request_queue_time_seconds added in v0.14+; absent on older builds.
{
  // --- Service health KPIs ---

  // Requests currently being decoded (active inference)
  requestsRunning:
    'sum(vllm:num_requests_running{namespace="$namespace", model_name=~"$model_name"})',

  // Requests waiting in scheduler queue
  requestsWaiting:
    'sum(vllm:num_requests_waiting{namespace="$namespace", model_name=~"$model_name"})',

  // Requests swapped to CPU KV cache (memory pressure signal)
  requestsSwapped:
    'sum(vllm:num_requests_swapped{namespace="$namespace", model_name=~"$model_name"})',

  // Request throughput — finished requests per second
  requestThroughput: |||
    sum(
      rate(vllm:request_success_total{namespace="$namespace", model_name=~"$model_name"}[5m])
    )
  |||,

  // Token generation rate — output tokens per second
  tokenGenRate: |||
    sum(
      rate(vllm:generation_tokens_total{namespace="$namespace", model_name=~"$model_name"}[5m])
    )
  |||,

  // Total tokens per second (prompt + generation)
  totalTokenRate: |||
    sum(
      rate(vllm:prompt_tokens_total{namespace="$namespace", model_name=~"$model_name"}[5m])
      + rate(vllm:generation_tokens_total{namespace="$namespace", model_name=~"$model_name"}[5m])
    )
  |||,

  // TTFT P99 — snapshot for KPI stat
  ttftP99Snapshot: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:time_to_first_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  // --- KV cache ---

  // GPU KV cache utilization (0–1, 1 = full)
  gpuCacheUsage:
    'avg(vllm:gpu_cache_usage_perc{namespace="$namespace", model_name=~"$model_name"})',

  // CPU KV cache utilization (0–1; only valid when CPU offload is enabled)
  cpuCacheUsage:
    'avg(vllm:cpu_cache_usage_perc{namespace="$namespace", model_name=~"$model_name"})',

  // Prefix cache hit rate (v0.14+; absent on older builds — panel shows no data gracefully)
  cacheHitRate:
    'avg(vllm:gpu_cache_hit_rate{namespace="$namespace", model_name=~"$model_name"})',

  // GPU cache over time — per pod for replica comparison
  gpuCacheOverTime: |||
    vllm:gpu_cache_usage_perc{namespace="$namespace", model_name=~"$model_name", pod=~"$pod"}
  |||,

  // CPU cache over time
  cpuCacheOverTime: |||
    vllm:cpu_cache_usage_perc{namespace="$namespace", model_name=~"$model_name", pod=~"$pod"}
  |||,

  // --- Request latency (histogram_quantile over rate) ---

  // Time to First Token — P50 / P95 / P99 snapshot stats
  ttftP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:time_to_first_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  ttftP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:time_to_first_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  ttftP99: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:time_to_first_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  // Time per Output Token — P50 / P95 / P99 snapshot stats
  tpotP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:time_per_output_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  tpotP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:time_per_output_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  tpotP99: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:time_per_output_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  // End-to-end request duration — P50 / P95 / P99 snapshot stats
  e2eP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:request_duration_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  e2eP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:request_duration_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  e2eP99: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:request_duration_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le)
    )
  |||,

  // TTFT over time — multiple quantiles for timeseries panel
  ttftP50OverTime: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:time_to_first_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  ttftP95OverTime: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:time_to_first_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  ttftP99OverTime: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:time_to_first_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  // E2E latency over time — multiple quantiles
  e2eP50OverTime: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:request_duration_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  e2eP95OverTime: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:request_duration_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  e2eP99OverTime: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:request_duration_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  // TPOT over time — per model_name
  tpotP50OverTime: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:time_per_output_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  tpotP99OverTime: |||
    histogram_quantile(0.99,
      sum(
        rate(vllm:time_per_output_token_seconds_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  // --- Token throughput ---

  // Prompt tokens per second over time — per model
  promptTokenRateOverTime: |||
    sum by (model_name) (
      rate(vllm:prompt_tokens_total{namespace="$namespace", model_name=~"$model_name"}[5m])
    )
  |||,

  // Generation tokens per second over time — per model
  genTokenRateOverTime: |||
    sum by (model_name) (
      rate(vllm:generation_tokens_total{namespace="$namespace", model_name=~"$model_name"}[5m])
    )
  |||,

  // Request throughput over time — per model
  requestThroughputOverTime: |||
    sum by (model_name) (
      rate(vllm:request_success_total{namespace="$namespace", model_name=~"$model_name"}[5m])
    )
  |||,

  // Prompt length distribution — P50 / P95 over time
  promptLenP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:request_prompt_tokens_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  promptLenP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:request_prompt_tokens_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  // Output length distribution — P50 / P95 over time
  outputLenP50: |||
    histogram_quantile(0.50,
      sum(
        rate(vllm:request_generation_tokens_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  outputLenP95: |||
    histogram_quantile(0.95,
      sum(
        rate(vllm:request_generation_tokens_bucket{
          namespace="$namespace", model_name=~"$model_name"
        }[5m])
      ) by (le, model_name)
    )
  |||,

  // --- Queue & scheduler ---

  // Queue depth over time — running + waiting + swapped per model
  queueRunningOverTime: |||
    sum by (model_name) (
      vllm:num_requests_running{namespace="$namespace", model_name=~"$model_name"}
    )
  |||,

  queueWaitingOverTime: |||
    sum by (model_name) (
      vllm:num_requests_waiting{namespace="$namespace", model_name=~"$model_name"}
    )
  |||,

  queueSwappedOverTime: |||
    sum by (model_name) (
      vllm:num_requests_swapped{namespace="$namespace", model_name=~"$model_name"}
    )
  |||,

  // Preemption rate (events per second)
  preemptionRate: |||
    sum by (model_name) (
      rate(vllm:num_preemptions_total{namespace="$namespace", model_name=~"$model_name"}[5m])
    )
  |||,

  // Request finish reason breakdown — per model, per finish_reason label
  finishReasonRate: |||
    sum by (model_name, finished_reason) (
      rate(vllm:request_success_total{namespace="$namespace", model_name=~"$model_name"}[5m])
    )
  |||,

  // Per-pod running requests — for replica-level view
  runningByPod: |||
    vllm:num_requests_running{namespace="$namespace", model_name=~"$model_name", pod=~"$pod"}
  |||,

  waitingByPod: |||
    vllm:num_requests_waiting{namespace="$namespace", model_name=~"$model_name", pod=~"$pod"}
  |||,
}
