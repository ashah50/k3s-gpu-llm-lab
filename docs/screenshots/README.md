# Grafana screenshots

Drop PNGs here to populate the README "Observability" section. Filenames must match:

| File | What to capture (Grafana → `http://10.0.0.30:30030`) |
|---|---|
| `cluster-health.png` | Dashboard **Kubernetes / Compute Resources / Cluster** — the top CPU/memory overview |
| `nodes.png` | Dashboard **Node Exporter / Nodes** — switch the `instance` to show both `k-cp` and `pi5` (the arm64 + amd64 story) |
| `llm-probe.png` | Dashboard **7587 (Blackbox Exporter)** — the Ollama target's probe status + duration panels |

Tips: dark theme, trim to the useful panels, ~1600px wide. These + the architecture
diagram are what sell the repo — worth a few minutes of framing.
