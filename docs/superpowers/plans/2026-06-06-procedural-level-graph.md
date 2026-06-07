# Procedural Level Graph (Roguelike Run) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Playdate roguelike run-graph (procedural rooms, doors, wall plugs, secret-room portals, per-run content, crew assignment, vertical=new-run, persistence) from `source/DOCS/source/` into the live LÖVE game, replacing the fixed-map model in `gameScene.lua`.

**Architecture:** A pure-Lua generator (`MapGenerator`) builds a per-run graph of nodes referencing immutable LDtk templates; `RunState` holds the active run and stages transitions. `gameScene` is **refactored** (not replaced) to drive room loading from `RunState.currentNode()` instead of `neighbourLevels`. Doors/plugs/portals become bump.lua entities. `SaveSystem` serializes `RunState` (format `3.0-PROCGEN`); non-3.0 saves are rejected. Meta-progression (items/skills/crew/sanity/runCount/comics) persists in `PlayerData` across runs.

**Tech Stack:** LÖVE 11.5 (Lua 5.1), bump.lua (AABB), anim8, middleclass, hump; no test framework — verification via `luac -p` (syntax), an in-game `MapGenerator.selfCheck` debug keybind (headless graph invariants), and manual smoke tests with `love source/`.

**Reference implementation (copy-from):** `source/DOCS/source/` contains the Playdate originals:
- `utilities/MapGenerator.lua`, `utilities/RunState.lua`, `utilities/Conditions.lua`
- `entities/props/door.lua` (Door + WallPlug + CreateDoorsFromNode/CreateWallPlugsFromNode), `entities/props/portal_door.lua`
- `scenes/MazeScene.lua` (room-load reference: spawn-at-entry-door, content application)
- `assets/data/Config.lua` (`Config.MapGen`, `Config.Doors.{spawnInset,plug,thickness,span}`)
- `assets/data/levels_floor3.lua`, `levels_floor4.lua` (procGen-authored templates, same `table.insert(levelsLDTK,…)` format)
- `DOCS/PROCEDURAL_GENERATION.md` (the spec — read §§1–17)

**Playdate→LÖVE deltas that recur (apply everywhere during ports):**
- `x += n` / `x -= n` → `x = x + n` / `x = x - n` (LÖVE Lua 5.1 has no compound assignment).
- `class('X').extends(playdate.graphics.sprite|NobleSprite)` → `local X = require 'libraries/middleclass'('X')` style used by existing LÖVE entities (mirror `entities/props/propItem.lua`).
- Sprite auto-draw/`:add()` → explicit `world:add(self, …)` (bump) + manual `:draw()` from the scene; depth via `self.zIndex` like propItem.
- `Graphics.imagetable.new(path):getImage(i)` → `love.graphics.newImage(path..'.png')` + `love.graphics.newQuad(...)` (mirror anim8 grid usage).
- `playdate.getCurrentTimeMilliseconds()` → `love.timer.getTime() * 1000`.
- `math.random` is fine; seed once at boot (Task 1.1).

---

## File Structure

**Created:**
- `source/utilities/MapGenerator.lua` — pure-Lua run-graph generator (port).
- `source/RunState.lua` — active-run state + serialize/deserialize (port). (Root, alongside `SaveSystem.lua`.)
- `source/utilities/Conditions.lua` — `spawnConditions` evaluator (port).
- `source/entities/props/Door.lua` — procedural door (bump entity) + `CreateDoorsFromNode`.
- `source/entities/props/WallPlug.lua` — closed-door wall cover (bump entity + quad-tiled canvas) + `CreateWallPlugsFromNode`.
- `source/entities/props/PortalDoor.lua` — secret-room portal (bump entity) + `CreatePortalsFromNode`.

**Modified:**
- `source/assets/data/levels_floor3.lua`, `source/assets/data/levels_floor4.lua` — replace with DOCS procGen-authored versions.
- `source/assets/data/Config.lua` — add `Config.MapGen`, extend `Config.Doors` (`spawnInset`, `plug`, `thickness`, `span`); confirm `Config.Tiles.IntGrid.hole`.
- `source/main.lua` — seed RNG at boot; `require` the new globals; add `gen-test` debug keybind.
- `source/scenes/gameScene.lua` — drive room load from `RunState`; refactor `loadDoors`→`loadDoorsFromNode`, add `loadWallPlugs`/`loadPortals`; roll per-node content in `loadEnemies`/`loadProps`/crew; spawn at entry door; route door touch → `RunState.goTo` + node transition; start/continue/death/hole/tube → `RunState.startRun`.
- `source/SaveSystem.lua` — replace `levelState` model with `{ version="3.0-PROCGEN", player=PlayerData, run=RunState.serialize() }`; `load()` rejects non-3.0.
- `source/scenes/titleScene.lua` — NewGame → `RunState.startRun()`; Continue → `RunState.deserialize`.

**Deleted/retired (after Phase 2 proves out):** `source/scenes/MazeScene.lua` (unported Playdate copy — never loaded; remove to avoid confusion). The old fixed-map `loadDoors` + `utilities.CreateDoorsFromLDTK` become dead code; remove in Phase 2.

> **Commit policy (user rule):** Do NOT auto-commit. Commit steps below are written for completeness but only run them when the user explicitly asks. See memory `feedback_no_commits.md`.

---

# PHASE 1 — Data + Generator Core (headless, no rendering)

Goal: `MapGenerator.selfCheck` passes for progress 0..12 with the new levels loaded. Nothing visible changes in-game yet.

### Task 1.1: Seed RNG + load new globals at boot

**Files:**
- Modify: `source/main.lua:109` (`love.load`, near the top, before scene loads)

- [ ] **Step 1: Seed the RNG once at boot**

In `love.load()`, add as the first lines (after `love.graphics.setDefaultFilter`):

```lua
	-- Procedural runs need a fresh RNG each boot.
	math.randomseed(os.time())
	math.random(); math.random()  -- discard first couple (Lua 5.1 low-entropy warmup)
```

- [ ] **Step 2: Verify boot still works**

Run: `luac -p source/main.lua && (./love.app/Contents/MacOS/love source/ & P=$!; sleep 3; kill $P)`
Expected: loads clean (existing debug log), no errors.

- [ ] **Step 3: Commit** (only if user asks)
```bash
git add source/main.lua && git commit -m "feat(procgen): seed RNG at boot"
```

---

### Task 1.2: Replace level templates with procGen-authored versions

**Files:**
- Modify: `source/assets/data/levels_floor3.lua` (replace)
- Modify: `source/assets/data/levels_floor4.lua` (replace)

- [ ] **Step 1: Back up and copy the DOCS versions**

```bash
cd source/assets/data
cp levels_floor3.lua levels_floor3.lua.bak
cp levels_floor4.lua levels_floor4.lua.bak
cp ../../DOCS/source/assets/data/levels_floor3.lua levels_floor3.lua
cp ../../DOCS/source/assets/data/levels_floor4.lua levels_floor4.lua
```

- [ ] **Step 2: Confirm format compatibility (both use the same loader)**

`source/assets/data/levels.lua` must still be:
```lua
levelsLDTK = {}
love.filesystem.load('assets/data/levels_floor4.lua')()
love.filesystem.load('assets/data/levels_floor3.lua')()
```
The DOCS files use `table.insert(levelsLDTK, {...})` (same as before) — no `import`, no Playdate calls. Verify:
```bash
grep -c "table.insert(levelsLDTK" source/assets/data/levels_floor3.lua source/assets/data/levels_floor4.lua
grep -c "import\|playdate\." source/assets/data/levels_floor3.lua source/assets/data/levels_floor4.lua   # expect 0
```
Expected: nonzero inserts; zero import/playdate.

- [ ] **Step 3: Confirm procGen metadata is present**
```bash
grep -roh "procGen\|roomRole\|requiredItems\|PortalID\|forceSpawn\|uniqueIdentifer" source/assets/data/levels_floor3.lua source/assets/data/levels_floor4.lua | sort | uniq -c
```
Expected: counts for procGen, roomRole, requiredItems, PortalID, forceSpawn, uniqueIdentifer all > 0.

- [ ] **Step 4: Verify the game still boots with new data (fixed-map path still active)**

Run: `(./love.app/Contents/MacOS/love source/ & P=$!; sleep 3; kill $P)`
Expected: loads clean. (gameScene still uses fixed-map; new templates may have different neighbour data but should not crash on load — if the title→first room transition breaks here, that's expected and fixed in Phase 2; only the *load* must succeed.)

- [ ] **Step 5: Remove backups + commit** (only if user asks)
```bash
rm source/assets/data/levels_floor3.lua.bak source/assets/data/levels_floor4.lua.bak
git add source/assets/data/levels_floor3.lua source/assets/data/levels_floor4.lua
git commit -m "feat(procgen): swap in procGen-authored level templates"
```

---

### Task 1.3: Add Config.MapGen + extend Config.Doors

**Files:**
- Modify: `source/assets/data/Config.lua` (after the existing `Config.Doors` block, ~line 149)

- [ ] **Step 1: Add `Config.MapGen`**

Insert after `Config.Portals` (~line 153):

```lua
-- Procedural run generation (see DOCS/PROCEDURAL_GENERATION.md §16)
Config.MapGen = {
    roomsBase         = 8,
    crewPerExtraRoom  = 1,
    roomsMax          = 20,
    roomsPerCrewSpawn = 4,
    utilityChance     = 0.4,
    totalCrew         = 12,
    enemyChance       = 0.6,
    itemChance        = 0.5,
    darkBiasPerCrew   = 0.02,
}
```

- [ ] **Step 2: Extend `Config.Doors`** with the procedural fields

Inside the existing `Config.Doors = { ... }` table, add these keys (keep `positions` and `spawnCoords`):

```lua
    spawnInset = 32,   -- px the player spawns inward from the door it entered
    thickness  = 10,   -- generic thin-door depth (fallback door)
    span       = 56,   -- generic thin-door length (fallback door)
    plug = {           -- closed-door wall covers (§11)
        tilesheet  = 'assets/images/tile/tile-table-16-16',
        depthTiles = 1,
        trimTiles  = 1,
        tiles = { top = 44, down = 38, left = 42, right = 40 },
    },
```

- [ ] **Step 3: Confirm `Config.Tiles.IntGrid.hole` exists** (the generator's hole detection needs it)
```bash
grep -n "IntGrid" source/assets/data/Config.lua | head
```
Expected: an `IntGrid` table with a `hole = <n>` key. If `hole` is missing, add it matching the LDtk hole IntGrid value already used by `utilities.HOLE_TILE_IDS` (grep `HOLE_TILE_IDS` in `source/utilities.lua` for the value).

- [ ] **Step 4: Confirm the plug tilesheet exists**
```bash
ls source/assets/images/tile/tile-table-16-16.png
```
Expected: file exists. If the name differs, update `Config.Doors.plug.tilesheet` accordingly (it is referenced without `.png`; LÖVE code appends it).

- [ ] **Step 5: Verify syntax**

Run: `luac -p source/assets/data/Config.lua`
Expected: OK.

- [ ] **Step 6: Commit** (only if user asks)
```bash
git add source/assets/data/Config.lua && git commit -m "feat(procgen): add Config.MapGen and Config.Doors plug/inset"
```

---

### Task 1.4: Port `Conditions.lua`

**Files:**
- Create: `source/utilities/Conditions.lua` (from `source/DOCS/source/utilities/Conditions.lua`)

- [ ] **Step 1: Copy the file verbatim, then port deltas**
```bash
mkdir -p source/utilities
cp source/DOCS/source/utilities/Conditions.lua source/utilities/Conditions.lua
```

- [ ] **Step 2: Apply Playdate→LÖVE deltas**

Open `source/utilities/Conditions.lua` and:
- Replace every `+=`/`-=` with explicit `x = x + …`.
- Ensure it ends with `return Conditions` (it must be `require`-able). If the Playdate version assigns a global `Conditions = {}` with no return, add `return Conditions` at the end and keep the global assignment (other ported files reference the global `Conditions`).
- Remove any `import`/`playdate.` lines (there should be none — it's pure string parsing against `PlayerData`).

- [ ] **Step 3: Verify syntax**

Run: `luac -p source/utilities/Conditions.lua`
Expected: OK.

- [ ] **Step 4: Commit** (only if user asks)
```bash
git add source/utilities/Conditions.lua && git commit -m "feat(procgen): port Conditions evaluator"
```

---

### Task 1.5: Port `MapGenerator.lua`

**Files:**
- Create: `source/utilities/MapGenerator.lua` (from `source/DOCS/source/utilities/MapGenerator.lua`)

- [ ] **Step 1: Copy verbatim**
```bash
cp source/DOCS/source/utilities/MapGenerator.lua source/utilities/MapGenerator.lua
```

- [ ] **Step 2: Fix the three `+=` occurrences** (LÖVE has no `+=`)

In `source/utilities/MapGenerator.lua` replace:
- `nextId += 1` (two occurrences, in the start-node block and the path-build loop) → `nextId = nextId + 1`
- `reached += 1` (in `selfCheck`) → `reached = reached + 1`

```bash
grep -n "+=" source/utilities/MapGenerator.lua   # must return nothing after the edit
```
Expected after edit: no matches.

- [ ] **Step 3: Confirm globals it depends on are available**

The generator reads globals `levelsLDTK`, `tileMapData`, `Config`, `PlayerData`, `math.random`, `printDebug`, and assigns global `MapGenerator` (plus `return MapGenerator`). These globals are all defined in `main.lua` before scenes load:
- `Config` (main.lua), `PlayerData` (`require 'assets/data/PlayerDataTables'`), `tileMapData` (`require 'assets/data/tilemap'`), `printDebug` (main.lua), `levelsLDTK` (`require 'assets.data.levels'`).
The file ends with `return MapGenerator` — keep both the global assignment and the return so it works as a `require`d module.

- [ ] **Step 4: Verify syntax**

Run: `luac -p source/utilities/MapGenerator.lua`
Expected: OK.

- [ ] **Step 5: Commit** (only if user asks)
```bash
git add source/utilities/MapGenerator.lua && git commit -m "feat(procgen): port MapGenerator (fix += for Lua 5.1)"
```

---

### Task 1.6: Port `RunState.lua`

**Files:**
- Create: `source/RunState.lua` (from `source/DOCS/source/utilities/RunState.lua`)

- [ ] **Step 1: Copy verbatim**
```bash
cp source/DOCS/source/utilities/RunState.lua source/RunState.lua
```

- [ ] **Step 2: Apply deltas**

- Replace any `+=`/`-=` (none expected, but check: `grep -n "+=" source/RunState.lua`).
- It assigns global `RunState = {…}` and references global `MapGenerator`, `PlayerData`, `levelsLDTK`, `printDebug`. Add `return RunState` at the very end if not present (so it's `require`-able).

- [ ] **Step 3: Verify syntax**

Run: `luac -p source/RunState.lua`
Expected: OK.

- [ ] **Step 4: Commit** (only if user asks)
```bash
git add source/RunState.lua && git commit -m "feat(procgen): port RunState"
```

---

### Task 1.7: Wire requires + a `gen-test` debug keybind

**Files:**
- Modify: `source/main.lua` (requires near top, ~line 37; keypressed handler ~line 278)

- [ ] **Step 1: Require the new modules at boot**

After the existing `require 'assets.data.levels'` chain in `main.lua` (and after `Config`/`PlayerData`/`tileMapData` are loaded — order matters), add:

```lua
require 'utilities.Conditions'    -- global Conditions
require 'utilities.MapGenerator'  -- global MapGenerator
require 'RunState'                -- global RunState
```

> Ensure these come AFTER `Config`, `PlayerData`, `tileMapData`, and `levels` are required, because `MapGenerator` reads them at call time (fine) but `require` order keeps globals defined.

- [ ] **Step 2: Add a `gen-test` keybind** in `love.keypressed(key)` (top of the function, before the CRT toggles)

```lua
	if key == "f9" then
		-- Procedural generator self-check across a range of progress values.
		for progress = 0, (Config.MapGen.totalCrew or 12) do
			local ok, err = pcall(MapGenerator.selfCheck, progress)
			if not ok then print("❌ selfCheck FAILED at progress " .. progress .. ": " .. tostring(err)) end
		end
		print("🎲 gen-test complete")
		return
	end
```

- [ ] **Step 3: Run the self-check**

Run:
```bash
(./love.app/Contents/MacOS/love source/ >/tmp/gen.log 2>&1 & P=$!; sleep 2; \
 osascript -e 'tell application "System Events" to key code 101' 2>/dev/null; sleep 1; kill $P)
grep -E "selfCheck|gen-test|FAILED|unreachable|non-bidirectional|no start" /tmp/gen.log
```
(If sending the F9 keypress via osascript is unreliable, instead temporarily call the Step-2 loop directly at the end of `love.load()`, run `love source/`, read the log, then revert to the keybind.)
Expected: `✅ MapGenerator.selfCheck OK — nodes:N progress:P` for every progress 0..12, then `🎲 gen-test complete`; NO `FAILED`, NO assertion text.

- [ ] **Step 4: If selfCheck asserts "pool has no start/normal rooms"**

That means the new templates' `roomRole`/`procGen` didn't parse into `customFields`. Confirm `buildPool` sees them:
```bash
grep -n "roomRole\|procGen" source/assets/data/levels_floor4.lua | head
```
The values must live under each template's `customFields = { procGen = true, roomRole = "Start"|"Normal"|... }`. If they're nested elsewhere, the LDtk export differs from the DOCS reference — re-export or adjust `buildPool`'s field reads. Do not proceed until selfCheck is green.

- [ ] **Step 5: Commit** (only if user asks)
```bash
git add source/main.lua && git commit -m "feat(procgen): wire generator globals + F9 gen-test self-check"
```

**Phase 1 done when:** F9 `gen-test` prints green selfCheck for progress 0..12.

---

# PHASE 2 — Doors, Wall Plugs, gameScene Integration (playable run)

Goal: A new run generates, the start room loads via `RunState`, doors lead to graph neighbours, unconnected sides are walled off, enemies/props roll per-run. The game is playable end-to-end on a generated graph (no portals/secret rooms yet; final room/save in Phase 4).

### Task 2.1: Port the procedural `Door` entity (bump)

**Files:**
- Create: `source/entities/props/Door.lua` (port of DOCS `door.lua` Door class + `CreateDoorsFromNode`)
- Reference for LÖVE entity idioms: `source/entities/props/propItem.lua`; existing door usage: `source/scenes/gameScene.lua:594` (`Door.new(...)`).

- [ ] **Step 1: Create the class skeleton (middleclass + bump)**

```lua
local Class = require 'libraries/middleclass'
local Door = Class('Door')

-- dir: "top"|"down"|"left"|"right"; targetNodeId: graph node to enter on touch.
-- x,y are the authored LDtk door CENTER; width/height the door size.
function Door:initialize(dir, targetNodeId, x, y, width, height, world)
    self.isDoor       = true
    self.direction    = dir
    self.targetNodeId = targetNodeId
    self.world        = world

    local isH = (dir == 'top' or dir == 'down')
    self.width  = width  or (isH and Config.Doors.span or Config.Doors.thickness)
    self.height = height or (isH and Config.Doors.thickness or Config.Doors.span)
    -- LDtk gives center; bump wants top-left.
    self.x = x - self.width  / 2
    self.y = y - self.height / 2
    self.posCross = isH and x or y   -- cross-axis center, for spawn-at-matching-door
    self.zIndex = ZIndex.props
    world:add(self, self.x, self.y, self.width, self.height)
end

function Door:draw(debug)
    if debug then
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Door:remove()
    if self.world and self.world:hasItem(self) then self.world:remove(self) end
end

return Door
```

> Doors are invisible in the baked room PNG (the opening is part of the art), so `draw` only shows a debug rect. Mirror how `propItem` exposes `:draw(debug)`.

- [ ] **Step 2: Add `CreateDoorsFromNode(node, world, doors)`** at the end of the file (before `return Door`)

Port from DOCS `CreateDoorsFromNode` (door.lua:209). For each `dir, destNodeId in pairs(node.edges)`, instantiate a `Door` for every authored door entity on that side (via `MapGenerator.doorsForSide(template, dir)`), else a single generic door at `Config.Doors.positions[dir]`. Append each to the `doors` array. Keep door positions/sizes from the LDtk entity (`de.x, de.y, de.width, de.height`).

```lua
function Door.createFromNode(node, world, out)
    if not node or not node.poolRoom then return end
    local template = node.poolRoom
    for dir, destNodeId in pairs(node.edges) do
        local list = MapGenerator.doorsForSide(template, dir)
        if #list > 0 then
            for _, de in ipairs(list) do
                out[#out+1] = Door(dir, destNodeId, de.x, de.y, de.width, de.height, world)
            end
        else
            local pos = Config.Doors.positions[dir]
            if pos then out[#out+1] = Door(dir, destNodeId, pos.x, pos.y, nil, nil, world) end
        end
    end
end
```

- [ ] **Step 3: Verify syntax**

Run: `luac -p source/entities/props/Door.lua`
Expected: OK.

- [ ] **Step 4: Commit** (only if user asks)
```bash
git add source/entities/props/Door.lua && git commit -m "feat(procgen): procedural Door entity (bump)"
```

---

### Task 2.2: Port `WallPlug` (quad-tiled wall cover)

**Files:**
- Create: `source/entities/props/WallPlug.lua` (port of DOCS WallPlug + `CreateWallPlugsFromNode`)

- [ ] **Step 1: Create the class — pre-render the brick tile to a Canvas**

```lua
local Class = require 'libraries/middleclass'
local WallPlug = Class('WallPlug')

local sheet, sheetQuads = nil, {}
local function brickQuad(tileIndex)
    if not sheet then
        sheet = love.graphics.newImage(Config.Doors.plug.tilesheet .. '.png')
        sheet:setFilter('nearest', 'nearest')
    end
    local idx = tileIndex or 1
    if not sheetQuads[idx] then
        local ts = Config.Tiles.size
        local cols = math.floor(sheet:getWidth() / ts)
        local col = (idx - 1) % cols
        local row = math.floor((idx - 1) / cols)
        sheetQuads[idx] = love.graphics.newQuad(col*ts, row*ts, ts, ts, sheet:getDimensions())
    end
    return sheet, sheetQuads[idx]
end

function WallPlug:initialize(x, y, w, h, tileIndex, world)
    self.x, self.y, self.width, self.height = x, y, w, h
    self.zIndex = ZIndex.props
    self.world = world
    -- Bake the tiled brick into a canvas once.
    local ts = Config.Tiles.size
    self.canvas = love.graphics.newCanvas(w, h)
    local img, quad = brickQuad(tileIndex)
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()
    for ty = 0, h - 1, ts do
        for tx = 0, w - 1, ts do love.graphics.draw(img, quad, tx, ty) end
    end
    love.graphics.setCanvas()
    world:add(self, x, y, w, h)   -- wall collider
    self.isWall = true
end

function WallPlug:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, self.x, self.y)
end

function WallPlug:remove()
    if self.world and self.world:hasItem(self) then self.world:remove(self) end
end

return WallPlug
```

> The player collision filter in `entities/player/collisions.lua` / `utilities.lua` must treat a WallPlug as solid. Verify the wall filter keys off something a WallPlug has (e.g. a `tileCollider`/`isWall` flag) — if it keys off a class/`type`, set the matching field on WallPlug in Step 1 (e.g. `self.type = 'wall'`). Confirm in Step 4 below.

- [ ] **Step 2: Add `WallPlug.createFromNode(node, world, out)`**

Port from DOCS `CreateWallPlugsFromNode` (door.lua:172): for each authored door whose side is NOT in `node.edges`, compute the plug rect (span = door size + trim; depth from screen edge using 400×240) and create a WallPlug with `Config.Doors.plug.tiles[dir]`. Append to `out`.

```lua
function WallPlug.createFromNode(node, world, out)
    if not node or not node.poolRoom then return end
    local doors = node.poolRoom.entities and node.poolRoom.entities.Doors
    if not doors then return end
    local tile  = Config.Tiles.size
    local cfg   = Config.Doors.plug
    local trim  = (cfg.trimTiles  or 1) * tile
    local depth = (cfg.depthTiles or 1) * tile
    for _, de in ipairs(doors) do
        local conn = de.customFields and de.customFields.DoorsConnection
        local dir  = conn and conn:lower()
        if dir and not node.edges[dir] then
            local hw, hh = (de.width or 0)/2, (de.height or 0)/2
            local x, y, w, h
            if dir == 'top' then x, w, y, h = de.x-hw-trim, de.width+2*trim, 0, depth
            elseif dir == 'down' then x, w, y, h = de.x-hw-trim, de.width+2*trim, 240-depth, depth
            elseif dir == 'left' then x, w, y, h = 0, depth, de.y-hh-trim, de.height+trim
            elseif dir == 'right' then x, w, y, h = 400-depth, depth, de.y-hh-trim, de.height+trim end
            if x then out[#out+1] = WallPlug(x, y, w, h, cfg.tiles and cfg.tiles[dir], world) end
        end
    end
end
```

- [ ] **Step 3: Verify syntax**

Run: `luac -p source/entities/props/WallPlug.lua`
Expected: OK.

- [ ] **Step 4: Confirm the player wall filter will block a WallPlug**

Inspect `source/entities/player/collisions.lua` and `source/utilities.lua` for how static walls are filtered (search `isWall`, `tileCollider`, `type == "wall"`). Set the corresponding marker on WallPlug in Step 1 so the player's bump filter returns `'slide'`/`'touch'` against it. (Verified in-game in Task 2.6.)

- [ ] **Step 5: Commit** (only if user asks)
```bash
git add source/entities/props/WallPlug.lua && git commit -m "feat(procgen): WallPlug wall cover (quad-tiled canvas + bump)"
```

---

### Task 2.3: gameScene — resolve room from `RunState` instead of fixed index

**Files:**
- Modify: `source/scenes/gameScene.lua` (`enter`/`reloadCurrentRoom` ~332–447; `currentRoom`/`currentLevelData` setters ~244–248)
- Require `Door`, `WallPlug` at top of `gameScene.lua` (near the existing requires ~line 8).

- [ ] **Step 1: Add requires + a node→template resolver**

At the top requires of `gameScene.lua`:
```lua
local Door     = require 'entities.props.Door'
local WallPlug = require 'entities.props.WallPlug'
```
Add a helper on the gameScene table:
```lua
-- Point gameScene.currentRoom/currentLevelData at the template for a graph node.
function gameScene.bindNode(node)
    local template = node and node.poolRoom
    if not template then return false end
    for i, lvl in ipairs(levelsLDTK) do
        if lvl == template then
            gameScene.currentRoom = i
            gameScene.currentLevelData = lvl
            PlayerData.floor = i
            return true
        end
    end
    return false
end
```

- [ ] **Step 2: On scene enter, consume the pending node and bind it**

In `gameScene.enter()` (line 332), BEFORE `reloadCurrentRoom()`/room load, insert:
```lua
	-- Procedural: resolve the room from the active run graph.
	if RunState then
		RunState.consumePending()
		if not RunState.currentNode() then
			RunState.startRun()
			RunState.consumePending()
		end
		gameScene.bindNode(RunState.currentNode())
	end
```

- [ ] **Step 3: Verify boot + first room loads from the graph**

Run: `(./love.app/Contents/MacOS/love source/ >/tmp/s.log 2>&1 & P=$!; sleep 4; kill $P); grep -iE "error|traceback|CurrentRoom|Room index" /tmp/s.log`
Expected: loads clean; the first room bound is a `roomRole="Start"` template. (Doors won't work yet — next tasks.)

- [ ] **Step 4: Commit** (only if user asks)
```bash
git add source/scenes/gameScene.lua && git commit -m "feat(procgen): gameScene binds room from RunState node"
```

---

### Task 2.4: gameScene — doors & wall plugs from the node

**Files:**
- Modify: `source/scenes/gameScene.lua` (`loadDoors` ~540; `reloadCurrentRoom` ~403; `clearCurrentRoom` ~101; draw loop)

- [ ] **Step 1: Replace `loadDoors` body with node-driven creation**

Rewrite `gameScene.loadDoors()` to:
```lua
function gameScene.loadDoors()
    for _, d in ipairs(gameScene.doors) do d:remove() end
    gameScene.doors = {}
    gameScene.wallPlugs = gameScene.wallPlugs or {}
    for _, p in ipairs(gameScene.wallPlugs) do p:remove() end
    gameScene.wallPlugs = {}
    local node = RunState and RunState.currentNode()
    if not node then return end
    Door.createFromNode(node, gameScene.world, gameScene.doors)
    WallPlug.createFromNode(node, gameScene.world, gameScene.wallPlugs)
    printDebug("🚪 doors:" .. #gameScene.doors .. " plugs:" .. #gameScene.wallPlugs)
end
```

- [ ] **Step 2: Clean up plugs in `clearCurrentRoom`** (line ~101)

Add alongside the door cleanup:
```lua
	if gameScene.wallPlugs then
		for _, p in ipairs(gameScene.wallPlugs) do p:remove() end
		gameScene.wallPlugs = {}
	end
```

- [ ] **Step 3: Draw doors (debug) + wall plugs**

In the scene draw, where props are drawn, add a pass for `gameScene.wallPlugs` (`p:draw()`), and doors only when a debug flag is on (`d:draw(gameScene.debugColliders)`). Wall plugs draw their baked canvas; doors are invisible otherwise.

- [ ] **Step 4: Remove the dead fixed-map door code**

Delete the old `neighbourLevels`/`leadsTo` resolution inside the former `loadDoors` and the now-unused `utilities.CreateDoorsFromLDTK` call. (Leave `utilities.CreateDoorsFromLDTK` itself for now; remove in cleanup Task 4.6.)

- [ ] **Step 5: Verify syntax + boot**

Run: `luac -p source/scenes/gameScene.lua && (./love.app/Contents/MacOS/love source/ >/tmp/s.log 2>&1 & P=$!; sleep 4; kill $P); grep -iE "error|traceback|doors:|plugs:" /tmp/s.log`
Expected: OK; logs `🚪 doors:N plugs:M` with N = number of connected sides.

- [ ] **Step 6: Commit** (only if user asks)
```bash
git add source/scenes/gameScene.lua && git commit -m "feat(procgen): doors & wall plugs from graph node"
```

---

### Task 2.5: gameScene — door touch transitions to the graph neighbour

**Files:**
- Modify: `source/scenes/gameScene.lua` (`performChangeLevel` ~857; the player/door overlap check in `update`; `Door:goTo` equivalent)

- [ ] **Step 1: Detect player↔door overlap and stage the node transition**

In the update loop where the player's movement/collisions are resolved, after a move, query bump for overlaps and, on touching a `Door`, record the crossing and go:
```lua
	-- Door crossing → enter the target node.
	if PlayerData.isGaming and gameScene.player then
		local px, py, pw, ph = gameScene.world:getRect(gameScene.player)
		local items = gameScene.world:queryRect(px, py, pw, ph)
		for _, it in ipairs(items) do
			if it.isDoor and it.targetNodeId then
				PlayerData.lastRoom = it.direction          -- side we exit through
				PlayerData.lastDoorCross = it.posCross       -- which door on that side
				RunState.goTo(it.targetNodeId)
				gameScene.enterPendingNode()
				break
			end
		end
	end
```

- [ ] **Step 2: Add `gameScene.enterPendingNode()`** — the node-transition entry point (replaces `performChangeLevel`)

```lua
function gameScene.enterPendingNode()
    RunState.consumePending()
    gameScene.bindNode(RunState.currentNode())
    -- Reuse the existing transition (same scene → same scene), then reload from node.
    sceneManager.startTransition("game", "game", "slide")
end
```
On the transition completing, `gameScene.enter()` runs (Task 2.3 Step 2 binds the node and `reloadCurrentRoom()` rebuilds everything). Confirm `startTransition("game","game",…)` re-runs `enter`; if it only calls `reloadCurrentRoom`, call `gameScene.bindNode` + `reloadCurrentRoom` directly here instead.

- [ ] **Step 3: Spawn at the entry door** (port from DOCS MazeScene `enter`, lines 132–194)

In `reloadCurrentRoom()` (or a `gameScene.computeSpawn(node)` helper called before `Player` is created), compute the spawn from `PlayerData.lastRoom`/`lastDoorCross`:
- `entrySide = MapGenerator.opposite(PlayerData.lastRoom)` (nil on fresh run → use first door).
- Among `MapGenerator.doorsForSide(template, entrySide)`, pick the door whose cross-axis center is closest to `PlayerData.lastDoorCross`.
- Offset the player body inward by `Config.Doors.spawnInset`, centering on the door's cross axis (use `Config.Player.collideRect` to align the body, per the DOCS comment).
- Write `PlayerData.playerSpawn.x/y` (unless `PlayerData.returningInPlace`).

Copy the exact arithmetic from DOCS `MazeScene.lua:163–194`.

- [ ] **Step 4: Smoke test a full run on the graph**

Run `love source/`, start a new game, walk through a door.
Expected: transition fires, you arrive in the connected room spawned at the facing door; unconnected sides are walled (can't walk into the void); walking back returns you through the matching door. No crash.

- [ ] **Step 5: Commit** (only if user asks)
```bash
git add source/scenes/gameScene.lua && git commit -m "feat(procgen): door touch → RunState node transition + entry-door spawn"
```

---

### Task 2.6: gameScene — per-node content (enemies, utilities, crew)

**Files:**
- Modify: `source/scenes/gameScene.lua` (`loadEnemies` ~461; `loadProps` ~657; crew spawn)
- Reference: DOCS `MazeScene.lua:266–413` (props utility gating, enemies from `node.content`, crew).

- [ ] **Step 1: Enemies from `node.content.enemies`, corpses from `node.cleared`**

Rewrite `loadEnemies()` to iterate `RunState.currentNode().content.enemies` (already rolled by the generator) instead of scanning `levelsLDTK[room].entities`. For each entry: if `node.cleared.enemies[e.key]` spawn a blood/debris prop at the recorded position; else spawn `Brocorat`/`Bosscolli` by `e.kind` with `e.key`. When an enemy dies, record `node.cleared.enemies[e.key] = {x,y}` (find the death hook in `Enemy.lua`/`Brocorat.lua` and write into the node).

- [ ] **Step 2: Utilities (microwave/minifier) gated by `node.content.utilities[iid]`**

In `loadProps()`, when the prop is a `microwave`/`minifier`, only spawn it if `node.content.utilities[prop.iid] == true`. Other props spawn as before.

- [ ] **Step 3: Crew from `node.content.crewId`**

If `node.content.crewId` and not `node.cleared.crewTaken`, spawn `CrewMember` at `node.content.crewSpawn`, passing the crew identity (`node.content.crewId`) and `node.id` (mirror DOCS `MazeScene.lua:408–413`). On capture, set `node.cleared.crewTaken = true` (in addition to the existing `PlayerData.CrewMemberData` update).

- [ ] **Step 4: Smoke test**

Run `love source/`, explore several rooms across two runs.
Expected: enemies/utilities/crew appear per the run roll; a killed enemy stays dead (shows blood) when you re-enter the room within the same run; a captured crew member doesn't respawn in that run.

- [ ] **Step 5: Commit** (only if user asks)
```bash
git add source/scenes/gameScene.lua && git commit -m "feat(procgen): per-node content (enemies/utilities/crew) + within-run clears"
```

**Phase 2 done when:** a generated run is fully playable — doors connect graph neighbours, plugs seal dead sides, content rolls per run, within-run kills/captures persist on revisit.

---

# PHASE 3 — Secret Rooms via Portals

Goal: PortalDoors link to secret rooms (A↔A by `PortalID`), gated by `Conditions` (e.g. `isTiny:true`).

### Task 3.1: Port `PortalDoor` entity + `CreatePortalsFromNode`

**Files:**
- Create: `source/entities/props/PortalDoor.lua` (port of DOCS `portal_door.lua`)
- Reference: DOCS `entities/props/portal_door.lua`; PROCEDURAL_GENERATION.md §7.

- [ ] **Step 1: Read the DOCS source to learn the exact API**

```bash
sed -n '1,200p' source/DOCS/source/entities/props/portal_door.lua
```
Note: `PortalDoor:goTo()` → `RunState.goTo(targetNodeId)` + transition with `PlayerData.returningInPlace=true` (spawn at authored `SpawnX`/`SpawnY`); gating via `Conditions` (`canEnter`); `CreatePortalsFromNode(node)` instantiates portals using `node.portals[pid]` for the target node id.

- [ ] **Step 2: Port to middleclass + bump** (mirror Task 2.1 Door)

- Collide rect from `Config.Portals.collideRect`.
- `self.targetNodeId = node.portals[pid]`, `self.conditions = pd.customFields.Conditions`, `self.spawnX/spawnY = pd.customFields.SpawnX/SpawnY`.
- `PortalDoor.createFromNode(node, world, out)`: iterate `node.poolRoom.entities.PortalDoors`, for each with a `PortalID` present in `node.portals`, create a portal with `targetNodeId = node.portals[pid]`.
- On touch: if `Conditions.met(self.conditions)` (and the tiny-gate passes), set `PlayerData.returningInPlace = true`, `PlayerData.playerSpawn = {x=spawnX, y=spawnY}`, `RunState.goTo(targetNodeId)`, transition; else show the existing BlockedDialog.

- [ ] **Step 3: Verify syntax**

Run: `luac -p source/entities/props/PortalDoor.lua`
Expected: OK.

- [ ] **Step 4: Commit** (only if user asks)
```bash
git add source/entities/props/PortalDoor.lua && git commit -m "feat(procgen): PortalDoor entity + createFromNode"
```

---

### Task 3.2: gameScene — spawn portals + handle portal crossing

**Files:**
- Modify: `source/scenes/gameScene.lua` (`reloadCurrentRoom` doors section; update overlap check; require PortalDoor)

- [ ] **Step 1: Require + spawn portals after doors/plugs**

Add `local PortalDoor = require 'entities.props.PortalDoor'`. In `loadDoors` (or a new `loadPortals`), call `PortalDoor.createFromNode(RunState.currentNode(), gameScene.world, gameScene.portals)` and clean `gameScene.portals` in `clearCurrentRoom`.

- [ ] **Step 2: Portal crossing in update** (alongside the door check, Task 2.5 Step 1)

```lua
		if it.isPortal and it.targetNodeId then
			if Conditions.met(it.conditions) and (not it.requiresTiny or PlayerData.isTiny) then
				PlayerData.returningInPlace = true
				PlayerData.playerSpawn.x, PlayerData.playerSpawn.y = it.spawnX, it.spawnY
				RunState.goTo(it.targetNodeId)
				gameScene.enterPendingNode()
			else
				-- existing BlockedDialog path
			end
			break
		end
```

- [ ] **Step 3: Smoke test a portal pair**

The DOCS data has Room 3 (`procGen`) ↔ Room 81 (secret, `procGen=false`, `PortalID=1`, `Conditions={"isTiny:true"}`). Run a few runs until a host room with a portal appears; shrink (minifier), enter the portal.
Expected: tiny → enter secret room; not tiny → BlockedDialog; returning lands at the portal's authored spawn.

- [ ] **Step 4: Commit** (only if user asks)
```bash
git add source/scenes/gameScene.lua && git commit -m "feat(procgen): portal spawning + gated secret-room crossing"
```

**Phase 3 done when:** portals route to secret nodes with the tiny gate, and the self-check still passes (portals don't affect side-connectivity).

---

# PHASE 4 — Persistence, Run Flow, Final Room, Cleanup

Goal: Saves use `3.0-PROCGEN`; NewGame/death/hole/tube start runs; Continue restores; recruiting all crew reveals the final room → CreditsScene.

### Task 4.1: SaveSystem — serialize/deserialize RunState (3.0-PROCGEN)

**Files:**
- Modify: `source/SaveSystem.lua` (replace `getLevelState`/`restoreLevelState` usage ~29–110, 200+)

- [ ] **Step 1: Save the new shape**

In `SaveSystem.save()`, write:
```lua
local data = {
    version = "3.0-PROCGEN",
    player  = PlayerData,
    run     = RunState.serialize(),
}
```
Remove `levelState = SaveSystem.getLevelState()` from the saved table.

- [ ] **Step 2: Load + reject non-3.0**

In `SaveSystem.load()`:
```lua
if not data or data.version ~= "3.0-PROCGEN" then
    printDebug("⚠️ SaveSystem: rejecting non-3.0 save")
    return false
end
-- restore PlayerData fields from data.player (existing merge logic)
RunState.deserialize(data.run)
```
`deserialize` stages `currentNodeId` as pending, so the next `gameScene.enter` lands on the saved room.

- [ ] **Step 3: Delete dead level-state code**

Remove `getLevelState`/`restoreLevelState` (and their calls). Keep the JSON helper + file IO.

- [ ] **Step 4: Verify syntax + a save/continue round-trip**

Run `love source/`: new game → walk 2 rooms → trigger a save (pause menu / `MazeScene:pause` equivalent) → quit → relaunch → Continue.
Expected: resumes in the same room/run at the saved position; old (pre-3.0) saves are rejected (offer New Game).

- [ ] **Step 5: Commit** (only if user asks)
```bash
git add source/SaveSystem.lua && git commit -m "feat(procgen): SaveSystem 3.0-PROCGEN (serialize RunState, reject old saves)"
```

---

### Task 4.2: titleScene — NewGame starts a run; Continue restores

**Files:**
- Modify: `source/scenes/titleScene.lua` (NewGame/Continue actions)

- [ ] **Step 1: NewGame**

On New Game: reset meta as today, set `PlayerData.runCount = 1`, `RunState.startRun()`, then transition to `game`. `gameScene.enter` consumes the pending start node.

- [ ] **Step 2: Continue**

On Continue: `SaveSystem.load()` (which calls `RunState.deserialize`), set `PlayerData.returningInPlace = true`, transition to `game`.

- [ ] **Step 3: Smoke test the title flows**

Expected: New Game generates a fresh run; Continue resumes the saved run; Delete wipes save + `RunState.clear()`.

- [ ] **Step 4: Commit** (only if user asks)
```bash
git add source/scenes/titleScene.lua && git commit -m "feat(procgen): title NewGame/Continue drive RunState"
```

---

### Task 4.3: Vertical navigation = new run (holes & tubes)

**Files:**
- Modify: `source/entities/player/collisions.lua` (`fallBelow`) and the tube/`riseAbove` path; `source/scenes/gameScene.lua` transition.
- Reference: PROCEDURAL_GENERATION.md §12; DOCS uses `RunState.startRun("startdown"|"startup")`.

- [ ] **Step 1: Hole fall → startdown run**

Where `Player:fallBelow` currently triggers (the hole system from the earlier session), instead of navigating a fixed neighbour, call:
```lua
RunState.startRun("startdown")
gameScene.enterPendingNode()
```

- [ ] **Step 2: Tube rise → startup run** (same, `"startup"`).

- [ ] **Step 3: Smoke test**

Expected: falling through a hole regenerates the run and drops you in a `StartDown` room (fallback Start/normal); meta persists; no softlock.

- [ ] **Step 4: Commit** (only if user asks)
```bash
git add source/entities/player/collisions.lua source/scenes/gameScene.lua && git commit -m "feat(procgen): hole/tube regenerate the run (startdown/startup)"
```

---

### Task 4.4: Final room reveal on full roster → CreditsScene

**Files:**
- Modify: `source/scenes/gameScene.lua` (crew capture path; enter-node endgame check)
- Reference: DOCS `MazeScene.lua:121–124` (mark `pendingEndgame`), `:451–458` (transition to CreditsScene on start), `RunState.revealFinalRoom`.

- [ ] **Step 1: Reveal on full roster**

When a crew capture brings `PlayerData.CrewMemberData.amountTaken` to `Config.MapGen.totalCrew`, call `RunState.revealFinalRoom()` (attaches a `Final`-role node to a free door side; appears next time you enter that node).

- [ ] **Step 2: Endgame on entering the final node**

In `gameScene.bindNode`/enter, if `node.content.isFinal`, set a `pendingEndgame` flag; once the transition completes (scene `start`/first update), `sceneManager.startTransition("game","credits",…)` (or the project's CreditsScene entry).

- [ ] **Step 3: Smoke test** (use a debug shortcut to grant all crew, or lower `Config.MapGen.totalCrew` temporarily)

Expected: recruiting the whole roster opens a final door; entering it ends the run → Credits.

- [ ] **Step 4: Commit** (only if user asks)
```bash
git add source/scenes/gameScene.lua && git commit -m "feat(procgen): final room reveal + endgame transition"
```

---

### Task 4.5: Re-run the self-check + full regression smoke

- [ ] **Step 1: F9 gen-test** across progress 0..12 → all green (Task 1.7).
- [ ] **Step 2: Play a full run** start→several rooms→portal→hole→continue→final room. No crashes; saves round-trip.
- [ ] **Step 3: Confirm `selfCheck` includes secret/final** by spot-checking logs (`nodes:N` grows with progress).

---

### Task 4.6: Remove dead fixed-map code

**Files:**
- Modify: `source/scenes/gameScene.lua`, `source/utilities.lua`
- Delete: `source/scenes/MazeScene.lua` (unported Playdate copy)

- [ ] **Step 1: Delete `source/scenes/MazeScene.lua`** (verify it's not `require`d anywhere first: `grep -rn "MazeScene" source --include=*.lua | grep -v DOCS`).
- [ ] **Step 2: Remove `utilities.CreateDoorsFromLDTK`** and the `neighbourLevels`/`leadsTo`/`performChangeLevel`/`changeLevel` fixed-map helpers in `gameScene.lua` now that all transitions go through `enterPendingNode`.
- [ ] **Step 3: `luac -p` all modified files; boot smoke test.**
- [ ] **Step 4: Commit** (only if user asks)
```bash
git add -A && git commit -m "chore(procgen): remove dead fixed-map level code"
```

**Phase 4 done when:** persistence, run flow, vertical regen, and endgame all work; dead code removed; self-check green.

---

## Risks & Open Questions

1. **LDtk metadata shape.** Plan assumes `customFields.{procGen,roomRole,requiredItems,...}` exactly as in DOCS levels. Task 1.7 Step 4 gates on this; if the export differs, re-export from LDtk or adjust `buildPool` reads.
2. **Player wall filter vs WallPlug.** The player's bump filter must treat WallPlug as solid (Task 2.2 Step 4). If walls are filtered by tile colliders only, WallPlug needs the same marker the filter checks.
3. **Same-scene transition reuse.** `sceneManager.startTransition("game","game",…)` must re-run `enter` (or we call bind+reload directly). Confirm in Task 2.5 Step 2.
4. **Door overlap vs collision.** Doors are `queryRect` overlaps (not solid). Ensure the door rect sits in the open doorway so the player reaches it before any plug/wall.
5. **Enemy death → node.cleared hook.** Requires finding the enemy death site in `Enemy.lua`/`Brocorat.lua` to write `node.cleared.enemies[key]`. Scoped in Task 2.6 Step 1.
6. **Crank/grapple/minifier unaffected.** This plan doesn't touch input; the recently-added trigger-crank and hole systems keep working (holes now also trigger `startRun("startdown")`).
7. **Sanity-driven repeats.** `MapGenerator` allows template repeats once `sanityCounter>0`; ensure `PlayerData.sanityCounter` persists in saves (it's meta).

## Verification summary (no test framework)

- **Syntax:** `luac -p <file>` after every edit.
- **Generator invariants:** F9 `gen-test` → `MapGenerator.selfCheck` (reachability + bidirectional edges) for progress 0..12.
- **Integration:** `love source/` smoke tests per task (door crossing, plugs solid, content rolls, portals, save round-trip, hole regen, endgame).
