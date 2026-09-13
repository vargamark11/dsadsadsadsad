# ALIEN: NIGHTFALL — Security & Anti-Exploit Architecture

## Threat Model & Core Invariant

> **"Never Trust the Client."**

In ALIEN: NIGHTFALL, the client is treated exclusively as an untrusted visual and input terminal. All game state, health points, stamina calculations, interaction progress, keycard verifications, and inventory mutations are calculated and committed strictly by the server.

---

## 1. Remote Invocations & Intent-Based Messaging

Clients never send commands that dictate state (e.g., `SetHealth(100)`, `UnlockDoor()`). Clients may only communicate **intents**:
- `InteractRequest:InvokeServer(objectId, "START_HOLD")`
- `SprintRequest:FireServer(true)`
- `FireWeapon:FireServer(origin, direction)`

The server independently evaluates:
1. Is the invoking player currently `ALIVE`?
2. Is the player's character physically loaded in workspace?
3. Is the player within the valid Euclidean interaction distance (default 10 studs + 2.5 studs latency buffer)?
4. Does the player have unobstructed line-of-sight (raycast collision with environment)?
5. Does the player possess the necessary keycard clearance level?
6. Has the hold duration actually elapsed on the server clock (`os.clock()`)?

---

## 2. Token-Bucket Rate Limiting

To prevent DoS, remote spamming, and memory exhaustion from malicious script injectors:
- Every client-to-server remote endpoint passes through a token-bucket rate limiter (`Utilities.CreateRateLimiter`).
- The rate limiter permits bursts up to 15 tokens with a recharge rate of 10 tokens per second.
- Excessive invocations are immediately dropped without allocating memory or firing callbacks.

---

## 3. Hold Interaction Validation & Time Checks

A classic exploit vector in Roblox survival games is spoofing the completion of hold interactions (e.g. instant revives, instant terminal hacking).

### Server Enforcement Pipeline:
1. When a player begins a hold, the server records:
   - `StartTime = os.clock()`
   - `TargetDuration = def.HoldDuration`
   - `InitialPosition = rootPart.Position`
2. When the client sends `COMPLETE_HOLD`:
   - The server verifies `(os.clock() - StartTime) >= TargetDuration * 0.90`.
   - The 10% margin accounts for network ping jitter. Any request arriving faster than 90% of the duration is rejected.
   - The server checks if the player moved beyond the hold drift buffer (3.5 studs). If the player moved away, the hold is voided.

---

## 4. Keycard Clearance Hierarchy

Keycard clearance levels are strictly validated as numerical tiers on the server:
- Level 1: Maintenance & low-security lockers
- Level 2: Bio-research corridors & laboratories
- Level 3: Geothermal powerplant & high-voltage junction
- Master: Command center, armory, and planetary comms array

Players cannot forge clearance; the server checks server-side attributes or secure inventory data stores before granting access.
