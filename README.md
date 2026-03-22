# DCGM Grafonnet

Grafana dashboards-as-code for GPU monitoring, built with [Jsonnet](https://jsonnet.org/) and [Grafonnet](https://github.com/grafana/grafonnet).

Covers NVIDIA DCGM device metrics, vLLM inference monitoring, and Kubernetes workload telemetry.

## Dashboards

| Dashboard | Description | Default Range |
|-----------|-------------|---------------|
| **GPU Capacity Planning** | Node → namespace → workload drill-down: device inventory, health, memory, load | 6h |
| **GPU Utilization Intelligence** | Fleet state, workload character, MIG fragmentation, allocation efficiency, trends | 7d |
| **GPU Weekly Report** | Executive summary: utilization percentiles, workload classification, efficiency scores | 7d |
| **vLLM Monitoring** | Operational metrics for vLLM inference servers: latency, throughput, KV cache, queue | 1h |
| **vLLM Capacity** | Platform → model → pod capacity planning: saturation signals, per-replica detail | 1h |

## Project Structure

```
dashboards/              # Dashboard definitions (.jsonnet)
lib/
├── queries.libsonnet    # DCGM / GPU PromQL queries
├── vllm_queries.libsonnet   # vLLM inference PromQL queries
├── intel_queries.libsonnet  # GPU utilization intelligence queries
├── thresholds.libsonnet     # Reusable threshold configs
└── panels/              # Panel components (28 modules)
output/                  # Compiled Grafana JSON (generated)
scripts/
└── check_dashboards.py  # Validation script
vendor/                  # Grafonnet library (installed via jb)
```

## Prerequisites

- [Go](https://go.dev/) (for installing Jsonnet toolchain)
- [jsonnet](https://github.com/google/go-jsonnet) — compiler
- [jsonnetfmt](https://github.com/google/go-jsonnet) — formatter
- [jsonnet-bundler (jb)](https://github.com/jsonnet-bundler/jsonnet-bundler) — dependency manager
- Python 3 (for validation script)

Install the tools:

```bash
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest
go install github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest
```

Make sure `~/go/bin` is in your `PATH`:

```bash
export PATH="$HOME/go/bin:$PATH"
```

## Getting Started

```bash
# Install Grafonnet library
jb install

# Build all dashboards
make build

# Validate compiled output
make test
```

Compiled JSON files are written to `output/`. Import them into Grafana via **Dashboards → Import → Upload JSON file**.

## Make Targets

| Command | Description |
|---------|-------------|
| `make build` | Compile all dashboards to `output/` |
| `make test` | Build + validate panel layout |
| `make fmt` | Auto-format all Jsonnet files |
| `make lint` | Check formatting (CI-friendly) |
| `make clean` | Remove `output/` directory |

## How It Works

```
dashboards/*.jsonnet       →  Dashboard assembly (variables + panels)
  imports
lib/panels/*.libsonnet     →  Panel components (widgets + layout)
lib/*_queries.libsonnet    →  PromQL query strings
lib/thresholds.libsonnet   →  Color threshold definitions
  imports
vendor/grafonnet/          →  Grafana's official Jsonnet SDK
  compiled by
jsonnet -J vendor          →  Jsonnet compiler
  produces
output/*.json              →  Grafana-importable dashboard JSON
```

## Adding a New Dashboard

1. **Define queries** — add PromQL expressions in `lib/` (or reuse existing ones)
2. **Build panels** — create `lib/panels/your_panels.libsonnet` exporting a `{ panels: [...] }` array
3. **Assemble dashboard** — create `dashboards/your-dashboard.jsonnet` importing panels and defining variables
4. **Add build rule** — add a target in `Makefile` following the existing pattern
5. **Build** — run `make build`

## Metric Sources

- **DCGM Exporter** — NVIDIA GPU device metrics (`DCGM_FI_*`)
- **vLLM** — LLM inference server metrics (`vllm:*`), scraped from port 8000 `/metrics`
- **kube-state-metrics + cAdvisor** — Kubernetes node and pod resource metrics

## Development

VS Code with the [Grafana Jsonnet IDE](https://marketplace.visualstudio.com/items?itemName=Grafana.vscode-jsonnet) extension is recommended for syntax highlighting, formatting, and go-to-definition support.

## License

See repository for license details.
