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

## Tag Taxonomy — DEPLOYED

Tags were created via API on 2026-06-06 against an empty library. Every piece of content added after this date should have at least one tag.

### Radarr Tags

| ID | Tag | Quality Profile | Delay Profile | Behavior |
|----|-----|----------------|---------------|---------|
| 1 | `4k` | Ultra-HD | 1440min (24h) — waits for remux over first-to-post WEB-DL | 2160p only |
| 2 | `hd` | HD-1080p | none (default) | Standard 1080p BluRay/WEB |
| 3 | `anime` | Anime | none | x265/HEVC preferred; anime indexers |
| 4 | `kids` | HD-720p | none (grab immediately) | 720p–1080p; safe content |
| 5 | `spanish` | HD-1080p | none | Bazarr prioritises ES-ES/ES-MX subs |
| 6 | `documentary` | HD-1080p | 240min (4h) — allows better encode to surface | WEB-DL fine |
| 7 | `concert` | HD-1080p | none | Music performance films |
| 8 | `hold` | Any | none | Monitored — do NOT auto-search |

### Sonarr Tags

| ID | Tag | Quality Profile | Delay Profile | Behavior |
|----|-----|----------------|---------------|---------|
| 1 | `4k` | Ultra-HD | 1440min (24h) | 2160p episodes |
| 2 | `hd` | HD-1080p | none | Standard |
| 3 | `anime` | Anime | none | Anime series |
| 4 | `kids` | HD-720p | none | Kids shows; grab fast |
| 5 | `spanish` | HD-1080p | none | Spanish-language series |
| 6 | `documentary` | HD-1080p | none | Docs/nature |
| 7 | `season-pack` | HD-1080p | 10080min (7 days) — waits for full season upload before grabbing | Binge shows |
| 8 | `hold` | Any | none | Monitored but manual grab only |

### Lidarr Tags

| ID | Tag | Quality Profile | Behavior |
|----|-----|----------------|---------|
| 1 | `lossless` | Lossless | FLAC/ALAC only; feeds Navidrome with lossless files |
| 2 | `hi-res` | Lossless | 24bit/96kHz+ preferred |
| 3 | `lossy-ok` | Standard | MP3/AAC acceptable; for artists with no lossless releases |
| 4 | `latin` | Any | Latin music; future indexer routing hook |

---

## How Tags Work — The Mechanics

Tags in arr apps are **not** auto-applied based on genre. When you add content, you:
1. Choose the quality profile manually (or the app defaults to "Any")
2. Assign one or more tags

The tag then activates the matching delay profile, indexer restrictions, and notification rules.

**Rule of thumb when adding content:**
- Know the type → pick the right tag + quality profile together
- `4k` tag → set quality profile to "Ultra-HD" at the same time
- `season-pack` tag → Sonarr will wait 7 days before grabbing any episode

## Applying Tags — Radarr/Sonarr UI

1. **Per-movie**: Movies → Click movie → Edit → Tags field (multi-select) + Quality Profile dropdown
2. **Per-show**: Series → Click show → Edit → Tags + Quality Profile
3. **Bulk-tag**: Movies/Series → check multiple → Edit → Tags → Add/Remove

> Tags and quality profiles are set independently — you must set both. A `4k` tag without the "Ultra-HD" quality profile does nothing useful.

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
