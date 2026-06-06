# Secret Sources

Where to find credentials for each service. **Never hardcode — always pull from Vaultwarden.**

Vaultwarden is at `https://vault.wittycomp.com`. Session token: `cat ~/.bw_session`

## Infra Credentials

| Service | Vaultwarden Item | Field / Note |
|---------|-----------------|-------------|
| Technitium DNS API | `Technitium DNS - API Token` | Token expires per session — re-auth via `/api/user/login?user=admin&pass=<pw>` |
| Cloudflare API | `Cloudflare - API Token` | Zone: `f2d562fd622786dbb39a7319e8e21d26` |
| Forgejo admin | `FORGEJO - AdminLogin (current)` | username: `bearboss` |
| Forgejo API token | `FORGEJO - Forgejo/Github Token` | Field: `FORGEJO-GITHUB-SYNC-TOKEN` (works for Forgejo API too) |
| GitHub PAT | `FORGEJO-GITHUB-Personal Access Token` | Field: `FORGEJO-GITHUB-PAT` |
| pfSense admin | `pfSense - bearboss` | admin / 7403B3ars! |

## Service Credentials

| Service | Vaultwarden Item | Field / Note |
|---------|-----------------|-------------|
| Vaultwarden admin | `Vaultwarden - Admin` | admin token |
| Nextcloud admin | `Nextcloud - bearboss` | username: bearboss |
| Immich | `Immich - bearboss` | EKZELH40qpZjND3ycRqxsvPJgRQueR |
| Penpot | `Penpot - bearboss` | 4thdirective@gmail.com |
| BookStack API | `BookStack - API Token` | Field: `BOOKSTACK-API-TOKEN` (format: id:secret) |
| BookStack login | `BookStack - bearboss` | |
| CouchDB (Obsidian) | `wn-obsidian-01 CouchDB` | admin / PgDmtTuKYXDSeifHafKVvGTqMdmvdI5q |
| Syncthing | `Syncthing - bearboss` | |
| FileBrowser | `FileBrowser - bearboss` | cZv8MX51cgkq_9s_8WiN4Q |
| Memos | `Memos - bearboss` | bearboss / i3vO060c5xtFvzZm5rCI |
| Postgres (Forgejo) | `FORGEJO - Secrets` | Field: FORGEJO-POSTGRES-PASSWORD |
| Akaunting | `Akaunting - bearboss` | |

## Retrieval Pattern

```bash
# Unlock session (if not already):
export BW_SESSION=$(bw unlock --raw)
# or read existing:
export BW_SESSION=$(cat ~/.bw_session)

# Get a password:
bw get password "Item Name" --session "$BW_SESSION"

# Get a custom field:
bw get item "Item Name" --session "$BW_SESSION" | \
  python3 -c "import sys,json; item=json.load(sys.stdin); [print(f['value']) for f in item.get('fields',[]) if f['name']=='FIELD-NAME']"
```
