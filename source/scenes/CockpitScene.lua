-- scenes/CockpitScene.lua
-- LÖVE 2D port of the Playdate CockpitScene.
-- A button-panel puzzle scene:
--   • Move a pointer with arrow/WASD keys (or accelerometer on Playdate).
--   • Press A (z/return/space) while hovering a button to advance a sequence.
--   • Complete a sequence to transition to a new scene.
--   • Too many wrong presses → transition to titleScene.
--   • Press B (x) to re-center the pointer.
--
-- Registered as "cockpit" in sceneManager.

local sceneManager = require 'sceneManager'
local Input        = require 'assets.data.InputBindings'

local CockpitButton    = require 'entities.UI.cockpit.CockpitButton'
local CockpitPointer   = require 'entities.UI.cockpit.CockpitPointer'
local CockpitBars      = require 'entities.UI.cockpit.CockpitBars'
local CockpitRadar     = require 'entities.UI.cockpit.CockpitRadar'
local CockpitIndicators = require 'entities.UI.cockpit.CockpitIndicators'

-- ── Scene table ───────────────────────────────────────────────────────────────
local CockpitScene = {}

-- ── Private scene state (reset on each enter) ─────────────────────────────────
local buttons    = {}
local bars       = nil
local pointer    = nil
local pointerX   = 200
local pointerY   = 120
local radar      = nil
local indicators = nil
local failCount  = 0

-- Background / foreground images (loaded lazily so pcall works correctly)
local bgImage = nil
local fgImage = nil

-- Add or modify entries here to create new sequences with different outcomes.
-- Each sequence has:
--   pattern  – ordered list of button labels that must be pressed in sequence
--   action   – function called when the sequence is completed
--   index    – current progress position (1 = first button not yet pressed)
local sequences = {
    {
        pattern = { "1", "3", "2", "4" },
        action  = function()
            sceneManager.startTransition("cockpit", "title", "fade")
        end,
        index = 1,
    },
    {
        pattern = { "A", "B", "C", "D" },
        action  = function()
            sceneManager.startTransition("cockpit", "title", "fade")
        end,
        index = 1,
    },
}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function resetAllSequences()
    for _, seq in ipairs(sequences) do
        seq.index = 1
    end
end

local function pressButton(label)
    local advanced = false
    for _, seq in ipairs(sequences) do
        if label == seq.pattern[seq.index] then
            seq.index = seq.index + 1
            advanced  = true
            if seq.index > #seq.pattern then
                resetAllSequences()
                failCount = 0
                seq.action()
                return
            end
        else
            seq.index = 1
        end
    end
    if not advanced then
        failCount = failCount + 1
        local limit = Config.Cockpit.failLimit or 10
        if failCount >= limit then
            sceneManager.startTransition("cockpit", "title", "fade")
        end
    end
end

-- Returns the sequence currently most advanced (for the progress indicator).
local function leadingSequence()
    local best = sequences[1]
    for _, seq in ipairs(sequences) do
        if seq.index > best.index then best = seq end
    end
    return best
end

local function isOverAnyButton()
    for _, btn in ipairs(buttons) do
        if btn:isHovered(pointerX, pointerY) then return true end
    end
    return false
end

-- ── Scene lifecycle ───────────────────────────────────────────────────────────
function CockpitScene.enter()
    pointerX = 200
    pointerY = 120
    buttons  = {}
    bars     = nil
    radar    = nil
    indicators = nil
    failCount  = 0
    resetAllSequences()

    -- Background image (optional – scene works without it)
    local okBg, bg = pcall(love.graphics.newImage, 'assets/images/cockpit/cockpit_background.png')
    bgImage = okBg and bg or nil

    local okFg, fg = pcall(love.graphics.newImage, 'assets/images/cockpit/cockpit_foreground.png')
    fgImage = okFg and fg or nil

    --[[
        Central grid layout (all coordinates are top-left corners, 400×240 canvas)
        Matches the Playdate original exactly (positions from btnDefs in CockpitScene.lua):

        Left panel:
            [1] 26,140  32×48
            [2] 74,140  32×48
        Central grid – left column (x=166):
            [6] 166,180  24×16
            [3] 166,200  24×16
            [4] 166,220  24×16
        Central grid – right column (x=246):
            [9] 246,180  24×16
            [7] 246,200  24×16
            [8] 246,220  24×16
        Bars widget: 206,190  50×31
        Far-right keypad (x=372):
            [A] 372,63   28×22
            [B] 372,89   28×22
            [C] 372,115  28×22
            [D] 372,141  28×22
        ESC: 206,228  50×20
    --]]
    local btnDefs = {
        { x=26,  y=140, w=32, h=48, label="1" },
        { x=74,  y=140, w=32, h=48, label="2" },
        { x=166, y=200, w=24, h=16, label="3" },
        { x=166, y=220, w=24, h=16, label="4" },
        { x=166, y=180, w=24, h=16, label="6" },
        { x=246, y=200, w=24, h=16, label="7" },
        { x=246, y=220, w=24, h=16, label="8" },
        { x=246, y=180, w=24, h=16, label="9" },
        { x=372, y=63,  w=28, h=22, label="A" },
        { x=372, y=89,  w=28, h=22, label="B" },
        { x=372, y=115, w=28, h=22, label="C" },
        { x=372, y=141, w=28, h=22, label="D" },
        { x=206, y=228, w=50, h=20, label="ESC" },
    }

    for _, cfg in ipairs(btnDefs) do
        table.insert(buttons, CockpitButton.new(cfg.x, cfg.y, cfg.w, cfg.h, cfg.label))
    end

    bars       = CockpitBars.new(206, 190, 50, 31)
    radar      = CockpitRadar.new(50, 200, 80, 60)
    indicators = CockpitIndicators.new()
    pointer    = CockpitPointer.new()
    pointer:moveTo(pointerX, pointerY)
end

function CockpitScene.exit()
    bgImage = nil
    fgImage = nil
    buttons = {}
    bars    = nil
    radar   = nil
    indicators = nil
    pointer    = nil
end

-- ── Update ────────────────────────────────────────────────────────────────────
function CockpitScene.update(dt)
    -- D-pad / WASD moves the pointer
    local spd   = Config.Cockpit.dpadSpeed or 3
    if Input.isDown("up")    then pointerY = math.max(0,                         pointerY - spd) end
    if Input.isDown("down")  then pointerY = math.min(Config.Screen.height,      pointerY + spd) end
    if Input.isDown("left")  then pointerX = math.max(0,                         pointerX - spd) end
    if Input.isDown("right") then pointerX = math.min(Config.Screen.width,       pointerX + spd) end

    -- Update pointer sprite
    if pointer then
        pointer:moveTo(pointerX, pointerY)
        pointer:update(dt)
        if isOverAnyButton() then
            pointer:setHover()
        else
            pointer:setIdle()
        end
    end

    -- Update animated widgets
    if bars       then bars:update(dt)       end
    if radar      then radar:update(dt)      end
    if indicators then indicators:update(dt) end

    -- Feed leading-sequence data to the indicator strip
    if indicators then
        local leading = leadingSequence()
        local limit   = Config.Cockpit.failLimit or 10
        indicators:setData(leading.index - 1, #leading.pattern,
                           math.min(1, failCount / limit))
    end
end

-- ── Draw ──────────────────────────────────────────────────────────────────────
function CockpitScene.draw()
    -- Background (black fill when asset is absent)
    if bgImage then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgImage, 0, 0)
    else
        love.graphics.setColor(0.05, 0.05, 0.1, 1)
        love.graphics.rectangle("fill", 0, 0, 400, 240)
    end

    -- Widgets
    if bars       then bars:draw()       end
    if radar      then radar:draw()      end

    -- Buttons (only visible in debug mode; always participate in hit-testing)
    for _, btn in ipairs(buttons) do
        btn:draw(DEBUG)
    end

    -- Foreground overlay (cockpit frame art)
    if fgImage then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(fgImage, 0, 0)
    end

    -- Indicators (on top of foreground)
    if indicators then indicators:draw() end

    -- Pointer (always on top)
    if pointer then pointer:draw() end

    -- Debug HUD
    if DEBUG then
        local leading = leadingSequence()
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.print(string.format(
            "cockpit  ptr=%.0f,%.0f  seq=%d/%d  fails=%d",
            pointerX, pointerY,
            leading.index - 1, #leading.pattern,
            failCount), 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- ── Input ─────────────────────────────────────────────────────────────────────
function CockpitScene.keypressed(key)
    -- A button: activate the button under the pointer
    if Input.is(key, "AButton") then
        for _, btn in ipairs(buttons) do
            if btn:isHovered(pointerX, pointerY) then
                if btn.label == "ESC" then
                    sceneManager.startTransition("cockpit", "title", "fade")
                else
                    pressButton(btn.label)
                end
                return
            end
        end
    end

    -- B button: re-center pointer
    if Input.is(key, "BButton") then
        pointerX = 200
        pointerY = 120
    end
end

function CockpitScene.keyreleased(key)
    -- nothing
end

return CockpitScene
