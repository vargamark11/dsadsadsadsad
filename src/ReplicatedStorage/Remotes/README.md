# ALIEN: NIGHTFALL — Network Remote Architecture

This directory serves as the synchronization mount point for the `ReplicatedStorage.Remotes` hierarchy in the Roblox DataModel.

## Server-Authoritative Remote Provisioning

All `RemoteEvent` and `RemoteFunction` instances are dynamically instantiated on the server during server startup (`ServerMain.server.luau` via `NetworkRemotes`). Clients and services do not rely on manually pre-placing remotes in Studio.

The server guarantees the existence of the following category folders and remotes:

```
ReplicatedStorage
└── Remotes/
    ├── Player/
    │   ├── SprintRequest (RemoteEvent) [Client -> Server, 10/s]
    │   ├── ReviveInteraction (RemoteFunction) [Client <-> Server, 5/s]
    │   ├── PlayerStateSync (RemoteEvent) [Server -> Client, Unbounded]
    │   └── DownedNotice (RemoteEvent) [Server -> All Clients, Unbounded]
    │
    ├── Interaction/
    │   ├── InteractRequest (RemoteFunction) [Client <-> Server, 10/s]
    │   ├── CancelInteraction (RemoteEvent) [Client -> Server, 10/s]
    │   ├── InteractionStateSync (RemoteEvent) [Server -> All Clients, Unbounded]
    │   └── FeedbackNotice (RemoteEvent) [Server -> Client, Unbounded]
    │
    ├── Mission/
    │   ├── ObjectiveUpdate (RemoteEvent) [Server -> All Clients]
    │   └── MissionStateSync (RemoteEvent) [Server -> Client]
    │
    ├── Combat/
    │   ├── FireWeapon (RemoteEvent) [Client -> Server, 25/s]
    │   ├── ReloadRequest (RemoteEvent) [Client -> Server, 5/s]
    │   └── HitConfirmed (RemoteEvent) [Server -> Client, Unbounded]
    │
    ├── Inventory/
    │   ├── PerformAction (RemoteFunction) [Client <-> Server, 10/s]
    │   └── ContainerSync (RemoteEvent) [Server -> Client, Unbounded]
    │
    ├── Admin/
    │   └── ExecuteAdminCommand (RemoteFunction) [Client <-> Server, 5/s]
    │
    ├── Shop/
    │   ├── PurchaseItem (RemoteFunction) [Client <-> Server, 5/s]
    │   └── EquipCosmetic (RemoteFunction) [Client <-> Server, 5/s]
    │
    └── Events/
        ├── ColonyAlert (RemoteEvent) [Server -> All Clients]
        └── WeatherUpdate (RemoteEvent) [Server -> All Clients]
```

## Security Invariants

1. **Token-Bucket Rate Limiting**: All client-to-server remotes enforce server-side rate limits using `Utilities.CreateRateLimiter`. Excessive request frequencies are dropped immediately.
2. **Authoritative Validation**: Remote invocations only represent *intents*. The server validates player health, state (`ALIVE`), inventory contents, and spatial proximity before executing any mutations.
3. **No Direct State Setting**: Clients never send authoritative state updates (e.g. client cannot send `Health = 100` or `SetState("OPEN")`).
