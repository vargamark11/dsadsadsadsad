# ALIEN: NIGHTFALL — Development Guide

## Overview

ALIEN: NIGHTFALL is developed outside of Roblox Studio using standard text editors (VS Code / Cursor), Git, and synchronized to Roblox Studio using Rojo.

## Prerequisites

1. **Rojo CLI**: Version 7.4.0 or newer (`cargo install rojo` or download binary from [GitHub](https://github.com/rojo-rbx/rojo/releases)).
2. **VS Code Extensions**:
   - Rojo (`rojo-rbx.rojo-code`)
   - Luau Language Server (`JohnnyMorganz.luau-lsp`)
   - Selene Linter (`Kampfkarren.selene-vscode`)

## Project Hierarchy

```
AlienNightfall/
├── default.project.json
├── src/
│   ├── ServerScriptService/    # Server-authoritative logic & services
│   ├── ReplicatedStorage/      # Shared libraries, configuration & remotes
│   ├── StarterPlayer/          # Client-side controllers & UI
│   └── Workspace/              # World zone geometry & landmark metadata
├── assets/                     # 3D models, textures, audio specifications
├── tests/                      # Automated server/client test suites
└── docs/                       # Architectural & operational manuals
```

## Running the Rojo Sync Server

To begin live synchronization with Roblox Studio:

```bash
rojo serve default.project.json
```

In Roblox Studio:
1. Install the Rojo Studio Plugin.
2. Open an empty baseplate or existing project place.
3. Click "Connect" in the Rojo plugin window (default port `34872`).

## Code Standards & Best Practices

1. **Strict Typing**: All `.luau` files must begin with `--!strict`.
2. **Server Authority**: The client is never trusted. All state mutations (health, stamina, inventory, doors, locks) must be validated on the server.
3. **No Hardcoded Constants**: Always reference `ReplicatedStorage.Config.*` or `ReplicatedStorage.Shared.Constants`.
4. **Service / Controller Lifecycle**:
   - `OnInit`: Synchronous state preparation and dependency wiring.
   - `OnStart`: Network listener registration and background loops.
