# ALIEN: NIGHTFALL — Deployment Guide

## Production Build & Distribution

ALIEN: NIGHTFALL utilizes Rojo's deterministic build engine to produce production-ready Roblox place files (`.rbxl`).

## Building the Place File

To compile the entire codebase into a standalone Roblox binary place file:

```bash
rojo build default.project.json --output build/AlienNightfall.rbxl
```

Or for XML format (useful for git diffing small environments):
```bash
rojo build default.project.json --output build/AlienNightfall.rbxlx
```

## Roblox Open Cloud CI/CD Pipeline

To deploy automatically via GitHub Actions or automated deployment scripts:

```bash
# 1. Build place binary
rojo build default.project.json --output build/AlienNightfall.rbxl

# 2. Publish to Roblox Experience via Open Cloud API
curl -X POST \
  -H "x-api-key: $ROBLOX_OPEN_CLOUD_KEY" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @build/AlienNightfall.rbxl \
  "https://apis.roblox.com/universes/v1/$UNIVERSE_ID/places/$PLACE_ID/versions?versionType=Published"
```

## StreamingEnabled Settings

The game place MUST have `workspace.StreamingEnabled = true` enabled:
- `StreamOutBehavior`: `LowMemory`
- `StreamingMinRadius`: 64 studs
- `StreamingTargetRadius`: 256 studs
- `OpportunisticStreamOut`: `Enabled`
