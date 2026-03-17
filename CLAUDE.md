# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Game

```bash
# From repo root (macOS)
./run_game.sh

# Or directly with LÖVE
love source/
./love.app/Contents/MacOS/love source/   # using bundled love.app
```

No build step, no package manager, no test framework. LÖVE 11.5 interprets Lua directly.

## Architecture Overview

DinoPirates Love is a top-down dungeon crawler ported from Playdate SDK to LÖVE 2D. It uses a **turn-based movement token system** (not real-time dt-based simulation) — enemy AI consumes "movement tokens" earned each time the player acts.

### Rendering Pipeline

Virtual canvas: **400×240** upscaled to window (default 800×480). `main.lua` renders the current scene to a canvas, then Moonshine applies CRT/scanline/chromatic aberration post-processing effects before blitting to screen.

### Scene System (`sceneManager.lua`)

Scenes implement `enter()`, `exit()`, `update(dt)`, `draw()`. Active scenes: `titleScene.lua` and `gameScene.lua`. Transitions are animated (imagetable-based frame sequences).

### Game Scene (`scenes/gameScene.lua`, ~1315 lines)

Central hub. On room load it:
1. Parses LDtk level data from `assets/data/levels.lua`
2. Instantiates entities (Player, Enemies, Props, Items, Doors, Triggers)
3. Registers all entities with the Bump.lua physics world

Room IDs follow the scheme: `level × 100 + roomNumber` (e.g., room 3 in level 2 = ID 203).

### Player (`entities/player/init.lua`)

Global state lives in `assets/data/PlayerDataTables.lua` (`PlayerData` table). Key subsystems split across files:
- `movements.lua` — 4-directional movement
- `collisions.lua` — enemy/prop/trigger collision responses
- `animations.lua` — anim8 sprite states
- `projectile.lua` / `plunge.lua` — Plungerang weapon
- `items.lua`, `state.lua`, `sanity.lua` — stubs for future systems

### Enemy AI (`entities/Enemy.lua`, `entities/Brocorat.lua`)

AI runs every **3 frames** (throttled). Enemies have a movement token budget capped at 90 frames. States: idle → searching → chasing → attacking. Can be blinded (flash) or destroyed.

### Collision System

Bump.lua handles AABB collision. Collision filter functions in `entities/player/collisions.lua` and `utilities.lua` determine response per entity type. Triggers use `isTouching` checks rather than physics resolution.

### Save System (`SaveSystem.lua`)

Serializes `PlayerData` + per-room entity state (dead enemies, collected items, visited rooms) to JSON. Entity state keyed by LDtk `iid`. Use `SaveSystem.save()` and `SaveSystem.load()`.

### Level Data

`assets/data/levels.lua` — LDtk-exported Lua tables (~79KB). Contains room layouts, entity spawn points, tile data, and trigger definitions for 80 rooms across 4 levels. Do not hand-edit; regenerate from LDtk.

## Key Libraries

| Library | Purpose |
|---|---|
| `libraries/bump.lua` | AABB collision detection |
| `libraries/anim8.lua` | Sprite sheet animation |
| `libraries/moonshine/` | Post-processing (CRT, scanlines) |
| `libraries/hump/` | Timer, Vector, Camera, Class utilities |
| `libraries/Noble/` | UI/menu framework (partial Playdate port) |
| `libraries/middleclass.lua` | OOP class system |

## Documentation

All system documentation is in `DOCS/`. Key files:
- `PLAYER_SYSTEMS.md` — Battery (0–100), sanity/health, size transformation, lighting
- `LEVEL_LOADING.md` — Room numbering scheme, LDtk data structure, minimap
- `ENEMIES_AND_COMBAT.md` — AI states, movement tokens, Dance Scene rhythm combat
- `SAVE_SYSTEM.md` — JSON format, entity state tracking, deepcopy pattern
- `DOORS_AND_KEYS.md` — Door/key mechanics, vertical room transitions
- `TRIGGER_SYSTEM.md` — Event triggers and conditional logic
- `PLUNGERANG.md` — Boomerang weapon mechanics

## Development Notes

- **Turn-based, not real-time**: enemy behavior is token-gated, not dt-scaled. Preserve the 3-frame AI throttle when modifying enemy logic.
- **Virtual resolution**: always draw to the 400×240 canvas space. Never hardcode screen pixel coordinates.
- **Global state**: `PlayerData` is the single source of truth for all persistent player state. Avoid duplicating it in entity instances.
- **LDtk rooms**: query by `iid` string for save/restore. Room loads happen in `gameScene.lua:loadRoom()`.
- **Input**: `main.lua` handles all raw input events (keyboard, mouse, touch, gamepad) and routes to the active scene.
- **Localization**: strings live in `en.strings` / `jp.strings`; do not hardcode UI text.
