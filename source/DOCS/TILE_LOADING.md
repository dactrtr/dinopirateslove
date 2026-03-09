# Tile Loading from LDtk

This document explains the technical flow of how the game determines and loads the tiles associated with each level/room defined in LDtk.

## 📄 Data Sources

The system relies on two main data tables in `source/assets/data/`:

1.  **`levels.lua` (`levelsLDTK`)**: Room information exported from LDtk.
2.  **`tilemap.lua` (`tileMapData`)**: Numeric matrices representing tile ID distributions for each room layout.

Total rooms in the game: **80** (defined as `TOTAL_ROOMS = 80` in `MapDrawer.calculateMapPercent()`).

---

## 🔄 Loading Flow

When the player enters a room (`MazeScene:enter`):

### 1. Room Identification
```lua
PlayerData.actualTilemap = levelsLDTK[room].customFields.tile
```

### 2. Retrieval of Tilemap ID
`customFields.tile` is an integer index into `tileMapData`:
```lua
customFields = {
    tile = 8,  -- uses map layout #8
    ...
}
```

### 3. Fetching the Tile Matrix
```lua
renderTileMap(tileMapData[PlayerData.actualTilemap], map)
```

### 4. Rendering (`renderTileMap`)
Defined in `utilities/Utilities.lua`:
```lua
function renderTileMap(tileData, tilemap)
    local height = #tileData
    local width  = #tileData[1]
    tilemap:setSize(width, height)
    for y = 1, height do
        for x = 1, width do
            tilemap:setTileAtPosition(x, y, tileData[y][x])
        end
    end
end
```
The tilemap is assigned to a `floor` sprite at `ZIndex = 1`.

---

## 🧱 Collisions and Walls

### 1. Wall Identification (`SECTION_TILE_IDS`)
`SECTION_TILE_IDS` in `Utilities.lua` is a lookup table of **walkable** tile IDs. Any tile ID **not** in this set is treated as a solid wall.

> [!NOTE]
> The `SECTION_TILE_IDS` table in `Utilities.lua` contains the full set of walkable IDs. The example below shows only one entry for illustration — the actual table may contain many more IDs. Always check the source for the complete set:
> ```lua
> local SECTION_TILE_IDS = {
>     [5] = true,
>     -- ... additional walkable tile IDs in Utilities.lua
> }
> ```

### 2. Collider Optimization (`CreateTileColliders`)
Merges non-walkable tiles into larger rectangles using a two-phase algorithm:
1.  **Phase 1**: Scan each row for contiguous wall tiles → group into horizontal segments.
2.  **Phase 2**: Compare consecutive rows — merge vertically if same X position and width.

This significantly reduces active sprite/collider count.

### 3. The `Box` Class
Merged wall areas are `Box` sprites:
- **Collision Group**: `CollideGroups.wall`
- **`setCollideRect`**: Matches the merged tile area.

---

## 🟩 Slime Tiles (IDs 89–97)

Slime is detected **via the tilemap**, not via prop entities. Tile IDs `89` through `97` represent slime.

- **Detection**: `GetTileUnderPlayer(px, py)` (in `Utilities.lua`) samples the tile ID under the player's 16×16 footprint.
- **Cross-reference**: See [PROPS_AND_ITEMS.md](PROPS_AND_ITEMS.md) for full sliding mechanics.
- **Immunity**: If `PlayerData.items.hasPlunger == true`, the player ignores slime entirely.

---

## 🛠️ Summary of Dependencies

| Component | Role |
|---|---|
| LDtk | Defines which layout each room uses via `tile` custom field |
| `levels.lua` | Bridge: logical room ↔ visual layout ID |
| `tilemap.lua` | Stores all tile matrix layouts |
| `MazeScene.lua` | Orchestrator — reads data, triggers rendering |
| `Utilities.lua` | Executes tile painting; defines `SECTION_TILE_IDS` |

---

## 🛠️ Love2D Porting Guide

### 1. Tilemap Rendering
Replace `Graphics.tilemap` with a `SpriteBatch` or pre-rendered `Canvas`:

```lua
-- Pre-render room tiles to a Canvas on room entry
function renderTileMap(tileData, tilesheet)
    local canvas = love.graphics.newCanvas(400, 240)
    local TILE_SIZE = 16

    love.graphics.setCanvas(canvas)
    for y, row in ipairs(tileData) do
        for x, tileId in ipairs(row) do
            local quad = tileQuads[tileId]  -- pre-built quad lookup
            if quad then
                love.graphics.draw(tilesheet, quad,
                    (x-1) * TILE_SIZE, (y-1) * TILE_SIZE)
            end
        end
    end
    love.graphics.setCanvas()
    return canvas
end
```

### 2. Walkable Tile Check
```lua
local SECTION_TILE_IDS = { [5] = true, --[[ ... check Utilities.lua for full set ]] }

function isWalkable(tileId)
    return SECTION_TILE_IDS[tileId] == true
end
```

### 3. Slime Detection
```lua
local SLIME_TILE_IDS = {}
for i = 89, 97 do SLIME_TILE_IDS[i] = true end

function getTileAt(tileData, px, py)
    local col = math.floor(px / 16) + 1
    local row = math.floor(py / 16) + 1
    if tileData[row] then return tileData[row][col] end
    return nil
end

function Player:checkSlimeTile(tileData)
    if self.isSliding or self.isDashing then return end
    if PlayerData.items.hasPlunger then return end  -- immune
    local id = getTileAt(tileData, self.x, self.y)
    if id and SLIME_TILE_IDS[id] then
        self:startSliding(PlayerData.direction)
    end
end
```

### 4. Wall Colliders
Replicate the two-phase merge algorithm and register merged rectangles in `bump.lua`:
```lua
-- After building merged wall rects:
for _, rect in ipairs(wallRects) do
    local wallObj = { isWall = true }
    world:add(wallObj, rect.x, rect.y, rect.w, rect.h)
end
```
