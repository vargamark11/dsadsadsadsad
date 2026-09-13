# ALIEN: NIGHTFALL — Player System Architecture (Phase 2)

## 1. Executive Summary & Philosophy

The Player System in **ALIEN: NIGHTFALL** is engineered from the ground up to support high-stakes multiplayer survival in an unpredictable alien environment. The system strictly adheres to the fundamental Roblox multiplayer security rule: **"Never trust the client."**

All critical attributes—health, maximum health, damage resolution, downed states, revive progress, stamina pools, sprint legality, authoritative movement states, and world zones—are strictly calculated, validated, and updated on the server. The client acts purely as an input source and responsive visual/audio predictor.

```
+-------------------------------------------------------------------------------+
|                               SERVER DATA MODEL                               |
|                                                                               |
|  +-------------------+   +--------------------+   +-----------------------+   |
|  | CharacterService  |   | PlayerStateManager |   |     HealthService     |   |
|  | Caching, spawning |   | Master State Enum, |   | Damage, heals, downed |   |
|  | & death events    |   | valid transitions  |   | & kill logic          |   |
|  +---------+---------+   +---------+----------+   +-----------+-----------+   |
|            |                       |                          |               |
|            +-----------------------+--------------------------+               |
|                                    |                                          |
|                          +---------v----------+                               |
|                          |   PlayerService    |                               |
|                          | Master Coordinator |                               |
|                          +---------+----------+                               |
|                                    |                                          |
|            +-----------------------+--------------------------+               |
|            |                                                  |               |
|  +---------v---------+                              +---------v-----------+   |
|  |  StaminaService   |                              |     ZoneService     |   |
|  | Central Heartbeat |                              | World partition and |   |
|  | sprint validation |                              | safe zone detection |   |
|  +-------------------+                              +---------------------+   |
+-------------------------------------------------------------------------------+
                                     |
                          [ Authoritative Remotes ]
                                     |
+------------------------------------v------------------------------------------+
|                              CLIENT CONTROLLERS                               |
|                                                                               |
|  +-------------------+   +--------------------+   +-----------------------+   |
|  |  InputController  |-->|  PlayerController  |-->|     UIController      |   |
|  | Multi-platform    |   | Predictor, state   |   | Health, stamina bars, |   |
|  | touch, pad, keys  |   | sync & attributes  |   | state and zone HUD    |   |
|  +-------------------+   +--------------------+   +-----------------------+   |
+-------------------------------------------------------------------------------+
```

---

## 2. Granular Service Breakdown

Instead of accumulating all player logic into a single monolithic script, the system decomposes responsibilities across 6 specialized modules:

### 2.1 `CharacterService` (`/src/server/Services/CharacterService.luau`)
* **Reference Caching:** Maintains a high-speed internal cache keyed by `player.UserId` storing `{ Model, Humanoid, RootPart, SpawnTimestamp }`. This prevents expensive `Workspace:FindFirstChild()` searches in high-frequency loops.
* **Lifecycle Management:** Safely listens to `player.CharacterAdded`, `player.CharacterRemoving`, and `humanoid.Died`.
* **Safe Spawning:** Controls respawn cooldowns (`PlayerConfig.Respawn.MinRespawnCooldown`) to eliminate rapid-respawn exploitation.
* **Physics Isolation:** Disables humanoid seat states and flinging vulnerabilities.

### 2.2 `PlayerStateManager` (`/src/server/Services/PlayerStateManager.luau`)
* **Authoritative Data Store:** Owns the `PlayerRuntimeData` record for each active session.
* **State Machine Rules:** Validates state transitions against `PlayerConfig.StateTransitions`.
  * For instance: A player in `DOWNED` or `DEAD` state cannot transition to `SPRINTING`.
  * A player in `LOBBY` cannot transition to `DOWNED`.
* **Attribute Mirroring:** Replicates `PlayerState` and `MovementState` onto the Roblox `Player` instance attributes for lightweight client and streaming replication.

### 2.3 `HealthService` (`/src/server/Services/HealthService.luau`)
* **Authoritative Damage:** Deducts health with clamp guards `[0, MaxHealth]`.
* **Downed State Loop:** When health reaches 0, rather than instantly killing the character, triggers `IsDowned = true`, shifts state to `DOWNED`, and initializes the bleedout timer (`PlayerConfig.Downed.BleedoutDuration`).
* **Medical Healing:** Allows medkits and adrenaline injections only if the target is alive and not currently downed.
* **Instant Lethality:** Direct execution / decapitation bypassing downed status via `KillPlayer()`.

### 2.4 `StaminaService` (`/src/server/Services/StaminaService.luau`)
* **Centralized Heartbeat Engine:** Avoids creating per-player loops or coroutines. Uses a single `RunService.Heartbeat` connection on the server that steps through all active sprinters.
* **Sprint Validation:** Verifies that the player is alive, not downed, has stamina $\ge$ `MinimumSprintStamina`, and has valid walkspeed.
* **Drain & Recovery:**
  * Drains at `PlayerConfig.Stamina.SprintDrainRate` (18 units/sec).
  * Enforces `RecoveryDelay` (1.2 sec) from the last drain before regeneration begins.
  * Regenerates at `PlayerConfig.Stamina.StaminaRecoveryRate` (22 units/sec).

### 2.5 `ZoneService` (`/src/server/Services/ZoneService.luau`)
* **World Partitioning:** Divides the map into tactical sectors (`LandingBase`, `ResearchWing`, `ReactorCore`, `MaintenanceTunnels`, `SurfaceWaste`).
* **Safe Zone Mechanics:** Identifies safe zones where alien spawns, hostile environmental hazard ticks, and PvP damage are suppressed.
* **Zone Replication:** Fires `PlayerRemotes.ZoneChanged` whenever a player crosses sector boundaries.

### 2.6 `PlayerService` (`/src/server/Services/PlayerService.luau`)
* **Master Coordinator:** Boots sub-services, sets up network endpoints, handles player join/leave dispatch, and coordinates squad revive interactions.
* **Backward Compatibility:** Preserves standard helper wrappers (`TakeDamage`, `Heal`, `GetLiveState`, `SetSprinting`) ensuring zero disruption to existing combat, AI, and mission systems.

---

## 3. Configuration & Balancing (`config/PlayerConfig.luau`)

No gameplay values are hardcoded in logic files. All tuning constants reside in `PlayerConfig.luau`:

| Category | Constant | Value | Purpose |
| :--- | :--- | :--- | :--- |
| **Health** | `DefaultHealth` | `100` | Starting player health |
| | `MaxHealth` | `100` | Absolute maximum health pool |
| | `DownedThreshold` | `0` | Health value at which downed mode engages |
| | `RespawnHealth` | `100` | Health upon respawn |
| **Stamina** | `DefaultStamina` | `100` | Starting stamina pool |
| | `SprintDrainRate` | `18.0` | Units depleted per second of sprinting |
| | `StaminaRecoveryRate` | `22.0` | Units restored per second of rest |
| | `RecoveryDelay` | `1.2` | Delay in seconds before recovery starts |
| | `MinimumSprintStamina` | `12.0` | Minimum stamina needed to initiate sprint |
| **Movement** | `WalkSpeed` | `16.0` | Standard survivor exploration speed |
| | `SprintSpeed` | `25.0` | Authoritative sprinting speed |
| | `DownedWalkSpeed` | `4.0` | Slow crawl speed while incapacitated |
| **Downed** | `BleedoutDuration` | `45.0` | Time in seconds before bleeding out |
| | `ReviveDuration` | `4.0` | Total seconds of continuous teammate revive |
| | `MaxReviveDistance` | `9.0` | Max studs allowable between reviver and downed player |

---

## 4. Networking Protocol & Data Synchronization

All player networking is handled through `NetworkProtocol.luau` using explicit type categorizations to avoid `RemoteEvent` vs `RemoteFunction` mismatches:

### Server-to-Client Remotes
* `PlayerRemotes.PlayerStateSync` (`RemoteEvent`): Sends high-priority deltas: `Health`, `MaxHealth`, `Stamina`, `MaxStamina`, `IsSprinting`, `IsDowned`, `DownedTimerRemaining`.
* `PlayerRemotes.StateChanged` (`RemoteEvent`): Broadcasts state transitions (`OldState` $\rightarrow$ `NewState`).
* `PlayerRemotes.PlayerUpdate` (`RemoteEvent`): Updates general attributes such as `CurrentZone` and `MovementState`.
* `PlayerRemotes.ZoneChanged` (`RemoteEvent`): Notifies client of world sector entry with ambient profile data.

### Client-to-Server Remotes
* `PlayerRemotes.SprintRequest` (`RemoteEvent`): Sends boolean `wantsSprint`. Server validates against state and stamina.
* `PlayerRemotes.RespawnRequest` (`RemoteEvent`): Requests manual respawn if permitted by game mode.
* `PlayerRemotes.ReviveInteraction` (`RemoteFunction`): Submits `{ TargetUserId }`. Returns `{ Success, Progress, Completed, Error }`.

---

## 5. Multi-Platform Client Input Architecture

Client input in `InputController.luau` uses `ContextActionService` and `UserInputService` to cleanly decouple gameplay from hardware keys:

1. **Abstraction Methods:**
   * `InputController:IsSprintPressed(): boolean`
   * `InputController:IsInteractPressed(): boolean`
   * `InputController:IsReloadPressed(): boolean`
   * `InputController:GetPlatform(): "Desktop" | "Mobile" | "Console"`
2. **Platform Mapping:**
   * **Desktop:** LeftShift (Sprint), E (Interact), R (Reload), F (Flashlight).
   * **Console:** Gamepad L3 Thumbstick Click (Sprint), ButtonX (Interact), ButtonY (Reload).
   * **Mobile:** Dynamically constructs touch action buttons (`SPRINT`, `INTERACT`) positioned and sized responsively to screen dimensions without hardcoding static pixels.

---

## 6. HUD Foundation (`UIController.luau`)

The client HUD provides instant visual feedback without clutter:
* **Health Gauge:** Animated fill bar with high-contrast numerical readout (`HP 100 / 100`). Turns pulsing crimson on critical damage.
* **Stamina Gauge:** Teal energy bar that drains smoothly and turns amber when depleted below the sprint activation threshold.
* **State Badge:** Displays current authoritative status (`STATE: ALIVE`, `SPRINTING`, `DOWNED`, `DEAD`) with adaptive color coding.
* **Zone Badge:** Displays current geographical sector (`ZONE: LandingBase`) indicating safe hub vs hostile zone.
* **Downed Bleedout Overlay:** Displays an urgent visual indicator and countdown (`Bleeding out... Awaiting teammate revive (44s)`).

---

## 7. Edge Cases & Defensive Engineering

* **Player Leaves Mid-Spawn:** `CharacterService:_OnCharacterAdded` and `PlayerStateManager:InitRuntimeData` verify `player.Parent ~= nil` before completing initialization.
* **Rapid Respawn Spam:** `CharacterService:Respawn` checks `os.clock() - lastSpawn >= MinRespawnCooldown` and rejects requests that arrive within 1 second.
* **Anti-Desync:** `PlayerService:SyncLiveState` sends an authoritative snapshot whenever a character spawns or state shifts.
* **Revive Interruption:** `HandleReviveRequest` checks distance on every pulse; if the reviver moves beyond 9 studs or takes fatal damage, the revive action aborts.

---

## 8. Test Specifications (`tests/PlayerSystem.spec.luau`)

Automated tests cover 15 distinct scenarios:
1. `Player Joins: Runtime State Initialization`
2. `Player Leaves: Cleanup Lifecycle`
3. `Character Spawns: Transition to ALIVE & Reset Systems`
4. `Character Respawns: Safe Offset & State Reset`
5. `Health Changes: Clamping & Signal Dispatch`
6. `Damage Handling & Downed Trigger`
7. `Healing & Revive Restoration`
8. `Sprint Request Validation & Activation`
9. `Stamina Drain During Active Sprint`
10. `Stamina Regeneration After Recovery Delay`
11. `Invalid Sprint Requests Blocked`
12. `Invalid State Transitions Rejected by Authority`
13. `Multiplayer Concurrency Isolation: 1, 2, 4, 8 Players`
14. `Edge Case: Player Leaves During Initialization`
15. `Edge Case: Rapid Respawn Spam Throttled`
