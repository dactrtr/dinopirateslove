# Procedural Map Rendering + Playdate Level Sync — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Bring the LÖVE port up to the current Playdate reference for (a) procedural graph generation, (b) the in-game-menu map render, and (c) player-skill parity — and load the Playdate's current level pool so both run on identical content.

**Why these are one plan:** The Playdate's new level data (`DOCS/source/assets/data/levels_floor4.lua`) addresses portal destinations by **string room identifier** (`DestRoom = "Room_81"`), which the port's numeric generator (`templateByRoomId`, `DestLevel*100+DestRoom`) cannot read — loading the new levels *requires* porting the new generator. The new generator also assigns each node a **grid cell** (`node.coord = {col,row}`), which the new map renderer (`MapDrawer`) reads to lay out the map. So levels → generator → render are a single coupled change. Skills parity is bundled because it surfaced in the same review.

**Reference (read-only source of truth):** `source/DOCS/source/` — especially `utilities/MapGenerator.lua`, `utilities/MapDrawer.lua`, `utilities/RunState.lua`, `assets/data/Config.lua` (`Config.Map`), `entities/player/grapple.lua`, `entities/player/items.lua`, `scenes/MazeScene.lua` (node.visited).

**Tech stack:** LÖVE 11.5, Lua. No test framework — verification is the headless gen-test harness (below) + `./love.app/Contents/MacOS/love source/` smoke load + visual menu check.

**Conventions:**
- Paths relative to repo root. Game source in `source/`. Never modify `source/DOCS/source/`.
- Port Playdate idioms: `+=` → `x = x + n`; `Graphics.*` → `love.graphics.*`; `import` → `require`/`love.filesystem.load`.
- **Do NOT commit.** Working tree already has unrelated changes — leave them.
- The `canCrossSlime` slime change (2026-06-17) is already done; don't redo it.

**Headless gen-test harness** (rigorous F9 equivalent — recreate at `/tmp/gencheck/main.lua`, run with `./love.app/Contents/MacOS/love /tmp/gencheck`):

```lua
local SRC = '/Users/dactrtr-mini/Documents/GitHub/DinopiratesLove/dinopirateslove/source/'
package.path = package.path .. ';' .. SRC .. '?.lua;' .. SRC .. '?/init.lua'
printDebug = function() end
function love.load()
    Config = require 'assets.data.Config'
    require 'assets.data.PlayerDataTables'
    require 'assets.data.tilemap'
    require 'utilities.Conditions'
    require 'utilities.MapGenerator'
    require 'RunState'
    levelsLDTK = {}
    assert(loadfile(SRC .. 'assets/data/levels_floor4.lua'))()
    print("templates: " .. #levelsLDTK)
    local total = (Config.MapGen and Config.MapGen.totalCrew) or 12
    local allok = true
    for p = 0, total do
        local ok, err, nodes
        for _ = 1, 20 do
            ok, err = pcall(function()
                local g = MapGenerator.generate(p); nodes = #g; MapGenerator.selfCheck(p)
            end)
            if not ok then break end
        end
        print(string.format("progress %2d: %s%s", p, ok and "OK" or ("FAIL -> "..tostring(err)),
            ok and ("  (nodes="..tostring(nodes)..")") or ""))
        if not ok then allok = false end
    end
    print(allok and "\nALL GREEN" or "\nFAILURES")
    love.event.quit()
end
```

---

## Phase 1 — Port the new MapGenerator + sync Playdate levels

Unblocks loading the Playdate level pool. After this phase the game generates runs from the new levels with grid coordinates on every node.

### Task 1.1: String-identifier room lookup

**Files:** Modify `source/utilities/MapGenerator.lua`

- [ ] **Step 1: Add `templateByIdentifier`, keep `templateByRoomId` for any legacy caller**

After the existing `templateByRoomId` function (around line 54-65), add:

```lua
-- Resolve a room template by its LDtk string identifier (e.g. "Room_81"). The
-- Playdate switched portal destinations from numeric RoomID to identifier.
local function templateByIdentifier(identifier)
	for _, tmpl in ipairs(levelsLDTK or {}) do
		if tmpl.identifier == identifier then return tmpl end
	end
	return nil
end
```

- [ ] **Step 2: Switch the portal-secret-room lookup to identifiers**

In `MapGenerator.generate`, the portal pass (around line 398-415) currently does:

```lua
	local secretByRoomId = {}
	...
				local destId = (cf.DestLevel or 0) * 100 + (cf.DestRoom or 0)
				local destTmpl = templateByRoomId(destId)
				if pid and destTmpl then
					local secretId = secretByRoomId[destId]
```

Replace the destination resolution + keying with identifier-based (mirror `DOCS/.../MapGenerator.lua` lines ~193-205):

```lua
	local secretByIdentifier = {}
	...
				local destIdentifier = cf.DestRoom
				local destTmpl = destIdentifier and templateByIdentifier(destIdentifier)
				if pid and destTmpl then
					local secretId = secretByIdentifier[destIdentifier]
```

…and the later `secretByRoomId[destId] = secretId` becomes `secretByIdentifier[destIdentifier] = secretId`.

- [ ] **Step 3: Verify the OLD levels still generate (no coords yet)**

Recreate the harness, run it against the CURRENT (old) `levels_floor4.lua`. Expected: ALL GREEN (this step is logic-neutral for the old numeric data only if old portals used DestRoom strings — if old data used numbers, this step will FAIL on old data, which is expected and fine; proceed to Task 1.3 which swaps the data). Note the result and move on.

### Task 1.2: Grid coordinates on every node

**Files:** Modify `source/utilities/MapGenerator.lua`

Port the grid system from `DOCS/.../MapGenerator.lua` faithfully (`+=` → `x = x + n`). The reference changes are inside `generate` (DOCS lines ~273-490). Specifically:

- [ ] **Step 1: Add the `DIR_OFFSET` constant** near the top (DOCS line 14):

```lua
local DIR_OFFSET = { right = { 1, 0 }, left = { -1, 0 }, top = { 0, -1 }, down = { 0, 1 } }
```

- [ ] **Step 2: Add grid bookkeeping at the top of `generate`** (DOCS lines 273-298): `occupied`, `cellKey(c,r)`, `setCoord(node,c,r)` (sets `node.coord = {col=c,row=r}` and `occupied[cellKey]=node.id`), and `freeCellNear(c,r)` (expanding-ring search). `setCoord(startNode, 0, 0)` after the start node is created.

- [ ] **Step 3: Growth places into EMPTY cells only** (DOCS lines 320-350): when scanning a placed node's free sides, compute the adjacent cell via `DIR_OFFSET[d]` and only pick that side if `not occupied[cellKey(cc,rr)]`; track `tCol,tRow`; `setCoord(node, tCol, tRow)` when the new node is created.

- [ ] **Step 4: Loops connect only physically-adjacent cells** (DOCS lines 388-410): for each placed node `a` with coord `ac`, for each free side `d`, look up `occupied[cellKey(ac.col+off[1], ac.row+off[2])]` → candidate `b`; connect only if `b` exists, opposite side free, and `sidesMatch`. (Replaces the port's exhaustive greedy double loop.)

- [ ] **Step 5: Secret (portal) rooms get a grid cell next to their host** (DOCS lines 460-480): after creating a secret node, give it a free neighbouring cell (cardinal first via `DIR_OFFSET`, else `freeCellNear`) with `setCoord`.

- [ ] **Step 6: Verify with the harness against the OLD data** — Expected: ALL GREEN, and (add a temporary print) every node now has `node.coord`. Remove the temp print after.

### Task 1.3: Sync the Playdate level pool

**Files:** Replace `source/assets/data/levels_floor4.lua`; modify `source/assets/data/levels.lua`; delete-from-load `levels_floor3.lua`

- [ ] **Step 1: Copy the Playdate floor4 over the port's**

```bash
cp source/DOCS/source/assets/data/levels_floor4.lua source/assets/data/levels_floor4.lua
```

- [ ] **Step 2: Load floor4 only (Playdate dropped floor3)**

`source/assets/data/levels.lua` becomes:

```lua
levelsLDTK = {}
-- Match the Playdate: the procedural pool is floor4 only (floor3 was dropped
-- upstream; its 5 rooms are not referenced by floor4).
love.filesystem.load('assets/data/levels_floor4.lua')()
```

Leave the `levels_floor3.lua` file on disk (unreferenced) — don't delete, in case of rollback.

- [ ] **Step 3: Verify generation on the NEW pool**

Run the harness. Expected: `templates: 15` and **ALL GREEN** across progress 0..12 with sane node counts (single-digit to ~20). If any FAIL with "arithmetic on a string" → the identifier switch (Task 1.1) is incomplete; fix before proceeding.

- [ ] **Step 4: Smoke-load the full game**

`cd ... && ./love.app/Contents/MacOS/love source/ > /tmp/love.txt 2>&1 & sleep 6; kill %1` — grep for `error|traceback`: none. Start a New Game from the title and confirm a room loads (no crash entering the procedural run).

---

## Phase 2 — Persist node coords + visited

The map renderer needs `node.coord` (done) and `node.visited`; both must survive Continue (save/load).

### Task 2.1: Track `node.visited` on the run graph

**Files:** Modify `source/scenes/gameScene.lua`

The port currently marks `customFields.visited` on the LDtk template (gameScene ~line 365, 534) — wrong target for the run graph. The Playdate sets `node.visited = true` on entry (`DOCS/.../MazeScene.lua:126`).

- [ ] **Step 1:** In `gameScene.enter()` (or wherever the node is bound after a transition — search for `RunState.currentNode()` / `bindNode`), after the current node is resolved, add:

```lua
	local node = RunState.currentNode()
	if node then node.visited = true end
```

- [ ] **Step 2: Verify** — add a temporary print of `RunState.currentNode().visited` on room entry; New Game, walk through a door, confirm the new room's node prints `visited=true`. Remove the temp print.

### Task 2.2: Serialize/deserialize coord + visited

**Files:** Modify `source/RunState.lua`

Mirror `DOCS/.../RunState.lua` (serialize lines ~103-104, deserialize ~144-145).

- [ ] **Step 1:** In `RunState.serialize`, add `visited = n.visited,` and `coord = n.coord,` to each serialized node (alongside `edges`, `portals`, `isSecret`).

- [ ] **Step 2:** In `RunState.deserialize`, restore `visited = sn.visited,` and `coord = sn.coord,` on each rebuilt node.

- [ ] **Step 3: Verify** — New Game, visit 2-3 rooms, save (whatever triggers `SaveSystem.save()`), then Continue from title; add a temp print dumping `#RunState.graph` and how many nodes have `coord` and `visited` — both should be preserved. Remove temp print. Smoke-load clean.

---

## Phase 3 — Config.Map + MapDrawer + menu rewire

### Task 3.1: Add `Config.Map`

**Files:** Modify `source/assets/data/Config.lua`

Port `DOCS/.../Config.lua` `Config.Map` (lines 264-274), adapting Playdate colors to LÖVE `{r,g,b}` (0..1):

```lua
-- In-game-menu procedural map (rendered by entities/UI/MapDrawer.lua)
Config.Map = {
    panel        = { x = 32, y = 18, w = 140, h = 75 }, -- rect on the menu image the map fits into
    maxCellSize  = 8,    -- cap on per-room box size
    cellGap      = 1,    -- gap between box and its grid cell edge
    lineWidth    = 1,    -- connection line width
    unvisitedAlpha = 0.35, -- alpha for unvisited boxes/edges (replaces Playdate dither)
    secretOffset = { col = 1, row = 0 }, -- cell offset for a visited secret node off its host
    roomColor    = { 1, 1, 1 },          -- room boxes + connection lines (white)
    markerColor  = { 0.196, 0.184, 0.161 }, -- current-room center dot (must contrast roomColor)
}
```

(`unvisitedAlpha` replaces Playdate's `setDitherPattern`; LÖVE has no 1-bit dither here, so unvisited rooms/edges draw at reduced alpha. The whole overlay still passes through the onebit shader downstream for the pixel look.)

- [ ] Verify: `luac -p source/assets/data/Config.lua`; smoke-load clean.

### Task 3.2: Port `MapDrawer` to LÖVE

**Files:** Create `source/entities/UI/MapDrawer.lua`

Port `DOCS/source/utilities/MapDrawer.lua` faithfully. Key adaptations:
- It draws into a target; in LÖVE, expose `MapDrawer.draw(x, y)` that renders **in virtual coords** directly (InGameMenu calls it inside its canvas) — OR `MapDrawer.drawToCanvas()` returning a canvas. Match how Task 3.3 wires it; simplest is a plain `MapDrawer.draw()` that issues `love.graphics` calls at `Config.Map.panel` offsets (the menu canvas is already in virtual space).
- `Graphics.pushContext/popContext` → draw directly (the caller sets the canvas).
- `Graphics.setColor(roomColor)` → `love.graphics.setColor(r,g,b,a)`.
- `Graphics.fillRect` → `love.graphics.rectangle("fill", ...)`; `Graphics.drawLine` → `love.graphics.line(...)`; `setLineWidth` → `love.graphics.setLineWidth`.
- Dither (`setDitherPattern(ditherAlpha, Bayer8x8)`) → draw that box/line at `Config.Map.unvisitedAlpha`.
- Keep `buildLayout(g)` verbatim in logic (phases 1-3 placement from `node.coord`, coord-less nodes nudged via edges, portal links, normalize min col/row = 0).
- Keep `MapDrawer.calculateMapPercent()`.
- Reads `RunState.graph`, `RunState.currentNodeId`, and `node.coord/visited/isSecret/portals`.

- [ ] **Step 1:** Write the module. `luac -p` it.
- [ ] **Step 2:** Headless smoke: a tiny love harness that builds a fake `RunState.graph` of ~5 nodes with coords + one visited secret, calls `MapDrawer.draw()` inside a canvas under `pcall`, asserts no error and `calculateMapPercent()` returns a number 0..100.

### Task 3.3: Rewire InGameMenu to the procedural map

**Files:** Modify `source/entities/UI/InGameMenu.lua`

- [ ] **Step 1:** Replace the body of `InGameMenu:_buildMapCanvas()` (the fixed `floorConfig` + `levelsLDTK` + `cf.visited` loop) with a call into `MapDrawer.draw()` rendered onto the cached canvas. Require `MapDrawer` at top. Remove now-dead `floorConfig`/`MAP_ROOM_SIZE`/`MAP_SPACING` map constants if nothing else uses them (grep first).
- [ ] **Step 2:** If the menu shows a percent, source it from `MapDrawer.calculateMapPercent()` instead of `cf.mapPercent`.
- [ ] **Step 3: Verify (visual)** — run the game, get the D-Watch (or temporarily set `PlayerData.items.hasDWatch = true` and `PlayerData.isEquiping` path), open the menu, walk a few rooms: the map must show the actual run graph (boxes at grid positions, lines between adjacent rooms, current room marked, unvisited dimmer). Take a screenshot to confirm layout.

---

## Phase 4 — Player-skill parity

From the skills review (port vs `DOCS/.../entities/player/*` + `PlayerDataTables.lua`).

### Task 4.1: `canGrapple` skill gates the grappling hook

**Files:** Modify `source/assets/data/PlayerDataTables.lua`, `source/entities/player/grapple.lua`

Playdate gates the grapple on a dedicated `canGrapple` (DOCS `grapple.lua:128`), separate from `canPlungerang`. The port gates it only on `canPlungerang` (`grapple.lua:117`).

- [ ] **Step 1:** Add to the skills table (PlayerDataTables, after `canPlungerang`): `canGrapple = false,` and `canDance = false,` (the latter is used dynamically today; declare it for clarity).
- [ ] **Step 2:** In `source/entities/player/grapple.lua`, at the charge/begin gate (line ~117), add after the existing `canPlungerang` check:

```lua
    if not PlayerData.skills.canGrapple then return end  -- grappling hook requires the canGrapple skill
```

- [ ] **Step 3: Verify** — with `canGrapple=false`, B-charge in light does a tap-plunge but never a grapple pull; after granting `canGrapple` (temp set true), the grapple fires. Smoke-load clean.

### Task 4.2: `canFlash` default parity

**Files:** Modify `source/assets/data/PlayerDataTables.lua`

Port defaults `canFlash = true`; Playdate defaults `false` and grants it on the lamp pickup (`DOCS/.../items.lua:20`; the port already grants it on lamp pickup per collisions). Starting with flash unlocked diverges.

- [ ] **Step 1:** Change `canFlash = true` → `canFlash = false`.
- [ ] **Step 2: Verify** — New Game: flash (B in darkness) does nothing until the lamp is picked up; after lamp, flash works. (Confirm the lamp pickup path sets `canFlash`/`hasLamp`.) Smoke-load clean.

> **Decision needed before this task:** `canFlash=true` may be an intentional testing convenience. Confirm with the user. Also `canDash` is a **port-only** ability (no Playdate equivalent) — leave it as-is unless the user wants parity-by-removal. The `canGrapple`/`canCrossSlime` **grants** live in level data (`grants="canGrapple:true"`); decide which pickup/floor grants them (content task, out of code scope).

---

## Self-Review checklist (run after writing each phase)
- Gen-test harness ALL GREEN after Phase 1 and after any MapGenerator/RunState change.
- `templateByIdentifier`/`secretByIdentifier` names consistent across Task 1.1-1.2.
- `node.coord` shape is `{col=, row=}` everywhere (MapGenerator sets it; RunState round-trips it; MapDrawer reads `.col/.row`).
- No reference left to the removed fixed-map `floorConfig` after Task 3.3 (grep).
- Smoke-load clean after every phase; visual menu check after Phase 3.
