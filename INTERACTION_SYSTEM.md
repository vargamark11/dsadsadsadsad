# ALIEN: NIGHTFALL — Interaction System Specification (Phase 3)

## 1. Architectural Overview

The **Interaction System** in **ALIEN: NIGHTFALL** is a modular, data-driven, server-authoritative framework engineered to handle every player-to-world touchpoint across the multiplayer survival horror experience. It establishes a unified contract for doors, security terminals, power generators, supply containers, switches, multi-player consoles, elevator lifts, and sequence puzzles without creating ad-hoc or fragmented interaction scripts.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CLIENT (StarterPlayerScripts)                   │
├───────────────────────────────┬────────────────────────────────────────┤
│     InteractionController     │       InteractionPromptController      │
│  - Proximity scanner (10 Hz)  │  - Context-sensitive key badges        │
│  - Hold progress tracking     │  - Responsive Desktop / Mobile / Gamepad│
│  - Instant / Hold dispatch    │  - Smooth progress bar & toast alerts  │
└───────────────┬───────────────┴────────────────────────────────────────┘
                │  RemoteFunction: InteractRequest (START / COMPLETE / INSTANT)
                │  RemoteEvent: CancelInteraction
                ▼
┌────────────────────────────────────────────────────────────────────────┐
│                       SERVER (ServerScriptService)                     │
├────────────────────────────────────────────────────────────────────────┤
│                           InteractionService                           │
│  - Master lifecycle (OnInit / OnStart)                                 │
│  - State machine dispatch & synchronization                            │
│  - Item consumption & inventory integration                            │
│  - Random loot distribution via LootTables                             │
│  - Event dispatch: DoorOpened, GeneratorRepaired, TerminalActivated...  │
├────────────────────────────────────────────────────────────────────────┤
│                          InteractionValidator                          │
│  - Player & object existence checks                                    │
│  - Euclidean distance validation (+ 2.5 studs latency buffer)          │
│  - Line-of-sight raycasts (occlusion detection)                        │
│  - Authoritative player state checks (ALIVE vs DOWNED / DEAD)          │
│  - Keycard clearance level verification (Levels 1 to 5)                │
│  - Inventory item presence & slot index resolution                     │
│  - Anti-exploit hold duration timing (rejects premature completes)     │
│  - Drift distance validation during active holds                       │
│  - Anti-spam rate-limiting cooldowns (player & object)                 │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Server-Authoritative Security Model

### Never Trust the Client
Clients are treated as untrusted display terminals. All interaction outcomes, item exchanges, state transitions, and door locks are determined exclusively by `InteractionValidator` on the server:

1. **Distance Validation**: Euclidean distance between the player's `HumanoidRootPart` and the object's world pivot is evaluated on every interaction action. Requests exceeding `def.Distance + 2.5 studs` are immediately rejected with `TOO_FAR`.
2. **Line of Sight (LoS)**: When `RequiresLineOfSight = true`, the server conducts a raycast from `HumanoidRootPart + RaycastOffset` toward the target. If an opaque static part obstructs the ray, the interaction is blocked with `NO_LINE_OF_SIGHT`.
3. **Player State Gating**: Queries `PlayerStateManager:GetState(player)`. Players who are `DOWNED`, `DEAD`, or `SPECTATING` cannot interact (`WRONG_STATE`).
4. **Anti-Exploit Hold Timing**:
   - When a client sends `Action = "START"`, the server initializes an `ActiveHoldSession` recording `os.clock()` and required duration.
   - When the client sends `Action = "COMPLETE"`, the server calculates `elapsedTime = os.clock() - session.StartTime`. If `elapsedTime < session.Duration - ToleranceGracePeriod (0.35s)`, the request is flagged as an instant completion exploit and denied with `FAILED`.
   - If the player drifts beyond `CancelDistance` during the hold, the session is cancelled with `TOO_FAR`.
5. **Inventory Clearance & Item Verification**: Keycard clearance and required consumable items are queried directly from `InventoryService:GetInventory(player)`. The client cannot spoof possessing an item.

---

## 3. Interaction Types & Domain Objects

| Type | Action Pattern | Typical Objects | Description |
| :--- | :--- | :--- | :--- |
| **`SIMPLE`** | Instant Click / Press | Elevators, Alarms, Quick Buttons | Immediate one-shot activation with anti-spam cooldown. |
| **`HOLD`** | Sustained Button Hold | Search Crates, Terminal Hacks | Requires holding interact button for $T$ seconds. Server validates hold duration. |
| **`PROGRESS`** | Sustained Repair Hold | Power Generators, Comms Dish | Long hold with item consumption and cancel-on-damage triggers. |
| **`TOGGLE`** | Instant State Flip | Doors, Power Switches | Flips between binary states (e.g. `OPEN` $\leftrightarrow$ `CLOSED`, `ON` $\leftrightarrow$ `OFF`). |
| **`REQUIRES_KEYCARD`** | Clearance Check | Security Airlocks, Armory Vaults | Queries inventory for Level 1–5 keycards. Denies if insufficient clearance. |
| **`REQUIRES_ITEM`** | Item Check + Consumption | Fuse Boxes, Fuel Injectors | Consumes designated item from inventory slot upon completion. |
| **`MULTI_PLAYER`** | Synchronized Crew Hold | Airlock Overrides, Self-Destruct | Requires $N$ players to hold simultaneously before triggering. |
| **`SEQUENCE`** | Ordered Inputs | Code Consoles, Matrix Puzzles | Requires correct sequence input (e.g. `[3, 1, 4, 2]`). Resets on error. |
| **`TIMED`** | Two-Stage Race | Reactor Coolant Dumps, Evac | Initial interaction starts countdown timer; second resolves before expiry. |

---

## 4. Keycard Clearance Hierarchy

Clearance levels are strictly hierarchical. Possessing a higher-level keycard grants access to all lower tiers:

- **Level 1 (`KEYCARD_LEVEL_1`)**: General Crew Quarters, Storage Closets, Auxiliary Airlocks.
- **Level 2 (`KEYCARD_LEVEL_2`)**: Research Laboratories, Specimen Containment corridors.
- **Level 3 (`KEYCARD_LEVEL_3`)**: Security Checkpoints, Armory Ante-chambers, Comms Relay.
- **Level 4 / Master (`KEYCARD_MASTER`)**: Reactor Core, Bridge Command, Main Armory Vault.
- **Level 5 (`KEYCARD_LEVEL_5`)**: Black-Site Quarantine, Emergency Self-Destruct Consoles.

---

## 5. Domain Object State Machines

### Doors
```
      ┌──────────┐
      │   OPEN   │◄────────┐
      └────┬─────┘         │
           │ Toggle        │ Valid Keycard /
           ▼               │ Toggle (Unlocked)
      ┌──────────┐         │
      │  CLOSED  ├─────────┘
      └────┬─────┘
           │
     ┌─────┴────────────────┐
     ▼                      ▼
┌──────────┐          ┌──────────┐
│  LOCKED  │          │ LOCKDOWN │
└──────────┘          └──────────┘
```

### Power Generators
```
┌───────────┐    Start Repair     ┌───────────┐    Hold Complete + Fuse    ┌──────────┐
│  DAMAGED  ├────────────────────►│ REPAIRING ├───────────────────────────►│  ACTIVE  │
└───────────┘                     └─────┬─────┘                            └──────────┘
                                        │
                                        │ Cancel / Damage
                                        ▼
                                  ┌───────────┐
                                  │  DAMAGED  │
                                  └───────────┘
```

---

## 6. Network Protocol & Contracts

All interaction networking is routed through `NetworkProtocol`:

### 1. `InteractRequest` (`RemoteFunction`)
- **Direction**: Client $\rightarrow$ Server
- **Rate Limit**: 10 requests / sec (Token Bucket)
- **Payload Schema**:
  ```luau
  {
      ObjectId: string,
      Action: "START" | "COMPLETE" | "CANCEL" | "INSTANT" | "SEQUENCE_STEP",
      ClientTimestamp: number?,
      StepValue: number?,
      Payload: any?,
  }
  ```
- **Response Schema**:
  ```luau
  {
      Success: boolean,
      Feedback: "SUCCESS" | "DENIED" | "TOO_FAR" | "LOCKED" | "ACCESS_GRANTED" | "ACCESS_DENIED" | "MISSING_ITEM" | "WRONG_STATE" | "COOLDOWN" | "FAILED" | "TIMED_OUT" | "NO_LINE_OF_SIGHT",
      ObjectId: string,
      NewState: string?,
      Message: string?,
      Data: any?,
  }
  ```

### 2. `CancelInteraction` (`RemoteEvent`)
- **Direction**: Client $\rightarrow$ Server
- **Rate Limit**: 10 requests / sec
- **Payload**: `{ ObjectId: string, Reason: string }`

### 3. `InteractionStateSync` (`RemoteEvent`)
- **Direction**: Server $\rightarrow$ All Clients
- **Payload**: `{ ObjectId: string, State: string, Attributes: any? }`

---

## 7. Multi-Platform Context-Adaptive UI

The `InteractionPromptController` dynamically formats prompts according to the active input platform detected by `InputController`:

| Interaction Type | Desktop (Keyboard/Mouse) | Console (Gamepad) | Mobile (Touch) |
| :--- | :--- | :--- | :--- |
| **Instant Action** | `[ E ]` Open Door | `[ X ]` Open Door | `[ TAP ]` Open Door |
| **Hold Action** | `[ HOLD E ]` Search Crate | `[ HOLD X ]` Search Crate | `[ HOLD ]` Search Crate |
| **Keycard Locked** | Clearance Required: Level 2 | Clearance Required: Level 2 | Clearance Required: Level 2 |
| **Item Required** | Item Required: Grid Fuse | Item Required: Grid Fuse | Item Required: Grid Fuse |
| **Hold Meter** | Green animated fill bar | Green animated fill bar | Green animated fill bar |
| **Toast Alerts** | `ACCESS GRANTED` / `LOCKED` | `ACCESS GRANTED` / `LOCKED` | `ACCESS GRANTED` / `LOCKED` |

---

## 8. Verification & Test Suite

The automated test runner (`tests/Runner.server.luau` and `tests/InteractionSystem.spec.luau`) verifies all 23 scenarios:

1. **Simple Interaction**: Instant trigger, state transition, and feedback codes.
2. **Hold Interaction & Anti-Exploit**: Duration verification and instant completion exploit rejection.
3. **Locked Interaction**: Rejection of access on locked objects without authorization.
4. **Keycard Hierarchy**: Access denial for Level 2 keycard on Level 3 door; access granted with Level 3.
5. **Item-Required Interaction**: Missing item rejection, item detection, and authoritative consumption.
6. **Door Cycle**: Open, close, toggle, and lockdown override blocking.
7. **Generator Repair**: Multi-second repair progress, fuse consumption, and activation state.
8. **Terminal Hacking**: Hold-to-hack duration validation and online state transition.
9. **Switch Mechanics**: On/Off toggling and signal dispatching.
10. **Container Mechanics**: Search hold and transition to OPEN state.
11. **Randomized Loot Generation**: Roll counts and item distribution from loot tables into player inventory.
12. **Elevator System**: Dynamic floor calling (Floor 1 $\leftrightarrow$ Floor 2) and movement state.
13. **Multiplayer Override**: Single player hold yields `REQUIRES_MORE_PLAYERS`; simultaneous dual hold succeeds.
14. **Sequence Puzzle**: Ordered input steps (e.g. `[3, 1, 4, 2]`) with error reset handling.
15. **Timed Interaction**: Timer start, in-time completion success, and expiry failure.
16. **Interaction Cooldown**: Rapid repeated inputs rejected by rate throttling.
17. **Invalid Remote Request**: Handling unregistered IDs and malformed payloads.
18. **Distance Spoofing**: Rejection of requests from players beyond interaction distance.
19. **Line of Sight Raycast**: Physical wall obstruction blocking interaction.
20. **Downed State Prohibition**: Rejection of incapacitated players.
21. **Dead State Prohibition**: Rejection of deceased players.
22. **Player Disconnection During Hold**: Session cleanup and active hold garbage collection.
23. **Multiplayer Concurrency**: Concurrent independent interactions scaled across **1, 2, 4, and 8 players**.
