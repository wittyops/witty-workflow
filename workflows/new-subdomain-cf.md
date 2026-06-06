# Workflow: Add a New Subdomain (Cloudflare Tunnel)

## Why

The wildcard `*.wittycomp.com` DNS CNAME routes all external traffic to the CF tunnel. This makes people assume a new subdomain "just works" once added to DNS. It doesn't.

The tunnel maintains its own hostname routing table. Without an explicit entry, it returns **CF Error 1033** (no route). Even with a route entry, the tunnel connects to Caddy by IP (`172.18.0.100`) and cannot verify Caddy's LE cert against an IP — causing **CF Error 502** unless `noTLSVerify: true` is set.

**All four steps are required for every new `<name>.wittycomp.com`.**

---

## Infrastructure Constants

| Value | Detail |
|-------|--------|
| CF Zone ID | `f2d562fd622786dbb39a7319e8e21d26` |
| CF Tunnel ID | `3e0a5181-c09b-49a6-bf3a-3a33af664e87` |
| Caddy VLAN30 IP | `10.10.30.5` |
| Caddy bridge IP (tunnel target) | `172.18.0.100` |
| CF edge IP (for --resolve tests) | `172.67.205.110` |
| Technitium DNS | `10.10.10.10:53443` |

---

## Step 1 — Technitium (LAN hairpin A record)

Without this, internal clients route through the CF tunnel instead of going directly to Caddy.

```bash
# Re-authenticate each session (token expires):
TOKEN=$(curl -s "http://10.10.10.10:53443/api/user/login?user=admin&pass=7403B3ars\!" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

curl -s "http://10.10.10.10:53443/api/zones/records/add?\
token=$TOKEN&zone=wittycomp.com&domain=<name>.wittycomp.com\
&type=A&ipAddress=10.10.30.5&ttl=3600"
```

The stored token in Vaultwarden (`Technitium DNS - API Token`) expires between sessions. Always re-login rather than relying on the stored value.

---

## Step 2 — Cloudflare DNS CNAME (external, proxied)

The wildcard already covers new names, but an explicit record is preferred to avoid edge cases where CF doesn't pick up the wildcard for new hostnames immediately.

```bash
CF_TOKEN=$(# from Vaultwarden: "Cloudflare - API Token")

curl -s -X POST \
  "https://api.cloudflare.com/client/v4/zones/f2d562fd622786dbb39a7319e8e21d26/dns_records" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CNAME",
    "name": "<name>",
    "content": "3e0a5181-c09b-49a6-bf3a-3a33af664e87.cfargotunnel.com",
    "proxied": true
  }'
```

If you get error **81053** (record already exists), the wildcard or a prior session already created it — check that it points to the correct tunnel ID and skip this step.

---

## Step 3 — Cloudflare Tunnel Ingress Rule

**This is the step most often missed.** Must be inserted BEFORE the catch-all `{"hostname":"*"}` entry.

```bash
# Get current ingress config first:
curl -s "https://api.cloudflare.com/client/v4/accounts/<account_id>/cfd_tunnel/3e0a5181-c09b-49a6-bf3a-3a33af664e87/configurations" \
  -H "Authorization: Bearer $CF_TOKEN" | python3 -m json.tool

# Then PUT the full updated ingress list (insert new rule before catch-all):
# {
#   "hostname": "<name>.wittycomp.com",
#   "service": "https://172.18.0.100:443",
#   "originRequest": {
#     "noTLSVerify": true,
#     "originServerName": "<name>.wittycomp.com"
#   }
# }
```

The automated script [scripts/cf-add-subdomain.sh](../scripts/cf-add-subdomain.sh) handles the GET→insert→PUT flow.

### Why `noTLSVerify: true` is required

The tunnel connects from cloudflared (inside `wn-tunnel-01` container on the `witty_network` bridge) to Caddy at `172.18.0.100:443`. Caddy's TLS cert is issued for `*.wittycomp.com` — a hostname, not an IP. TLS verification against an IP fails. `noTLSVerify: true` skips origin cert verification while keeping the public → CF → tunnel path encrypted end-to-end.

`originServerName` is set so Caddy's SNI-based routing picks the correct vhost.

---

## Step 4 — Caddyfile Block

```caddy
<name>.wittycomp.com {
    import cloudflare_tls
    reverse_proxy <backend-ip>:<port>
}
```

Sync and reload — see [workflows/new-service.md](new-service.md#step-3--add-caddy-vhost) for the exact commands.

---

## Verification

```bash
# Internal (LAN path — direct to Caddy, no CF):
curl -sk --resolve "<name>.wittycomp.com:443:10.10.30.5" \
  -o /dev/null -w "%{http_code}" "https://<name>.wittycomp.com/"

# External (CF tunnel path):
curl -sk --resolve "<name>.wittycomp.com:443:172.67.205.110" \
  -o /dev/null -w "%{http_code}" "https://<name>.wittycomp.com/"
```

Both should return `200` (or `401` for protected services).

---

## Automated Script

See [scripts/cf-add-subdomain.sh](../scripts/cf-add-subdomain.sh) which handles steps 1–3 in a single run given a subdomain name.
