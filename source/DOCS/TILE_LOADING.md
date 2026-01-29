# Tile Loading from LDtk

This document explains the technical flow of how the game determines and loads the tiles associated with each level/room defined in LDtk.

## 📄 Data Sources

The system relies on two main data tables located in `source/assets/data/`:

1.  **`levels.lua` (`levelsLDTK`)**: Contains room information exported from LDtk.
2.  **`tilemap.lua` (`tileMapData`)**: Contains numeric matrices representing the tile distribution (IDs) for each room layout.

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

### 3. Fetching the Tile Matrix
The game uses the retrieved ID (`PlayerData.actualTilemap`) to fetch the data matrix from `tileMapData`.

```lua
-- MazeScene.lua
renderTileMap(tileMapData[PlayerData.actualTilemap], map)
```

### 4. Rendering (`renderTileMap`)
The `renderTileMap` function (defined in `utilities/Utilities.lua`) takes the data matrix and configures the `Graphics.tilemap` object from the Playdate SDK.

```lua
-- utilities/Utilities.lua
function renderTileMap(tileData, tilemap)
  local height = #tileData
  local width = #tileData[1]
  tilemap:setSize(width, height)
  for y = 1, height do
    for x = 1, width do
      -- Assigns the tile ID at position (x, y)
      tilemap:setTileAtPosition(x, y, tileData[y][x])
    end
  end
end
```

Finally, this map is assigned to a sprite (`floor`) which is drawn on screen with Z-Index 1.

---

## 🧱 Collisions and Walls

Beyond rendering, the tilemap is used to generate physical colliders for walls. This logic is handled by `CreateTileColliders` in `utilities/Utilities.lua`.

### 1. Wall Identification
The system identifies which tiles are "non-wall" (sections) using a lookup table. Any tile NOT in this list is considered a wall:

```lua
local SECTION_TILE_IDS = {
    [5] = true,
}
```

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
- **tilemap.lua**: Massive store for all possible tile layouts.
- **MazeScene.lua**: Orchestrator that reads the data and requests the rendering.
- **Utilities.lua**: Technical executor that paints the tiles onto the grid.
