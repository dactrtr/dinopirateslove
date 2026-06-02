# Grapple (Grappling Hook) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the charged grappling-hook variant of the plungerang — hold B + crank (right stick / mouse wheel) to charge launch distance, release to fire a hook that ignores all sprites and only reacts to tiles (grapplePoint = pull; wall/max = boomerang return).

**Architecture:** New module `entities/player/grapple.lua` (enfoque A) defines a `GrappleHook` class (no bump; pure position + tile sampling) plus module functions taking `player` (mirrors `plunge.lua`'s pattern). The hook updates/draws from `Player:update`/`Player:draw` like the existing projectile. Input is wired in `gameScene` (B down → begin charge; B up → resolve grapple-vs-plunge; crank routed by state).

**Tech Stack:** LÖVE 11.5, Lua, middleclass, anim8. **No test framework** — verification is `luac -p` syntax checks plus manual in-game checks.

**Spec:** `docs/superpowers/specs/2026-06-01-grapple-grappling-hook-design.md`

**Commit policy:** This repo's owner commits manually. Commit steps below are written for completeness but DO NOT run `git commit` unless the user explicitly asks. After each task, stage nothing automatically.

---

### Task 1: Config — grapple constants and tile id

**Files:**
- Modify: `source/assets/data/Config.lua`

- [ ] **Step 1: Add `grapplePoint` to IntGrid and `33` to walkable**

In `Config.Tiles`, the `IntGrid` table currently ends with `tinyHole = 32,`. Change it to:

```lua
    IntGrid = {
        wall         = 1,
        slime        = 2,
        hole         = 3,
        floor        = 4,
        tinyHole     = 32,
        grapplePoint = 33,   -- hookable + walkable tile for the grappling hook
    }
```

And add `33` to the `walkable` list (currently `walkable = {0, 2, 3, 4, 32},`):

```lua
    walkable = {0, 2, 3, 4, 32, 33},
```

- [ ] **Step 2: Add `feetOffsetY` and `movementTokensPerAction` to `Config.Player`**

In `Config.Player`, after `movementFramesPerAction = 3,` add:

```lua
    feetOffsetY             = 12,  -- px from sprite position down to the player's feet (tile sampling / grapple landing)
    movementTokensPerAction = 5,   -- movement tokens granted to enemies/crew when a B-ability fires
```

- [ ] **Step 3: Add the `Config.Grapple` table**

After the `Config.Player = { ... }` block closes (before the next `Config.X` table), add:

```lua
-- Grappling hook (charged plungerang)
Config.Grapple = {
    holdDelay       = 400,   -- ms holding B before the charge is "armed" (tap < this = plunge)
    minDistance     = 64,    -- px guaranteed on any armed release (~4 tiles)
    maxDistance     = 320,   -- px cap (~20 tiles)
    pixelsPerDegree = 0.4,   -- crank degrees -> launch distance
    projectileSpeed = 8,     -- px/frame the hook flies out / returns
    pullSpeed       = 8,     -- px/frame the player slides toward the tile
    cooldown        = 500,   -- ms between uses (reserved; NOT enforced, faithful to Playdate)
    ropeWidth       = 2,     -- px width of the rope drawn from player to hook
}
```

- [ ] **Step 4: Syntax check**

Run: `luac -p source/assets/data/Config.lua`
Expected: no output (success).

- [ ] **Step 5: Commit (only if user asks)**

```bash
git add source/assets/data/Config.lua
git commit -m "feat(grapple): add Config.Grapple, grapplePoint tile, feetOffsetY"
```

---

### Task 2: Utilities — walkable tile helper

**Files:**
- Modify: `source/utilities.lua`

The grapple hook bounces on non-walkable tiles. Add a lookup + helper next to the existing `SLIME_TILE_IDS` / `HOLE_TILE_IDS` block.

- [ ] **Step 1: Add walkable lookup and `isTileWalkable`**

After the `utilities.TINY_HOLE_TILE_IDS` block (added during the holes work), add:

```lua
-- Walkable tiles (the grapple hook flies over these; anything else is a wall it bounces off).
utilities.WALKABLE_TILE_IDS = {}
for _, id in ipairs((Config and Config.Tiles and Config.Tiles.walkable) or {0, 2, 3, 4, 32, 33}) do
    utilities.WALKABLE_TILE_IDS[id] = true
end
-- Slime tiles are also walkable (the player slides over them, not into a wall).
utilities.WALKABLE_TILE_IDS[(Config and Config.Tiles and Config.Tiles.IntGrid and Config.Tiles.IntGrid.slime) or 2] = true

-- nil (off-map) counts as NOT walkable so the hook returns at room edges.
function utilities.isTileWalkable(tileId)
    if tileId == nil then return false end
    return utilities.WALKABLE_TILE_IDS[tileId] == true
end
```

- [ ] **Step 2: Syntax check**

Run: `luac -p source/utilities.lua`
Expected: no output.

- [ ] **Step 3: Commit (only if user asks)**

```bash
git add source/utilities.lua
git commit -m "feat(grapple): add isTileWalkable helper"
```

---

### Task 3: InputBindings — `Input.wasReleased`

**Files:**
- Modify: `source/assets/data/InputBindings.lua`

Gamepad B-release is detected by polling. `Input.wasPressed` exists; add its mirror.

- [ ] **Step 1: Add `Input.wasReleased` after `Input.wasPressed`**

After the `Input.wasPressed` function (returns `curState[action] and not prevState[action]`), add:

```lua
-- Returns true only on the first frame an action goes from held to not-held.
function Input.wasReleased(action)
    return (prevState[action] == true) and not (curState[action] == true)
end
```

- [ ] **Step 2: Syntax check**

Run: `luac -p source/assets/data/InputBindings.lua`
Expected: no output.

- [ ] **Step 3: Commit (only if user asks)**

```bash
git add source/assets/data/InputBindings.lua
git commit -m "feat(input): add Input.wasReleased"
```

---

### Task 4: Grapple module — GrappleHook class + player functions

**Files:**
- Create: `source/entities/player/grapple.lua`

This is the core. The module follows `plunge.lua`'s pattern (functions take `player`). The `GrappleHook` class uses NO bump — it moves by position and samples tiles.

- [ ] **Step 1: Create the module file**

Create `source/entities/player/grapple.lua` with the full contents:

```lua
-- entities/player/grapple.lua
-- Grappling hook: the charged variant of the plungerang.
-- The hook ignores ALL sprites (no bump) and only reacts to tiles: a grapplePoint
-- (Config.Tiles.IntGrid.grapplePoint) pulls the player to that tile; a wall (non-walkable
-- tile) or reaching maxDistance makes it return like a boomerang.

local Class        = require 'libraries/middleclass'
local anim8        = require 'libraries/anim8'
local utilities    = require 'utilities'
local playerPlunge = require 'entities.player.plunge'

local grapple = {}

-- ── Tile sampling helper ────────────────────────────────────────────────────
-- Returns (tileId, centerX, centerY) for the tile under world point (px, py).
function grapple.tileUnderPoint(px, py)
    local sceneManager = require 'sceneManager'
    local gameScene = sceneManager.getScene("game")
    if not gameScene or not gameScene.tileMapData then return nil end

    local ts     = gameScene.tileSize
    local startX = VIRTUAL_WIDTH  / 2 - (gameScene.mapWidth  * ts) / 2
    local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * ts) / 2

    local tileId = utilities.getTileUnderPlayer(gameScene.tileMapData, ts, px, py, startX, startY)
    local col    = math.floor((px - startX) / ts)
    local row    = math.floor((py - startY) / ts)
    local cx     = startX + col * ts + ts / 2
    local cy     = startY + row * ts + ts / 2
    return tileId, cx, cy
end

-- ── GrappleHook (projectile; no bump) ───────────────────────────────────────
local GrappleHook = Class('GrappleHook')

function GrappleHook:initialize(player, direction, maxDistance)
    self.player           = player
    self.direction        = direction
    self.maxDistance       = maxDistance
    self.distanceTravelled = 0
    self.returning        = false
    self.finished         = false
    self.speed            = (Config and Config.Grapple and Config.Grapple.projectileSpeed) or 8

    local feet = (Config and Config.Player and Config.Player.feetOffsetY) or 12
    self.x = player.x
    self.y = player.y + feet

    self.spritesheet = love.graphics.newImage('assets/images/items/projectile-table-24-24.png')
    local grid = anim8.newGrid(24, 24, self.spritesheet:getWidth(), self.spritesheet:getHeight())
    self.animation = anim8.newAnimation(grid('1-4', 1), 0.1)
end

function GrappleHook:update(dt)
    self.animation:update(dt)
    local step = self.speed * 60 * dt
    local feet = (Config and Config.Player and Config.Player.feetOffsetY) or 12

    if self.returning then
        local dx = self.player.x - self.x
        local dy = (self.player.y + feet) - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= step then
            self.finished = true
        else
            self.x = self.x + (dx / dist) * step
            self.y = self.y + (dy / dist) * step
        end
        return
    end

    -- Fly out in the launch direction.
    if     self.direction == 'left'  then self.x = self.x - step
    elseif self.direction == 'right' then self.x = self.x + step
    elseif self.direction == 'up'    then self.y = self.y - step
    elseif self.direction == 'down'  then self.y = self.y + step
    end

    local grapplePointId = (Config and Config.Tiles and Config.Tiles.IntGrid and Config.Tiles.IntGrid.grapplePoint) or 33
    local tileId, cx, cy = grapple.tileUnderPoint(self.x, self.y)

    if tileId == grapplePointId then
        -- Land the player's feet on the tile center.
        grapple.startPull(self.player, cx, cy - feet)
        self.finished = true
        return
    elseif not utilities.isTileWalkable(tileId) then
        self.returning = true   -- hit a wall or left the map
        return
    end

    self.distanceTravelled = self.distanceTravelled + step
    if self.distanceTravelled >= self.maxDistance then
        self.returning = true
    end
end

function GrappleHook:draw()
    local feet = (Config and Config.Player and Config.Player.feetOffsetY) or 12

    -- Rope: line from the player's feet to the hook.
    love.graphics.setColor(0.12, 0.11, 0.10, 1)
    love.graphics.setLineWidth((Config and Config.Grapple and Config.Grapple.ropeWidth) or 2)
    love.graphics.line(self.player.x, self.player.y + feet, self.x, self.y)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)

    -- Hook sprite (centered).
    self.animation:draw(self.spritesheet, self.x, self.y, 0, 1, 1, 12, 12)
end

-- ── Charge / fire (called from input wiring) ────────────────────────────────
function grapple.beginCharge(player)
    if not player.isAlive or PlayerData.isGaming ~= true then return end
    if player:isOnHole() then return end                 -- on a hole the player may only walk
    if PlayerData.isInDarkness then return end            -- grapple is the lit-room ability
    if not PlayerData.items.hasPlunger or not PlayerData.skills.canPlungerang then return end
    if not player.hasProjectile then return end           -- lost to a CrewMember; recover first
    if PlayerData.isTiny then return end
    if player.isGrappleCharging or player.isPlunging or player.isGrapplePulling or player.isGrappling then return end

    player.isGrappleCharging = true
    player.grappleCrankAccum = 0
    player.grappleChargeStart = love.timer.getTime()
end

function grapple.addCrankDelta(player, delta)
    if not player.isGrappleCharging then return end
    if delta and delta > 0 then
        player.grappleCrankAccum = player.grappleCrankAccum + delta
    end
end

-- Whether the charge has been held long enough to "arm" (else a tap → plunge).
function grapple.isArmed(player)
    if not player.isGrappleCharging then return false end
    local holdDelay = ((Config and Config.Grapple and Config.Grapple.holdDelay) or 400) / 1000
    return (love.timer.getTime() - (player.grappleChargeStart or 0)) >= holdDelay
end

function grapple.endCharge(player)
    -- Not charging (couldn't grapple, e.g. no plunger): treat as a normal plunge tap.
    if not player.isGrappleCharging then
        playerPlunge.tryActivate(player)
        return
    end

    local armed = grapple.isArmed(player)
    player.isGrappleCharging = false

    local dir = PlayerData.direction
    if dir == 'idle' or dir == nil then dir = PlayerData.lastDirection end

    if not armed then
        -- Quick tap → plungerang (existing behavior).
        player.grappleCrankAccum = 0
        playerPlunge.tryActivate(player)
        return
    end

    if not dir or dir == 'idle' then player.grappleCrankAccum = 0; return end
    if player:isOnHole() then player.grappleCrankAccum = 0; return end

    local g = Config.Grapple
    local distance = (g.minDistance or 64) + math.deg(player.grappleCrankAccum) * (g.pixelsPerDegree or 0.4)
    if distance > (g.maxDistance or 320) then distance = g.maxDistance end
    player.grappleCrankAccum = 0

    player.isGrappling = true
    player.grappleHook = GrappleHook(player, dir, distance)
    player:distributeMovementTokens((Config and Config.Player and Config.Player.movementTokensPerAction) or 5)
    player:idle()
end

function grapple.onFinished(player)
    player.isGrappling = false
    player.grappleHook = nil
end

-- ── Pull (fast slide to the tile) ───────────────────────────────────────────
function grapple.startPull(player, targetX, targetY)
    player.grappleTargetX = targetX
    player.grappleTargetY = targetY
    player.isGrapplePulling = true
end

function grapple.updatePull(player, dt)
    if not player.isGrapplePulling then return end
    local speed = ((Config and Config.Grapple and Config.Grapple.pullSpeed) or 8) * 60 * dt
    local dx = player.grappleTargetX - player.x
    local dy = player.grappleTargetY - player.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= speed then
        player:moveTo(player.grappleTargetX, player.grappleTargetY)
        player.isGrapplePulling = false
        PlayerData.direction = 'idle'
        player:idle()
    else
        player:moveTo(player.x + (dx / dist) * speed, player.y + (dy / dist) * speed)
    end
end

-- ── Per-frame update / draw (called from Player) ────────────────────────────
function grapple.update(player, dt)
    if player.grappleHook then
        player.grappleHook:update(dt)
        if player.grappleHook.finished then
            grapple.onFinished(player)
        end
    end
end

function grapple.draw(player)
    if player.grappleHook then player.grappleHook:draw() end
end

return grapple
```

- [ ] **Step 2: Syntax check**

Run: `luac -p source/entities/player/grapple.lua`
Expected: no output.

- [ ] **Step 3: Commit (only if user asks)**

```bash
git add source/entities/player/grapple.lua
git commit -m "feat(grapple): add GrappleHook and charge/pull module"
```

---

### Task 5: Player integration — state, require, update, draw

**Files:**
- Modify: `source/entities/player/init.lua`

- [ ] **Step 1: Require the grapple module**

Near the other player-submodule requires at the top (e.g., after `local playerCollisions = require 'entities.player.collisions'`), add:

```lua
local playerGrapple = require 'entities.player.grapple'
```

- [ ] **Step 2: Initialize grapple state in the constructor**

In the constructor, right after the falling-state block added during the holes work (`self.isFalling = false`), add:

```lua
	-- Grapple state
	self.isGrappleCharging = false
	self.isGrappling       = false
	self.isGrapplePulling  = false
	self.grappleCrankAccum = 0
	self.grappleChargeStart = 0
	self.grappleHook       = nil
	self.grappleTargetX    = 0
	self.grappleTargetY    = 0
```

- [ ] **Step 3: Update the hook each frame**

In `Player:update`, find the projectile update block:

```lua
	-- Update projectile if active
	if self.projectile then
		playerPlunge.update(self, dt)
	end
```

Immediately after it, add:

```lua
	-- Update grapple hook if active
	playerGrapple.update(self, dt)
```

- [ ] **Step 4: Add the pull branch to the movement state machine**

In `Player:update`, the movement branch currently reads:

```lua
	if self.isDashing then
		self:updateDash()
	elseif PlayerData.isSliding then
		self:updateSliding(dt)
	else
```

Change it to insert the pull branch (pull blocks normal input, like sliding):

```lua
	if self.isDashing then
		self:updateDash()
	elseif self.isGrapplePulling then
		playerGrapple.updatePull(self, dt)
	elseif PlayerData.isSliding then
		self:updateSliding(dt)
	else
```

- [ ] **Step 5: Skip hole checks while pulling**

In `Player:checkHoleTile` and `Player:checkTinyHoleTile` (added during the holes work), the guard line reads:

```lua
	if PlayerData.isSliding or self.isPlunging or self.isFalling then return end
```

Change BOTH (in `checkHoleTile` and `checkTinyHoleTile`) to also skip while pulling:

```lua
	if PlayerData.isSliding or self.isPlunging or self.isFalling or self.isGrapplePulling then return end
```

- [ ] **Step 6: Draw the hook**

In `Player:draw`, find where the projectile is drawn:

```lua
	-- Draw projectile if active
	if self.projectile and not self.projectile.destroyed then
		self.projectile:draw()
	end
```

Immediately after that block, add:

```lua
	-- Draw grapple hook (with rope) if active
	playerGrapple.draw(self)
```

- [ ] **Step 7: Syntax check**

Run: `luac -p source/entities/player/init.lua`
Expected: no output.

- [ ] **Step 8: Commit (only if user asks)**

```bash
git add source/entities/player/init.lua
git commit -m "feat(grapple): wire hook update/draw/pull into Player"
```

---

### Task 6: gameScene — input wiring (B down/up, crank routing)

**Files:**
- Modify: `source/scenes/gameScene.lua`

- [ ] **Step 1: Require the grapple module**

Near the top requires (e.g., after `local InteractionHUD = require 'entities.UI.interactionHUD'`), add:

```lua
local playerGrapple = require 'entities.player.grapple'
```

- [ ] **Step 2: Keyboard B-down → begin charge**

In `gameScene.keypressed`, the BButton branch currently reads:

```lua
			-- BButton: cancela el minifier si está bloqueado, si no activa el item equipado
			if Input.is(key, "BButton") then
				if PlayerData.isMinifying then
					gameScene.player:finishMinifying()
				elseif gameScene.player and gameScene.player.handleActionButton then
					gameScene.player:handleActionButton()
				end
			end
```

Replace the `elseif` action with begin-charge:

```lua
			-- BButton: cancela el minifier si está bloqueado, si no inicia la carga
			-- del plungerang/grapple (el disparo se resuelve al soltar B).
			if Input.is(key, "BButton") then
				if PlayerData.isMinifying then
					gameScene.player:finishMinifying()
				elseif gameScene.player then
					playerGrapple.beginCharge(gameScene.player)
				end
			end
```

- [ ] **Step 3: Add keyboard B-up → end charge**

Add a new `gameScene.keyreleased` function (sceneManager already routes to it). Place it right before `function gameScene.gamepadInput(input)`:

```lua
function gameScene.keyreleased(key)
	if ComicPlayer.isActive() then return end
	if PlayerData.isTalking or PlayerData.isEquiping then return end
	if gameScene.pauseMenu and gameScene.pauseMenu:isVisible() then return end
	if Input.is(key, "BButton") and gameScene.player then
		playerGrapple.endCharge(gameScene.player)
	end
end
```

- [ ] **Step 4: Gamepad B press/release + crank routing**

In `gameScene.gamepadInput`, the crank block currently reads:

```lua
	-- Crank via right stick
	local cd = Input.getCrankDelta()
	if cd ~= 0 and gameScene.player and gameScene.player.handleCrankInput then
		gameScene.player:handleCrankInput(cd)
	end
```

Replace it with state-aware routing:

```lua
	-- Crank via right stick → grapple charge while charging, else minifier
	local cd = Input.getCrankDelta()
	if cd ~= 0 and gameScene.player then
		if gameScene.player.isGrappleCharging then
			playerGrapple.addCrankDelta(gameScene.player, cd)
		elseif gameScene.player.handleCrankInput then
			gameScene.player:handleCrankInput(cd)
		end
	end
```

Then, the gamepad BButton press branch currently reads:

```lua
		-- BButton: cancel minifier if locked in, otherwise fire equipped item
		if Input.wasPressed("BButton") then
			if PlayerData.isMinifying then
				gameScene.player:finishMinifying()
			elseif gameScene.player then
				gameScene.player:handleActionButton()
			end
		end
```

Replace the action and add the release handler:

```lua
		-- BButton: cancel minifier if locked in, otherwise begin charge (fires on release)
		if Input.wasPressed("BButton") then
			if PlayerData.isMinifying then
				gameScene.player:finishMinifying()
			elseif gameScene.player then
				playerGrapple.beginCharge(gameScene.player)
			end
		end

		-- BButton release: resolve plunge (tap) or grapple (held + crank)
		if Input.wasReleased("BButton") and gameScene.player and not PlayerData.isMinifying then
			playerGrapple.endCharge(gameScene.player)
		end
```

- [ ] **Step 5: Mouse wheel → grapple charge while charging**

In `gameScene.wheelmoved`, the body currently reads:

```lua
	if gameScene.player and gameScene.player.handleCrankInput then
		gameScene.player:handleCrankInput(y)
	end
```

Replace with state-aware routing (one wheel notch ≈ 30°):

```lua
	if gameScene.player and gameScene.player.isGrappleCharging then
		playerGrapple.addCrankDelta(gameScene.player, y * math.rad(30))
	elseif gameScene.player and gameScene.player.handleCrankInput then
		gameScene.player:handleCrankInput(y)
	end
```

- [ ] **Step 6: Syntax check**

Run: `luac -p source/scenes/gameScene.lua`
Expected: no output.

- [ ] **Step 7: Commit (only if user asks)**

```bash
git add source/scenes/gameScene.lua
git commit -m "feat(grapple): wire B charge/release and crank routing"
```

---

### Task 7: gameScene — crankClock charge HUD

**Files:**
- Modify: `source/scenes/gameScene.lua`

Show the existing `interactionHUD` `crankClock` state while a grapple charge is armed (mirrors how the minifier shows it).

- [ ] **Step 1: Drive the HUD from update**

In `gameScene.update`, immediately AFTER the `gameScene.player:update(dt)` call (around line 1015), add:

```lua
		-- Grapple charge indicator (crankClock), shown once the charge is armed.
		if gameScene.player and gameScene.player.isGrappleCharging
			and playerGrapple.isArmed(gameScene.player) and gameScene.interactionHUD then
			gameScene.interactionHUD:setState("crankClock")
			gameScene.interactionHUD:setVisible(true)
			gameScene.suppressInteractionHUD = true
		else
			gameScene.suppressInteractionHUD = false
		end
```

- [ ] **Step 2: Prevent the trigger check from hiding the charge HUD**

In `gameScene.checkTriggerInteraction`, find the trailing block that hides the HUD when no trigger is found:

```lua
	if not foundTrigger and gameScene.interactionHUD then
		gameScene.interactionHUD:setVisible(false)
	end
```

Change its condition so the charge HUD wins:

```lua
	if not foundTrigger and gameScene.interactionHUD and not gameScene.suppressInteractionHUD then
		gameScene.interactionHUD:setVisible(false)
	end
```

- [ ] **Step 3: Syntax check**

Run: `luac -p source/scenes/gameScene.lua`
Expected: no output.

- [ ] **Step 4: Manual verification (in-game)**

Run the game (`./run_game.sh`) and, with the plungerang owned/equipped in a lit room:
1. **Tap B** → plungerang fires (boomerang goes out and returns). No behavior regression.
2. **Hold B (~0.5s) + spin right stick / mouse wheel** → `crankClock` icon appears; on release the hook flies out in the faced direction, bounces off walls and returns.
3. **(Optional, needs a tile id 33 in the room)** the hook touching a grapplePoint pulls the player to that tile, input locked until arrival.
4. In **darkness**, or while **tiny**, or **without the plunger**: B does not grapple (tap still plunges where applicable).

- [ ] **Step 5: Commit (only if user asks)**

```bash
git add source/scenes/gameScene.lua
git commit -m "feat(grapple): show crankClock charge indicator"
```

---

## Notes for the implementer

- **Paths:** commands above use `source/...` from repo root. If your shell is already inside `source/`, drop the prefix.
- **Radians vs degrees:** the port's crank delta is in **radians**; `Config.Grapple.pixelsPerDegree` expects **degrees**. `grapple.endCharge` converts with `math.deg(...)` — do not change this.
- **No bump for the hook:** the `GrappleHook` is intentionally NOT added to the bump world. It must not collide with sprites; it only samples tiles.
- **Plunge timing:** for players who can grapple, the plungerang now fires on B **release** (tap), not press. This was approved in the spec review.
- **Out of scope:** the dark/lamp charge side, authoring `grapplePoint` tiles in LDtk levels, and any functional cooldown (the `cooldown` config value is inert by design).
