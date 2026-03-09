# Props & Items Documentation

This document details the environment objects (Props) and collectibles (Items) that populate the game world.

---

## 📦 Items (Pickups)

Items are specialized sprites that grant the player new abilities or resources upon contact.

### 1. Item Types & Rendering
Items are implemented in `entities/items/Items.lua`.
- **Tileset**: `assets/images/items/items-key-table-32-32.png`
- **Size & Colliders**: Every item is `32×32` pixels, on the `ZIndex.items` layer.
- **Animation**: All item animations operate at an 8-frame duration.
  - **`boots`**: (Frames 1–3) Prevents falling into holes if battery is available.
  - **`plunger`**: (Frames 4–6) Prevents sliding on slime tiles (89–97).
  - **`lamp`**: (Frames 7–9) Enables visibility in dark rooms; triggers sanity regen logic.
  - **`notes`**: (Frames 10–12) Story-relevant item.
  - **`keycard`**: (Frames 13–15) Grants access to doors with matching `keyNumber`.
  - **`itemgift`**: (Frames 16–18) Generic delivery item — grants items/skills via `grants` field.

### 2. Positioning & Dynamic Grants (LDtk)
```lua
Items(x, y, type, keyNumber, cf.grants)
```
For `itemgift` and `notes`, the `grants` field directly updates `PlayerData`:
- **Format**: `"key1:value1,key2:value2"` (e.g., `"hasPlunger:true"` or `"canFlash:true"`).
- **Conditional Rendering**: Items with a `grants` field are only spawned if the player **does not** already own the granted item/skill.

### 3. Collection & Interaction Flow
When the player collides with an Item:
1. `other:removeAll()` — disables `FXsonar` and removes the sprite.
2. `self:grabKey()`, `self:grabBoots()`, etc. (in `entities/player/items.lua`) are called.
3. Modifies `PlayerData.items.*`, `PlayerData.skills.*`, or `PlayerData.keys[keyNumber] = true`.

### 4. FXsonar
Items emit a visual **FXsonar** ping — a pulsing circle that radiates outward from the item's position. This helps players locate items in dark or visually noisy rooms.
- Sonar is active while the item exists and is disabled via `removeAll()` on collection.
- **Love2D equivalent**: Animated circle with alpha oscillation (e.g., `love.graphics.circle("line", x, y, radius)` where radius and alpha cycle over time).

---

## 🖼️ PropItem System

Props represent interactive furniture and environmental details.

### 1. Visuals and States
Props share a single image sheet (`props.png`) with animation states like `chair`, `table`, `microwave`, `fridge`, etc.
- **Debris**: When destroyed, state changes to `debris`.
- **Z-Index**: Updated every frame based on Y position (pseudo-3D depth sort), unless "flat" (blood, holes) or special (minifiers).
- **Configuration**: `PropItem:init` uses a centralized `propConfigs` table for colliders, `isEdible`, `isHole`, `isSlime` flags, and Z-Index overrides.

### 2. Environmental Hazards & Utility

- **Holes**: Prop types like `holeCenter`, `holeLeft`, etc.
    - **Falling**: Without boots/battery → `self:fallBelow()`.
    - **Walking with boots**: Player drains battery (amount — verify exact value in `entities/player/collisions.lua`).

- **Minifiers**: Two-stage interaction requiring the physical crank:
    1. Standing on minifier → shows "Press A" prompt.
    2. A press → centers player, locks movement (`isGaming = false`).
    3. Crank counter-clockwise → shrink; clockwise → restore normal size.
    4. B press at any time → cancels and restores movement.
    5. Target size reached → movement restored automatically.

- **Slime (Tile IDs 89–97)**: Detected via the **tilemap**, not prop entities.
    - Detection: `GetTileUnderPlayer()` samples tile ID under player's 16×16 footprint.
    - Sliding immunity: `PlayerData.items.hasPlunger == true` → `checkSlimeTile()` returns early.
    - Full sliding mechanics in [PROPS_AND_ITEMS.md slime section below] and cross-referenced in [TILE_LOADING.md](TILE_LOADING.md).

    **Sliding Behavior**:
    - `isSliding = true` locks all directional input.
    - `slidingSpeed = 4` (faster than walk, slower than dash).
    - Direction-based animation states: `slideRight`, `slideDown`, `slideTiny` (if tiny).
    - Stops on tile departure OR wall collision.
    - Exit animations: `slideExitRight`, `slideExitLeft`, `slideExitUp`, `slideExitDown` (or `idle()` if tiny).
    - **`slideHitWall`** flag: set if wall hit while still on slime — prevents re-triggering the slide. Cleared when player presses a new directional key.

### 3. Destruction & Persistence
- **`destroyProp(id)`**: Uses LDtk IID to mark prop as destroyed in `levelsLDTK` (in-memory). Persisted by SaveSystem via IID match.
- **Persistence**: `MazeScene.lua` checks `destroyed` custom field on spawn.

---

## 👥 Entity Interactions

- **CrewMember**:
    - **Solid**: Slides against chairs, tables, walls, enemies.
    - **Pass-through**: Minifier pods, blood, debris, keycards, triggers.
- **Enemies (Brocorat)**: May eat edible props if `powerLevel` is high enough → destroys prop, gains power.

> [!TIP]
> Items use `FXsonar` to ping their location. See FXsonar note above for porting details.

---

## 🛠️ Love2D Porting Guide

### 1. Sprite System (`NobleSprite` → Love2D class)
- Use a class library (`middleclass`, `classic`, etc.) for `PropItem`.
- Store props in a table (`scene.props`) and iterate in `love.draw()`.
- **Animation**: Use `anim8` with a sprite atlas. Load `props.png` once, define frames as `Quad`s on a grid (mostly 32×32).

### 2. Item Management
- Load `items-key-table-32-32.png` once; use `love.graphics.newQuad` for each 3-frame animation range.
- Collision via bump.lua: on overlap, `world:remove(item)` + `table.remove(scene.items, i)`.

### 3. Collision System (bump.lua)
- Props: `world:add(prop, prop.x, prop.y, prop.w, prop.h)`.
- Use `propConfigs` table exactly as-is — it is pure data, engine-agnostic.

### 4. Z-Indexing (Depth Sorting)
```lua
table.sort(scene.entities, function(a, b)
    return a.y + a.height < b.y + b.height
end)
```
Static Z-index props (holes, rugs): force to a low layer — always draw first.

### 5. Slime Sliding (Tile-Based)
```lua
local SLIME_TILE_IDS = {}
for i = 89, 97 do SLIME_TILE_IDS[i] = true end

function Player:checkSlimeTile(tileData)
    if self.isSliding or self.isDashing then return end
    if PlayerData.items.hasPlunger then return end  -- immune

    local id = getTileAt(tileData, self.x, self.y)
    if id and SLIME_TILE_IDS[id] then
        self:startSliding(PlayerData.direction)
    end
end

function Player:updateSliding(tileData, world)
    if not self.isSliding then return end
    local dx, dy = 0, 0
    if     self.slideDir == "left"  then dx = -self.slideSpeed
    elseif self.slideDir == "right" then dx =  self.slideSpeed
    elseif self.slideDir == "up"    then dy = -self.slideSpeed
    elseif self.slideDir == "down"  then dy =  self.slideSpeed
    end
    local actualX, actualY, cols, len = world:move(self, self.x+dx, self.y+dy, self.collisionFilter)
    self.x, self.y = actualX, actualY
    local tileId = getTileAt(tileData, actualX, actualY)
    if len > 0 or not (tileId and SLIME_TILE_IDS[tileId]) then
        self:endSliding(len > 0)
    end
end

function Player:endSliding(hitWall)
    self.isSliding = false
    self.slideDir = nil
    PlayerData.direction = "idle"
    if hitWall then self.slideHitWall = true end
    -- trigger exit animation here
end
```
**Handling `slideHitWall`**: Reset `self.slideHitWall = false` when the player presses a directional key.

### 6. Crank (Minifier) Remapping
- **Mouse**: Scroll wheel up/down.
- **Keyboard**: Q/E or L/R triggers on gamepad.
- Replace crank UI indicator with "Scroll" or trigger button prompt.

### 7. propConfigs
Copy the `propConfigs` table exactly as-is. It is pure data and engine-agnostic. Use it in Love2D's `PropItem` constructor to set `isHole`, collision rects, etc.

### 8. Holes
In Love2D: if player center is within a Hole bounding box, trigger `fallBelow()`.
