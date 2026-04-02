# Tile Loading from LDtk

This document explains the technical flow of how the game determines and loads the tiles associated with each level/room defined in LDtk.

## 📄 Data Sources

The system relies on two main data tables located in `source/assets/data/`:

1.  **`levels.lua` (`levelsLDTK`)**: Contains room information exported from LDtk.
2.  **`tilemap.lua` (`tileMapData`)**: Contains numeric matrices representing the IntGrid tile layout for each room layout.

---

## 🔄 Loading Flow

When the player enters a room (`MazeScene:enter`), the following process occurs:

### 1. Room Identification
The game locates the correct entry in the `levelsLDTK` table using the current level and room number.
This is stored in the `room` variable (table index).

```lua
-- MazeScene.lua
PlayerData.actualTilemap = levelsLDTK[room].customFields.tile
```

### 2. Retrieval of Tilemap ID
Within the `customFields` of the room in `levelsLDTK`, there is a field called **`tile`**.
This field is an **integer** that serves as an index to fetch the corresponding tile matrix from `tileMapData`.

*Example in `levels.lua`:*
```lua
customFields = {
    tile = 8, -- Uses map layout #8
    ...
}
```

### 3. Room Background Rendering
The room visual is **not** rendered via a tilemap object at runtime. Instead, `MazeScene:enter()` loads a **pre-rendered PNG** image file that matches the room layout:

```lua
-- MazeScene.lua (actual implementation)
local roomBgPath = 'assets/images/rooms/room_' .. PlayerData.actualTilemap
local roomBg = Graphics.image.new(roomBgPath)
-- roomBg is assigned to a floor sprite at ZIndex.floor
```

> [!IMPORTANT]
> `renderTileMap` is defined in `utilities/Utilities.lua` and takes a data matrix to configure a `Graphics.tilemap` SDK object (using `tilemap:setSize` and `tilemap:setTileAtPosition`). However, **this function is not called in the current room loading pipeline**. Room visuals come from pre-baked PNG files.

### 4. Tile Data for Collision
The raw tile matrix from `tileMapData[PlayerData.actualTilemap]` is passed directly to `CreateTileColliders` for wall generation — it is used for **physics only**, not for rendering.

---

## 🧱 Collisions and Walls

Beyond rendering, the tilemap matrix is used to generate physical colliders for walls. This logic is handled by `CreateTileColliders` in `utilities/Utilities.lua`.

### 1. Walkable Tile Identification
The system identifies which tiles are "walkable" using the **IntGrid values** from `Config.Tiles.IntGrid`:

```lua
-- Config.lua
Tiles = {
    IntGrid = {
        slime = 2,
        hole  = 3,
        floor = 4,
    }
}
```

Any cell in the tile matrix whose value is NOT one of these walkable IntGrid values is treated as a **wall**. Tile value `0` (empty) and any border/wall value (e.g., `5`) are considered non-walkable.

> [!NOTE]
> The `WALKABLE_TILES` check is based on IntGrid values (`2`, `3`, `4`), not on graphical tile sprite IDs. This distinction matters when porting to other engines.

### 2. Collider Optimization (`CreateTileColliders`)
Instead of creating a collider for every single tile, the system optimizes them into larger rectangles using a two-phase clustering algorithm:

1.  **Phase 1: Horizontal Identification**: Scans each row for contiguous wall tiles and groups them into segments.
2.  **Phase 2: Vertical Merging**: Compares segments between consecutive rows. If two segments have the same horizontal position and width, they are merged into a single taller rectangle.

This significantly reduces the number of active sprites/colliders, improving performance.

### 3. The `Box` Class
Merged areas are instantiated as `Box` objects (a subclass of `playdate.graphics.sprite`).
- **Collision Group**: `CollideGroups.wall`
- **Visuals**: Draws a white rectangle (useful for debugging).
- **Physics**: Uses `setCollideRect` to match the merged tile area.

---

## 🛠️ Summary of Dependencies

- **LDtk**: Defines which layout each room uses via the `tile` custom field.
- **levels.lua**: The bridge connecting the logical room (Room_8) with the visual layout ID.
- **tilemap.lua**: Stores all possible tile matrices (IntGrid data for collision).
- **MazeScene.lua**: Orchestrator that reads the tile ID, loads the pre-rendered PNG, and passes the matrix to `CreateTileColliders`.
- **Utilities.lua**: Technical executor that builds wall colliders from the tile matrix. Also contains `renderTileMap` (currently unused in the room loading pipeline).

---

## 🎮 Love2D Porting Notes

### 1. Room Background
- In Playdate, rooms load pre-rendered PNGs. In Love2D, do the same: `love.graphics.newImage("assets/images/rooms/room_8.png")` and draw it in `love.draw`.
- Alternatively, use **STI (Simple Tiled Implementation)** or **LDtk-love** to render tilemaps dynamically from LDtk JSON exports.

### 2. Tile Matrix for Collisions
The `tileMapData` matrices are pure Lua tables — they transfer to Love2D without changes.

```lua
-- Love2D: Build wall colliders from tileMapData
local TILE_SIZE = 16
local function buildWallColliders(tileData, world)
    -- walkable IntGrid values
    local walkable = { [2]=true, [3]=true, [4]=true }
    for row = 1, #tileData do
        for col = 1, #tileData[row] do
            local val = tileData[row][col]
            if not walkable[val] then
                local x = (col - 1) * TILE_SIZE
                local y = (row - 1) * TILE_SIZE
                world:add({type="wall"}, x, y, TILE_SIZE, TILE_SIZE)
            end
        end
    end
end
```

### 3. Slime and Hole Detection
Slime and holes are identified by IntGrid value at runtime (not graphical tile IDs):

```lua
local INTGRID = { slime=2, hole=3, floor=4 }

function getTileAt(tileData, px, py)
    local col = math.floor(px / TILE_SIZE) + 1
    local row = math.floor(py / TILE_SIZE) + 1
    if tileData[row] then return tileData[row][col] end
    return nil
end

function isSlime(tileData, px, py)
    return getTileAt(tileData, px, py) == INTGRID.slime
end

function isHole(tileData, px, py)
    return getTileAt(tileData, px, py) == INTGRID.hole
end
```

### 4. Collision Merging
The horizontal+vertical merging optimization is pure Lua logic and can be ported directly. Use **bump.lua** as the collision backend instead of Playdate's sprite system:

```lua
world:add({type="wall"}, rectX, rectY, rectW, rectH)
```
