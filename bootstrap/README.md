# Bootstrap

How the cluster is stood up. Networking stays on the **LAN (10.0.0.x)** — the on-prem
GPU/LLM host is LAN-only by design, so the cluster is **not** routed over Tailscale.

## 1. Control plane — `k-cp` (amd64)
```bash
export KCP_IP=10.0.0.30
curl -sfL https://get.k3s.io | sh -s - server \
  --node-ip="$KCP_IP" \
  --tls-san="$KCP_IP" --tls-san=k-cp \
  --write-kubeconfig-mode=0644

# kubeconfig + node token
mkdir -p ~/.kube && sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config && sudo chown "$USER:$USER" ~/.kube/config
sudo cat /var/lib/rancher/k3s/server/node-token
```
`--tls-san` bakes the LAN IP + hostname into the API cert (so other hosts can reach it
without cert errors); `--node-ip` pins the advertised address.

## 2. Worker — `pi5` (arm64)
Run **on the Pi** with the control-plane IP + node token:
```bash
curl -sfL https://get.k3s.io | \
  K3S_URL="https://10.0.0.30:6443" K3S_TOKEN="<node-token>" \
  sh -s - agent --node-ip=10.0.0.200
```

## 3. Verify
```bash
kubectl get nodes -o wide
# k-cp  Ready  control-plane  amd64
# pi5   Ready  worker         arm64   <- multi-arch
```
k3s auto-labels `kubernetes.io/arch`, so `nodeSelector` arch-pinning works out of the box.

## Notes / gotchas
- **No host firewall** on either node, so k3s ports (6443, 8472/udp flannel, 10250) are open node-to-node.
- The control-plane host should **never sleep**: `sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`.
- `--node-ip` + a **fixed IP** on the control plane matter — the value is baked into the API cert; changing it later means re-clustering.
