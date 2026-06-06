# Workflow: Deploy a ZIM to Kiwix

## Why

`kiwix.wittycomp.com` serves offline content from ZIM archives — compressed snapshots of entire websites usable without internet. New ZIMs are added by downloading them to the ZIM directory; the systemd service auto-detects them on restart.

**Use case**: iFixit for repair guides, ArchWiki for Linux reference, devdocs for offline API docs during network outages.

---

## Infrastructure

| Component | Detail |
|-----------|--------|
| Service URL | `https://kiwix.wittycomp.com` |
| ZIM storage | `/data/witty-lab-data/kiwix-zims/` |
| Systemd service | `kiwix-serve` on `wn-srv-01` |
| Wrapper script | `/usr/local/bin/kiwix-serve-witty.sh` ([source](../scripts/kiwix-serve-witty.sh)) |
| Port | `0.0.0.0:8282` → Caddy at `10.10.30.250:8282` |

---

## Finding ZIM Files

Browse available ZIMs at the official library: `https://library.kiwix.org`

Or use the command-line catalog:

```bash
# Search for a specific topic:
curl -s "https://library.kiwix.org/catalog/v2/entries?lang=eng&q=wikipedia" \
  | python3 -c "
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.stdin).getroot()
ns = {'a': 'http://www.w3.org/2005/Atom'}
for e in root.findall('a:entry', ns):
    name = e.find('a:title', ns).text
    link = e.find(\"a:link[@rel='http://opds-spec.org/acquisition']\", ns)
    size = link.attrib.get('{http://www.w3.org/2005/Atom}length', '?') if link else '?'
    url = link.attrib.get('href', '') if link else ''
    print(f'{name} | {int(size)//1024//1024} MB | {url}')
"
```

---

## Adding a ZIM

```bash
cd /data/witty-lab-data/kiwix-zims

# Download (use curl with resume support for large files):
curl -L --continue-at - -o "<filename>.zim" "<download-url>"

# Verify the file:
ls -lh *.zim

# Restart the service to pick up the new ZIM:
sudo systemctl restart kiwix-serve

# Confirm it's serving:
curl -s http://10.10.30.250:8282/ | grep -i title
```

---

## Currently Deployed ZIMs

See [reference/zim-catalog.md](../reference/zim-catalog.md) for the full catalog with file sizes and download sources.

| ZIM | Description | Size |
|-----|-------------|------|
| `ifixit_en_all_2025-12.zim` | iFixit — complete repair guide database | 3.4 GB |
| `archlinux_en_all_maxi_2026-04.zim` | ArchWiki — full Linux reference | 34 MB |
| `devdocs_en_ansible_2026-04.zim` | Ansible documentation | 30 MB |
| `devdocs_en_python_2026-05.zim` | Python 3 docs | 4.2 MB |
| `devdocs_en_postgresql_2026-05.zim` | PostgreSQL docs | 2.5 MB |
| `devdocs_en_docker_2026-04.zim` | Docker docs | 1.7 MB |
| `devdocs_en_go_2026-04.zim` | Go docs | 1.6 MB |
| `devdocs_en_redis_2026-04.zim` | Redis docs | 851 KB |
| `devdocs_en_nginx_2026-04.zim` | nginx docs | 797 KB |
| `devdocs_en_bash_2026-04.zim` | Bash reference | 546 KB |

---

## Removing a ZIM

```bash
rm /data/witty-lab-data/kiwix-zims/<filename>.zim
sudo systemctl restart kiwix-serve
```

Update `reference/zim-catalog.md` after removing.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Service won't start | No ZIM files in directory | Check `ls /data/witty-lab-data/kiwix-zims/*.zim` |
| ZIM not appearing in UI | Service not restarted | `sudo systemctl restart kiwix-serve` |
| Partial/corrupt ZIM | Download interrupted | `curl -L --continue-at -` to resume, then check file size matches source |
| 502 on kiwix.wittycomp.com | CF tunnel rule missing noTLSVerify | See [workflows/new-subdomain-cf.md](new-subdomain-cf.md) |
