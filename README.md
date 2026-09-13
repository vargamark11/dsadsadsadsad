# ALIEN: NIGHTFALL

A cooperative sci-fi multiplayer survival horror game built in modern Luau for Roblox.

## Status

* **Phase 1 (Architecture & Foundation):** Completed
* **Phase 2 (Player System & Multi-Platform Client):** Completed
* **Phase 3 (Alien AI Systems):** Planned
* **Phase 4 (Weapons & Combat Systems):** Planned
* **Phase 5 (Colony Map & Extraction Missions):** Planned

---

## Key Features in Phase 2 (Player System)

* **Server-Authoritative Lifecycle:** Managed across `CharacterService`, `PlayerStateManager`, `HealthService`, `StaminaService`, and `ZoneService`.
* **State Machine:** Authoritative transitions (`LOBBY`, `SPAWNING`, `ALIVE`, `SPRINTING`, `INTERACTING`, `DOWNED`, `DEAD`, `EXTRACTING`, `SPECTATING`).
* **Downed & Revive Loop:** 45-second bleedout timer with proximity-checked squad revive progress.
* **Centralized Stamina Heartbeat:** Single-loop stamina engine with sprint validation, drain rate, and recovery cooldown.
* **Multi-Platform Controls:** Decoupled input abstraction supporting Desktop (Keyboard/Mouse), Mobile (Dynamic Touch Buttons), and Console (Gamepad).
* **HUD Indicators:** Dynamic health, stamina, player state badge, and sector zone tracker.
* **15-Spec Test Suite:** Full automated test harness validating single-player, multi-player (1, 2, 4, 8 players), and edge cases.

---

## Rojo Setup

To synchronize this repository with Roblox Studio:

```bash
rojo serve default.project.json
```

Then in Roblox Studio, connect via the **Rojo** plugin.
