# Workflow: Arr Stack Tagging & Metadata Strategy

## Why

Tags in Sonarr/Radarr/Lidarr are the control plane for content routing. Without them, all content uses the same quality profile, the same download client, and the same indexers — which means no programmatic sorting, no per-genre quality tiers, and no automated routing for special content types (anime, 4K, kids). Add tags early, before the library grows, so the system self-sorts as content arrives.

**Key principle**: a tag is not a label — it's a routing key. Every tag you create should map to a *behavior change* (different quality profile, different download client, different notification channel, different delay profile).

---

## The Arr Stack

| Service | URL | Purpose |
|---------|-----|---------|
| Radarr | [radarr.wittycomp.com](https://radarr.wittycomp.com) | Movies |
| Sonarr | [sonarr.wittycomp.com](https://sonarr.wittycomp.com) | TV shows |
| Lidarr | [lidarr.wittycomp.com](https://lidarr.wittycomp.com) | Music (albums/artists) |
| Prowlarr | [prowlarr.wittycomp.com](https://prowlarr.wittycomp.com) | Indexer management |
| Bazarr | [bazarr.wittycomp.com](https://bazarr.wittycomp.com) | Subtitles |
| Readarr | [readarr.wittycomp.com](https://readarr.wittycomp.com) | Books/ebooks |
| Mylar3 | [mylar.wittycomp.com](https://mylar.wittycomp.com) | Comics |
| Recyclarr | — | Quality profile sync (config-as-code) |

---

## Tag Taxonomy

### Radarr / Sonarr

| Tag | Maps to | Behavior |
|-----|---------|---------|
| `4k` | 4K quality profile | Prefer 2160p remux; bigger file, less compression |
| `hd` | HD quality profile (default) | 1080p BluRay/WEB |
| `anime` | Anime quality profile | Prefer HEVC/x265 from anime-specific indexers |
| `kids` | Kids quality profile | 1080p max; no HDR; auto-download without waiting |
| `spanish` | Spanish dub/sub quality profile | Bazarr pulls ES-ES/ES-MX subs automatically |
| `documentary` | Documentary quality profile | Accept 1080p WEB; less strict on source |
| `no-monitor` | No quality profile change | Stops auto-search on stalled/unwanted items |

### Lidarr

| Tag | Maps to | Behavior |
|-----|---------|---------|
| `lossless` | FLAC quality profile | Only grab FLAC/ALAC; reject MP3/AAC |
| `hi-res` | Hi-res audio profile | Prefer 24bit/96kHz+ downloads |
| `lossy-ok` | MP3 320 profile | For artists where lossless isn't available |
| `latin` | Latin indexers preferred | Weight indexers with Spanish/Portuguese catalog |

---

## Applying Tags — Radarr/Sonarr UI

1. **Settings → Tags** — Create all tags first (they're just strings)
2. **Settings → Quality Profiles** — One profile per content tier
3. **Settings → Download Clients** — Optionally tag clients (e.g., `vpn-client` tag)
4. **Per-movie/show**: Movies → Edit → Tags field (multi-select)
5. **Bulk-tag**: Movies → select multiple → Edit → Tags → Add/Remove

### Linking tags to quality profiles (Radarr/Sonarr)
Tags don't automatically assign quality profiles — you assign a quality profile when you add content. The tag is used by:
- **Delay profiles** (Settings → Profiles → Delay Profiles): "Apply to releases with tag X" — useful for giving 4K content a 24h wait for better releases
- **Indexer restrictions** (Settings → Indexers → Restrictions): "Apply restriction for tag X" — e.g., only grab releases without "CAM" for `4k` tag
- **Notifications** (Settings → Connect): Fire webhook/Discord only for tagged content

---

## Programmatic Bulk Tagging via API

All arr services expose a REST API. Bulk-tag by genre, year, or studio programmatically:

```bash
# Radarr: get all movies, add "4k" tag to movies released after 2020
RADARR_URL="https://radarr.wittycomp.com"
RADARR_KEY=$(# from Vaultwarden: "Radarr - API Key")

# Get all tags (to find the ID for "4k")
curl -s -H "X-Api-Key: $RADARR_KEY" "$RADARR_URL/api/v3/tag"

# Get all movies
curl -s -H "X-Api-Key: $RADARR_KEY" "$RADARR_URL/api/v3/movie" | python3 -c "
import sys, json
movies = json.load(sys.stdin)
for m in movies:
    if m.get('year', 0) >= 2020:
        print(m['id'], m['title'])
"

# Bulk tag movies (replace TAG_ID with actual ID from /api/v3/tag):
# PUT /api/v3/movie/editor with { 'movieIds': [...], 'tags': [TAG_ID], 'applyTags': 'add' }
```

The same pattern works for Sonarr (`/api/v3/series`) and Lidarr (`/api/v1/artist`).

---

## Beets — Music Metadata Pipeline

Beets is the music library manager feeding Navidrome. It auto-tags music files using MusicBrainz metadata.

Config: [wittycomp-lab/apps/beets/config/config.yaml](http://git.wittycomp.com/bearboss/wittycomp-lab/src/branch/main/apps/beets/config/config.yaml)

Key operations:
```bash
# Auto-tag all untagged music in inbox:
docker exec wn-beets-01 beet import /music/inbox

# Fix metadata for a specific album:
docker exec wn-beets-01 beet modify album:"Album Name" year=2024

# List all tracks by genre:
docker exec wn-beets-01 beet ls genre:Jazz

# Export stats:
docker exec wn-beets-01 beet stats
```

Beets writes ID3/FLAC tags directly into music files, which Navidrome reads for library display.

---

## Frigate — Object Detection Tags → HA Automations

Frigate publishes MQTT events that Home Assistant turns into actionable automations. The event payload includes object type, confidence, and camera name — these become the "tags" for HA.

MQTT topic pattern:
```
frigate/<camera-name>/events         # all events (JSON payload)
frigate/<camera-name>/person/state   # person detected: ON/OFF
frigate/<camera-name>/car/state      # car detected: ON/OFF
```

Home Assistant automation example (add to `automations.yaml`):
```yaml
- alias: "Frigate: Person at front door"
  trigger:
    - platform: mqtt
      topic: frigate/front_door/person/state
      payload: "ON"
  action:
    - service: notify.mobile_app_phone
      data:
        message: "Person detected at front door"
```

See [workflows/frigate-camera-setup.md](frigate-camera-setup.md) for camera-specific config.

---

## Metadata Across the Stack

| Layer | Tool | Metadata type | Where stored |
|-------|------|---------------|-------------|
| Music files | Beets + MusicBrainz | ID3/FLAC tags | In the audio file |
| Music library | Navidrome | Reads file tags | SQLite DB |
| Video library | Jellyfin | NFO files + TMDB/TVDB | `/data/media/` NFO sidecar |
| Photos | Immich | EXIF + ML labels | PostgreSQL + ML pipeline |
| Documents | Paperless-NGX | OCR text + tags | PostgreSQL |
| Notes | Memos | Hashtags in content | SQLite |
| Notes | Obsidian | YAML front matter + inline #tags | Markdown files |
| IoT events | Frigate → MQTT → HA | Object detection labels | HA event log |
