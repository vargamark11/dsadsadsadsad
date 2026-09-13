# ALIEN: NIGHTFALL — World System Architecture

## Overview

The world of ALIEN: NIGHTFALL is partitioned into seven distinct, atmospheric colony sectors on LV-894. The world hierarchy is represented directly inside `Workspace.World` using real Roblox `Folder` instances synchronized via Rojo.

---

## 1. Workspace Hierarchy

```
Workspace
└── World/ (Folder)
    ├── Zones/ (Folder)
    │   ├── LandingBase (Part / Bounding Box)
    │   ├── ResearchComplex
    │   ├── Hospital
    │   ├── Forest
    │   ├── Underground
    │   ├── AbandonedCity
    │   └── AlienNest
    │
    ├── Landmarks/ (Folder)
    │   ├── AegisMainBeacon
    │   ├── GeothermalCoolingTower
    │   └── CommsDishRelay
    │
    ├── Transitions/ (Folder)
    │   ├── Airlock_Alpha_Bravo
    │   └── Tunnel_Gate_04
    │
    ├── SpawnPoints/ (Folder)
    │   └── SafeDropZone (SpawnLocation)
    │
    ├── MissionLocations/ (Folder)
    │   ├── ServerRoom_Alpha
    │   └── SpecimenContainment_Vault
    │
    ├── EncounterZones/ (Folder)
    │   └── Hive_Ambush_Chamber
    │
    └── ExtractionZones/ (Folder)
        └── PrimaryLandingPad
```

---

## 2. Colony Sectors Breakdown

| Zone ID | Display Name | Threat | Safe Zone | Keycard Required | Atmosphere / Lighting |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **LandingBase** | Landing Base (Aegis Hub) | 1 / 5 | **Yes** | None | Steel Gray `(80, 85, 95)`, Low Fog |
| **ResearchComplex**| Research Complex Sector Alpha | 3 / 5 | No | Level 2 | Cold Cyan `(35, 45, 55)`, Fluorescent Flicker |
| **Hospital** | Medical Center & Quarantine | 3 / 5 | No | Level 1 | Muted Teal `(30, 40, 45)`, Dense Mist |
| **Forest** | Blackwood Perimeter Forest | 2 / 5 | No | None | Deep Charcoal `(25, 30, 35)`, Heavy Fog |
| **Underground** | Subterranean Geothermal Tunnels| 4 / 5 | No | Level 3 | Pitch Black `(15, 15, 20)`, Steam Vents |
| **AbandonedCity** | New Eden Colony Ruins | 4 / 5 | No | None | Amber Haze `(20, 25, 35)`, Urban Shadows |
| **AlienNest** | Sub-Surface Hive Infestation | 5 / 5 | No | Master | Crimson Glow `(25, 10, 15)`, Spore Cloud |

---

## 3. Zone Detection Engine

`ZoneService` sweeps active player character coordinates every 0.5 seconds (2 Hz):
1. Point-in-box coordinate space transformation against bounding box parts under `Workspace.World.Zones`.
2. Fallback distance calculation to `LandingBase` center (140-stud radius).
3. If an operative crosses into a new sector, `ZoneChanged` fires to notify client controllers and adjust atmospheric lighting and soundscapes dynamically.
