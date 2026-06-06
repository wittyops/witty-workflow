# IP Allocation Registry

All VLAN30 (`10.10.30.x`) addresses. **Check this before assigning a new IP.**
Source of truth is [wittycomp-lab/SERVICES.md](http://git.wittycomp.com/bearboss/wittycomp-lab/src/branch/main/SERVICES.md) — this file is a quick-reference index.

## Reserved / Infrastructure

| IP | Role |
|----|------|
| `10.10.30.1` | wn-seneca-01 — network gateway / router |
| `10.10.30.5` | wn-caddy-01 — primary reverse proxy (macvlan) |
| `10.10.30.4` | wn-vault-01 — Vaultwarden (macvlan + witty_network bridge) |
| `10.10.30.250` | Host shim — bind address for host-process services (kiwix, etc.) |

## Assigned Services (VLAN30 macvlan)

| IP | Service | URL |
|----|---------|-----|
| `10.10.30.10` | wn-openhands-01 | — |
| `10.10.30.20` | wn-mcp-dns | dns-mcp.wittycomp.com |
| `10.10.30.25` | wn-nocodb-01 | data.wittycomp.com |
| `10.10.30.30` | wn-ollama-01 | ollama.wittycomp.com |
| `10.10.30.35` | wn-mcp-cook | cook.wittycomp.com (Cooklang MCP) |
| `10.10.30.40` | wn-mcp-tailscale | — |
| `10.10.30.41` | wn-obsidian-01 | brain.wittycomp.com (CouchDB) |
| `10.10.30.43` | wn-penpot-01 | design.wittycomp.com |
| `10.10.30.44` | wn-memos-01 | memo.wittycomp.com |
| `10.10.30.45` | wn-homepage-01 | home.wittycomp.com |
| `10.10.30.46` | wn-bookstack-01 | wiki.wittycomp.com |
| `10.10.30.47` | wn-paperless-01 | paper.wittycomp.com |
| `10.10.30.48` | wn-nextcloud-01 | cloud.wittycomp.com |
| `10.10.30.49` | wn-chroma-01 | — (internal; Chroma vector DB) |
| `10.10.30.50` | wn-lazarus-memory-01 | — (internal; memory layer) |
| `10.10.30.55` | wn-akaunting-01 | books.wittycomp.com |
| `10.10.30.60` | wn-immich-01 | photos.wittycomp.com |
| `10.10.30.62` | wn-jellyfin-01 | watch.wittycomp.com |
| `10.10.30.63` | wn-syncthing-01 | sync.wittycomp.com |
| `10.10.30.64` | wn-hermes-01 | hermes.wittycomp.com (identity proxy) |
| `10.10.30.65` | wn-navidrome-01 | music.wittycomp.com |
| `10.10.30.67` | wn-stirling-01 | pdf.wittycomp.com |
| `10.10.30.68` | wn-memory-os-01 | mem.wittycomp.com |
| `10.10.30.69` | wn-filebrowser-01 | files.wittycomp.com |
| `10.10.30.70` | wn-gitingest-01 | ingest.wittycomp.com |

## Next Available

As of 2026-06-06, the next free addresses are approximately `.71`, `.72`, etc. Always verify against [SERVICES.md](http://git.wittycomp.com/bearboss/wittycomp-lab/src/branch/main/SERVICES.md) before assigning.

## Host-Shim Services (port on 10.10.30.250)

Services running as host processes (not Docker containers) bind to `0.0.0.0:<port>` and are reached by Caddy at `10.10.30.250:<port>`.

| Port | Service |
|------|---------|
| `3001` | Homepage (also in Docker at `.45`) |
| `8282` | kiwix-serve |
