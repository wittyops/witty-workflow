# Workflow: Obsidian LiveSync Setup

## Why

Obsidian is the primary second-brain and note-taking tool for the Wittycomp Lab. The [obsidian-livesync](https://github.com/vrtmrz/obsidian-livesync) plugin replaces Obsidian Sync ($10/mo) with a self-hosted CouchDB backend, enabling vault sync across desktop, Android, and iOS with end-to-end encryption.

The backend is `wn-obsidian-01` running CouchDB 3.5.2 at `10.10.30.41:5984`, exposed via Caddy at `https://brain.wittycomp.com`.

---

## Infrastructure

| Component | Detail |
|-----------|--------|
| CouchDB container | `wn-obsidian-01` at `10.10.30.41:5984` |
| External URL | `https://brain.wittycomp.com` |
| Alias | `https://obsidian.wittycomp.com` → redirects to brain |
| Database name | `obsidian-livesync` |
| Compose file | [wittycomp-lab/apps/wn-obsidian-01/](http://git.wittycomp.com/bearboss/wittycomp-lab/src/branch/main/apps/wn-obsidian-01/) |
| CouchDB credentials | Vaultwarden: "wn-obsidian-01 CouchDB" |

---

## One-Time Server Setup (already done)

These steps were completed during the 2026-06-06 session — documented here for recovery purposes.

### CouchDB configuration

```bash
# Enable single-node mode
curl -s -X PUT http://admin:<pass>@10.10.30.41:5984/_node/_local/_config/couchdb/single_node -d '"true"'

# Require auth for all requests
curl -s -X PUT http://admin:<pass>@10.10.30.41:5984/_node/_local/_config/chttpd/require_valid_user -d '"true"'

# CORS — required for browser-based Obsidian plugin
curl -s -X PUT http://admin:<pass>@10.10.30.41:5984/_node/_local/_config/cors/enable_cors -d '"true"'
curl -s -X PUT http://admin:<pass>@10.10.30.41:5984/_node/_local/_config/cors/credentials -d '"true"'
curl -s -X PUT http://admin:<pass>@10.10.30.41:5984/_node/_local/_config/cors/methods -d '"GET, PUT, POST, HEAD, DELETE"'
curl -s -X PUT http://admin:<pass>@10.10.30.41:5984/_node/_local/_config/cors/headers -d '"accept, authorization, content-type, origin, referer"'
curl -s -X PUT http://admin:<pass>@10.10.30.41:5984/_node/_local/_config/cors/origins -d '"app://obsidian.md,capacitor://localhost,http://localhost"'

# Create the sync database
curl -s -X PUT http://admin:<pass>@10.10.30.41:5984/obsidian-livesync
```

---

## Desktop Setup (Windows / macOS / Linux)

1. Install [Obsidian](https://obsidian.md) and open (or create) your vault
2. Go to **Settings → Community plugins → Browse** → search `Self-hosted LiveSync` → Install → Enable
3. Open **Self-hosted LiveSync** settings:
   - **Remote database configuration**
     - URI: `https://brain.wittycomp.com`
     - Username: `admin`
     - Password: *(from Vaultwarden: "wn-obsidian-01 CouchDB")*
     - Database name: `obsidian-livesync`
   - Click **Check** — should show green
4. **Sync settings**:
   - Enable "Sync on startup" and "Sync on file modification"
   - Recommended: enable "End-to-end encryption" with a passphrase stored in Vaultwarden
5. Perform initial sync: click **Replicate**

---

## Android / iOS Setup

1. Install Obsidian from Play Store / App Store
2. Create vault (or copy vault files if using Syncthing)
3. Enable community plugins (Settings → Community plugins → Allow)
4. Install **Self-hosted LiveSync** (same as desktop — search in Browse)
5. Configure with same URI/credentials as desktop
6. The mobile Obsidian app uses `capacitor://localhost` as its origin — this is already in the CouchDB CORS config

> **Tip**: Use Syncthing to bootstrap the vault on mobile by syncing the vault folder first, then activating LiveSync on top. This avoids a full initial replication over cellular.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `401 Unauthorized` | Wrong credentials | Re-check Vaultwarden item |
| `CORS error` in browser console | Origin not in CouchDB allowlist | Re-run the `cors/origins` PUT with the missing origin |
| Plugin shows `Network error` | Caddy routing issue | `curl -sk https://brain.wittycomp.com/ -w "%{http_code}"` should return 401 |
| Sync works LAN but not cellular | CF tunnel ingress missing | Check [workflows/new-subdomain-cf.md](new-subdomain-cf.md) — brain + obsidian rules must exist |
| `database does not exist` | DB wasn't created | `curl -X PUT http://admin:<pass>@10.10.30.41:5984/obsidian-livesync` |

---

## Recovery

If the CouchDB container needs to be recreated:

```bash
cd /data/witty-lab-data/apps/wn-obsidian-01
docker compose down
docker compose up -d
# Re-run the server setup commands above
```

Data is persisted in the Docker volume — the database survives container recreation.
