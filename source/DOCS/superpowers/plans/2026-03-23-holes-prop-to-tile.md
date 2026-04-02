# Holes: Prop → Tile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate hole obstacles from the LDtk entity/prop system to the tile system, parallel to how slime tiles already work.

**Architecture:** Add `Config.Tiles.hole` with the new tile IDs, create `IsPlayerOnHole()` in `Utilities.lua`, and handle the fall/battery-drain logic in a new `entities/player/hole.lua` file called from `Player:update()`. Remove all `isHole` prop code once the tile path is wired up.

**Tech Stack:** Lua, Playdate SDK, Noble Engine, LDtk (level editor), React export app.

**No test runner** — validation is: `pdc source "DinoPirates from inner space Brocolation.pdx"` compiles clean, then verify in Playdate Simulator.

---

## Pre-requisite (manual, in LDtk)

Before touching any Lua code, the new hole tiles must exist in the LDtk tileset and their numeric IDs must be known.

- [ ] Open the LDtk project and add the hole tile graphics to the tileset (or identify existing tiles that represent holes).
- [ ] Note the assigned tile IDs. They will be the values for `Config.Tiles.hole`.
      Current max walkable/slime ID is **98**. New hole tiles will likely start at **99+**.
- [ ] Re-export levels via the React app → regenerate `levels_floor4.lua` and `levels_floor3.lua` (the orchestrator `levels.lua` stays unchanged).

> Everything below assumes the hole tile IDs are known. Replace `{99, 100, ...}` with the real IDs throughout the plan.

---

## File Map

| File | Change |
|---|---|
| `source/assets/data/Config.lua` | Add `Config.Tiles.hole`, add IDs to `walkable` |
| `source/utilities/Utilities.lua` | Add `HOLE_TILE_IDS` hash + `IsPlayerOnHole()` |
| `source/entities/player/hole.lua` | **New** — `Player:checkHoleTile()` |
| `source/entities/player/init.lua` | Add `import "entities/player/hole"` |
| `source/entities/player/state.lua` | Call `self:checkHoleTile()` in `Player:update()` |
| `source/entities/player/collisions.lua` | Remove `isHole` prop collision block (lines 130–143) |
| `source/entities/player/sliding.lua` | Simplify `not other.isHole` guard (line 82) |
| `source/entities/props/propItem.lua` | Remove all hole entries from `propConfigs`, remove `isHole` property |

---

## Task 1 — Add hole tile IDs to Config and mark as walkable

**Files:**
- Modify: `source/assets/data/Config.lua`

### Context
`Config.Tiles` currently has:
```lua
Config.Tiles = {
    size     = 16,
    walkable = {1,2,3,5,6,50,66,67,68,69,72,73,74,75,77,79,80,81,82,89,90,91,92,93,94,95,96,97,98},
    slime    = {89,90,91,92,93,94,95,96,97,98},
}
```
Slime tiles are in `walkable` so they don't create wall colliders but still trigger the sliding effect. Hole tiles need the same treatment: walkable (no wall collider) but detected separately.

- [ ] **Step 1: Add `Config.Tiles.hole` and append hole IDs to `walkable`**

```lua
Config.Tiles = {
    size     = 16,
    walkable = {1,2,3,5,6,50,66,67,68,69,72,73,74,75,77,79,80,81,82,89,90,91,92,93,94,95,96,97,98,
                99,100},   -- ← replace with actual hole tile IDs
    slime    = {89,90,91,92,93,94,95,96,97,98},
    hole     = {99,100},   -- ← replace with actual hole tile IDs
}
```

- [ ] **Step 2: Compile**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add source/assets/data/Config.lua
git commit -m "feat: add hole tile IDs to Config.Tiles"
```

---

## Task 2 — Add `IsPlayerOnHole()` to Utilities

**Files:**
- Modify: `source/utilities/Utilities.lua`

### Context
`IsPlayerOnSlime()` already exists and works by sampling a 3×3 grid of pixel positions around the player's feet. `IsPlayerOnHole()` is identical in structure — just uses `HOLE_TILE_IDS` instead.

The relevant existing code (reference only, do not change):
```lua
-- lines ~629–644
function GetTileUnderPlayer(px, py)
    local floor = PlayerData.actualTilemap or 1
    local tileX = math.floor(px / TILE_SIZE) + 1
    local tileY = math.floor(py / TILE_SIZE) + 1
    local floorData = tileMapData[floor]
    if not floorData then return nil end
    local row = floorData[tileY]
    if not row then return nil end
    return row[tileX]
end

SLIME_TILE_IDS = {}
for _, id in ipairs(Config.Tiles.slime) do
    SLIME_TILE_IDS[id] = true
end

function IsPlayerOnSlime(px, py)
    local feetY = py + 12
    local halfW = PlayerData.isTiny and 5 or 8
    local xOffsets = { -halfW, 0, halfW }
    local yOffsets = { -4, 0, 4 }
    for _, dx in ipairs(xOffsets) do
        for _, dy in ipairs(yOffsets) do
            local tileID = GetTileUnderPlayer(px + dx, feetY + dy)
            if tileID and SLIME_TILE_IDS[tileID] then
                return true
            end
        end
    end
    return false
end
```

- [ ] **Step 1: Add `HOLE_TILE_IDS` hash and `IsPlayerOnHole()` directly after the slime block**

Find the line `function IsPlayerOnSlime` and add after its closing `end`:

```lua
HOLE_TILE_IDS = {}
for _, id in ipairs(Config.Tiles.hole) do
    HOLE_TILE_IDS[id] = true
end

-- Checks if the player is standing on a hole tile.
-- Uses the same foot-sampling logic as IsPlayerOnSlime.
function IsPlayerOnHole(px, py)
    local feetY = py + 12
    local halfW = PlayerData.isTiny and 5 or 8
    local xOffsets = { -halfW, 0, halfW }
    local yOffsets = { -4, 0, 4 }
    for _, dx in ipairs(xOffsets) do
        for _, dy in ipairs(yOffsets) do
            local tileID = GetTileUnderPlayer(px + dx, feetY + dy)
            if tileID and HOLE_TILE_IDS[tileID] then
                return true
            end
        end
    end
    return false
end
```

- [ ] **Step 2: Compile**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add source/utilities/Utilities.lua
git commit -m "feat: add IsPlayerOnHole() tile detection utility"
```

---

## Task 3 — Create `entities/player/hole.lua`

**Files:**
- Create: `source/entities/player/hole.lua`

### Context
The original prop-collision logic (from `collisions.lua` lines 130–143):
```lua
elseif other:isa(PropItem) and other.isHole then
    if PlayerData.items.hasBoots == true and PlayerData.battery > 0 then
        if PlayerData.isTiny == true then
            self:drainBattery(Config.Battery.drainHoleTiny)
        else
            self:drainBattery(Config.Battery.drainHoleNormal)
        end
        return 'overlap'
    else
        self:fallBelow()
        return 'overlap'
    end
```

The new tile-based version fires from `Player:update()` every frame. The logic is identical: boots+battery → drain; otherwise → fall. Battery drain every frame while standing on the hole is the correct behavior (same as before — the overlap callback fired every frame).

- [ ] **Step 1: Create `source/entities/player/hole.lua`**

```lua
-- Player hole tile handling.
-- Mirrors the old PropItem isHole collision logic but driven by tile detection.

function Player:checkHoleTile()
    -- Guard: skip if already transitioning or in a special movement state
    if self.isDashing or self.isSliding or self.isPlunging or self.isFalling then
        return
    end

    if not IsPlayerOnHole(self.x, self.y) then
        return
    end

    if PlayerData.items.hasBoots == true and PlayerData.battery > 0 then
        -- Only drain battery when the player is actively moving
        -- (preserves the "time moves when you move" contract)
        if PlayerData.isActive then
            if PlayerData.isTiny == true then
                self:drainBattery(Config.Battery.drainHoleTiny)
            else
                self:drainBattery(Config.Battery.drainHoleNormal)
            end
        end
    else
        -- Set flag BEFORE fallBelow() to block re-entry on subsequent frames
        -- while the Noble.transition() is still in progress.
        self.isFalling = true
        self:fallBelow()
    end
end
```

- [ ] **Step 2: Compile**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```
Expected: no errors (function is defined but not yet called).

- [ ] **Step 3: Commit**

```bash
git add source/entities/player/hole.lua
git commit -m "feat: add Player:checkHoleTile() tile-based hole handler"
```

---

## Task 4 — Wire `hole.lua` into the player system

**Files:**
- Modify: `source/entities/player/init.lua`
- Modify: `source/entities/player/state.lua`

### Context
All player sub-files are imported in `init.lua`:
```lua
-- lines 6-17
import "entities/player/animations"
import "entities/player/collisions"
import "entities/player/movement"
import "entities/player/sanity"
import "entities/player/items"
import "entities/player/state"
import "entities/player/dash"
import "entities/player/abilities"
import "entities/player/lightburst"
import "entities/player/sliding"
import "entities/player/projectile"
import "entities/player/plunge"
```

`checkSlimeTile()` is called in `Player:update()` at `state.lua:259`:
```lua
self:checkSlimeTile()
```

- [ ] **Step 1: Add import to `init.lua`** — after the `sliding` import:

```lua
import "entities/player/sliding"
import "entities/player/hole"      -- ← add this line
import "entities/player/projectile"
```

- [ ] **Step 2: Initialize `self.isFalling` in `Player:init()` in `init.lua`** — in the sliding state block (around line 80):

```lua
    -- Sliding state variables
    self.isSliding = false
    self.slidingDirection = nil
    self.slidingSpeed = Config.Slide.speed
    self.slideHitWall = false

    -- Hole state variable
    self.isFalling = false  -- Prevents fallBelow() firing every frame during transition
```

- [ ] **Step 3: Call `checkHoleTile()` in `Player:update()` in `state.lua`** — after `checkSlimeTile()`:

```lua
  -- Check if player is on a slime tile (IDs 89-97)
  self:checkSlimeTile()

  -- Check if player is on a hole tile
  self:checkHoleTile()
```

- [ ] **Step 4: Compile**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```
Expected: no errors.

- [ ] **Step 4: Smoke test in simulator**

Open the `.pdx` in Playdate Simulator. Enter a room that has hole tiles. Confirm:
- Without boots: player falls through immediately.
- With boots + battery: player walks over with battery draining.
- With boots, battery reaches 0 mid-hole: player falls.

- [ ] **Step 5: Commit**

```bash
git add source/entities/player/init.lua source/entities/player/state.lua
git commit -m "feat: wire checkHoleTile() into player update loop, add isFalling guard"
```

---

## Task 5 — Remove hole prop handling

**Files:**
- Modify: `source/entities/player/collisions.lua`
- Modify: `source/entities/player/sliding.lua`
- Modify: `source/entities/props/propItem.lua`

The hole behavior is now fully handled by tiles. Remove all prop-era `isHole` code.

### 5a — `collisions.lua`: remove the hole collision block

Lines 130–143 (the entire `elseif other:isa(PropItem) and other.isHole then` block):

- [ ] **Step 1: Delete the hole block from `collisions.lua`**

Remove these lines entirely:
```lua
  elseif other:isa(PropItem) and other.isHole then
  -- If player has boots with battery, can walk over the hole
  if PlayerData.items.hasBoots == true and PlayerData.battery > 0 then
    if PlayerData.isTiny == true then
      self:drainBattery(Config.Battery.drainHoleTiny)
    else
      self:drainBattery(Config.Battery.drainHoleNormal)
    end
      return 'overlap'
  else
      -- Without boots or without battery = fall
      self:fallBelow()
      return 'overlap'
  end
```

### 5b — `sliding.lua`: simplify hole guard

Line 82 currently reads:
```lua
                if not other.isHole and other.type ~= 'minifier' then
```

Since no `PropItem` will ever have `isHole = true` after this change, simplify to:

- [ ] **Step 2: Update line 82 in `sliding.lua`**

```lua
                if other.type ~= 'minifier' then
```

### 5c — `propItem.lua`: remove all `isHole` code

- [ ] **Step 3: Remove the 9 hole `addState` animation entries from `PropItem:init()` (lines 34–42)**

```lua
  self.animation:addState('holeTopLeft', 24, 24)
  self.animation:addState('holeLeft', 25, 25)
  self.animation:addState('holeBottomLeft', 26, 26)
  self.animation:addState('holeTop', 27, 27)
  self.animation:addState('holeCenter', 28, 28)
  self.animation:addState('holeBottom', 29, 29)
  self.animation:addState('holeTopRight', 30, 30)
  self.animation:addState('holeRight', 31, 31)
  self.animation:addState('holeBottomRight', 32, 32)
```

- [ ] **Step 4: Remove the 9 hole entries from `propConfigs`**

Delete these lines from the `propConfigs` table:
```lua
    holeLeft        = { isHole = true,  isEdible = false, collideRect = {10, 0, 22, 32} },
    holeRight       = { isHole = true,  isEdible = false, collideRect = {0, 0, 22, 32} },
    holeCenter      = { isHole = true,  isEdible = false, collideRect = {0, 0, 32, 32} },
    holeTopLeft     = { isHole = true,  isEdible = false, collideRect = {10, 10, 22, 22} },
    holeTop         = { isHole = true,  isEdible = false, collideRect = {0, 10, 32, 22} },
    holeTopRight    = { isHole = true,  isEdible = false, collideRect = {0, 10, 22, 22} },
    holeBottomRight = { isHole = true,  isEdible = false, collideRect = {0, 0, 22, 22} },
    holeBottom      = { isHole = true,  isEdible = false, collideRect = {0, 0, 32, 22} },
    holeBottomLeft  = { isHole = true,  isEdible = false, collideRect = {10, 0, 22, 22} },
```

- [ ] **Step 5: Remove `isHole` property from `PropItem`**

Remove the default declaration (line 62):
```lua
  self.isHole = false
```

Remove the assignment (line 96):
```lua
  self.isHole = config.isHole or false
```

Remove the `isHole` guard in the collider setup block (line 104):
```lua
    elseif not self.isHole and not self.isTube then
```
→ simplify to:
```lua
    elseif not self.isTube then
```

Remove `isHole` from the no-collider condition (line 120):
```lua
  if self.nocollide or self.isDestroyed or self.isHole or self.type == 'minifier' then
```
→ simplify to:
```lua
  if self.nocollide or self.isDestroyed or self.type == 'minifier' then
```

Remove the `isHole` debug log block (lines 111–113):
```lua
  if self.isHole then
      printDebug("🕳️  Hole created:", type, "at", x, y)
  elseif self.isTube then
```
→ simplify to:
```lua
  if self.isTube then
```

- [ ] **Step 6: Compile**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add source/entities/player/collisions.lua \
        source/entities/player/sliding.lua \
        source/entities/props/propItem.lua
git commit -m "refactor: remove isHole prop system, holes now tile-based"
```

---

## Task 6 — Update LDtk levels and re-export

**Files:**
- `source/assets/data/levels_floor4.lua` (regenerated by React app)
- `source/assets/data/levels_floor3.lua` (regenerated by React app)

- [ ] **Step 1: In LDtk**, open every room that has hole prop entities. Delete the hole entity sprites and paint the corresponding hole tiles on the tile layer instead.

- [ ] **Step 2: Export** from the React app → new `levels_floor4.lua` and `levels_floor3.lua`. The orchestrator `levels.lua` does not change.

- [ ] **Step 3: Verify zero hole entities remain in the exported data**

```bash
grep -r "holeCenter\|holeLeft\|holeRight\|holeTop\|holeBottom" \
     source/assets/data/levels_floor4.lua \
     source/assets/data/levels_floor3.lua
```
Expected: **no output** (zero matches). If any hole type strings appear, the LDtk migration was incomplete — go back and remove the remaining hole entity sprites from those rooms.

- [ ] **Step 4: Compile + full simulator test**

```bash
pdc source "DinoPirates from inner space Brocolation.pdx"
```

Walk through every room with holes. Confirm:
- Hole tiles are visually correct.
- Fall behavior works (no boots → fall).
- Boots + battery drain works.
- Battery running out mid-hole → fall.
- Sliding over a hole tile: player slides through (no fall while sliding — guarded by `self.isSliding` check in `checkHoleTile`).
- Save and reload → holes still present (tile data is static, not saved per-entity).

- [ ] **Step 5: Commit**

```bash
git add source/assets/data/levels_floor4.lua \
        source/assets/data/levels_floor3.lua
git commit -m "feat: replace hole prop entities with hole tiles in all rooms"
```

---

## Verification Checklist

- [ ] `pdc` compiles with no errors or warnings
- [ ] `#levelsLDTK == 18` (room count unchanged) — check via debug menu
- [ ] No hole entities remain in `levelsLDTK` tables
- [ ] Player falls through hole tile without boots
- [ ] Player crosses hole tile with boots + battery draining
- [ ] Battery reaches 0 while on hole → fall
- [ ] Sliding through hole tile: no fall (slide guard active)
- [ ] Dashing through hole tile: no fall (dash guard active)
- [ ] Save/load: room state unchanged (tiles are not saved per-entity)
- [ ] No Lua errors in simulator console (`debug` mode on)
