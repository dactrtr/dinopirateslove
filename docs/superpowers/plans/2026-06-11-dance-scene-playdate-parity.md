# Dance Scene Playdate Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the LÖVE 2D `DanceScene` behave identically to the Playdate original (`source/DOCS/source/scenes/DanceScene.lua` + `source/DOCS/source/DOCS/DANCE_SCENE.md`).

**Architecture:** The LÖVE port already exists (`source/scenes/DanceScene.lua` + `source/entities/UI/battle/`). This plan fixes two game-breaking bugs (input mapping, button icon frames), converts the rhythm logic to a fixed 50 Hz tick (Playdate locks combat to 50 fps), restores Playdate collision/recycle semantics for the scrolling buttons via bump.lua, matches sprite positions/animation speeds, completes the win/lose/exit flow (returningInPlace, calorie cap, HP reset to 2, save), and ports the battle audio.

**Tech Stack:** LÖVE 11.5, Lua, anim8 (animations), bump.lua (already in `source/libraries/`), love.audio.

**Conventions for this plan:**
- All paths are relative to the repo root (`dinopirateslove/`). The game source lives in `source/`.
- The Playdate reference code is read-only: `source/DOCS/source/...`. Never modify it.
- **No test framework exists in this project** (per CLAUDE.md). Verification is manual: run `./run_game.sh` and use the F5 debug entry added in Task 1. Each task ends with a run-and-observe step.
- **Do NOT commit.** The user commits manually (explicit user preference). The working tree already has unrelated uncommitted changes — leave them alone.
- Playdate frame durations are in 50 fps frames. Conversion used throughout: `N frames → N/50 seconds`. `frameDuration = bpm/2` → `bpm/100` seconds.
- Playdate sprites default to center anchoring; the LÖVE port uses top-left x,y. Playdate `add(x, y)` of a w×h sprite → LÖVE top-left `(x − w/2, y − h/2)`.

**Known dead code in the Playdate original — intentionally NOT ported** (no observable effect): `self.enemyHP -= 10` on A/B hits (only feeds an overwritten local), `lifes`, `evadePower` (write-only), the Noble `Sequence` entrance/exit tweens (value never read), `phaseLength` in the pattern profiles. Also skipped: the `enemyBosscolliDance` spritesheet branch for `lastEnemyTouched.type == "bosscolli"` — that asset does not exist even in the Playdate tree (`source/DOCS/source/assets/images/ui/battle/`), so the default `enemyDance` sheet is always used, same as the shipped Playdate build.

---

### Task 1: Debug entry (F5 + `debugMode`) — enables manual verification of every later task

Playdate has `DanceScene.debugMode`: forces `basic` difficulty and, on win, exits to TitleScene. Port it and add an F5 shortcut so the dance can be reached instantly.

**Files:**
- Modify: `source/scenes/DanceScene.lua`
- Modify: `source/main.lua` (love.keypressed chain, around line 398)

- [ ] **Step 1: Add the `debugMode` flag to the scene module**

In `source/scenes/DanceScene.lua`, right after `local danceScene = {}` (line 19):

```lua
local danceScene = {}
danceScene.debugMode = false  -- Playdate: DanceScene.debugMode (forces basic, win exits to title)
```

- [ ] **Step 2: Branch difficulty on debugMode and read values from Config.Dance**

In `danceScene.enter()`, replace the whole difficulty block (the `local chance = determineDifficultyUpgrade()` … `end` if/else, currently lines 109–123, including the hardcoded bpm/button numbers) with:

```lua
    if danceScene.debugMode then
        state.enemyType       = "basic"
        state.enemyEvolving   = false
        state.bpm             = Config.Dance.basic.bpm
        state.numberOfButtons = Config.Dance.basic.buttons
    else
        -- Decide whether to upgrade difficulty based on PlayerData
        local chance = determineDifficultyUpgrade()
        local roll   = math.random(0, 100)
        if roll <= chance then
            state.enemyType = determineEnemyType()
            local diffConfig = Config.Dance[state.enemyType] or Config.Dance.basic
            state.bpm             = diffConfig.bpm
            state.numberOfButtons = diffConfig.buttons
            state.enemyEvolving   = true
        else
            state.enemyType       = "basic"
            state.enemyEvolving   = false
            state.bpm             = Config.Dance.basic.bpm
            state.numberOfButtons = Config.Dance.basic.buttons
        end
    end
```

(`Config.Dance` already holds the exact Playdate values: basic 16/4, evolve 24/6, badass 28/8, boss 32/12 — see `source/assets/data/Config.lua:280`.)

- [ ] **Step 3: debugMode win path exits to title; exit() clears the flag**

In `danceScene.checkDanceResults()`, immediately after `state.totalAccuracy = 0` in the win branch, add:

```lua
        if danceScene.debugMode then
            sceneManager.startTransition("dance", "title", "fade")
            return
        end
```

In `danceScene.exit()` add `danceScene.debugMode = false` (Playdate resets it in `scene:exit()`).

- [ ] **Step 4: Add the F5 shortcut in main.lua**

In `source/main.lua`, `love.keypressed`, extend the debug-key chain (after the `elseif Input.is(key, "res3")` branch; the file already has `local danceScene = require "scenes/DanceScene"` at line 26):

```lua
	elseif key == "f5" then
		-- Debug: jump straight into the rhythm battle (Playdate DanceScene.debugMode)
		danceScene.debugMode = true
		sceneManager.startTransition("game", "dance", "fade")
```

- [ ] **Step 5: Run and verify**

Run: `./run_game.sh`, start the game, press **F5**.
Expected: fade into the dance scene showing the "ready" overlay. Press Z (A button) to start; buttons scroll right→left. Drive `balancePosition` to −50 by pressing wrong keys repeatedly → "lose" overlay → press Z → returns to **title** scene (debugMode path).

---

### Task 2: Fix input mapping (game-breaking) + gamepad support

`Input.danceKeys` currently maps to display labels (`"A"`, `"up"`) but the scene compares against `buttonKey` values (`"aButton"`, `"upButton"`), so **every press registers as wrong** and the dance is unwinnable. Also the scene has no gamepad handlers at all (Playdate is a handheld — A/B/d-pad must work on a controller).

**Files:**
- Modify: `source/assets/data/InputBindings.lua` (danceKeys table, ~line 57)
- Modify: `source/scenes/DanceScene.lua` (add gamepad handlers)
- Modify: `source/sceneManager.lua` (add `gamepadreleased` routing)
- Modify: `source/main.lua` (add `love.gamepadreleased`)

- [ ] **Step 1: Confirm danceKeys has no other consumers**

Run: `grep -rn "danceKeys" source --include="*.lua" | grep -v DOCS`
Expected: only `source/assets/data/InputBindings.lua` (definition + comment) and `source/scenes/DanceScene.lua` (the `Input.danceKeys[key]` lookup). If anything else consumes it, stop and reassess.

- [ ] **Step 2: Rewrite the mapping with internal button names and add the gamepad map**

In `source/assets/data/InputBindings.lua`, replace the `Input.danceKeys` table with (keys mirror `keyBindings` above it):

```lua
-- Dance mode: raw key → internal dance button name (must match ButtonPress.buttonKey)
Input.danceKeys = {
    ["z"]      = "aButton",
    ["return"] = "aButton",
    ["space"]  = "aButton",
    ["x"]      = "bButton",
    ["lshift"] = "bButton",
    ["up"]     = "upButton",
    ["w"]      = "upButton",
    ["down"]   = "downButton",
    ["s"]      = "downButton",
    ["left"]   = "leftButton",
    ["a"]      = "leftButton",
    ["right"]  = "rightButton",
    ["d"]      = "rightButton",
}

-- Dance mode: gamepad button → internal dance button name
Input.dancePadButtons = {
    a       = "aButton",
    b       = "bButton",
    dpup    = "upButton",
    dpdown  = "downButton",
    dpleft  = "leftButton",
    dpright = "rightButton",
}
```

- [ ] **Step 3: Add gamepad handlers to the dance scene**

In `source/scenes/DanceScene.lua`, after `danceScene.keyreleased`:

```lua
function danceScene.gamepadpressed(button)
    if not PlayerData.isDancing and state.condition == nil then
        if button == "a" then danceScene.startBattle() end
        return
    end
    if state.condition ~= nil then
        if button == "a" then danceScene.checkDanceResults() end
        return
    end
    local mapped = Input.dancePadButtons[button]
    if mapped then
        state.ButtonPressed = mapped
    end
end

function danceScene.gamepadreleased(button)
    state.ButtonPressed = nil  -- Playdate clears on any *ButtonUp
end
```

- [ ] **Step 4: Route gamepadreleased through sceneManager and main.lua**

In `source/sceneManager.lua`, next to `sceneManager.gamepadpressed` (line 283):

```lua
function sceneManager.gamepadreleased(button)
	if transition.active then return end
	if currentScene and currentScene.gamepadreleased then
		currentScene.gamepadreleased(button)
	end
end
```

In `source/main.lua`, next to `love.gamepadpressed` (line 425):

```lua
function love.gamepadreleased(joystick, button)
	if joystick == activeJoystick and sceneManager.gamepadreleased then
		sceneManager.gamepadreleased(button)
	end
end
```

- [ ] **Step 5: Run and verify**

Run: `./run_game.sh`, F5, Z to start. Press the key matching the icon while it crosses the hit zone.
Expected: balance bar moves **right** on a correct press (it could never move right before this fix). Wrong key still moves it left. If a controller is available: A starts the battle and d-pad/A/B register.

> Note: icons may still look mismatched to keys until Task 4 fixes the sprite frame mapping — verify by *button name in the debug print*, or temporarily trust arrow keys vs A/B groupings.

---

### Task 3: Fixed 50 Hz logic tick

Playdate locks the scene to 50 fps; `accuracy` (+1 per frame), the miss drain (−0.3 per frame past 5), hit detection (one `ButtonPressed` consumed per frame), and button movement (px per frame) are all frame-based. The LÖVE port runs them per render frame (60+ fps, variable), so timing-sensitive values drift. Wrap the rhythm logic in a 1/50 s accumulator.

**Files:**
- Modify: `source/scenes/DanceScene.lua`

- [ ] **Step 1: Add the tick constants and accumulator**

Near the layout constants at the top of `source/scenes/DanceScene.lua`:

```lua
-- Playdate locks DanceScene to 50 fps; all rhythm logic runs on this fixed tick.
local TICK = 1 / 50
local tickAccumulator = 0
```

In `danceScene.enter()`, after `resetState()`, add `tickAccumulator = 0`.

- [ ] **Step 2: Split update into real-time part + fixed tick**

Replace the whole body of `danceScene.update(dt)` with:

```lua
function danceScene.update(dt)
    if not state.hitZone then return end

    -- Visual animations advance in real time (ready screen included)
    state.hitZone:update(dt)
    state.playerDance:update(dt)
    state.enemyDance:update(dt)

    -- Stagger timers run in real time from enter() — Playdate starts them in
    -- scene:start(), i.e. they elapse during the ready screen too.
    for _, btn in ipairs(state.buttons) do
        btn:updateDelay(dt * 1000)
    end

    tickAccumulator = tickAccumulator + dt
    while tickAccumulator >= TICK do
        tickAccumulator = tickAccumulator - TICK
        danceScene.logicTick()
    end
end

-- One Playdate frame (1/50 s) of rhythm logic.
function danceScene.logicTick()
    -- Buttons move per tick, battle only (ButtonPress:tick gates on .active)
    if PlayerData.isDancing then
        for _, btn in ipairs(state.buttons) do
            btn:tick()
        end
    end

    -- Hit detection only runs during active battle
    if not PlayerData.isDancing then return end
    if state.condition ~= nil then return end

    local inZone = state.hitZone:overlapping(state.buttons)

    if #inZone > 0 then
        local btn = inZone[1]

        if state.ButtonPressed == nil then
            -- Button in zone, no key pressed: accuracy builds; drain past 5 frames
            state.accuracy = state.accuracy + 1
            if state.accuracy > Balance.MISS_GRACE_FRAMES then
                state.balancePosition = state.balancePosition + Balance.MISS_DELTA
            end
            state.enemyDance:changeAnimation(btn.buttonKey)

        elseif btn.buttonKey == state.ButtonPressed then
            -- Correct press
            if state.ButtonPressed == "aButton" or state.ButtonPressed == "bButton" then
                state.enemyDance:attackAnimation(state.ButtonPressed)
                state.balancePosition = Balance.applyABHit(state.balancePosition)
            else
                state.balancePosition = Balance.applyArrowHit(state.balancePosition, state.accuracy)
                state.totalAccuracy = state.totalAccuracy + state.accuracy
            end
            state.playerDance:changeAnimation(state.ButtonPressed)
            state.correctButtonPresses[state.ButtonPressed] = (state.correctButtonPresses[state.ButtonPressed] or 0) + 1
            btn:hit()

        else
            -- Wrong press
            btn:hit()
            state.balancePosition = Balance.applyWrongPress(state.balancePosition)
        end

        state.ButtonPressed = nil  -- consumed: one press counts once per tick

    else
        state.accuracy = 0
    end

    state.balancePosition = Balance.clamp(state.balancePosition, state.balanceMaxOffset)

    if Balance.isWin(state.balancePosition, state.balanceMaxOffset) then
        state.resultsScreen:win()
        PlayerData.isDancing = false
        state.condition = "win"
    end
    if Balance.isLose(state.balancePosition, state.balanceMaxOffset) then
        state.resultsScreen:lose()
        PlayerData.isDancing = false
        state.condition = "lose"
    end
end
```

Notes: `btn:updateDelay(ms)` and `btn:tick()` replace `btn:update(dt)` — they are implemented in Task 4 (do Task 4 immediately after; the game will error on F5 between Step 2 here and Task 4 completion — that is expected). `state.evadePower` assignment dropped (write-only dead code in the original).

- [ ] **Step 3: (after Task 4) Run and verify**

Run: `./run_game.sh`, F5, Z.
Expected: identical feel at any window fps; holding no key while a button sits in the zone drains the bar slowly (−0.3 per 1/50 s past the 5-tick grace).

---

### Task 4: ButtonPress parity — frame mapping, bump collisions, instant recycle, positions, real-time delays

Four problems vs Playdate:
1. **Wrong icon frames** (game-breaking): the sheet `button-table-32-32.png` is ordered **A, B, left, up, right, down, ?, empty** (verified visually), exactly Playdate's mapping (`aButton`=1 … `downButton`=6, empty=8). The port uses `leftButton=1, upButton=2, …` so every icon shown is wrong.
2. **Hit pause**: the port shows an empty frame for 0.15 s before recycling; Playdate recycles instantly (`hit()` → teleport to start + new key, the empty frame is never visible).
3. **No button-to-button collision**: Playdate uses `moveWithCollisions` with a `freeze` response so buttons can never overlap/pass each other (Playdate's collision system is modeled on bump.lua — use the bundled `libraries/bump.lua` with the `"touch"` response, the closest equivalent).
4. **Position/timing details**: row center y=30 (top-left 14, not 40); recycle when center x ≤ 32 (top-left ≤ 16); spawn center x = 400+bpm; key re-rolls must repeat-until-different on edge recycle but allow repetition after a hit (Playdate sets key to `"empty"` first, so any real key passes the `until newKey ~= self.buttonKey` check); delay timers elapse in real time from `enter()` (Playdate starts them during the ready screen).

**Files:**
- Rewrite: `source/entities/UI/battle/ButtonPress.lua`
- Modify: `source/scenes/DanceScene.lua` (create bump world, pass it to buttons)

- [ ] **Step 1: Rewrite ButtonPress.lua**

Replace the entire file `source/entities/UI/battle/ButtonPress.lua` with:

```lua
-- entities/UI/battle/ButtonPress.lua
-- Scrolling input prompt for the dance battle. Mirrors the Playdate original:
-- moves a fixed amount per 50 Hz tick, freezes against other buttons (bump
-- "touch"), recycles instantly to the spawn point when hit or past the left edge.
ButtonPress = {}
ButtonPress.__index = ButtonPress

-- Frame indices in button-table-32-32.png — same order as the Playdate sheet.
local BUTTON_FRAMES = {
    aButton     = 1,
    bButton     = 2,
    leftButton  = 3,
    upButton    = 4,
    rightButton = 5,
    downButton  = 6,
}
local EMPTY_FRAME = 8

local SIZE       = 32
local ROW_TOP_Y  = 14   -- Playdate adds at center y=30 → top-left 14
local RECYCLE_X  = 16   -- Playdate recycles at center x<=32 → top-left 16

local _image, _quads  -- module-level cache shared across all instances

local function loadAssets()
    if _image then return end
    _image = love.graphics.newImage('assets/images/ui/battle/button-table-32-32.png')
    _quads = {}
    local iw = _image:getWidth()
    local nFrames = math.floor(iw / SIZE)
    for i = 1, nFrames do
        _quads[i] = love.graphics.newQuad((i-1)*SIZE, 0, SIZE, SIZE, iw, SIZE)
    end
end

-- startCenterX: Playdate passes startPoint+bpm as the sprite CENTER x.
function ButtonPress.new(bpm, startCenterX, keyProvider, world)
    loadAssets()
    local self = setmetatable({}, ButtonPress)
    self.keyProvider  = keyProvider
    self.world        = world
    self.startX       = startCenterX - SIZE/2  -- stored as top-left
    self.x            = self.startX
    self.y            = ROW_TOP_Y
    self.width        = SIZE
    self.height       = SIZE
    self.buttonKey    = keyProvider()
    self.active       = false
    self.delayMs      = 0
    self.elapsedMs    = 0
    self.speedPerTick = 0.5 * bpm / 3  -- px per 50 Hz tick (Playdate px/frame)
    world:add(self, self.x, self.y, SIZE, SIZE)
    return self
end

function ButtonPress:movementDelay(ms)
    self.delayMs = ms
end

-- Real-time stagger timer; runs from scene enter, ready screen included
-- (Playdate uses playdate.timer.performAfterDelay from scene:start()).
function ButtonPress:updateDelay(dtMs)
    if self.active then return end
    self.elapsedMs = self.elapsedMs + dtMs
    if self.elapsedMs >= self.delayMs then
        self.active = true
    end
end

-- Playdate collisionResponse: ButtonPress vs ButtonPress → freeze; else overlap.
local function moveFilter(item, other)
    if getmetatable(other) == ButtonPress then return "touch" end
    return "cross"
end

-- Teleport without collision resolution (Playdate moveTo).
function ButtonPress:teleportToStart()
    self.x = self.startX
    self.world:update(self, self.x, self.y)
end

-- Edge recycle: repeat-until-different (Playdate changeButtonSprite).
function ButtonPress:changeButtonSprite()
    local newKey
    repeat
        newKey = self.keyProvider()
    until newKey ~= self.buttonKey
    self.buttonKey = newKey
end

-- Hit recycle: instant; key set to "empty" first, so the re-roll may legally
-- repeat the key that was just hit (faithful to the Playdate original).
function ButtonPress:hit()
    self.buttonKey = "empty"
    self:teleportToStart()
    self:changeButtonSprite()
end

-- One 50 Hz tick of movement. Called only while PlayerData.isDancing.
function ButtonPress:tick()
    if not self.active then return end
    local goalX = self.x - self.speedPerTick
    local ax, ay = self.world:move(self, goalX, self.y, moveFilter)
    self.x, self.y = ax, ay
    if self.x <= RECYCLE_X then
        self:teleportToStart()
        self:changeButtonSprite()
    end
end

function ButtonPress:draw(scale)
    scale = scale or 1
    local frameIdx = BUTTON_FRAMES[self.buttonKey] or EMPTY_FRAME
    local quad = _quads[frameIdx]
    if not quad then return end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(_image, quad,
        (self.x + SIZE/2) * scale, (self.y + SIZE/2) * scale,
        0, scale, scale,
        SIZE/2, SIZE/2)
end

function ButtonPress:getBounds()
    return self.x, self.y, self.width, self.height
end
```

- [ ] **Step 2: Create the bump world in DanceScene and pass it to the buttons**

In `source/scenes/DanceScene.lua`:

Add near the top requires: `local bump = require 'libraries/bump'`

In `resetState()`, add: `state.world = nil`

In `danceScene.enter()`, replace the button-building block with:

```lua
    -- Build buttons (dedicated bump world: buttons freeze against each other,
    -- replicating Playdate's moveWithCollisions 'freeze' response)
    state.world = bump.newWorld(64)
    local startPoint = 400
    local delayStep  = 300
    local profile    = EnemyPatterns[state.enemyType] or EnemyPatterns.basic
    local function kp() return getPatternKey(profile) end
    for i = 1, state.numberOfButtons do
        local b = ButtonPress.new(state.bpm, startPoint + state.bpm, kp, state.world)
        b:movementDelay((i-1) * delayStep)
        table.insert(state.buttons, b)
    end
```

In `HitZone:overlapping` (`source/entities/UI/battle/HitZone.lua`), delete the `if not btn.isHit then` guard (the field no longer exists; Playdate's `overlappingSprites()` has no such filter):

```lua
function HitZone:overlapping(buttons)
    local result = {}
    for _, btn in ipairs(buttons) do
        local bx, by, bw, bh = btn:getBounds()
        if aabbOverlap(self.x, self.y, self.w, self.h, bx, by, bw, bh) then
            result[#result + 1] = btn
        end
    end
    return result
end
```

- [ ] **Step 3: Run and verify**

Run: `./run_game.sh`, F5, Z.
Expected:
- Icons now match keys: pressing the key shown on the icon in the zone pushes the bar right.
- On a hit, the button disappears from the zone **instantly** and re-enters from the right (no lingering empty square).
- Buttons never overlap or pass through each other while scrolling.
- If you wait ~1 s on the ready screen before pressing Z, all buttons start together from the right (stagger timers already elapsed — faithful to Playdate); pressing Z immediately shows the staggered entrance.

---

### Task 5: HitZone position + checker animation speed

Playdate: HitZone is centered at (40, 30), 10×40 → top-left (35, 10); its `checker` animation runs at `frameDuration = bpm` frames → `bpm/50` seconds per frame. The port uses top-left (40, 30) and a fixed 0.06 s.

**Files:**
- Modify: `source/entities/UI/battle/HitZone.lua`
- Modify: `source/scenes/DanceScene.lua` (constructor call)

- [ ] **Step 1: Pass bpm and use it for the animation speed**

In `source/entities/UI/battle/HitZone.lua`, change the constructor:

```lua
function HitZone.new(x, y, w, h, bpm)
    local self = setmetatable({ x=x, y=y, w=w, h=h }, HitZone)
    self.image = love.graphics.newImage('assets/images/ui/battle/hitzone-table-10-40.png')
    local g    = anim8.newGrid(w, h, self.image:getWidth(), self.image:getHeight())
    -- Playdate: frameDuration = bpm (50 fps frames) → bpm/50 seconds
    self.anim  = anim8.newAnimation(g('1-8', 1), (bpm or 16) / 50)
    return self
end
```

- [ ] **Step 2: Fix the position in DanceScene**

In `danceScene.enter()`:

```lua
    -- Playdate: HitZone centered at (40,30), 10×40 → top-left (35,10)
    state.hitZone = HitZone.new(35, 10, 10, 40, state.bpm)
```

- [ ] **Step 3: Run and verify**

Run: `./run_game.sh`, F5, Z.
Expected: hit zone sits slightly higher/left than before, vertically spanning the button row; its checker animation visibly pulses slower (0.32 s per frame at basic bpm 16). Hits still register across the same-width window.

---

### Task 6: PlayerDance / EnemyRatDance animation parity + tiny player sprite

Gaps vs Playdate:
- Frame durations must follow bpm: `bpm/2` frames → **`bpm/100` s** for everything except enemy `aButton`/`bButton` which are 3 frames → **0.06 s**. The port hardcodes 0.1 s.
- Player `idle` is frames **1–5** (port uses 1–4).
- Player one-shot animations (jump/crouch/left/right) must return to idle after playing once. The current port relies on `pauseAtEnd()` **called at construction**, which pauses the animation immediately — combined with `gotoFrame(1)` (which does not resume), the one-shots never play. Use anim8's `onLoop = 'pauseAtEnd'` constructor argument plus `resume()` on trigger, for both player and enemy.
- Player sprite must switch to `playerDanceTiny-table-246-214.png` when `PlayerData.isTiny` (asset already present).

**Files:**
- Modify: `source/entities/UI/battle/PlayerDance.lua`
- Modify: `source/entities/UI/battle/EnemyRatDance.lua`

- [ ] **Step 1: Rewrite PlayerDance animation setup**

In `source/entities/UI/battle/PlayerDance.lua`, replace `PlayerDance.new` with:

```lua
function PlayerDance.new(bpm)
    local self = setmetatable({ bpm = bpm }, PlayerDance)
    local path = PlayerData.isTiny
        and 'assets/images/ui/battle/playerDanceTiny-table-246-214.png'
        or  'assets/images/ui/battle/playerDance-table-246-214.png'
    self.image = love.graphics.newImage(path)
    local g    = anim8.newGrid(246, 214, self.image:getWidth(), self.image:getHeight())
    -- Playdate: frameDuration = bpm/2 (50 fps frames) → bpm/100 seconds
    local frameDur = bpm / 100
    self.anims = {
        idle   = anim8.newAnimation(g('1-5',  1), frameDur),
        jump   = anim8.newAnimation(g('5-9',  1), frameDur, 'pauseAtEnd'),
        crouch = anim8.newAnimation(g('11-15',1), frameDur, 'pauseAtEnd'),
        left   = anim8.newAnimation(g('16-20',1), frameDur, 'pauseAtEnd'),
        right  = anim8.newAnimation(g('21-24',1), frameDur, 'pauseAtEnd'),
    }
    self.currentAnim = self.anims.idle
    return self
end
```

Replace `PlayerDance:changeAnimation` and `PlayerDance:update`:

```lua
function PlayerDance:changeAnimation(buttonKey)
    local map = {
        upButton    = "jump",
        downButton  = "crouch",
        leftButton  = "left",
        rightButton = "right",
    }
    local name = map[buttonKey]
    if name and self.anims[name] then
        self.currentAnim = self.anims[name]
        self.currentAnim:gotoFrame(1)
        self.currentAnim:resume()
    end
end

function PlayerDance:update(dt)
    self.currentAnim:update(dt)
    -- One-shots return to idle when finished (Playdate addState(..., 'idle'))
    if self.currentAnim ~= self.anims.idle and self.currentAnim.status == "paused" then
        self:setIdle()
    end
end
```

(`setIdle` and `draw` stay as they are.)

- [ ] **Step 2: Fix EnemyRatDance frame durations and one-shot playback**

In `source/entities/UI/battle/EnemyRatDance.lua`:

Change `buildAnim` to accept a duration in seconds and an optional onLoop:

```lua
local function buildAnim(g, fromFrame, toFrame, frameDur, onLoop)
    local quads = {}
    for n = fromFrame, toFrame do
        local col = ((n-1) % COLS) + 1
        local row = math.floor((n-1) / COLS) + 1
        for _, q in ipairs(g(col, row)) do
            quads[#quads+1] = q
        end
    end
    return anim8.newAnimation(quads, frameDur, onLoop)
end
```

Replace the anims block in `EnemyRatDance.new` (delete the `attackNames` / `pauseAtEnd()` loop that follows it):

```lua
    -- Playdate: frameDuration = bpm/2 frames → bpm/100 s; aButton/bButton are
    -- hardcoded to 3 frames → 0.06 s
    local frameDur = bpm / 100
    self.anims = {
        idle        = buildAnim(g, 1,  5,  frameDur),
        upAttack    = buildAnim(g, 6,  9,  frameDur, 'pauseAtEnd'),
        leftAttack  = buildAnim(g, 10, 13, frameDur, 'pauseAtEnd'),
        rightAttack = buildAnim(g, 14, 17, frameDur, 'pauseAtEnd'),
        downAttack  = buildAnim(g, 18, 21, frameDur, 'pauseAtEnd'),
        bButton     = buildAnim(g, 22, 25, 0.06,     'pauseAtEnd'),
        aButton     = buildAnim(g, 26, 29, 0.06,     'pauseAtEnd'),
        evolving    = buildAnim(g, 30, 33, frameDur),
    }
```

In `EnemyRatDance:changeAnimation` and `EnemyRatDance:attackAnimation`, add `self.currentAnim:resume()` right after each `self.currentAnim:gotoFrame(1)`.

(`update`'s paused→idle check already exists and now works, since animations are no longer born paused.)

- [ ] **Step 3: Run and verify**

Run: `./run_game.sh`, F5, Z.
Expected: enemy reacts with up/down/left/right attack poses while arrow prompts sit unpressed in the zone, plays fast A/B poses on correct A/B hits, and returns to idle after each. Player jumps/crouches/leans on correct arrow hits and returns to idle. At basic difficulty the idle sway is noticeably slower than before (0.16 s/frame).

---

### Task 7: Balance bar image + indicator centering

Playdate draws `nudgeIndicator.png` with `drawCentered` at `(200 + balancePosition − 4, 56)`, and Win/Lose indicators **centered** at (266, 55) / (134, 55). The port draws a yellow placeholder rect and treats the indicator coords as top-left (shifting them by half their size). There is also an always-on gray debug print Playdate only shows in debug.

**Files:**
- Modify: `source/scenes/DanceScene.lua` (draw)
- Modify: `source/entities/UI/battle/WinIndicator.lua`
- Modify: `source/entities/UI/battle/LoseIndicator.lua`

- [ ] **Step 1: Replace the placeholder rect with the nudgeIndicator image**

In `source/scenes/DanceScene.lua`, add a module-local near the other caches:

```lua
local nudgeImage  -- balance bar sprite, loaded on first draw
```

In `danceScene.draw()`, replace the "Balance bar (z=9)" block (the `love.graphics.rectangle` lines) with:

```lua
    -- Balance bar (z=9): Playdate drawCentered(nudgeIndicator, 200+pos-4, 56)
    if not nudgeImage then
        nudgeImage = love.graphics.newImage('assets/images/ui/battle/nudgeIndicator.png')
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(nudgeImage,
        SCREEN_CENTER_X + state.balancePosition - BAR_WIDTH/2, BAR_Y,
        0, 1, 1, nudgeImage:getWidth()/2, nudgeImage:getHeight()/2)
```

- [ ] **Step 2: Gate the debug print behind debugMode**

Still in `danceScene.draw()`, wrap the trailing gray `love.graphics.print(...)` block in `if danceScene.debugMode then ... end`.

- [ ] **Step 3: Center the win/lose indicators**

In both `source/entities/UI/battle/WinIndicator.lua` and `LoseIndicator.lua`, change the draw call so (x, y) is the sprite **center** (Playdate default anchoring):

```lua
function WinIndicator:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image,
        self.x * scale, self.y * scale,
        0, scale, scale,
        FRAME_W/2, FRAME_H/2)
end
```

(Same change in `LoseIndicator:draw`. The positions DanceScene passes — (266, 55) and (134, 55) — already match the Playdate formula and stay unchanged.)

- [ ] **Step 4: Run and verify**

Run: `./run_game.sh`, F5, Z.
Expected: the moving balance marker is the nudgeIndicator sprite (no yellow rectangle); the two end-of-bar indicator sprites sit symmetric around the bar at y≈55; no gray debug text unless entered via F5.

---

### Task 8: Win/lose/exit flow parity

Missing vs Playdate `checkDanceResults()` / `scene:exit()`:
- Win: `PlayerData.returningInPlace = true` (without it, `gameScene.loadRoom` snaps the player to a door instead of the fight spot — see `source/scenes/gameScene.lua:413`); calories capped at `Config.Dance.caloriesMax`; heal clamped to `Config.Player.maxHealthPoints` (Playdate value 10 — missing from the LÖVE Config, which made the scene fall back to 3).
- Lose: `deathCause = "hp"` (Playdate). The LÖVE DeadScene's message fallback for unknown causes is "they caught you", which is exactly what the Playdate DeadScene shows for "hp" — no DeadScene change needed.
- Exit (both outcomes): `PlayerData.healthPoints = 2` — Playdate always resets HP to 2 when leaving the dance, *after* the win-heal (the heal is then overwritten; that is the shipped behavior) — and `SaveSystem.save()`.

**Files:**
- Modify: `source/assets/data/Config.lua` (Config.Player block, line 44)
- Modify: `source/scenes/DanceScene.lua` (checkDanceResults, exit)

- [ ] **Step 1: Add maxHealthPoints to Config.Player**

In `source/assets/data/Config.lua`, inside `Config.Player = { ... }`:

```lua
    maxHealthPoints         = 10,  -- hard cap on healthPoints (Playdate Config.Player.maxHealthPoints)
```

- [ ] **Step 2: Rewrite checkDanceResults**

In `source/scenes/DanceScene.lua`, replace `danceScene.checkDanceResults()` with:

```lua
function danceScene.checkDanceResults()
    local gameScene = require 'scenes.gameScene'
    if state.condition == "win" then
        state.condition     = nil
        state.totalAccuracy = 0

        if danceScene.debugMode then
            sceneManager.startTransition("dance", "title", "fade")
            return
        end

        gameScene.findAndKillEnemyById(PlayerData.lastEnemyTouched.id)
        PlayerData.healthPoints = math.min(
            PlayerData.healthPoints + (PlayerData.healedHP or 2),
            Config.Player.maxHealthPoints)
        -- Resume at the fight spot, not at a door
        PlayerData.playerSpawn.x   = PlayerData.playerExit.x
        PlayerData.playerSpawn.y   = PlayerData.playerExit.y
        PlayerData.returningInPlace = true
        PlayerData.amountDances = (PlayerData.amountDances or 0) + 1
        PlayerData.calories = math.min((PlayerData.calories or 0) + 60, Config.Dance.caloriesMax)
        sceneManager.startTransition("dance", "game", "fade")

    elseif state.condition == "lose" then
        state.condition = nil
        PlayerData.deathCause = "hp"  -- Playdate: lose the dance → "hp" death
        sceneManager.startTransition("dance", "dead", "fade")
    end
end
```

- [ ] **Step 3: Rewrite exit()**

```lua
function danceScene.exit()
    PlayerData.isDancing = false
    danceScene.debugMode = false
    -- Playdate parity: HP always resets to 2 when leaving the dance,
    -- regardless of outcome (original scene:exit() runs after the win-heal).
    PlayerData.healthPoints = 2
    SaveSystem.save()
end
```

Add `local SaveSystem = require 'SaveSystem'` to the requires at the top of the file.

- [ ] **Step 4: Run and verify**

Run: `./run_game.sh`. Two checks:
1. **F5 debug win** → returns to title; relaunch a normal game and confirm no errors from the save written on exit.
2. **Real flow**: in a normal run, set `PlayerData.skills.canDance = true` via a temporary printDebug-adjacent line or the in-game path (floor-4 Notes pickup), get hit until HP < 1 → dance starts; win → player reappears **at the spot where the fight started** (not at a door), the enemy that triggered the fight is dead, HP is 2. Lose → DeadScene shows "they caught you".

---

### Task 9: Battle audio (music + kick/snare)

Playdate plays a looping battle track (volume 0.7) **only for the `basic` enemy type**, a snare (0.8) on every A press while dancing, and a kick (0.8) on every d-pad press while dancing (B is silent). The LÖVE port has no audio at all; the wavs exist in the Playdate tree and LÖVE plays .wav natively. This is the first audio in the LÖVE port — no global audio system needed, scene-local sources suffice.

**Files:**
- Create (copy): `source/assets/sounds/music/battle_music_test_ima.wav`, `source/assets/sounds/music/drums/kick_test_ima.wav`, `source/assets/sounds/music/drums/snare_test_ima.wav`
- Modify: `source/scenes/DanceScene.lua`

- [ ] **Step 1: Copy the sound assets from the Playdate tree**

```bash
mkdir -p source/assets/sounds/music/drums
cp source/DOCS/source/assets/sounds/music/battle_music_test_ima.wav source/assets/sounds/music/
cp source/DOCS/source/assets/sounds/music/drums/kick_test_ima.wav source/assets/sounds/music/drums/
cp source/DOCS/source/assets/sounds/music/drums/snare_test_ima.wav source/assets/sounds/music/drums/
```

- [ ] **Step 2: Load and wire the sources in DanceScene**

In `source/scenes/DanceScene.lua`, add module-locals near the other caches:

```lua
-- Battle audio (lazy-loaded once; Playdate volumes: music 0.7, drums 0.8)
local battleMusic, kickSound, snareSound
local function loadAudio()
    if battleMusic then return end
    battleMusic = love.audio.newSource('assets/sounds/music/battle_music_test_ima.wav', 'stream')
    battleMusic:setLooping(true)
    battleMusic:setVolume(0.7)
    kickSound = love.audio.newSource('assets/sounds/music/drums/kick_test_ima.wav', 'static')
    kickSound:setVolume(0.8)
    snareSound = love.audio.newSource('assets/sounds/music/drums/snare_test_ima.wav', 'static')
    snareSound:setVolume(0.8)
end

-- Playdate: snare on A presses, kick on d-pad presses, B silent — only while dancing.
local function playInputSound(mapped)
    if not PlayerData.isDancing then return end
    if mapped == "aButton" then
        snareSound:stop(); snareSound:play()
    elseif mapped == "upButton" or mapped == "downButton"
        or mapped == "leftButton" or mapped == "rightButton" then
        kickSound:stop(); kickSound:play()
    end
end
```

At the end of `danceScene.enter()`:

```lua
    loadAudio()
    -- Playdate only has a track for the basic profile
    if state.enemyType == "basic" then
        battleMusic:play()
    end
```

In `danceScene.exit()`, add:

```lua
    if battleMusic then battleMusic:stop() end
```

In `danceScene.keypressed`, in the mid-battle branch after `state.ButtonPressed = mapped`, add `playInputSound(mapped)`. Same in `danceScene.gamepadpressed` after its `state.ButtonPressed = mapped`.

- [ ] **Step 3: Run and verify**

Run: `./run_game.sh`, F5, Z.
Expected: looping battle music starts with the scene (basic type); arrow keys thump a kick, Z snaps a snare, X is silent; all audio stops when leaving the scene (win or lose).

---

### Task 10: Final verification pass

- [ ] **Step 1: Full parity checklist against the Playdate doc**

Run `./run_game.sh` and verify each line:

| # | Behavior (Playdate reference) | How to check |
|---|---|---|
| 1 | Ready screen until A; A starts battle | F5 → "ready" frame; Z/pad-A starts |
| 2 | Icons match keys; correct press → bar right (+5 A/B, +accuracy arrows) | play |
| 3 | Wrong press → −5; unpressed in zone > 5 ticks → −0.3/tick | hold nothing, watch slow drain |
| 4 | Buttons recycle instantly on hit, at left edge (center x≤32), never overlap | watch |
| 5 | Win at +50 → win overlay, A → back to game **at the fight spot**, enemy dead, calories +60 (≤500) | real flow with canDance |
| 6 | Lose at −50 → lose overlay, A → DeadScene "they caught you" | lose on purpose |
| 7 | HP always 2 after the dance | check HUD after win |
| 8 | Tiny player uses playerDanceTiny sheet | set `PlayerData.isTiny = true` temporarily before F5 |
| 9 | Difficulty roll: high powerLevel/sanity/calories → evolve/badass/boss (more+faster buttons) | temporarily set `PlayerData.EnemiesData.powerLevel = 20`, F5 **without** debugMode (use the real flow), expect boss 12 buttons; revert |
| 10 | Music only for basic; kick/snare on input | listen |
| 11 | debugMode (F5): always basic, win → title | F5 win |

- [ ] **Step 2: Check nothing else regressed**

- Start a normal run, walk a few rooms, open doors, throw the plungerang: no errors from the `gamepadreleased` routing or Config change.
- Confirm `grep -rn "danceKeys" source --include="*.lua" | grep -v DOCS` still shows only InputBindings + DanceScene.

- [ ] **Step 3: Report**

Summarize results to the user, listing any checklist line that could not be verified and why. Do not commit (user commits manually).
