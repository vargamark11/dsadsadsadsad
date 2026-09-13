# ALIEN: NIGHTFALL — Testing Guide

## Testing Philosophy

Automated testing is critical for multiplayer horror mechanics. Because gameplay is strictly server-authoritative, network exploitation attempts, latency drifts, and state machines are validated against automated test harnesses.

## Test Directory Structure

```
tests/
├── Server/
│   ├── ServerRunner.luau
│   ├── PlayerService.spec.luau
│   └── InteractionService.spec.luau
├── Client/
│   └── InteractionController.spec.luau
└── Shared/
    └── Utilities.spec.luau
```

## Running Tests

### Option A: Test Harness Execution in Roblox Studio
Run the automated test runner in command bar or Studio Test mode:
```luau
local ServerRunner = require(game:GetService("ServerScriptService").AlienNightfall.tests.Server.ServerRunner)
ServerRunner.RunAll()
```

### Option B: Local Headless CI Runner
When running in local Luau environments with test fixtures:
```bash
luau tests/Shared/Utilities.spec.luau
```

## Test Coverage Invariants

1. **Spatial Validation**: Ensures players outside 10 studs + tolerance cannot trigger interactive objects.
2. **Line of Sight**: Validates that raycast collisions with solid walls block interactions.
3. **Keycard Clearance**: Ensures lower-tier clearance cannot unlock higher-tier security terminals.
4. **Token-Bucket Throttling**: Ensures burst remote abuse is cleanly dropped without server crash.
5. **Stamina Depletion**: Validates that sprinting drops stamina to 0 and forces normal walking speed.
