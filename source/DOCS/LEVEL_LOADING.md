# Level Loading & Room Translation

This document explains the technical flow of how rooms are loaded from data and how the game transitions between them.

---

## 🗺️ Data Source: `levels.lua`
The game uses a large table called `levelsLDTK` (exported from LDtk) as its world database. Each entry contains:
- **`identifier`**: The room name (e.g., "Room_8").
- **`customFields`**: Critical metadata: `level`, `roomNumber`, `shadow`, `tile`, `visited`, `DoorsConnection`, etc.
- **`entities`**: All objects to spawn (Doors, Props, Enemies, etc.) with coordinates and custom fields.
- **`neighbourLevels`**: Structural data for creating doors and vertical connections.

---

## 🔢 Room Numbering & Translation

**`RoomNumber = (Level × 100) + InternalRoomID`**

*Example: Level 4, Room 8 → `408`.*

Total rooms: **80** (`TOTAL_ROOMS = 80` in `MapDrawer.calculateMapPercent()`).

### `RoomTranslate(roomNumber)`
Located in `utilities/Utilities.lua`:
```lua
function RoomTranslate(roomNumber)
    local floorClass = "Floor" .. roomNumber
    return _G[floorClass]
end
```
Looks up `"Floor408"` in the global Lua table `_G` and returns the class, which `Noble.transition` uses.

---

## 🏗️ The `MazeScene` Loading Flow

### 1. Finding the Room (`setFloor`)
Searches `levelsLDTK` for the entry matching the desired `level` and `roomNumber`.

### 2. Room Setup (`enter`)
- Sets `PlayerData.isInDarkness` and `PlayerData.actualTilemap`.
- Renders the tilemap and creates `FXshadow` if the room is dark.
- Calls `CreateTileColliders` (walls) and `CreateDoorsFromLDTK`.

### 3. Entity Spawning
Iterates room `entities` to spawn Props, Items, Enemies, and CrewMembers based on their state flags (`dead`, `destroyed`, `isTaken`, `collected`).

---

## 🔄 Persistence
- `MazeScene:finish()` calls `SaveSystem.save()` (two call sites) to persist changes on room exit.
- `DanceScene:exit()` also calls `SaveSystem.save()`.
- State is stored in-memory in `levelsLDTK` until saved.

---

## 🗺️ Minimap: `MapDrawer`
Path: `utilities/MapDrawer.lua`

### floorConfig — Important: Inverted Index Order

> [!IMPORTANT]
> `floorConfig` in `MapDrawer.drawMap` uses **inverted array indices**: `floorConfig[1]` describes Level 4 rooms, and `floorConfig[4]` describes Level 1 rooms. The lookup uses `floorConfig[cf.level]` directly, so the index must match the room's `cf.level` field from LDtk.

```lua
local floorConfig = {
    [1] = { cols=5, rows=3, posX=142, posY=73,  startRoom=66 },  -- Level 4: rooms 66–80
    [2] = { cols=7, rows=5, posX=131, posY=18,  startRoom=31 },  -- Level 3: rooms 31–65
    [3] = { cols=5, rows=3, posX=32,  posY=65,  startRoom=16 },  -- Level 2: rooms 16–30
    [4] = { cols=5, rows=3, posX=32,  posY=29,  startRoom=1  },  -- Level 1: rooms 1–15
}
```

**startRoom values**: L4=66, L3=31, L2=16, L1=1.

### Grid Dimensions
- Room cell: **7×7 pixels** (`roomSize = 7`)
- Cell spacing: **6 pixels** (`spacing = 6`)
- Room index on floor: `roomNumber - config.startRoom` (0-based)

### Rendering States
- **Current room** (`PlayerData.actualLevel == level AND actualRoom == roomNumber`): White outer square (5×5), black inner square (3×3).
- **Visited rooms**: White filled square (5×5) at `posX+1, posY+1`.
- **Unvisited rooms**: Dithered background grid only.

### DoorsConnection Case Sensitivity
`DoorsConnection` values in LDtk use **Title Case** (`"Lower"`, `"Upper"`, `"Top"`, `"Down"`, `"Left"`, `"Right"`). The `CanMoveVertically()` function normalizes with `:lower()` before comparing:
```lua
if allowed:lower() == requiredConnection:lower() then
```
Porters must handle this normalization when checking `DoorsConnection`.

---

## 🪜 Vertical Level Navigation System

### Level Connection Architecture

Each room contains two critical fields:

#### `neighbourLevels` Array
Defines adjacent rooms. Each entry:
- `levelIid`: unique identifier of the neighboring room
- `dir`: direction — `"<"` (lower floor), `">"` (upper floor), `"n"`, `"s"`, `"e"`, `"w"` (cardinal)

#### `customFields.DoorsConnection` Array
Permission system for connections (Title Case strings): `"Upper"`, `"Lower"`, `"Top"`, `"Down"`, `"Left"`, `"Right"`.

> [!IMPORTANT]
> A room can have a neighbor without the corresponding permission in `DoorsConnection`. No permission = player cannot use that connection.

### How `fallBelow()` / `riseAbove()` Work

```lua
function Player:fallBelow()
    local lowerRoomNumber, _ = GetLowerRoom(PlayerData.floor)
    if not lowerRoomNumber then return end
    PlayerData.playerSpawn.x = self.x
    PlayerData.playerSpawn.y = self.y
    Noble.transition(RoomTranslate(lowerRoomNumber), 1.5, Noble.Transition.Imagetable, {
        imagetableEnter = Graphics.imagetable.new('assets/images/screens/transitions/transitionFallEnter'),
        imagetableExit  = Graphics.imagetable.new('assets/images/screens/transitions/transitionFallOut'),
    })
end
```

### Helper Functions

#### `GetLowerRoom(currentRoomIndex)`
1. Validates `"Lower"` in `DoorsConnection` via `CanMoveVertically(currentRoom, "<")`.
2. Finds neighbor with `dir = "<"`.
3. Looks up room via `FindRoomByIid(neighbor.levelIid)`.
4. Returns `level * 100 + roomNumber`.

#### `CanMoveVertically(currentRoom, direction)`
```lua
local directionMap = { ["<"] = "lower", [">"] = "upper" }
-- Compares with :lower() for case-insensitive match
```

#### `FindRoomByIid(iid)`
Uses `roomsByIid` hash for O(1) lookup (built in `main.lua`). Linear search fallback.

---

## 💡 Love2D Porting Guide

### 1. Data Structure
`levelsLDTK` is pure Lua/JSON — works identically in Love2D:
```lua
local json = require("json")
local file = love.filesystem.read("assets/data/levels.json")
levelsLDTK = json.decode(file)
```

### 2. Build Hash Indices
```lua
roomsByIid = {}
roomsByNumber = {}
for i, room in ipairs(levelsLDTK) do
    roomsByIid[room.uniqueIdentifer] = room
    local n = room.customFields.level * 100 + room.customFields.roomNumber
    roomsByNumber[n] = room
end
```

### 3. RoomTranslate Without _G
```lua
local SceneRegistry = {}
-- Register each scene:
SceneRegistry[101] = Floor101
-- ...
function RoomTranslate(roomNumber)
    return SceneRegistry[roomNumber]
end
```

### 4. Scene Transition
Replace `Noble.transition` with a scene manager that supports transition types (`"fade"`, `"fall"`, `"slide"`).

### 5. Minimap Canvas
Draw the minimap to a `love.graphics.Canvas` instead of a `Graphics.image`:
```lua
local minimapCanvas = love.graphics.newCanvas(400, 240)
love.graphics.setCanvas(minimapCanvas)
-- ... draw room cells ...
love.graphics.setCanvas()
-- In draw: love.graphics.draw(minimapCanvas, 0, 0)
```

### 6. Vertical Transition Animation
Replace imagetable transitions with shaders or sprite sequences:
```lua
local fallShader = love.graphics.newShader([[
    extern number progress;
    vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pc) {
        vec4 sum = vec4(0.0);
        float blur = progress * 0.05;
        for(float i = -4.0; i <= 4.0; i++) {
            sum += Texel(texture, vec2(tc.x, tc.y + i * blur));
        }
        return sum / 9.0 * color;
    }
]])
```

### 7. Collision Detection for Holes/Tubes
```lua
function Player:checkVerticalTriggers()
    local items, len = world:queryRect(self.x, self.y, self.width, self.height)
    for i = 1, len do
        local item = items[i]
        if item.type == "hole" then self:fallBelow()
        elseif item.type == "tube" then self:riseAbove()
        end
    end
end
```
