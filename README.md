# ALIEN: NIGHTFALL

**ALIEN: NIGHTFALL** is an intense, cooperative multiplayer survival horror game built in typed Luau for Roblox. Up to 8 players deploy to the overrun research colony of New Eden on LV-894 to complete objectives, scavenge critical resources, repair station sub-systems, and escape via extraction shuttle while hunted by intelligent alien predators.

Developed outside of Roblox Studio using Git, text editors, and synchronized via **Rojo**.

---

## 1. System Requirements

- **Operating System:** Windows 10/11, macOS 12+, or modern Linux (Ubuntu 20.04+)
- **Roblox Studio:** Latest version with the official Rojo Studio plugin installed
- **Rojo CLI:** v7.4.0 or newer
- **Luau Tooling (Recommended):**
  - VS Code or Cursor
  - Luau Language Server (`JohnnyMorganz.luau-lsp`)
  - Selene Linter (`Kampfkarren.selene-vscode`)

---

## 2. Installing Rojo

### Option A: Cargo (Rust Package Manager)
```bash
cargo install rojo
```

### Option B: Aftman / Foreman
```bash
aftman add rojo-rbx/rojo
```

### Option C: Standalone Binary
Download the pre-compiled executable for your platform from the [Rojo GitHub Releases](https://github.com/rojo-rbx/rojo/releases) and add it to your system PATH.

Verify installation:
```bash
rojo --version
# Expected: rojo 7.4.x (or newer)
```

---

## 3. Connecting to Roblox Studio

1. **Start the Rojo Sync Server:**
   In your terminal at the project root directory, run:
   ```bash
   rojo serve default.project.json
   ```
   Rojo will serve on `localhost:34872`.

2. **Open Roblox Studio:**
   - Open an empty Baseplate or your existing ALIEN: NIGHTFALL place.
   - In the Plugins ribbon, open the **Rojo** plugin.
   - Verify the port is `34872` and click **Connect**.
   - Your local code under `src/` will instantaneously sync into `ReplicatedStorage`, `ServerScriptService`, `StarterPlayer`, and `Workspace`.

---

## 4. Complete Project Structure

```
AlienNightfall/
├── default.project.json          # Canonical Rojo DataModel project mapping
├── README.md                     # Project overview and setup manual
├── ARCHITECTURE.md               # Detailed architectural systems breakdown
├── GAMEPLAY.md                   # Survival horror mechanics, stats, loops
├── SECURITY.md                   # Threat model and server-authoritative rules
├── WORLD_SYSTEM.md               # 7 Colony sectors and zone detection engine
├── PLAYER_SYSTEM.md              # Health, stamina, state machine, downed loop
├── INTERACTION_SYSTEM.md         # 9 interaction archetypes and validation
│
├── src/
│   ├── ServerScriptService/      # Server authoritative code
│   │   ├── ServerMain.server.luau# Master server bootstrapper
│   │   └── Services/             # Modular server services
│   │       ├── PlayerService.luau
│   │       ├── CharacterService.luau
│   │       ├── ZoneService.luau
│   │       └── InteractionService.luau
│   │
│   ├── ReplicatedStorage/        # Replicated modules & dynamic remotes
│   │   ├── Shared/               # Types, constants, utilities, remotes
│   │   │   ├── Types.luau
│   │   │   ├── Constants.luau
│   │   │   ├── Utilities.luau
│   │   │   └── NetworkRemotes.luau
│   │   ├── Config/               # Gameplay configuration modules
│   │   │   ├── PlayerConfig.luau
│   │   │   ├── WorldConfig.luau
│   │   │   └── InteractionConfig.luau
│   │   └── Remotes/              # Network remotes mount point
│   │       └── README.md
│   │
│   ├── StarterPlayer/            # Client scripts
│   │   └── StarterPlayerScripts/
│   │       ├── ClientMain.client.luau # Master client bootstrapper
│   │       └── Controllers/      # Modular client controllers
│   │           ├── PlayerController.luau
│   │           ├── InputController.luau
│   │           ├── InteractionController.luau
│   │           └── UIController.luau
│   │
│   └── Workspace/                # World layout folders
│       └── World/                # Folder instance
│           ├── Zones/            # Sector boundary bounding parts
│           ├── Landmarks/        # Colony landmarks
│           ├── Transitions/      # Airlocks and security gates
│           ├── SpawnPoints/      # Drop zones
│           ├── MissionLocations/ # Objectives and terminals
│           ├── EncounterZones/   # Hive ambush triggers
│           └── ExtractionZones/  # Landing pads
│
├── assets/                       # Asset specifications and manifests
│   ├── Buildings/
│   ├── Environment/
│   ├── Props/
│   ├── Weapons/
│   ├── Aliens/
│   ├── Vehicles/
│   ├── UI/
│   └── Audio/
│
├── tests/                        # Automated test suites
│   ├── Server/
│   │   ├── ServerRunner.luau
│   │   ├── PlayerService.spec.luau
│   │   └── InteractionService.spec.luau
│   ├── Client/
│   │   └── InteractionController.spec.luau
│   └── Shared/
│       └── Utilities.spec.luau
│
└── docs/                         # Extended documentation
    ├── development.md
    ├── testing.md
    └── deployment.md
```

---

## 5. Development Workflow

1. **Branching & Commits:** Create feature branches for game systems.
2. **Local Editing:** Edit code directly in VS Code / Cursor with Luau LSP syntax checking.
3. **Studio Live Testing:**
   - Keep `rojo serve` active in a background terminal.
   - Save any file in your editor — Rojo will push the changes to Studio within milliseconds.
   - Press **F5 (Play)** in Studio to test changes immediately.
4. **Service & Controller Lifecycle:**
   - All services expose `OnInit()` and `OnStart()`.
   - `ServerMain.server.luau` boots services in deterministic order.
   - `ClientMain.client.luau` boots controllers in deterministic order.

---

## 6. Build Instructions

### Compile Standalone Place Binary (`.rbxl`)
```bash
rojo build default.project.json --output build/AlienNightfall.rbxl
```

### Compile Place XML (`.rbxlx`)
```bash
rojo build default.project.json --output build/AlienNightfall.rbxlx
```

The resulting file can be opened directly in Roblox Studio without needing a live Rojo sync connection.

---

## 7. How to Run Tests

### In Roblox Studio (Command Bar or Test Mode)
```luau
local ServerRunner = require(game:GetService("ServerScriptService").AlienNightfall.tests.Server.ServerRunner)
ServerRunner.RunAll()
```

### In Headless Luau (CI)
```bash
luau tests/Shared/Utilities.spec.luau
```

---

## 8. Core Architectural Conventions

1. **Strict Luau (`--!strict`):** All modules must use Luau strict typing mode.
2. **Server Authority:** The client is never trusted. All interactions, damage calculations, and state changes are validated and applied on the server.
3. **Intent-Based Networking:** Clients invoke RemoteFunctions or fire RemoteEvents to request an action (e.g. `InteractRequest`). The server validates distance, line-of-sight, hold duration, and inventory before applying mutations.
4. **Data-Driven Configuration:** Values like health, stamina drain rates, interaction distances, and loot tables must live inside `ReplicatedStorage.Config.*` rather than hardcoded inside scripts.
