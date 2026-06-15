# Architecture

```mermaid
flowchart TB
    T14["T14 — dev client<br/>git · kubectl-over-SSH"]
    GH["GitHub Actions<br/>buildx (amd64 + arm64)"]
    GHCR["ghcr.io"]

    subgraph LAN["Home LAN · 10.0.0.x"]
        direction TB
        subgraph K3S["k3s cluster"]
            direction LR
            KCP["k-cp · amd64<br/>control plane · 10.0.0.30<br/>Prometheus · Grafana"]
            PI["pi5 · arm64<br/>worker · 10.0.0.200"]
            KCP <-->|flannel VXLAN| PI
        end
        NTPC["nt-pc · RTX 4060 Ti<br/>Ollama LLM · 10.0.0.24:11434"]
    end

    EKS["EKS GPU node · planned<br/>vLLM · spot · ephemeral"]

    T14 -->|git push| GH --> GHCR
    GHCR -->|pull image| KCP
    GHCR -->|pull image| PI
    KCP -->|Service + EndpointSlice| NTPC
    EKS -.->|terraform up → demo → destroy| K3S

    classDef plan stroke-dasharray:5 5,fill:#f6f6f6,color:#666;
    class EKS plan;
```

> Rendered inline by GitHub (diagram-as-code). A static `architecture.png` export can be
> added later, but the Mermaid source is the source of truth.

## Nodes
| Node | Hardware | Arch | Role | Notes |
|---|---|---|---|---|
| **k-cp** | HP EliteDesk 800 G4 Mini — i5-8500T, 32 GB | amd64 | control plane (always-on) | hosts Prometheus/Grafana + all stateful monitoring; 24/7, low-power |
| **pi5** | Raspberry Pi 5, 8 GB | arm64 | worker | the multi-arch story; runs node-exporter + arm64 workloads |
| _(on-prem LLM)_ | Windows host, RTX 4060 Ti, Ollama | amd64 | external service | **not a node** — reused via Service + EndpointSlice → `10.0.0.24:11434`; zero GPU contention |
| _(k-gpu, planned)_ | EKS GPU node group (spot) | amd64 | ephemeral GPU worker | vLLM for the GPU-scheduling demo; spin-up → demo → `teardown` |

## Networking
- Cluster comms on the **LAN `10.0.0.x`** (flannel VXLAN). The GPU/LLM host is LAN-only
  by design, so the cluster is deliberately **not** routed over Tailscale.
- Control plane pinned to a **static `10.0.0.30`** (baked into the API-server cert SANs).

## In-cluster endpoints
| Service | Address | Backed by |
|---|---|---|
| LLM (Ollama) | `ollama.llm.svc.cluster.local:11434` | external GPU host via EndpointSlice |
| Grafana | NodePort `30030` → `http://10.0.0.30:30030` | kube-prometheus-stack |
| Prometheus | `kube-prometheus-stack-prometheus.monitoring:9090` | kube-prometheus-stack |
