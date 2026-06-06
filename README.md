# Witty-Workflow

Operational knowledge base for the **Wittycomp Lab** homelab stack — workflows, scripts, and runbooks that document *how* and *why* things are done, not just what exists.

## Structure

```
workflows/   Processes with context, rationale, and step-by-step guides
scripts/     Executable helpers — shell, Python, curl one-liners
reference/   Static registries: IP allocations, port map, secret sources
```

## Quick Links

### Workflows
- [Add a New Service](workflows/new-service.md) — full checklist from IP allocation → CF tunnel → commit
- [Add a New Subdomain (CF)](workflows/new-subdomain-cf.md) — 4-step CF tunnel + DNS + Caddy process
- [Arr Tagging & Metadata Strategy](workflows/arr-tagging-strategy.md) — tag taxonomy, bulk API tagging, Beets, Frigate→HA event pipeline
- [Frigate Camera Setup](workflows/frigate-camera-setup.md) — add IP cameras, zones, HA integration, hardware acceleration
- [Provision BookStack Content](workflows/bookstack-api-provisioning.md) — create books/chapters/pages via REST API
- [Deploy a ZIM to Kiwix](workflows/kiwix-zim-deploy.md) — add offline content to kiwix.wittycomp.com
- [Obsidian LiveSync Setup](workflows/obsidian-livesync-setup.md) — configure vault sync on desktop + Android

### Reference
- [IP Allocation Registry](reference/ip-allocation.md) — all VLAN30 `.30.x` addresses, reserved ranges
- [Port Registry](reference/port-registry.md) — service → port map to avoid collisions
- [Secret Sources](reference/secret-sources.md) — which Vaultwarden item holds which credential
- [ZIM Catalog](reference/zim-catalog.md) — all ZIM files deployed to kiwix.wittycomp.com

### Scripts
- [kiwix-serve-witty.sh](scripts/kiwix-serve-witty.sh) — systemd wrapper; globs ZIMs and launches kiwix-serve
- [provision-bookstack.sh](scripts/provision-bookstack.sh) — BookStack API content provisioning helper
- [cf-add-subdomain.sh](scripts/cf-add-subdomain.sh) — automates all 4 CF subdomain steps via API

## Related Repos

| Repo | Purpose |
|------|---------|
| [wittycomp-lab](http://git.wittycomp.com/bearboss/wittycomp-lab) | Compose files, Caddyfile, SERVICES.md — the primary infra repo |
| [witty-blueprints](http://git.wittycomp.com/bearboss/witty-blueprints) | Architecture diagrams and planning docs |
| [lazarus-recovery-stage](http://git.wittycomp.com/bearboss/lazarus-recovery-stage) | Lazarus AI agent identity and config |

## Conventions

- Every workflow has a **Why** section explaining the motivation
- Scripts include usage examples and expected output
- When a workflow references a file in another repo, it links directly to the path in that repo
- IP/port assignments here must stay in sync with [SERVICES.md](http://git.wittycomp.com/bearboss/wittycomp-lab/src/branch/main/SERVICES.md)
