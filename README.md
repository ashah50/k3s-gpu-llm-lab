# k3s-gpu-llm-lab

> Multi-arch (ARM + x86) k3s cluster with a local LLM served in-cluster, full
> Prometheus/Grafana observability, GitOps CI/CD, and Terraform-managed EKS parity.

A *production-shaped* home cluster — not a tutorial follow-along. Real hardware, real
constraints (a LAN-only GPU host, a mixed arm64/amd64 node pool), and the design
decisions that came with them.

![CI](https://github.com/ashah50/k3s-gpu-llm-lab/actions/workflows/build.yml/badge.svg)

## What this demonstrates
- **Multi-arch bootstrap** — k3s control plane (amd64) + a Raspberry Pi worker (arm64), one cluster
- **LLM serving on Kubernetes** — a self-hosted model exposed in-cluster, with availability/latency monitoring
- **Observability** — kube-prometheus-stack: cluster, per-node, and LLM-endpoint dashboards
- **GitOps CI/CD** — GitHub Actions `buildx` multi-arch images → ghcr.io
- **Cloud parity (planned)** — the same workloads on EKS via Terraform, `terraform destroy` after each demo

## Architecture
| Node | Hardware | Arch | Role |
|---|---|---|---|
| **k-cp** | HP EliteDesk 800 G4 Mini (i5-8500T, 32 GB) | amd64 | control plane (always-on) |
| **pi5** | Raspberry Pi 5 (8 GB) | arm64 | worker — the multi-arch story |
| _(on-prem LLM)_ | Windows host w/ RTX 4060 Ti, Ollama | amd64 | external service (not a node) — reused via Service + EndpointSlice |
| _(k-gpu, planned)_ | EKS GPU node group (spot) | amd64 | ephemeral GPU worker — vLLM, spin-up→demo→teardown |

Cluster networking is on the **LAN** (the GPU/LLM host is LAN-only by design — *not* routed over Tailscale).

## Repo layout
```
bootstrap/    k3s control-plane + worker join (how the cluster is stood up)
apps/         workloads — ollama/ (LLM Service), hello-arch/ (multi-arch sample + CI)
monitoring/   kube-prometheus-stack values, blackbox LLM probe
docs/         architecture diagram + notes
Makefile      one-command operations (drives the cluster over SSH)
```

## Quick start
```bash
make nodes          # show the cluster
make deploy-llm     # Ollama Service + EndpointSlice (in-cluster LLM endpoint)
make deploy-app     # multi-arch hello app (runs on both arm64 + amd64)
make probe-up       # blackbox LLM availability/latency probe
make status         # what's running
```
(`make` targets drive the cluster from this dev box via SSH to the control plane — see the `Makefile`.)

## Status
- ✅ **Phase 1** — multi-arch bootstrap (k-cp amd64 + pi5 arm64), cross-arch scheduling verified
- ✅ **Phase 2** — on-prem LLM serving (Ollama via `ollama.llm.svc:11434`), in-cluster inference verified
- ✅ **Phase 3** — observability (kube-prometheus-stack; LLM up/latency via blackbox)
- 🟡 **Phase 4** — GitOps CI/CD (multi-arch buildx → ghcr.io) ← *in progress*
- ⏳ **Phase 5** — EKS parity (Terraform) · **Phase 6** — deploy a real app workload

## Design decisions & trade-offs
- **k3s, not kubeadm** — single small control plane; lightweight, production-shaped for the edge. (kubeadm built once in a throwaway VM to learn the real bootstrap.)
- **Reuse an existing on-prem GPU as an external Service** rather than carving it into a cluster node — the GPU host already runs another live workload, so a no-selector Service + manual EndpointSlice points at it with zero GPU contention. (Can't `ExternalName` to a bare IP → Service + EndpointSlice.)
- **LAN, not Tailscale, for cluster comms** — the GPU/LLM host is LAN-only by design.
- **Multi-arch images via `buildx`** (arm64 + amd64) so workloads schedule on any node, incl. the Pi.

## License
MIT
