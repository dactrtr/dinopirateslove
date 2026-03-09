# Doors & Keys Documentation

This document explains how the maze navigation works through doors and the security system using keys.

---

## 🚪 Door System

Doors in this game are more than just sprites — they handle the heavy lifting for level transitions.

### 1. Constructor Signature

```lua
Door(direction, status, leadsTo, zIndex, keyNumber, x, y, width, height)
```

| Parameter | Type | Description |
|---|---|---|
| `direction` | string | Internal direction: `"top"`, `"down"`, `"left"`, `"right"` |
| `status` | string | `"open"` or `"closed"` |
| `leadsTo` | number | Destination room ID: `level * 100 + roomNumber` (e.g., level 4 room 8 → `408`) |
| `zIndex` | number | Rendering layer, typically `ZIndex.props` |
| `keyNumber` | number or nil | Required key index; nil if door is keyless |
| `x, y` | number | Position (from LDtk entity coordinates) |
| `width, height` | number | Collision rect size (from LDtk entity dimensions) |

### 2. Types & Directions

- **Directions**: `top`, `down`, `left`, `right` (cardinal) and `upper`, `lower` (stairs).
- **leadsTo formula**: `level * 100 + roomNumber`
    - Example: Level 4, Room 8 → `leadsTo = 408`
    - This is the same as the `RoomNumber` system used throughout the game.

### 3. Room Transitions

Transitions are handled via `Door:goTo()` and `Door:prevRoom(direction)`:
- **`prevRoom`**: Calculates spawn position in the **next** room based on exit direction (e.g., exiting "top" spawns at Y=196 of the next room). Sets `PlayerData.lastRoom`.
- **Navigation**: Uses `Noble.transition` to move to the scene class identified by `leadsTo` via `RoomTranslate(leadsTo)`.

### 4. LDtk Loading

Doors are generated in `MazeScene.lua` via `CreateDoorsFromLDTK(currentRoom)`:
1. Reads `Doors` entities from `currentRoom.entities.Doors`.
2. Reads `DoorsConnection` custom field (Title Case string: `"Top"`, `"Down"`, `"Left"`, `"Right"`, `"Upper"`, `"Lower"`).
3. Converts to lowercase and maps to LDtk direction symbols.
4. Looks up the matching neighbor in `neighbourLevels` by direction symbol.
5. Calculates `leadsTo` via `CalculateLeadsTo(...)`.
6. Creates `Door(direction, open, leadsTo, ZIndex.props, keyNumber, entity.x, entity.y, entity.width, entity.height)`.

### 5. LDtk Direction Mapping (`ConvertLDTKDirection`)

```lua
function ConvertLDTKDirection(dir)
    if dir == ">" then return "down"  -- Staircase up (visually at bottom of screen)
    elseif dir == "<" then return "top"   -- Staircase down (visually at top of screen)
    elseif dir == "n" then return "top"   -- North door
    elseif dir == "s" then return "down"  -- South door
    elseif dir == "e" then return "right" -- East door
    elseif dir == "w" or dir == "o" then return "left"  -- West door ("o" is alternate LDtk notation)
    end
end
```

**Visual inversion for stairs**: In LDtk, `">"` means "upper floor" (staircase going up), but it renders at the **bottom of the screen** (mapped to `"down"`). Conversely, `"<"` (staircase going down to a lower floor) renders at the **top** (mapped to `"top"`). This is intentional — the visual staircase position is inverted relative to its destination.

**The `"o"` case**: LDtk sometimes exports west-facing directions as `"o"` instead of `"w"`. Both are handled.

---

## 🔐 Key System

The game features a locking mechanism that gates progress.

### 1. Key Data Structure

Keys are stored in `PlayerData.keys` as an indexed table:
```lua
PlayerData.keys = {
    [1] = true,   -- Player has key #1
    [2] = false,  -- Player does not have key #2
    -- ...
}
```
Key pickup grants `PlayerData.keys[keyNumber] = true` via `Player:grabKey()`.

> [!WARNING]
> `keyHud.lua` uses the legacy flat boolean `PlayerData.hasKey`. This is a **legacy component** — the actual key check in `collisions.lua` uses `PlayerData.keys[keyNumber]`. Do not rely on `PlayerData.hasKey` when porting.

### 2. Door Lock Check

In `collisions.lua`, when a player hits a `closed` door:
1. Checks `PlayerData.keys[door.keyNumber]`.
2. If `true`: allows passage, calls `door:goTo()`.
3. If `false` / missing: calls `self.dialogUI:addScreen('nokeys')` — shows the locked dialog.

### 3. Global State

Keys collected on any floor are available throughout the game world (stored in `PlayerData.keys` which is part of the global save state).

---

## 🛠️ Love2D Porting Guide

### 1. RoomTranslate Equivalent

Playdate uses `_G[floorClass]` to look up scene classes dynamically:
```lua
function RoomTranslate(roomNumber)
    local floorClass = "Floor" .. roomNumber
    return _G[floorClass]
end
```
In Love2D, maintain a registry table instead:
```lua
local SceneRegistry = {}
SceneRegistry[101] = Floor101Scene
SceneRegistry[102] = Floor102Scene
-- ...

function RoomTranslate(roomNumber)
    return SceneRegistry[roomNumber]
end
```

### 2. Noble.transition Replacement

```lua
-- Love2D equivalent
function Door:goTo()
    local nextScene = RoomTranslate(self.leadsTo)
    SceneManager:switchTo(nextScene, "default", 0.3)
end
```

### 3. Key System

```lua
-- Check if player has a specific key
function hasKey(keyNumber)
    return PlayerData.keys and PlayerData.keys[keyNumber] == true
end

-- On door collision:
if hasKey(door.keyNumber) then
    door:goTo()
else
    dialogUI:addScreen('nokeys')
end
```
