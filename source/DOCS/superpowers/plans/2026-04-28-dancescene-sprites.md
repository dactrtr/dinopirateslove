# DanceScene Sprite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two critical bugs (button recycling + keyreleased routing) and replace all placeholder rectangle rendering in battle UI entities with the real sprite assets already in `assets/images/ui/battle/`.

**Architecture:** The scene logic in `DanceScene.lua` is complete and correct. The entities are all functional stubs that draw colored rectangles. This plan (A) fixes what breaks gameplay, then (B) swaps in real sprites entity by entity. No scene logic changes except adding `update(dt)` calls for animated entities and restructuring the early-return guards.

**Tech Stack:** LÖVE 2D 11.5, anim8 (`require 'libraries/anim8'`), love.graphics imagetables

---

## Asset Frame Reference

> Verify visually after each task — frame order is inferred from docs and sheet dimensions.

| File | Dimensions | Frames | Layout |
|---|---|---|---|
| `button-table-32-32.png` | 256×32 | 8 | 1 row: left=1, up=2, right=3, down=4, A=5, B=6, empty=7 |
| `hitzone-table-10-40.png` | 80×40 | 8 | 1 row: looping checker animation |
| `playerDance-table-246-214.png` | 5904×214 | 24 | 1 row: idle=1-4, jump=5-9, crouch=11-15, left=16-20, right=21-24 |
| `enemyDance-table-211-214.png` | 1266×1284 | 36 | 6×6 grid: idle=1-5, upAttack=6-9, downAttack=10-13, leftAttack=14-17, rightAttack=18-21, bButton=22-25, aButton=26-29, evolving=30-33 |
| `resultsdance-table-400-240.png` | 1600×240 | 4 | 1 row: empty=1, ready=2, win=3, lose=4 |
| `background-table-400-240.png` | 400×240 | 1 | Static |
| `buttoncover-table-78-58.png` | 78×58 | 1 | Static |
| `enemyIndicator-table-39-31.png` | 39×31 | 1 | Static |
| `playerIndicator-table-39-31.png` | 39×31 | 1 | Static |
| `nudgeIndicator.png` | 8×15 | 1 | Already used for balance bar |

---

## Layout Positions (logical 400×240)

| Entity | x | y | w | h |
|---|---|---|---|---|
| HitZone | 40 | 30 | 10 | 40 |
| ButtonPress | scrolling | 40 | 32 | 32 |
| PlayerDance | 0 | 26 | 246 | 214 |
| EnemyRatDance | 158 | 26 | 211 | 214 |
| ButtonCover | 361 | 32 | 78 | 58 |
| WinIndicator | 266 | 55 | 39 | 31 |
| LoseIndicator | 134 | 55 | 39 | 31 |

> `WinIndicator x = 200 + 50 + 2×8 = 266`. `LoseIndicator x = 200 - 50 - 2×8 = 134`. `y = BAR_Y + BAR_HEIGHT/2 - 6 = 56 + 5 - 6 = 55`.

---

## File Map

| File | Change |
|---|---|
| `source/main.lua` | Add `love.keyreleased` → routes to sceneManager |
| `source/sceneManager.lua` | Add `sceneManager.keyreleased` forwarding |
| `source/entities/UI/battle/ButtonPress.lua` | Store keyProvider + startX; add recycling; use button imagetable |
| `source/entities/UI/battle/HitZone.lua` | Animated sprite via anim8 |
| `source/entities/UI/battle/BackgroundDance.lua` | Static image |
| `source/entities/UI/battle/ButtonCover.lua` | Static image |
| `source/entities/UI/battle/WinIndicator.lua` | Static image |
| `source/entities/UI/battle/LoseIndicator.lua` | Static image |
| `source/entities/UI/battle/ResultsScreen.lua` | Imagetable, 4 frames |
| `source/entities/UI/battle/PlayerDance.lua` | anim8 animated sprite |
| `source/entities/UI/battle/EnemyRatDance.lua` | anim8 animated sprite |
| `source/scenes/DanceScene.lua` | Fix HitZone y; add update calls; restructure guards |

---

## Task 1: Fix keyreleased routing

**Without this fix:** `state.ButtonPressed` is never cleared on key release — the "held" button keeps matching every frame even after the player lets go.

**Files:**
- Modify: `source/sceneManager.lua` (after `sceneManager.wheelmoved`)
- Modify: `source/main.lua` (after `love.keypressed`)

- [ ] **Step 1: Add `sceneManager.keyreleased` to sceneManager.lua**

Add this function after `sceneManager.wheelmoved` (around line 285):

```lua
function sceneManager.keyreleased(key)
    if transition.active then return end
    if currentScene and currentScene.keyreleased then
        currentScene.keyreleased(key)
    end
end
```

- [ ] **Step 2: Add `love.keyreleased` to main.lua**

Add this function after `love.keypressed` (after line 287):

```lua
function love.keyreleased(key)
    sceneManager.keyreleased(key)
end
```

- [ ] **Step 3: Verify in-game**

Run `love source/`. Enter a dance battle, hold ← then release it. Press a different button immediately — the first button must not still be "active".

- [ ] **Step 4: Commit**

```bash
git add source/main.lua source/sceneManager.lua
git commit -m "fix: route love.keyreleased through sceneManager to scenes"
```

---

## Task 2: Fix ButtonPress recycling

**Without this fix:** Buttons disappear after being hit and never come back. After the first few presses the game has no buttons on screen.

**Files:**
- Modify: `source/entities/UI/battle/ButtonPress.lua`

- [ ] **Step 1: Replace ButtonPress.lua entirely**

```lua
-- entities/UI/battle/ButtonPress.lua
ButtonPress = {}
ButtonPress.__index = ButtonPress

local BUTTON_LABELS = {
    aButton    = "A",
    bButton    = "B",
    leftButton = "◀",
    upButton   = "▲",
    rightButton= "▶",
    downButton = "▼",
}

local LEFT_BOUNDARY = 20  -- recycle when button exits left side

-- bpm        : beats per minute (controls scroll speed)
-- startX     : x position to reset to after recycling
-- keyProvider: function() → buttonKey string
function ButtonPress.new(bpm, startX, keyProvider)
    local self = setmetatable({}, ButtonPress)
    self.keyProvider = keyProvider
    self.startX      = startX or 400
    self.buttonKey   = keyProvider()
    self.label       = BUTTON_LABELS[self.buttonKey] or "?"
    self.x           = startX or 400
    self.y           = 40         -- aligns with HitZone at y=30, h=40
    self.width       = 32
    self.height      = 32
    self.isHit       = false
    self.hitTimer    = 0
    self.delayMs     = 0
    self.elapsedMs   = 0
    self.speed       = 400 / (60 / bpm)  -- px/sec
    return self
end

function ButtonPress:movementDelay(ms)
    self.delayMs = ms
end

function ButtonPress:recycle()
    self.x         = self.startX
    self.buttonKey = self.keyProvider()
    self.label     = BUTTON_LABELS[self.buttonKey] or "?"
    self.isHit     = false
    self.hitTimer  = 0
    self.elapsedMs = self.delayMs  -- skip delay on subsequent passes
end

function ButtonPress:hit()
    self.isHit    = true
    self.hitTimer = 0.15  -- 150 ms empty state, then recycle
end

function ButtonPress:update(dt)
    if self.hitTimer > 0 then
        self.hitTimer = self.hitTimer - dt
        if self.hitTimer <= 0 then
            self:recycle()
        end
        return
    end

    if self.isHit then return end

    local dtMs = dt * 1000
    if self.elapsedMs < self.delayMs then
        self.elapsedMs = self.elapsedMs + dtMs
        return
    end

    self.x = self.x - self.speed * dt

    if self.x < LEFT_BOUNDARY - self.width then
        self:recycle()
    end
end

function ButtonPress:draw(scale)
    if self.isHit then return end
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line",
        self.x * scale, self.y * scale,
        self.width * scale, self.height * scale)
    love.graphics.printf(self.label,
        self.x * scale, self.y * scale + 8 * scale,
        self.width * scale, "center")
end

function ButtonPress:getBounds()
    return self.x, self.y, self.width, self.height
end
```

- [ ] **Step 2: Verify recycling in-game**

Run `love source/`. Enter a battle. Hit several buttons — they should reappear from the right side with new labels immediately after the 150 ms cooldown.

- [ ] **Step 3: Commit**

```bash
git add source/entities/UI/battle/ButtonPress.lua
git commit -m "fix: ButtonPress now recycles after hit and off-screen exit"
```

---

## Task 3: Fix HitZone and DanceScene layout positions

**Without this fix:** HitZone is at y=100 but sprites will render at y=26. The gameplay works but positions are inconsistent with the doc layout.

**Files:**
- Modify: `source/scenes/DanceScene.lua`

- [ ] **Step 1: Fix HitZone construction in DanceScene.lua**

Change line ~140:
```lua
-- OLD
state.hitZone = HitZone.new(40, 100, 10, 40)
-- NEW
state.hitZone = HitZone.new(40, 30, 10, 40)
```

- [ ] **Step 2: Restructure update() to always animate**

Replace the top of `danceScene.update` so animations run during the ready screen and post-condition states:

```lua
function danceScene.update(dt)
    -- Always update visual elements (animations run during ready screen too)
    state.hitZone:update(dt)
    state.playerDance:update(dt)
    state.enemyDance:update(dt)

    -- Buttons scroll continuously (visible during ready screen)
    for _, btn in ipairs(state.buttons) do
        btn:update(dt)
    end

    -- Hit detection only runs during active battle
    if not PlayerData.isDancing then return end
    if state.condition ~= nil then return end

    local inZone = state.hitZone:overlapping(state.buttons)
    -- ... rest unchanged ...
end
```

- [ ] **Step 3: Verify layout in-game**

Run `love source/`. Enter a battle — hitzone rectangle should be near the top-left, buttons should pass through it.

- [ ] **Step 4: Commit**

```bash
git add source/scenes/DanceScene.lua
git commit -m "fix: align HitZone to y=30 per doc layout; animate during ready screen"
```

---

## Task 4: Sprite — BackgroundDance

**Files:**
- Modify: `source/entities/UI/battle/BackgroundDance.lua`

- [ ] **Step 1: Replace BackgroundDance.lua**

```lua
-- entities/UI/battle/BackgroundDance.lua
BackgroundDance = {}
BackgroundDance.__index = BackgroundDance

function BackgroundDance.new()
    local self = setmetatable({}, BackgroundDance)
    self.image = love.graphics.newImage('assets/images/ui/battle/background-table-400-240.png')
    return self
end

function BackgroundDance:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, 0, 0, 0, scale, scale)
end
```

- [ ] **Step 2: Verify in-game**

Battle background should show the actual sprite instead of dark blue fill.

- [ ] **Step 3: Commit**

```bash
git add source/entities/UI/battle/BackgroundDance.lua
git commit -m "feat: BackgroundDance uses real sprite asset"
```

---

## Task 5: Sprite — ButtonCover

**Files:**
- Modify: `source/entities/UI/battle/ButtonCover.lua`

- [ ] **Step 1: Replace ButtonCover.lua**

```lua
-- entities/UI/battle/ButtonCover.lua
ButtonCover = {}
ButtonCover.__index = ButtonCover

local COVER_X = 361
local COVER_Y = 32

function ButtonCover.new()
    local self = setmetatable({}, ButtonCover)
    self.image = love.graphics.newImage('assets/images/ui/battle/buttoncover-table-78-58.png')
    return self
end

function ButtonCover:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, COVER_X * scale, COVER_Y * scale, 0, scale, scale)
end
```

- [ ] **Step 2: Verify in-game**

The right-side panel should show the real decorative cover sprite over the button spawn area.

- [ ] **Step 3: Commit**

```bash
git add source/entities/UI/battle/ButtonCover.lua
git commit -m "feat: ButtonCover uses real sprite asset"
```

---

## Task 6: Sprites — WinIndicator and LoseIndicator

**Files:**
- Modify: `source/entities/UI/battle/WinIndicator.lua`
- Modify: `source/entities/UI/battle/LoseIndicator.lua`

- [ ] **Step 1: Replace WinIndicator.lua**

```lua
-- entities/UI/battle/WinIndicator.lua
WinIndicator = {}
WinIndicator.__index = WinIndicator

function WinIndicator.new(x, y)
    local self = setmetatable({ x = x, y = y }, WinIndicator)
    self.image = love.graphics.newImage('assets/images/ui/battle/enemyIndicator-table-39-31.png')
    return self
end

function WinIndicator:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, self.x * scale, self.y * scale, 0, scale, scale)
end
```

- [ ] **Step 2: Replace LoseIndicator.lua**

```lua
-- entities/UI/battle/LoseIndicator.lua
LoseIndicator = {}
LoseIndicator.__index = LoseIndicator

function LoseIndicator.new(x, y)
    local self = setmetatable({ x = x, y = y }, LoseIndicator)
    self.image = love.graphics.newImage('assets/images/ui/battle/playerIndicator-table-39-31.png')
    return self
end

function LoseIndicator:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, self.x * scale, self.y * scale, 0, scale, scale)
end
```

- [ ] **Step 3: Verify in-game**

Win/lose markers flanking the balance bar should show the real indicator sprites.

- [ ] **Step 4: Commit**

```bash
git add source/entities/UI/battle/WinIndicator.lua source/entities/UI/battle/LoseIndicator.lua
git commit -m "feat: WinIndicator and LoseIndicator use real sprite assets"
```

---

## Task 7: Animated Sprite — HitZone

**Files:**
- Modify: `source/entities/UI/battle/HitZone.lua`

- [ ] **Step 1: Replace HitZone.lua**

```lua
-- entities/UI/battle/HitZone.lua
local anim8 = require 'libraries/anim8'

HitZone = {}
HitZone.__index = HitZone

function HitZone.new(x, y, w, h)
    local self = setmetatable({ x=x, y=y, w=w, h=h }, HitZone)
    self.image    = love.graphics.newImage('assets/images/ui/battle/hitzone-table-10-40.png')
    local g       = anim8.newGrid(w, h, self.image:getWidth(), self.image:getHeight())
    self.anim     = anim8.newAnimation(g('1-8', 1), 0.06)  -- 8 frames, ~0.5s loop
    return self
end

local function aabbOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and
           ay < by + bh and ay + ah > by
end

function HitZone:overlapping(buttons)
    local result = {}
    for _, btn in ipairs(buttons) do
        if not btn.isHit then
            local bx, by, bw, bh = btn:getBounds()
            if aabbOverlap(self.x, self.y, self.w, self.h, bx, by, bw, bh) then
                result[#result + 1] = btn
            end
        end
    end
    return result
end

function HitZone:update(dt)
    self.anim:update(dt)
end

function HitZone:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    self.anim:draw(self.image, self.x * scale, self.y * scale, 0, scale, scale)
end
```

- [ ] **Step 2: Verify in-game**

The hitzone on the left should show the animated sprite cycling through its 8 frames.

- [ ] **Step 3: Commit**

```bash
git add source/entities/UI/battle/HitZone.lua
git commit -m "feat: HitZone uses animated sprite (8-frame loop)"
```

---

## Task 8: Imagetable Sprite — ButtonPress

**Files:**
- Modify: `source/entities/UI/battle/ButtonPress.lua` (extend Task 2 version)

Frame mapping for `button-table-32-32.png` (8 frames, 1 row):
- 1=leftButton, 2=upButton, 3=rightButton, 4=downButton, 5=aButton, 6=bButton, 7=empty, 8=unused

- [ ] **Step 1: Add imagetable to ButtonPress.lua**

Replace the file (keep all recycling logic from Task 2, add sprite fields):

```lua
-- entities/UI/battle/ButtonPress.lua
ButtonPress = {}
ButtonPress.__index = ButtonPress

local BUTTON_LABELS = {
    aButton    = "A",
    bButton    = "B",
    leftButton = "◀",
    upButton   = "▲",
    rightButton= "▶",
    downButton = "▼",
}

-- Frame indices in button-table-32-32.png (8 frames, 1 row)
local BUTTON_FRAMES = {
    leftButton  = 1,
    upButton    = 2,
    rightButton = 3,
    downButton  = 4,
    aButton     = 5,
    bButton     = 6,
}
local EMPTY_FRAME = 7

local LEFT_BOUNDARY = 20
local _image, _quads  -- module-level cache (shared across all instances)

local function loadAssets()
    if _image then return end
    _image = love.graphics.newImage('assets/images/ui/battle/button-table-32-32.png')
    _quads = {}
    local fw, fh = 32, 32
    local iw = _image:getWidth()
    local nFrames = math.floor(iw / fw)
    for i = 1, nFrames do
        _quads[i] = love.graphics.newQuad((i-1)*fw, 0, fw, fh, iw, fh)
    end
end

function ButtonPress.new(bpm, startX, keyProvider)
    loadAssets()
    local self = setmetatable({}, ButtonPress)
    self.keyProvider = keyProvider
    self.startX      = startX or 400
    self.buttonKey   = keyProvider()
    self.label       = BUTTON_LABELS[self.buttonKey] or "?"
    self.x           = startX or 400
    self.y           = 40
    self.width       = 32
    self.height      = 32
    self.isHit       = false
    self.hitTimer    = 0
    self.delayMs     = 0
    self.elapsedMs   = 0
    self.speed       = 400 / (60 / bpm)
    return self
end

function ButtonPress:movementDelay(ms)
    self.delayMs = ms
end

function ButtonPress:recycle()
    self.x         = self.startX
    self.buttonKey = self.keyProvider()
    self.label     = BUTTON_LABELS[self.buttonKey] or "?"
    self.isHit     = false
    self.hitTimer  = 0
    self.elapsedMs = self.delayMs  -- skip delay on subsequent passes
end

function ButtonPress:hit()
    self.isHit    = true
    self.hitTimer = 0.15
end

function ButtonPress:update(dt)
    if self.hitTimer > 0 then
        self.hitTimer = self.hitTimer - dt
        if self.hitTimer <= 0 then self:recycle() end
        return
    end
    if self.isHit then return end
    local dtMs = dt * 1000
    if self.elapsedMs < self.delayMs then
        self.elapsedMs = self.elapsedMs + dtMs
        return
    end
    self.x = self.x - self.speed * dt
    if self.x < LEFT_BOUNDARY - self.width then
        self:recycle()
    end
end

function ButtonPress:draw(scale)
    scale = scale or 1
    local frameIdx = self.isHit and EMPTY_FRAME or (BUTTON_FRAMES[self.buttonKey] or 1)
    local quad = _quads[frameIdx]
    if not quad then return end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(_image, quad, self.x * scale, self.y * scale, 0, scale, scale)
end

function ButtonPress:getBounds()
    return self.x, self.y, self.width, self.height
end
```

> **Note:** The hit-state draws `EMPTY_FRAME` for the 150 ms cooldown, then recycles. Remove the `if self.isHit then return end` guard that was in Task 2's draw — we now draw the empty frame instead.

- [ ] **Step 2: Verify in-game**

Buttons should show the real button sprites. On hit, they briefly show the empty frame before reappearing from the right.

- [ ] **Step 3: Commit**

```bash
git add source/entities/UI/battle/ButtonPress.lua
git commit -m "feat: ButtonPress renders real button imagetable sprites"
```

---

## Task 9: Imagetable Sprite — ResultsScreen

**Files:**
- Modify: `source/entities/UI/battle/ResultsScreen.lua`

Frame mapping for `resultsdance-table-400-240.png` (4 frames, 1 row):
- 1=empty (transparent / no overlay), 2=ready (Press A to start), 3=win, 4=lose

- [ ] **Step 1: Replace ResultsScreen.lua**

```lua
-- entities/UI/battle/ResultsScreen.lua
ResultsScreen = {}
ResultsScreen.__index = ResultsScreen

local FRAME = { playing=1, loading=2, win=3, lose=4 }

function ResultsScreen.new()
    local self = setmetatable({ state = "loading" }, ResultsScreen)
    self.image = love.graphics.newImage('assets/images/ui/battle/resultsdance-table-400-240.png')
    local iw = self.image:getWidth()
    local fw, fh = 400, 240
    self.quads = {}
    local nFrames = math.floor(iw / fw)
    for i = 1, nFrames do
        self.quads[i] = love.graphics.newQuad((i-1)*fw, 0, fw, fh, iw, fh)
    end
    return self
end

function ResultsScreen:empty()         self.state = "playing" end
function ResultsScreen:win()           if self.state ~= "win"  then self.state = "win"  end end
function ResultsScreen:lose()          if self.state ~= "lose" then self.state = "lose" end end
function ResultsScreen:loadingScreen() self.state = "loading" end

function ResultsScreen:draw(scale)
    scale = scale or 1
    local frameIdx = FRAME[self.state] or 1
    local quad = self.quads[frameIdx]
    if not quad then return end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.image, quad, 0, 0, 0, scale, scale)
end
```

> If the frame order is wrong after visual inspection, swap the `FRAME` table values.

- [ ] **Step 2: Verify in-game**

Each state (ready, win, lose) should show the correct full-screen overlay frame. In `playing` state, the screen should be clear (frame 1 = empty/transparent).

- [ ] **Step 3: Commit**

```bash
git add source/entities/UI/battle/ResultsScreen.lua
git commit -m "feat: ResultsScreen uses real imagetable (ready/win/lose frames)"
```

---

## Task 10: Animated Sprite — PlayerDance

`playerDance-table-246-214.png` is 5904×214 → 24 frames in 1 row (246×214 each).

Animation states:
| State | Frames | Trigger |
|---|---|---|
| idle | 1–4 | default / `setIdle()` |
| jump | 5–9 | upButton correct press |
| crouch | 11–15 | downButton correct press |
| left | 16–20 | leftButton correct press |
| right | 21–24 | rightButton correct press |

Frame 10 is a transition/gap frame — include it in idle or skip (use frames 1-4 for idle).

**Files:**
- Modify: `source/entities/UI/battle/PlayerDance.lua`
- Modify: `source/scenes/DanceScene.lua` (update call already added in Task 3)

- [ ] **Step 1: Replace PlayerDance.lua**

```lua
-- entities/UI/battle/PlayerDance.lua
local anim8 = require 'libraries/anim8'

PlayerDance = {}
PlayerDance.__index = PlayerDance

local PLAYER_X = 0
local PLAYER_Y = 26

function PlayerDance.new(bpm)
    local self = setmetatable({ bpm = bpm }, PlayerDance)
    self.image = love.graphics.newImage('assets/images/ui/battle/playerDance-table-246-214.png')
    local g    = anim8.newGrid(246, 214, self.image:getWidth(), self.image:getHeight())
    local fps  = 10  -- animation frames per second
    self.anims = {
        idle   = anim8.newAnimation(g('1-4',  1), 1/fps),
        jump   = anim8.newAnimation(g('5-9',  1), 1/fps),
        crouch = anim8.newAnimation(g('11-15',1), 1/fps),
        left   = anim8.newAnimation(g('16-20',1), 1/fps),
        right  = anim8.newAnimation(g('21-24',1), 1/fps),
    }
    self.currentAnim = self.anims.idle
    return self
end

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
    end
end

function PlayerDance:setIdle()
    self.currentAnim = self.anims.idle
end

function PlayerDance:update(dt)
    self.currentAnim:update(dt)
end

function PlayerDance:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    self.currentAnim:draw(self.image, PLAYER_X * scale, PLAYER_Y * scale, 0, scale, scale)
end
```

- [ ] **Step 2: Verify `update` call exists in DanceScene.update()**

Confirm `state.playerDance:update(dt)` is called at the top of `danceScene.update` (added in Task 3). If not, add it.

- [ ] **Step 3: Verify in-game**

Player sprite should show idle animation by default, switch to directional animations on correct arrow presses.

- [ ] **Step 4: Commit**

```bash
git add source/entities/UI/battle/PlayerDance.lua
git commit -m "feat: PlayerDance uses anim8 animated sprite (24-frame sheet)"
```

---

## Task 11: Animated Sprite — EnemyRatDance

`enemyDance-table-211-214.png` is 1266×1284 → 6 cols × 6 rows = 36 frames.

Frame numbering (row-major): frame N → col = `((N-1) % 6) + 1`, row = `math.floor((N-1) / 6) + 1`.

Animation states:
| State | Frames | Trigger |
|---|---|---|
| idle | 1–5 | default / `setIdle()` |
| upAttack | 6–9 | downButton in zone |
| downAttack | 10–13 | upButton in zone |
| leftAttack | 14–17 | leftButton in zone |
| rightAttack | 18–21 | rightButton in zone |
| bButton | 22–25 | correct bButton press |
| aButton | 26–29 | correct aButton press |
| evolving | 30–33 | (unused in combat) |

**Files:**
- Modify: `source/entities/UI/battle/EnemyRatDance.lua`
- Modify: `source/scenes/DanceScene.lua` (update call already added in Task 3)

- [ ] **Step 1: Replace EnemyRatDance.lua**

```lua
-- entities/UI/battle/EnemyRatDance.lua
local anim8 = require 'libraries/anim8'

EnemyRatDance = {}
EnemyRatDance.__index = EnemyRatDance

local ENEMY_X = 158
local ENEMY_Y = 26
local COLS    = 6  -- columns in the 6×6 grid

local function buildAnim(g, fromFrame, toFrame, fps)
    local quads = {}
    for n = fromFrame, toFrame do
        local col = ((n-1) % COLS) + 1
        local row = math.floor((n-1) / COLS) + 1
        for _, q in ipairs(g(col, row)) do
            quads[#quads+1] = q
        end
    end
    return anim8.newAnimation(quads, 1 / fps)
end

function EnemyRatDance.new(bpm, enemyType, evolving)
    local self = setmetatable({
        bpm=bpm, enemyType=enemyType or "basic", evolving=evolving or false
    }, EnemyRatDance)
    self.image = love.graphics.newImage('assets/images/ui/battle/enemyDance-table-211-214.png')
    local g    = anim8.newGrid(211, 214, self.image:getWidth(), self.image:getHeight())
    local fps  = 10
    self.anims = {
        idle        = buildAnim(g, 1,  5,  fps),
        upAttack    = buildAnim(g, 6,  9,  fps),
        downAttack  = buildAnim(g, 10, 13, fps),
        leftAttack  = buildAnim(g, 14, 17, fps),
        rightAttack = buildAnim(g, 18, 21, fps),
        bButton     = buildAnim(g, 22, 25, fps),
        aButton     = buildAnim(g, 26, 29, fps),
        evolving    = buildAnim(g, 30, 33, fps),
    }
    self.currentAnim = self.anims.idle
    return self
end

-- Called when a button prompt is visible in the zone
local ZONE_MAP = {
    downButton  = "upAttack",
    upButton    = "downAttack",
    leftButton  = "leftAttack",
    rightButton = "rightAttack",
}

function EnemyRatDance:changeAnimation(buttonKey)
    local name = ZONE_MAP[buttonKey]
    if name and self.anims[name] then
        self.currentAnim = self.anims[name]
        self.currentAnim:gotoFrame(1)
    end
end

-- Called on correct A/B press
function EnemyRatDance:attackAnimation(buttonKey)
    local name = (buttonKey == "aButton") and "aButton" or "bButton"
    if self.anims[name] then
        self.currentAnim = self.anims[name]
        self.currentAnim:gotoFrame(1)
    end
end

function EnemyRatDance:setIdle()
    self.currentAnim = self.anims.idle
    self.currentAnim:gotoFrame(1)
end

function EnemyRatDance:update(dt)
    self.currentAnim:update(dt)
    -- Return to idle when non-looping attack finishes
    if self.currentAnim ~= self.anims.idle and self.currentAnim.status == "paused" then
        self:setIdle()
    end
end

function EnemyRatDance:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    self.currentAnim:draw(self.image, ENEMY_X * scale, ENEMY_Y * scale, 0, scale, scale)
end
```

- [ ] **Step 2: Set attack animations to non-looping**

In `EnemyRatDance.new`, after building attack anims, set them to pause at end:

```lua
local attackNames = {"upAttack","downAttack","leftAttack","rightAttack","bButton","aButton","evolving"}
for _, name in ipairs(attackNames) do
    self.anims[name]:pauseAtEnd()
end
```

Add this block inside `EnemyRatDance.new` after the `self.anims = { ... }` table.

- [ ] **Step 3: Verify `update` call in DanceScene.update()**

Confirm `state.enemyDance:update(dt)` is called at top of `danceScene.update` (added Task 3). If not, add it.

- [ ] **Step 4: Verify in-game**

Enemy sprite should animate idle by default. When a button prompt is in the zone, enemy should react. On correct A/B press, enemy attack animation should play then return to idle.

- [ ] **Step 5: Commit**

```bash
git add source/entities/UI/battle/EnemyRatDance.lua
git commit -m "feat: EnemyRatDance uses anim8 animated sprite (6x6 grid, 36 frames)"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] keyreleased routing → Task 1
- [x] ButtonPress recycling → Task 2
- [x] HitZone position fix → Task 3
- [x] All 9 sprite entities replaced → Tasks 4-11
- [x] Animation update calls added to DanceScene → Task 3
- [x] EnemyRatDance attack→idle return → Task 11 Step 2

**Known assumptions (verify visually):**
- Button imagetable frame order (left=1, up=2, right=3, down=4, A=5, B=6, empty=7)
- ResultsScreen frame order (empty=1, ready=2, win=3, lose=4)
- EnemyRatDance frame ranges for idle and directional attacks (inferred from doc + sheet math)
- PlayerDance frame 10 skipped (gap between jump and crouch sequences)

**Type/name consistency:**
- `HitZone:update(dt)` added in Task 7, called in Task 3 ✓
- `PlayerDance:update(dt)` in Task 10, called in Task 3 ✓
- `EnemyRatDance:update(dt)` in Task 11, called in Task 3 ✓
- `ButtonPress:recycle()` defined in Task 2, reused in Task 8 ✓
- `ButtonPress:getBounds()` returns `self.width=32` (was 20) — HitZone AABB still works ✓
