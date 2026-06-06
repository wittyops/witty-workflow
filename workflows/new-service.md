# Workflow: Add a New Service

## Why

Every new service in the lab follows a predictable pattern: VLAN30 IP → compose file → Caddy vhost → DNS → CF tunnel. Skipping any step causes either silent LAN-only access or CF 1033/502 errors. This checklist exists because those errors are hard to diagnose from scratch.

## Prerequisites

- Vaultwarden unlocked (`cat ~/.bw_session` non-empty)
- SERVICES.md open to check IP/port collisions: [wittycomp-lab/SERVICES.md](http://git.wittycomp.com/bearboss/wittycomp-lab/src/branch/main/SERVICES.md)
- Caddy admin API reachable: `curl http://10.10.30.5:2019/config/`

---

## Step 1 — Allocate an IP

Check [reference/ip-allocation.md](../reference/ip-allocation.md) for the next free `.30.x` address.
Also run:

```bash
grep -E '10\.10\.30\.' /home/bearboss/wittycomp-lab/SERVICES.md | grep -oP '10\.10\.30\.\d+' | sort -V | tail -5
```

Pick the next unused address. Add it to [SERVICES.md](http://git.wittycomp.com/bearboss/wittycomp-lab/src/branch/main/SERVICES.md) in the same commit as the compose file.

---

## Step 2 — Create Compose File

Location: `/data/witty-lab-data/apps/wn-<name>-01/compose.yaml`

Minimum template:

```yaml
services:
  <name>:
    image: <image>:<tag>
    container_name: wn-<name>-01
    networks:
      witty_vlan30:
        ipv4_address: ${APP_IP}
    restart: unless-stopped

networks:
  witty_vlan30:
    external: true
```

`.env` file alongside compose:

```
APP_IP=10.10.30.<N>
```

> **CRITICAL**: macvlan containers on the same host **cannot** reach each other via VLAN30 IPs.
> Use container hostnames (e.g., `wn-vault-01`) or host shim `10.10.30.250:<port>` for inter-container calls.

Start the container:

```bash
cd /data/witty-lab-data/apps/wn-<name>-01
docker compose up -d
docker compose logs -f --tail=20
```

---

## Step 3 — Add Caddy Vhost

Edit [apps/caddy/Caddyfile](http://git.wittycomp.com/bearboss/wittycomp-lab/src/branch/main/apps/caddy/Caddyfile):

```caddy
<name>.wittycomp.com {
    import cloudflare_tls
    reverse_proxy 10.10.30.<N>:<port>
}
```

Sync to container and reload (both copies must stay in sync):

```bash
docker exec -i wn-caddy-01 tee /etc/caddy/Caddyfile < /home/bearboss/wittycomp-lab/apps/caddy/Caddyfile > /dev/null
docker exec wn-caddy-01 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile --address localhost:2019
```

---

## Step 4 — Technitium DNS (LAN hairpin)

Adds the A record so internal clients resolve directly to Caddy instead of routing through CF.

```bash
# Token from vault if needed:
TOKEN=$(curl -s "http://10.10.10.10:53443/api/user/login?user=admin&pass=7403B3ars\!" | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

curl -s "http://10.10.10.10:53443/api/zones/records/add?token=$TOKEN&zone=wittycomp.com&domain=<name>.wittycomp.com&type=A&ipAddress=10.10.30.5&ttl=3600"
```

See [reference/secret-sources.md](../reference/secret-sources.md) for the stored token.

---

## Step 5 — Cloudflare DNS + Tunnel Ingress

**This is a 2-part step. Both are required. See [workflows/new-subdomain-cf.md](new-subdomain-cf.md) for the full explanation.**

### 5a. CF DNS CNAME

Via CF API (or Cloudflare MCP):

```bash
# Zone ID: f2d562fd622786dbb39a7319e8e21d26
# Tunnel ID: 3e0a5181-c09b-49a6-bf3a-3a33af664e87
CF_TOKEN=$(# get from Vaultwarden "Cloudflare - API Token")

curl -s -X POST "https://api.cloudflare.com/client/v4/zones/f2d562fd622786dbb39a7319e8e21d26/dns_records" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"CNAME","name":"<name>","content":"3e0a5181-c09b-49a6-bf3a-3a33af664e87.cfargotunnel.com","proxied":true}'
```

### 5b. Tunnel Ingress Rule

Insert BEFORE the catch-all entry. Must include `noTLSVerify: true`.

See the automated script: [scripts/cf-add-subdomain.sh](../scripts/cf-add-subdomain.sh)

---

## Step 6 — Verify

```bash
# LAN path (via Technitium → Caddy direct):
curl -sk --resolve "<name>.wittycomp.com:443:10.10.30.5" -o /dev/null -w "%{http_code}" "https://<name>.wittycomp.com/"

# CF tunnel path (external):
curl -sk --resolve "<name>.wittycomp.com:443:172.67.205.110" -o /dev/null -w "%{http_code}" "https://<name>.wittycomp.com/"
```

Both should return `200` (or `401` for auth-protected services — that's correct).

---

## Step 7 — Commit

```bash
cd /home/bearboss/wittycomp-lab
git add apps/caddy/Caddyfile SERVICES.md
git commit -m "feat(<name>): deploy wn-<name>-01 at <name>.wittycomp.com"
```

Commit must include **both** the Caddyfile update and SERVICES.md update.

---

## Checklist

- [ ] IP allocated, no collision with SERVICES.md
- [ ] Compose + .env created, container running
- [ ] Caddy vhost added, synced, reloaded
- [ ] Technitium A record added
- [ ] CF DNS CNAME added (proxied)
- [ ] CF tunnel ingress rule added (noTLSVerify: true)
- [ ] LAN curl → 200/401
- [ ] CF path curl → 200/401
- [ ] SERVICES.md updated
- [ ] git commit (Caddyfile + SERVICES.md in same commit)
