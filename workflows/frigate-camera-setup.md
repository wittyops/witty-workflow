# Workflow: Frigate Camera Setup

## Why

Frigate runs with zero cameras by default (`cameras: {}`). This file documents how to add a real IP camera once you have the RTSP stream URL. Every camera added here immediately starts publishing object detection events to MQTT, which Home Assistant consumes for automations.

## Infrastructure

| Component | Detail |
|-----------|--------|
| Frigate URL | `https://frigate.wittycomp.com` |
| Container | `wn-frigate-01` at `10.10.30.71:5000` |
| Config | `/data/witty-lab-data/apps/wn-frigate-01/config/config.yml` |
| MQTT broker | `wn-mosquitto-01` at `10.10.30.35:1883` |
| RTSP restream | `rtsp://10.10.30.71:8554/<camera-name>` |
| Media storage | `/data/witty-lab-data/frigate/` |
| HA integration | Frigate HACS integration or manual MQTT |

---

## Step 1 — Find Your Camera's RTSP URL

Most IP cameras expose RTSP at one of:
```
rtsp://<user>:<pass>@<camera-ip>:554/stream1     # Hikvision, Dahua, Reolink
rtsp://<user>:<pass>@<camera-ip>:554/h264Preview_01_main  # Reolink main
rtsp://<camera-ip>/live/ch0                      # generic
```

Test the stream before adding to Frigate:
```bash
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate \
  "rtsp://<user>:<pass>@<camera-ip>:554/stream1"
```

---

## Step 2 — Add Camera to Frigate Config

Edit `/data/witty-lab-data/apps/wn-frigate-01/config/config.yml`:

```yaml
cameras:
  front_door:                          # name used in MQTT topics
    ffmpeg:
      inputs:
        - path: rtsp://<user>:<pass>@<camera-ip>:554/stream1
          roles:
            - detect                   # low-res, high FPS for object detection
        - path: rtsp://<user>:<pass>@<camera-ip>:554/stream2
          roles:
            - record                   # high-res for recordings (optional second stream)
    detect:
      enabled: true
      width: 1280
      height: 720
      fps: 5                           # 5 FPS is enough for detection
    record:
      enabled: true                    # set false if storage is limited
```

Apply the config (Frigate hot-reloads most changes):
```bash
# Option 1: restart container
docker restart wn-frigate-01

# Option 2: Frigate UI → Settings → Restart (preserves stats)
```

---

## Step 3 — Tune Detection Zones (Optional)

To avoid false positives from cars on the street, restrict detection to a zone:

```yaml
cameras:
  front_door:
    # ... (ffmpeg + detect blocks from above)
    zones:
      porch:
        coordinates: 100,200,300,200,300,400,100,400  # polygon x,y pairs
        objects:
          - person
```

Frigate UI → Camera → Debug → shows detection zones and bounding boxes in real-time.

---

## Step 4 — Wire Home Assistant

### Via Frigate Integration (recommended)
Install the [Frigate HACS integration](https://github.com/blakeblackshear/frigate-hacs-integration) in HA:
1. HA → HACS → Search "Frigate" → Install
2. HA → Settings → Integrations → Add → Frigate
3. URL: `http://10.10.30.71:5000`

This creates:
- Binary sensors: `binary_sensor.front_door_person`, `binary_sensor.front_door_motion`
- Camera entities with live + snapshot feeds
- Event sensors per camera

### Via Raw MQTT (manual)
```yaml
# configuration.yaml
mqtt:
  broker: 10.10.30.35
  port: 1883

binary_sensor:
  - platform: mqtt
    name: "Front Door Person"
    state_topic: "frigate/front_door/person/state"
    payload_on: "ON"
    payload_off: "OFF"
```

---

## Step 5 — Verify MQTT Events

```bash
# Subscribe to all Frigate topics to watch live:
docker exec wn-mosquitto-01 mosquitto_sub -h 10.10.30.35 -t "frigate/#" -v
```

You should see `frigate/front_door/person/state ON` when a person enters frame, then `OFF` when they leave.

---

## Hardware Acceleration (Future)

When the detection CPU load is too high, add a Coral TPU or use GPU.

**Coral USB Accelerator** (plug in, then in compose.yaml):
```yaml
devices:
  - /dev/bus/usb:/dev/bus/usb
```
In config.yml:
```yaml
detectors:
  coral:
    type: edgetpu
    device: usb
```

**Intel QuickSync** (if Proxmox host has Intel iGPU):
```yaml
devices:
  - /dev/dri/renderD128:/dev/dri/renderD128
```
In config.yml under each camera's ffmpeg:
```yaml
ffmpeg:
  hwaccel_args: preset-vaapi
```
