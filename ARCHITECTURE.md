# ALIEN: NIGHTFALL — Architecture & Systems Specification

## 1. System Overview

**ALIEN: NIGHTFALL** is a cooperative survival horror multiplayer game built in modern Luau for Roblox. The project is organized for seamless bidirectional synchronization with Roblox Studio using **Rojo**.

```
ALIEN: NIGHTFALL
├── config/                  # Balance tuning & constant tables
│   ├── EconomyConfig.luau   # Credits, scraps, trade margins
│   ├── GameConfig.luau      # Match limits, tick rates, world constants
│   ├── PlayerConfig.luau    # Health, stamina, downed, speed parameters
│   ├── ProgressionConfig.luau # Level XP curves, milestone rewards
│   └── WeaponConfig.luau    # Fire rates, damages, recoil, spread tables
├── src/
│   ├── client/              # Client-side controllers (StarterPlayerScripts)
│   │   ├── Controllers/     # Audio, Camera, Input, Player, UI, Weapon, etc.
│   │   ├── ControllerManager.luau # Lifecycle boots (OnInit -> OnStart)
│   │   └── init.client.luau # Client bootstrap entry point
│   ├── server/              # Server-side authoritative services (ServerScriptService)
│   │   ├── Services/        # Character, State, Health, Stamina, Zone, Player, etc.
│   │   ├── ServiceManager.luau # Service lifecycle registry
│   │   └── init.server.luau # Server bootstrap entry point
│   └── shared/              # Shared modules (ReplicatedStorage)
│       ├── Constants/       # Shared enum declarations
│       ├── Network/         # NetworkProtocol remote event/function dispatcher
│       ├── Types/           # PlayerTypes, NetworkTypes, GameTypes
│       └── Utility/         # Signal, RateLimiter, TableUtil, Logger
├── tests/                   # Automated unit testing suite
│   ├── PlayerSystem.spec.luau # Phase 2 Player System validation
│   └── Runner.server.luau   # Master test runner
└── default.project.json     # Rojo project definition
```

---

## 2. Core Architectural Principles

1. **Strict Server Authority:**
   * Health, stamina, downed bleedout timers, squad revives, economy balances, inventory contents, and world zones are strictly calculated on the server.
   * Client-side inputs are treated as untrusted intent requests and validated against rate limiters and state preconditions.

2. **Single-Responsibility Service Decomposition:**
   * Large subsystems are split into focused modules. For instance, the Player System is divided across:
     - `CharacterService`: Reference caching and character lifecycle.
     - `PlayerStateManager`: State machine and attribute mirroring.
     - `HealthService`: Damage, heal, and downed triggers.
     - `StaminaService`: Heartbeat-driven stamina loop and sprint validation.
     - `ZoneService`: Sector boundary detection.
     - `PlayerService`: Master coordination and network endpoints.

3. **Centralized Engine Loops:**
   * Systems requiring continuous simulation (e.g. `StaminaService` or bleedout checks) utilize single, centralized `RunService.Heartbeat` or `task.wait` loops rather than spawning uncoordinated per-player coroutines.

4. **Multi-Platform Input Abstraction:**
   * High-level gameplay mechanics query abstract actions (`InputController:IsSprintPressed()`, `IsInteractPressed()`) instead of binding directly to keyboard keycodes, natively supporting PC, mobile touch, and console gamepad.

---

## 3. Rojo Mapping Reference

The project maps directly into Roblox Studio DataModel hierarchies as defined in `default.project.json`:

| File System Path | Roblox DataModel Location |
| :--- | :--- |
| `src/shared/` | `game.ReplicatedStorage.AlienNightfall.Shared` |
| `config/` | `game.ReplicatedStorage.AlienNightfall.Config` |
| `src/server/` | `game.ServerScriptService.AlienNightfall.Server` |
| `src/client/` | `game.StarterPlayer.StarterPlayerScripts.AlienNightfall.Client` |
| `tests/` | `game.ServerStorage.AlienNightfall.Tests` |
