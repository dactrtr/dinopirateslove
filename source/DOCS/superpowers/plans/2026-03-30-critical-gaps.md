# Critical Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Lightburst skill, port the Love2D DanceScene prototype into the main source tree, and wire `fight()` to complete the core gameplay loop.

**Architecture:** A complete DanceScene implementation already exists in `love2d-dancescene/` with passing busted tests. Integration work: copy battle entities into `source/entities/UI/battle/`, adapt DanceScene.lua (change require paths, SCALE, sceneManager calls), register the scene, and wire `fight()`. Lightburst is a separate, self-contained addition to player + gameScene.

**Tech Stack:** LÖVE 11.5, Lua, bump.lua, anim8, hump timer, busted (for battle logic tests)

---

## File Map

### New files (created)
| File | Source |
|---|---|
| `source/entities/UI/battle/ButtonPress.lua` | Adapted from `love2d-dancescene/src/entities/ButtonPress.lua` |
| `source/entities/UI/battle/HitZone.lua` | Adapted from `love2d-dancescene/src/entities/HitZone.lua` |
| `source/entities/UI/battle/PlayerDance.lua` | Adapted from `love2d-dancescene/src/entities/PlayerDance.lua` |
| `source/entities/UI/battle/EnemyRatDance.lua` | Adapted from `love2d-dancescene/src/entities/EnemyRatDance.lua` |
| `source/entities/UI/battle/BackgroundDance.lua` | Adapted from `love2d-dancescene/src/entities/BackgroundDance.lua` |
| `source/entities/UI/battle/ButtonCover.lua` | Adapted from `love2d-dancescene/src/entities/ButtonCover.lua` |
| `source/entities/UI/battle/WinIndicator.lua` | Adapted from `love2d-dancescene/src/entities/WinIndicator.lua` |
| `source/entities/UI/battle/LoseIndicator.lua` | Adapted from `love2d-dancescene/src/entities/LoseIndicator.lua` |
| `source/entities/UI/battle/ResultsScreen.lua` | Adapted from `love2d-dancescene/src/entities/ResultsScreen.lua` |
| `source/utilities/balance.lua` | Adapted from `love2d-dancescene/src/logic/balance.lua` |

### Rewritten
| File | Change |
|---|---|
| `source/scenes/DanceScene.lua` | Full rewrite using love2d-dancescene logic + source integration points |

### Modified
| File | Change |
|---|---|
| `source/main.lua` | Add `flash` Input binding, require + register DanceScene |
| `source/scenes/gameScene.lua` | Add `findAndKillEnemyById`, add flash key handler |
| `source/utilities.lua` | Add `Utilities.pointInPolygon(pts, x, y)` |
| `source/entities/player/init.lua` | Add `Player:lightBurst()` method |
| `source/entities/player/collisions.lua` | Replace `fight()` stub with real transition |

---

## Key integration differences: love2d-dancescene → source

| love2d-dancescene | source (what to use instead) |
|---|---|
| `require "src/data/PlayerData"` | `PlayerData` is a global — no require needed |
| `SCALE = 2` in DanceScene, `draw(SCALE)` | Source draws to 400×240 canvas. Pass `scale = 1` to all entity `draw()` calls |
| `SceneManager.switch(TitleScene.new())` | `sceneManager.startTransition("dance", "title", "slide")` |
| `SceneManager.switch(DanceScene.new())` → win returns to maze | `sceneManager.startTransition("dance", "game", "slide")` |
| `findAndKillEnemyById(id)` is a print stub | call `gameScene.findAndKillEnemyById(id)` (added in Task 5) |
| `require "src/entities/ButtonPress"` etc. | `require 'entities.UI.battle.ButtonPress'` etc. |
| `EnemyPatterns` loaded via require | inline in DanceScene.lua (already local in love2d-dancescene) |

---

## Task 1: Verify battle logic tests pass

**Files:** `love2d-dancescene/tests/` (read-only, do not modify)

- [ ] **Step 1: Run busted tests**

```bash
cd /Users/dactrtr-mini/Documents/GitHub/DinopiratesLove/dinopirateslove/love2d-dancescene
busted tests/
```

Expected output: `31 successes / 0 failures / 0 errors`

If busted is not installed: `luarocks install busted` or `brew install lua && luarocks install busted`

- [ ] **Step 2: Confirm all 5 test files pass**

The tests cover: `test_balance.lua`, `test_button_press.lua`, `test_hitzone.lua`, `test_difficulty.lua`, `test_patterns.lua`. All must pass before proceeding.

---

## Task 2: Copy battle entities into source

**Files:** Create `source/entities/UI/battle/*.lua`

The only adaptation needed: remove `require "src/..."` lines (all globals are pre-loaded by source/main.lua), and no SCALE changes (the `draw(scale)` parameter is kept — callers pass `1` since source uses a 400×240 canvas).

- [ ] **Step 1: Create ButtonPress.lua**

Create `source/entities/UI/battle/ButtonPress.lua` with this content (identical to love2d-dancescene version — no changes needed, it has no requires and uses only love.graphics):

```lua
-- entities/UI/battle/ButtonPress.lua
-- Scrolls right→left across the screen. Owned and updated by DanceScene.

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

function ButtonPress.new(bpm, startX, keyProvider)
    local self  = setmetatable({}, ButtonPress)
    self.buttonKey   = keyProvider()
    self.label       = BUTTON_LABELS[self.buttonKey] or "?"
    self.x           = startX or 400
    self.y           = 110
    self.width       = 20
    self.height      = 20
    self.isHit       = false
    self.delayMs     = 0
    self.elapsedMs   = 0
    self.speed       = 400 / (60 / bpm)
    return self
end

function ButtonPress:movementDelay(ms)
    self.delayMs = ms
end

function ButtonPress:update(dt)
    if self.isHit then return end
    local dtMs = dt * 1000
    if self.elapsedMs < self.delayMs then
        self.elapsedMs = self.elapsedMs + dtMs
        return
    end
    self.x = self.x - self.speed * dt
end

function ButtonPress:draw(scale)
    if self.isHit then return end
    scale = scale or 1
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", self.x * scale, self.y * scale, self.width * scale, self.height * scale)
    love.graphics.printf(self.label, self.x * scale, self.y * scale + 2 * scale, self.width * scale, "center")
end

function ButtonPress:hit()
    self.isHit = true
end

function ButtonPress:getBounds()
    return self.x, self.y, self.width, self.height
end
```

- [ ] **Step 2: Create HitZone.lua**

Create `source/entities/UI/battle/HitZone.lua`:

```lua
-- entities/UI/battle/HitZone.lua
HitZone = {}
HitZone.__index = HitZone

function HitZone.new(x, y, w, h)
    return setmetatable({ x=x, y=y, w=w, h=h }, HitZone)
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

function HitZone:draw(scale)
    scale = scale or 1
    love.graphics.setColor(0.2, 0.8, 0.2, 0.5)
    love.graphics.rectangle("fill", self.x * scale, self.y * scale, self.w * scale, self.h * scale)
    love.graphics.setColor(1, 1, 1)
end
```

- [ ] **Step 3: Create PlayerDance.lua**

Create `source/entities/UI/battle/PlayerDance.lua`:

```lua
-- entities/UI/battle/PlayerDance.lua
PlayerDance = {}
PlayerDance.__index = PlayerDance

function PlayerDance.new(bpm)
    return setmetatable({ bpm=bpm, state="idle" }, PlayerDance)
end

function PlayerDance:changeAnimation(buttonKey)
    -- Only responds to arrow buttons (directional), not A/B
    if buttonKey == "leftButton" or buttonKey == "rightButton"
    or buttonKey == "upButton"   or buttonKey == "downButton" then
        self.state = buttonKey
    end
end

function PlayerDance:setIdle()
    self.state = "idle"
end

function PlayerDance:update(dt) end

function PlayerDance:draw(scale)
    scale = scale or 1
    local x, y = 60 * scale, 150 * scale
    love.graphics.setColor(0.3, 0.6, 1)
    love.graphics.rectangle("fill", x, y, 30 * scale, 40 * scale)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("P\n" .. self.state:sub(1,3), x, y + 4 * scale, 30 * scale, "center")
end
```

- [ ] **Step 4: Create EnemyRatDance.lua**

Create `source/entities/UI/battle/EnemyRatDance.lua`:

```lua
-- entities/UI/battle/EnemyRatDance.lua
EnemyRatDance = {}
EnemyRatDance.__index = EnemyRatDance

function EnemyRatDance.new(bpm, enemyType, evolving)
    return setmetatable({
        bpm=bpm, enemyType=enemyType or "basic",
        evolving=evolving or false, state="idle",
    }, EnemyRatDance)
end

function EnemyRatDance:changeAnimation(buttonKey) self.state = buttonKey end
function EnemyRatDance:attackAnimation(buttonKey) self.state = "attack_" .. buttonKey end
function EnemyRatDance:setIdle() self.state = "idle" end
function EnemyRatDance:update(dt) end

function EnemyRatDance:draw(scale)
    scale = scale or 1
    local x, y = 280 * scale, 150 * scale
    local color = self.evolving and {1, 0.5, 0} or {0.8, 0.2, 0.2}
    love.graphics.setColor(table.unpack(color))
    love.graphics.rectangle("fill", x, y, 30 * scale, 40 * scale)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("E\n" .. self.state:sub(1,3), x, y + 4 * scale, 30 * scale, "center")
end
```

- [ ] **Step 5: Create BackgroundDance.lua, ButtonCover.lua, WinIndicator.lua, LoseIndicator.lua**

Create `source/entities/UI/battle/BackgroundDance.lua`:
```lua
-- entities/UI/battle/BackgroundDance.lua
BackgroundDance = {}
BackgroundDance.__index = BackgroundDance

function BackgroundDance.new()
    return setmetatable({}, BackgroundDance)
end

function BackgroundDance:draw(scale)
    scale = scale or 1
    love.graphics.setColor(0.05, 0.05, 0.15)
    love.graphics.rectangle("fill", 0, 0, 400 * scale, 240 * scale)
    love.graphics.setColor(1, 1, 1)
end
```

Create `source/entities/UI/battle/ButtonCover.lua`:
```lua
-- entities/UI/battle/ButtonCover.lua
ButtonCover = {}
ButtonCover.__index = ButtonCover

function ButtonCover.new()
    return setmetatable({}, ButtonCover)
end

function ButtonCover:draw(scale)
    scale = scale or 1
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 100 * scale, 25 * scale, 40 * scale)
    love.graphics.setColor(1, 1, 1)
end
```

Create `source/entities/UI/battle/WinIndicator.lua`:
```lua
-- entities/UI/battle/WinIndicator.lua
WinIndicator = {}
WinIndicator.__index = WinIndicator

function WinIndicator.new(x, y)
    return setmetatable({ x=x, y=y }, WinIndicator)
end

function WinIndicator:draw(scale)
    scale = scale or 1
    love.graphics.setColor(0.2, 1, 0.2)
    love.graphics.print("WIN", self.x * scale, self.y * scale)
    love.graphics.setColor(1, 1, 1)
end
```

Create `source/entities/UI/battle/LoseIndicator.lua`:
```lua
-- entities/UI/battle/LoseIndicator.lua
LoseIndicator = {}
LoseIndicator.__index = LoseIndicator

function LoseIndicator.new(x, y)
    return setmetatable({ x=x, y=y }, LoseIndicator)
end

function LoseIndicator:draw(scale)
    scale = scale or 1
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.print("LOSE", self.x * scale, self.y * scale)
    love.graphics.setColor(1, 1, 1)
end
```

- [ ] **Step 6: Create ResultsScreen.lua**

Create `source/entities/UI/battle/ResultsScreen.lua`:

```lua
-- entities/UI/battle/ResultsScreen.lua
ResultsScreen = {}
ResultsScreen.__index = ResultsScreen

function ResultsScreen.new()
    return setmetatable({ state = "loading" }, ResultsScreen)
end

function ResultsScreen:empty()   self.state = "playing" end
function ResultsScreen:win()     if self.state ~= "win"  then self.state = "win"  end end
function ResultsScreen:lose()    if self.state ~= "lose" then self.state = "lose" end end
function ResultsScreen:loadingScreen() self.state = "loading" end

function ResultsScreen:draw(scale)
    scale = scale or 1
    if self.state == "playing" then return end

    local W = 400 * scale
    local H = 240 * scale

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(1, 1, 1)

    if self.state == "loading" then
        love.graphics.printf("Press SPACE to START BATTLE", 0, H * 0.42, W, "center")
    elseif self.state == "win" then
        love.graphics.setColor(0.2, 1, 0.2)
        love.graphics.printf("YOU WIN!\nPress SPACE to continue", 0, H * 0.375, W, "center")
        love.graphics.setColor(1, 1, 1)
    elseif self.state == "lose" then
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.printf("YOU LOSE!\nPress SPACE to continue", 0, H * 0.375, W, "center")
        love.graphics.setColor(1, 1, 1)
    end
end
```

- [ ] **Step 7: Create balance.lua in source/utilities/**

Create `source/utilities/balance.lua` (identical to love2d-dancescene version — pure Lua, no dependencies):

```lua
-- utilities/balance.lua
-- Pure balance-position logic. No love2d or PlayerData dependencies.
Balance = {}

Balance.A_BUTTON_DELTA    =  5
Balance.WRONG_PRESS_DELTA = -5
Balance.MISS_DELTA        = -0.3
Balance.MISS_GRACE_FRAMES =  5

function Balance.applyABHit(pos)      return pos + Balance.A_BUTTON_DELTA    end
function Balance.applyArrowHit(pos, accuracy) return pos + accuracy           end
function Balance.applyWrongPress(pos) return pos + Balance.WRONG_PRESS_DELTA  end

function Balance.applyMissPenalty(pos, accuracyFrames)
    if accuracyFrames > Balance.MISS_GRACE_FRAMES then
        return pos + Balance.MISS_DELTA
    end
    return pos
end

function Balance.clamp(pos, maxOffset)
    return math.max(-maxOffset, math.min(maxOffset, pos))
end

function Balance.isWin(pos, maxOffset)  return pos >= maxOffset  end
function Balance.isLose(pos, maxOffset) return pos <= -maxOffset end
```

---

## Task 3: Rewrite source/scenes/DanceScene.lua

**Files:** Rewrite `source/scenes/DanceScene.lua`

This replaces the existing Playdate SDK file with a Love2D scene table. All game logic (difficulty, patterns, balance mechanics) is preserved verbatim from the love2d-dancescene prototype. Integration changes: require paths, scale=1, sceneManager calls, real findAndKillEnemyById.

- [ ] **Step 1: Verify the battle entities from Task 2 are in place**

```bash
ls source/entities/UI/battle/
```

Expected: `BackgroundDance.lua  ButtonCover.lua  ButtonPress.lua  EnemyRatDance.lua  HitZone.lua  LoseIndicator.lua  PlayerDance.lua  ResultsScreen.lua  WinIndicator.lua`

- [ ] **Step 2: Write source/scenes/DanceScene.lua**

Create `source/scenes/DanceScene.lua` with the following content. Key differences from love2d-dancescene:
- `require` uses dot notation (`'entities.UI.battle.ButtonPress'`)
- `PlayerData` is global (no require)
- `scale = 1` passed to all `draw()` calls (source draws to 400×240 canvas)
- `sceneManager.startTransition(...)` replaces `SceneManager.switch(...)`
- `gameScene.findAndKillEnemyById(id)` replaces the print stub

```lua
-- scenes/DanceScene.lua
-- Love2D port of the rhythm combat scene.
-- Registered as "dance" in sceneManager. Reads enemy info from PlayerData.lastEnemyTouched.

local sceneManager = require 'sceneManager'

require 'entities.UI.battle.ButtonPress'
require 'entities.UI.battle.HitZone'
require 'entities.UI.battle.PlayerDance'
require 'entities.UI.battle.EnemyRatDance'
require 'entities.UI.battle.BackgroundDance'
require 'entities.UI.battle.ButtonCover'
require 'entities.UI.battle.WinIndicator'
require 'entities.UI.battle.LoseIndicator'
require 'entities.UI.battle.ResultsScreen'
require 'utilities.balance'

local danceScene = {}

-- ── Screen layout constants (logical 400×240) ─────────────────────────────────
local SCREEN_CENTER_X = 200
local BAR_WIDTH       = 8
local BAR_HEIGHT      = 10
local BAR_Y           = 56

-- ── Enemy pattern profiles ────────────────────────────────────────────────────
local EnemyPatterns = {
    basic  = { weights = { arrows=0.8, aButton=0.2, bButton=0.0 }, phaseLength=10 },
    evolve = { weights = { arrows=0.6, aButton=0.2, bButton=0.2 }, phaseLength=10 },
    badass = { weights = { arrows=0.4, aButton=0.3, bButton=0.3 }, phaseLength=8  },
    boss   = { weights = { arrows=0.2, aButton=0.4, bButton=0.4 }, phaseLength=6  },
}

local function getPatternKey(profile)
    local w = profile.weights
    local rand = math.random()
    local sum = w.arrows + w.aButton + w.bButton
    local choice = rand * sum
    if choice < w.arrows then
        local arrows = {"leftButton","upButton","rightButton","downButton"}
        return arrows[math.random(#arrows)]
    elseif choice < w.arrows + w.aButton then
        return "aButton"
    else
        return "bButton"
    end
end

-- ── Difficulty helpers (verbatim from love2d-dancescene) ──────────────────────
local function determineDifficultyUpgrade()
    local sanity   = PlayerData.sanityCounter or 0
    local power    = (PlayerData.EnemiesData and PlayerData.EnemiesData.powerLevel) or 0
    local calories = PlayerData.calories or 0
    local sN = math.max(0, math.min(1, sanity   / 100))
    local pN = math.max(0, math.min(1, power    / 20))
    local cN = math.max(0, math.min(1, calories / 500))
    return math.max(0, math.min(100, (sN*0.35 + pN*0.45 + cN*0.20) * 100))
end

local function determineEnemyType()
    local pwr = PlayerData.EnemiesData.powerLevel
    if pwr >= 1  and pwr <= 5  then return "basic"  end
    if pwr >= 6  and pwr <= 12 then return "evolve" end
    if pwr >= 13 and pwr <= 19 then return "badass" end
    if pwr == 20               then return "boss"   end
    return "basic"
end

-- ── Scene state (reset on each enter) ────────────────────────────────────────
local state = {}

local function resetState()
    state.bpm             = 16
    state.ButtonPressed   = nil
    state.accuracy        = 0
    state.totalAccuracy   = 0
    state.enemyHP         = 50
    state.evadePower      = 30
    state.condition       = nil
    state.enemyType       = nil
    state.enemyEvolving   = false
    state.numberOfButtons = 4
    state.balancePosition = 0
    state.balanceMaxOffset = state.enemyHP
    state.accuracyFrames  = 0
    state.correctButtonPresses = {
        aButton=0, bButton=0,
        leftButton=0, rightButton=0, upButton=0, downButton=0,
    }
    state.buttons          = {}
    state.hitZone          = nil
    state.playerDance      = nil
    state.enemyDance       = nil
    state.backgroundDance  = nil
    state.buttonCover      = nil
    state.winIndicator     = nil
    state.loseIndicator    = nil
    state.resultsScreen    = nil
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────
function danceScene.enter()
    math.randomseed(math.floor(love.timer.getTime() * 1000))
    resetState()

    PlayerData.isDancing = false

    -- Determine difficulty
    local chance = determineDifficultyUpgrade()
    local roll   = math.random(0, 100)
    if roll <= chance then
        state.enemyType = determineEnemyType()
        if state.enemyType == "basic"  then state.bpm=16; state.numberOfButtons=4  end
        if state.enemyType == "evolve" then state.bpm=24; state.numberOfButtons=6  end
        if state.enemyType == "badass" then state.bpm=28; state.numberOfButtons=8  end
        if state.enemyType == "boss"   then state.bpm=32; state.numberOfButtons=12 end
        state.enemyEvolving = true
    else
        state.enemyType     = "basic"
        state.enemyEvolving = false
        state.bpm           = 16
        state.numberOfButtons = 4
    end

    printDebug("DanceScene.enter: type=" .. state.enemyType .. " bpm=" .. state.bpm)

    -- Build buttons
    local startPoint  = 400
    local delayStep   = 300
    local profile     = EnemyPatterns[state.enemyType] or EnemyPatterns.basic
    local function kp() return getPatternKey(profile) end
    for i = 1, state.numberOfButtons do
        local b = ButtonPress.new(state.bpm, startPoint + state.bpm, kp)
        b:movementDelay((i-1) * delayStep)
        table.insert(state.buttons, b)
    end

    -- Build entities
    state.hitZone        = HitZone.new(40, 100, 10, 40)
    state.playerDance    = PlayerDance.new(state.bpm)
    state.enemyDance     = EnemyRatDance.new(state.bpm, state.enemyType, state.enemyEvolving)
    state.backgroundDance = BackgroundDance.new()
    state.buttonCover    = ButtonCover.new()
    state.winIndicator   = WinIndicator.new(SCREEN_CENTER_X + state.balanceMaxOffset + 2*BAR_WIDTH, BAR_Y + BAR_HEIGHT/2 - 6)
    state.loseIndicator  = LoseIndicator.new(SCREEN_CENTER_X - state.balanceMaxOffset - 2*BAR_WIDTH, BAR_Y + BAR_HEIGHT/2 - 6)
    state.resultsScreen  = ResultsScreen.new()
end

function danceScene.exit()
    PlayerData.isDancing = false
end

-- ── Update ────────────────────────────────────────────────────────────────────
function danceScene.update(dt)
    if not PlayerData.isDancing then return end
    if state.condition ~= nil then return end

    -- Update all buttons
    for _, btn in ipairs(state.buttons) do
        btn:update(dt)
    end

    -- Check buttons in hitzone
    local inZone = state.hitZone:overlapping(state.buttons)

    if #inZone > 0 then
        state.accuracyFrames = 0
        if state.ButtonPressed then
            local collisions = {}
            for _, btn in ipairs(inZone) do
                if btn.buttonKey == state.ButtonPressed then
                    collisions[#collisions+1] = btn
                end
            end

            if #collisions > 0 then
                -- Correct press
                collisions[1]:hit()
                state.accuracy = state.accuracy + 1
                state.totalAccuracy = state.totalAccuracy + 1
                if state.ButtonPressed == "aButton" or state.ButtonPressed == "bButton" then
                    state.balancePosition = Balance.applyABHit(state.balancePosition)
                    state.enemyDance:attackAnimation(state.ButtonPressed)
                else
                    state.balancePosition = Balance.applyArrowHit(state.balancePosition, state.accuracy)
                    state.playerDance:changeAnimation(state.ButtonPressed)
                end
            else
                -- Wrong press
                collisions[1] = inZone[1]
                collisions[1]:hit()
                state.balancePosition = Balance.applyWrongPress(state.balancePosition)
            end
            state.ButtonPressed = nil
        end
    else
        state.accuracyFrames = state.accuracyFrames + 1
        state.balancePosition = Balance.applyMissPenalty(state.balancePosition, state.accuracyFrames)
        state.accuracy = 0
        state.ButtonPressed = nil
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

-- ── Draw ──────────────────────────────────────────────────────────────────────
function danceScene.draw()
    state.backgroundDance:draw(1)

    for _, btn in ipairs(state.buttons) do btn:draw(1) end

    state.hitZone:draw(1)
    state.buttonCover:draw(1)

    -- Balance bar
    local bx = SCREEN_CENTER_X + state.balancePosition - BAR_WIDTH/2
    love.graphics.setColor(1, 1, 0)
    love.graphics.rectangle("fill", bx, BAR_Y, BAR_WIDTH, BAR_HEIGHT)
    love.graphics.setColor(1, 1, 1)

    state.winIndicator:draw(1)
    state.loseIndicator:draw(1)
    state.playerDance:draw(1)
    state.enemyDance:draw(1)
    state.resultsScreen:draw(1)

    -- Debug
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(string.format("type=%s bpm=%d bal=%.1f",
        tostring(state.enemyType), state.bpm, state.balancePosition), 4, 4)
    love.graphics.setColor(1, 1, 1)
end

-- ── Input ─────────────────────────────────────────────────────────────────────
function danceScene.keypressed(key)
    -- Pre-battle: wait for space/return to start
    if not PlayerData.isDancing and state.condition == nil then
        if key == "space" or key == "return" then
            danceScene.startBattle()
        end
        return
    end

    -- Post-result: press space/return to transition
    if state.condition ~= nil then
        if key == "space" or key == "return" then
            danceScene.checkDanceResults()
        end
        return
    end

    -- Mid-battle: map key → button name
    local keyMap = {
        ["return"] = "aButton",  ["space"]  = "aButton",
        ["lshift"] = "bButton",  ["rshift"] = "bButton",
        ["left"]   = "leftButton", ["right"] = "rightButton",
        ["up"]     = "upButton",   ["down"]  = "downButton",
    }
    local mapped = keyMap[key]
    if mapped then
        state.ButtonPressed = mapped
    end
end

function danceScene.keyreleased(key)
    state.ButtonPressed = nil
end

-- ── Game actions ──────────────────────────────────────────────────────────────
function danceScene.startBattle()
    state.resultsScreen:empty()
    PlayerData.isDancing = true
    state.enemyDance:setIdle()
end

function danceScene.checkDanceResults()
    local gameScene = require 'scenes.gameScene'
    if state.condition == "win" then
        state.condition     = nil
        state.totalAccuracy = 0
        gameScene.findAndKillEnemyById(PlayerData.lastEnemyTouched.id)
        PlayerData.healthPoints = math.min(
            PlayerData.healthPoints + (PlayerData.healedHP or 1),
            (Config.Player and Config.Player.maxHealth) or 3)
        PlayerData.calories     = (PlayerData.calories or 0) + 60
        PlayerData.amountDances = (PlayerData.amountDances or 0) + 1
        sceneManager.startTransition("dance", "game", "slide")

    elseif state.condition == "lose" then
        state.condition = nil
        sceneManager.startTransition("dance", "title", "slide")
    end
end

return danceScene
```

- [ ] **Step 3: Run the game and confirm no require errors**

```bash
cd /Users/dactrtr-mini/Documents/GitHub/DinopiratesLove/dinopirateslove
./run_game.sh
```

Expected: game launches to title screen without Lua errors in the terminal. Any `require` errors for battle entities will appear here — fix paths if needed.

---

## Task 4: Add `findAndKillEnemyById` to gameScene

**Files:** Modify `source/scenes/gameScene.lua`

- [ ] **Step 1: Find where to add the function**

The function should go near the other enemy-management functions. Search for `gameScene.loadEnemies` and add just below it (around line 521).

- [ ] **Step 2: Add the function**

In `source/scenes/gameScene.lua`, add after the `loadEnemies` function block:

```lua
-- Removes the enemy with the given id from the world and the enemies table.
-- Called by DanceScene on win to clean up the defeated enemy.
function gameScene.findAndKillEnemyById(id)
    if not id then return end
    for i, enemy in ipairs(gameScene.enemies) do
        if enemy.id == id then
            if gameScene.world and gameScene.world.hasItem and gameScene.world:hasItem(enemy) then
                gameScene.world:remove(enemy)
            end
            table.remove(gameScene.enemies, i)
            printDebug("⚔️ findAndKillEnemyById: killed enemy id=" .. tostring(id))
            return
        end
    end
    printDebug("⚠️ findAndKillEnemyById: enemy id=" .. tostring(id) .. " not found")
end
```

---

## Task 5: Register DanceScene in main.lua

**Files:** Modify `source/main.lua`

- [ ] **Step 1: Add require for DanceScene**

In `source/main.lua`, after the line `local gameScene = require "scenes/gameScene"`, add:

```lua
local danceScene = require "scenes/DanceScene"
```

- [ ] **Step 2: Register the scene**

In `source/main.lua`, after the line `sceneManager.registerScene("game", gameScene)`, add:

```lua
sceneManager.registerScene("dance", danceScene)
```

- [ ] **Step 3: Run the game and confirm DanceScene is accessible**

```bash
./run_game.sh
```

Expected: title screen loads normally. No errors. The `"dance"` scene is now registered but not yet reachable from gameplay (that's the next task).

---

## Task 6: Wire `fight()` in collisions.lua

**Files:** Modify `source/entities/player/collisions.lua`

- [ ] **Step 1: Replace the fight() stub**

Find the existing stub at approximately line 416:

```lua
function collisions.fight(player)
    printDebug("⚔️ Player:fight() triggered!")
end
```

Replace it with:

```lua
function collisions.fight(player)
    local sceneManager = require 'sceneManager'
    PlayerData.amountDances = (PlayerData.amountDances or 0) + 1
    -- Save player exit position for return after battle
    PlayerData.playerExit = PlayerData.playerExit or {}
    PlayerData.playerExit.x = PlayerData.x
    PlayerData.playerExit.y = PlayerData.y
    printDebug("⚔️ fight() → transitioning to DanceScene")
    sceneManager.startTransition("game", "dance", "slide")
end
```

- [ ] **Step 2: Test the full fight loop**

```bash
./run_game.sh
```

Expected sequence:
1. Walk a player character into a Brocorat enemy
2. DanceScene appears with the "Press SPACE to START BATTLE" screen
3. Press SPACE → rhythm buttons start scrolling
4. Play the rhythm game — win or lose
5. Press SPACE on result screen:
   - **Win**: game returns to the maze, enemy is gone
   - **Lose**: title screen appears

If the game crashes on `gameScene.findAndKillEnemyById`, verify Task 4 was completed and the function exists.

---

## Task 7: Add Lightburst skill

**Files:**
- Modify: `source/utilities.lua`
- Modify: `source/entities/player/init.lua`
- Modify: `source/main.lua`
- Modify: `source/scenes/gameScene.lua`

### Step 7a: Add pointInPolygon to utilities.lua

- [ ] **Step 1: Add the function**

In `source/utilities.lua`, add at the end of the file (before the final `return Utilities` or at the bottom):

```lua
-- Ray-casting point-in-polygon test.
-- pts: flat table of alternating x,y pairs {x1,y1,x2,y2,...}
-- Returns true if (px,py) is inside the polygon.
function Utilities.pointInPolygon(pts, px, py)
    local n = #pts / 2
    local inside = false
    local j = n
    for i = 1, n do
        local xi, yi = pts[i*2-1], pts[i*2]
        local xj, yj = pts[j*2-1], pts[j*2]
        if ((yi > py) ~= (yj > py)) and
           (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end
```

### Step 7b: Add lightBurst() to Player

- [ ] **Step 2: Add lightBurst method to player/init.lua**

In `source/entities/player/init.lua`, add the following method after `Player:endSliding` (around line 438):

```lua
local LIGHTBURST_COST     = 10      -- battery units
local LIGHTBURST_COOLDOWN = 1.0     -- seconds
local LIGHTBURST_DURATION = 1.0     -- seconds showLightCone stays true
local lightburstCooldownEnd = 0

function Player:lightBurst()
    -- Guards
    if not PlayerData.skills.canFlash        then return end
    if PlayerData.activeItem ~= 1            then return end  -- lamp must be selected
    if PlayerData.battery < LIGHTBURST_COST  then return end
    if love.timer.getTime() < lightburstCooldownEnd then return end

    -- Activate
    PlayerData.battery = PlayerData.battery - LIGHTBURST_COST
    PlayerData.showLightCone = true
    lightburstCooldownEnd = love.timer.getTime() + LIGHTBURST_COOLDOWN

    -- Schedule cone off
    local Timer = require 'libraries/hump/timer'
    Timer.after(LIGHTBURST_DURATION, function()
        PlayerData.showLightCone = false
    end)

    -- Blind entities inside the cone
    local FXshadow = require 'entities.UI.FXshadow'
    local dir = PlayerData.direction
    if dir and dir ~= "idle" and dir ~= "" then
        local pts = FXshadow.buildConeVertices(PlayerData.x, PlayerData.y, dir, 200, 12)
        if pts then
            local gameScene = require 'scenes.gameScene'
            -- Blind enemies
            for _, enemy in ipairs(gameScene.enemies or {}) do
                if Utilities.pointInPolygon(pts, enemy.x, enemy.y) then
                    if enemy.blind then enemy:blind(60) end
                end
            end
            -- Blind crewMembers
            for _, cm in ipairs(gameScene.crewMembers or {}) do
                if Utilities.pointInPolygon(pts, cm.x, cm.y) then
                    if cm.blind then cm:blind(60) end
                end
            end
        end
    end

    printDebug("⚡ Lightburst activated! dir=" .. tostring(PlayerData.direction))
end
```

### Step 7c: Add flash keybinding

- [ ] **Step 3: Add "flash" to Input bindings in main.lua**

In `source/main.lua`, inside the `Input = { ... }` table, add after the `action` line:

```lua
    flash   = {"f"},                      -- Lightburst (lamp skill)
```

### Step 7d: Wire flash key in gameScene

- [ ] **Step 4: Add flash handler in gameScene.keypressed**

In `source/scenes/gameScene.lua`, inside `gameScene.keypressed(key)`, add after the `elseif Input.is(key, "dash") then` block:

```lua
    elseif Input.is(key, "flash") then
        if gameScene.player then
            gameScene.player:lightBurst()
        end
```

- [ ] **Step 5: Test Lightburst**

```bash
./run_game.sh
```

Expected sequence:
1. Collect the lamp item
2. Press `Tab` to open equipment menu, select the lamp (item 1)
3. Press `F` key
4. The light cone should expand (FXshadow already handles this via `PlayerData.showLightCone`)
5. Any Brocorat or CrewMember within the cone should freeze for ~2 seconds
6. Pressing `F` while lamp is not selected (activeItem ≠ 1) should do nothing
7. Pressing `F` with battery < 10 should do nothing

---

## Self-Review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| Lightburst key binding | Task 7c, 7d |
| `Player:lightBurst()` activation guards | Task 7b |
| `showLightCone` set + timer to clear | Task 7b |
| FXshadow cone rendered | Already implemented (no changes) |
| Enemy blinding via pointInPolygon | Task 7a, 7b |
| `Utilities.pointInPolygon` | Task 7a |
| Battle entities in `entities/UI/battle/` | Task 2 |
| `balance.lua` in `source/utilities/` | Task 2 step 7 |
| DanceScene as Love2D scene table | Task 3 |
| DanceScene `enter()` / `exit()` / `update()` / `draw()` | Task 3 step 2 |
| DanceScene `keypressed` routing | Task 3 step 2 |
| Pre-battle ready screen | Task 3 (ResultsScreen state="loading") |
| Difficulty profiles + BPM/buttons | Task 3 step 2 |
| Balance bar logic | Task 3 step 2 + Task 2 step 7 |
| Win → kill enemy + heal + return to game | Task 3 step 2 (`checkDanceResults`) |
| Lose → title screen | Task 3 step 2 (`checkDanceResults`) |
| `findAndKillEnemyById` in gameScene | Task 4 |
| Register "dance" in sceneManager | Task 5 |
| `fight()` stub replaced | Task 6 |
| `PlayerData.playerExit` saved before fight | Task 6 |

**Placeholder scan:** No TBDs, TODOs, or "implement later" phrases. All code blocks are complete.

**Type consistency:**
- `ButtonPress.new(bpm, startX, keyProvider)` — used consistently in Task 2 and Task 3
- `HitZone.new(x, y, w, h)` — created in Task 2, instantiated as `HitZone.new(40, 100, 10, 40)` in Task 3
- `Balance.applyABHit`, `Balance.applyArrowHit`, `Balance.applyWrongPress`, `Balance.applyMissPenalty`, `Balance.clamp`, `Balance.isWin`, `Balance.isLose` — defined in Task 2 step 7, used in Task 3 update loop
- `FXshadow.buildConeVertices(px, py, dir, d, h)` — already exported in `entities/UI/FXshadow.lua:112`
- `gameScene.findAndKillEnemyById(id)` — defined in Task 4, called in Task 3 `checkDanceResults`
- `PlayerData.lastEnemyTouched.id` — set by existing collision code before `fight()` is called
