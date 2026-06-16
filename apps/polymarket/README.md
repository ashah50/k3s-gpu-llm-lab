# apps/polymarket

Polymarket read-only API stack deployed on k3s — a frozen, sanitized snapshot of Polymarket market and trade data served behind basic-auth on a LAN-scoped endpoint.

---

## Architecture

- **Namespace:** `polymarket` (isolated from default workloads)
- **Postgres 16** — StatefulSet + PVC (`data-postgres-0`), pinned to `amd64` (T14/control-plane node). Seeded out-of-band from a sanitized private dump; never receives live traffic.
- **API Deployment** — 2 replicas, multi-arch (`amd64` + `arm64`/Pi5), image from GHCR (`ghcr.io/ashah50/polymarket-api`). Exposes `/healthz` and the read endpoints listed below.
- **Traefik Ingress + BasicAuth** — host `polymarket.k3s.local`; basic-auth Middleware enforced at the ingress layer (user: `demo`).
- **NetworkPolicy** — Postgres only accepts traffic from the `api` pods within the namespace; no external ingress to Postgres.
- **Sealed Secrets** — all credentials (GHCR pull secret, Postgres creds, basic-auth htpasswd) are committed as `*.sealed.yaml` (Bitnami SealedSecret, encrypted with the cluster's public key — safe to publish). Plaintext secrets never enter the repo.

---

## Deploy

Apply in order. All commands stream the manifest via SSH to the control-plane node (`10.0.0.30`).

```bash
# 1. Namespace
ssh ashah@10.0.0.30 'kubectl apply -f -' < namespace.yaml

# 2. Sealed Secrets (credentials — decrypted in-cluster by the SealedSecrets controller)
ssh ashah@10.0.0.30 'kubectl apply -f -' < sealed/db.sealed.yaml
ssh ashah@10.0.0.30 'kubectl apply -f -' < sealed/ghcr.sealed.yaml
ssh ashah@10.0.0.30 'kubectl apply -f -' < sealed/basicauth.sealed.yaml

# 3. Postgres StatefulSet + PVC
ssh ashah@10.0.0.30 'kubectl apply -f -' < postgres.yaml

# 4. Seed database (out-of-band — see "Data" section below)
#    kubectl -n polymarket exec -i postgres-0 -- psql -U polymarket polymarket < /path/to/seed.sql

# 5. API Deployment
ssh ashah@10.0.0.30 'kubectl apply -f -' < api.yaml

# 6. Ingress
ssh ashah@10.0.0.30 'kubectl apply -f -' < ingress.yaml

# 7. NetworkPolicy
ssh ashah@10.0.0.30 'kubectl apply -f -' < networkpolicy.yaml
```

The `db-seed.job.yaml` is a reference manifest documenting ordering and idempotency behaviour; it is not part of the normal deploy sequence.

---

## Secrets (Sealed Secrets)

The three secrets were generated locally and sealed offline:

```bash
kubectl create secret ... --dry-run=client -o yaml \
  | kubeseal --cert <cluster-pub-cert> -o yaml > sealed/<name>.sealed.yaml
```

The resulting `*.sealed.yaml` files are ciphertext tied to this cluster's SealedSecrets controller key pair. They are safe to commit to a public repo. The underlying plaintext is never stored here.

---

## Data

The Postgres instance is seeded from a **sanitized subset** of a private Polymarket database produced by `ops/make_seed_dump.sh` in the private polymarket repo. The seed file (`seed.sql`) is streamed directly into `postgres-0` via `kubectl exec` and **never enters any repo** (public or private).

**Sanitization applied:**

- Wallet addresses are replaced with a salted hash (random per-run salt, discarded after the run — not recomputable from public wallet lists).
- `trades.tx_hash` is dropped (set to NULL) — no real on-chain transaction identifier is included.
- `traded_at` timestamps are jittered.

The served data is a frozen, static snapshot. It is scoped to the local network and gated behind basic-auth.

---

## Access

Add the following line to `/etc/hosts` on any machine that needs browser/curl access (requires sudo):

```
10.0.0.30  polymarket.k3s.local
```

Example request:

```bash
curl -u demo:<pass> -H 'Host: polymarket.k3s.local' http://10.0.0.30/stats
```

Replace `<pass>` with the value from the `basicauth` secret.

---

## Working Endpoints

| Endpoint | Description |
|---|---|
| `/healthz` | Liveness probe — returns `200 OK` |
| `/stats` | Aggregate market statistics |
| `/markets` | Market listing |
| `/wallet/{address}` | Wallet summary for a (hashed) address |
| `/wallet/{address}/trades` | Trade history for a (hashed) address |
| `/copy-clusters` | Copy-cluster groupings |

> **Note:** `/leaderboard` and `/confluence` are deprecated in the app and return a structured removal notice (deprecated 2026-05-03). Use `/stats` and `/markets` instead.
