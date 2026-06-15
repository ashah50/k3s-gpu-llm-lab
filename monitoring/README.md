# Monitoring

`kube-prometheus-stack` (Prometheus + Grafana + Alertmanager + node-exporter +
kube-state-metrics), with the heavy/stateful components pinned to the amd64 control
plane so the 8 GB Pi stays light. node-exporter runs as a DaemonSet → per-node metrics
on **both** arches.

## Install
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f values.yaml
```
`values.yaml` highlights: `nodeSelector: kubernetes.io/arch=amd64` on Prometheus/Grafana/
Alertmanager/kube-state-metrics/operator; Prometheus 15d retention on a 20 Gi `local-path`
PVC; Grafana on **NodePort 30030**.

## Grafana
- URL: `http://10.0.0.30:30030` · user `admin`
- Password (source of truth is the secret, not the UI — no Grafana PVC, so UI changes don't persist):
  ```bash
  kubectl -n monitoring get secret kube-prometheus-stack-grafana \
    -o jsonpath='{.data.admin-password}' | base64 -d; echo
  ```
- Dashboards: dozens built-in (cluster / per-node / k8s). For the LLM endpoint, import
  dashboard **7587** (Blackbox Exporter). *TODO:* codify dashboards as `grafana_dashboard`
  ConfigMaps so they survive restarts.

## LLM endpoint probe (blackbox)
`blackbox-probe.yaml` is a prometheus-operator `Probe` that has blackbox-exporter hit the
in-cluster Ollama Service (`/api/version`). It yields:
- `probe_success` — endpoint up/down
- `probe_duration_seconds` — response latency

```bash
helm install blackbox-exporter prometheus-community/prometheus-blackbox-exporter -n monitoring
kubectl apply -f blackbox-probe.yaml
```

> Full LLM **throughput** (tokens/s) + **GPU util/VRAM** need vLLM's native metrics + a
> DCGM exporter on a GPU node — those come with the EKS/vLLM track, not the on-prem reuse.
