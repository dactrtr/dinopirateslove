-- entities/UI/TouchControls.lua
-- On-screen touch controls for mobile (Android/iOS): a fixed D-pad plus A/B and
-- pause buttons. Every control feeds the game through TWO channels so all
-- existing input code keeps working untouched:
--
--   1. Input.setTouch(action, held)  → the central held-state layer
--      (movement reads Input.isDown; the A-hold-to-menu timer reads isDown).
--   2. sceneManager.keypressed/keyreleased(boundKey) → discrete key events,
--      reusing each scene's existing keyboard handlers. This is what makes the
--      DanceScene work: its keypressed already maps these keys via danceKeys
--      (e.g. "up" → "upButton", "z" → "aButton"), so the rhythm battle needs no
--      touch-specific code. The overworld's keypressed likewise drives trigger
--      interaction, plungerang charge/release, pause, and menu navigation.
--
-- On a real phone there is no active gamepad, so gameScene.gamepadInput (the
-- wasPressed-based path) never runs — meaning the synthesized key events are the
-- single source of A/B actions, with no double-firing.
--
-- A D-pad (rather than a free joystick) gives clean discrete per-direction
-- press/release events, which is exactly what the dance's arrow timing needs.
--
-- Layout is authored in virtual 400×240 coordinates; main.lua converts real
-- touch positions to virtual before handing them here, and draws this overlay
-- crisp on top of the CRT using the same offset/scale.
--
-- TODO: the Playdate crank (L2/R2 + mouse wheel on desktop) has no touch gesture
-- yet; that's a separate follow-up.

local Input = require 'assets.data.InputBindings'

local TouchControls = {}

-- ── D-pad geometry (virtual px) ───────────────────────────────────────────────
local DPAD_CX     = 46    -- centre
local DPAD_CY     = 186
local DPAD_ARM_L  = 30    -- arm length from centre
local DPAD_ARM_W  = 18    -- arm thickness
local DPAD_CLAIM  = 40    -- half-size of the square that captures a touch
local DPAD_DEAD   = 9     -- px from centre before any direction registers
local DIAG_THRESH = 0.38  -- ≈ sin(22.5°): how far off-axis before a 2nd dir joins

-- Action buttons (circles). action = held-state name; key = synthesized key.
local BUTTONS = {
    { id = "B",     action = "BButton", key = "x",      x = 312, y = 206, r = 19, label = "B"  },
    { id = "A",     action = "AButton", key = "z",      x = 360, y = 206, r = 19, label = "A"  },
    { id = "pause", action = "pause",   key = "escape", x = 384, y = 16,  r = 12, label = "||" },
}

-- Directional action → synthesized key (also used as the Input action name).
local DIR_KEY = { up = "up", down = "down", left = "left", right = "right" }

-- ── Optional PNG skin ─────────────────────────────────────────────────────────
-- Drop art in assets/images/ui/touch/ and set the paths here (or call
-- TouchControls.setSkin{...} at runtime). Any field left nil falls back to the
-- built-in vector drawing, so this is fully optional and non-breaking.
--
-- Recommended sizes (virtual px; author at 2× for crispness): A/B ~38, pause ~24,
-- d-pad ~60. Images are scaled to fit each control and use nearest-neighbour
-- filtering to match the pixel-art look.
local SKIN = {
    dpadBase  = nil,  -- static cross, centred on the pad
    dpadUp    = nil,  -- per-direction "lit" overlays, shown while that dir is held
    dpadDown  = nil,
    dpadLeft  = nil,
    dpadRight = nil,
    A = nil, A_pressed = nil,        -- button idle / optional pressed variant
    B = nil, B_pressed = nil,
    pause = nil, pause_pressed = nil,
}

local imageCache = {}  -- path → Image, or false if it failed to load

local function loadImage(path)
    if not path then return nil end
    local cached = imageCache[path]
    if cached ~= nil then return cached or nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
        img:setFilter("nearest", "nearest")
        imageCache[path] = img
        return img
    end
    print("⚠️ TouchControls: could not load skin image '" .. tostring(path) .. "'")
    imageCache[path] = false
    return nil
end

local function loadSkin()
    for _, path in pairs(SKIN) do loadImage(path) end
end

-- Merge new paths into the skin and (re)load them. Edit SKIN directly to clear a
-- field back to the vector fallback.
function TouchControls.setSkin(tbl)
    for k, v in pairs(tbl) do SKIN[k] = v end
    loadSkin()
end

-- ── State ─────────────────────────────────────────────────────────────────────
TouchControls.enabled = false

local pad = { id = nil, dirs = { up = false, down = false, left = false, right = false } }
-- Each BUTTONS entry gets a `.touchId` at runtime while held.

-- ── Emit helpers ──────────────────────────────────────────────────────────────
-- Push an action change through both channels. Lazy-require sceneManager to keep
-- the module load order independent.
local function emit(action, key, pressed)
    Input.setTouch(action, pressed)
    local sm = require 'sceneManager'
    if pressed then
        if sm.keypressed  then sm.keypressed(key)  end
    else
        if sm.keyreleased then sm.keyreleased(key) end
    end
end

-- Apply a freshly computed direction set, emitting only the ones that changed.
local function setPadDirs(newDirs)
    for dir, key in pairs(DIR_KEY) do
        local want = newDirs[dir] or false
        if want ~= pad.dirs[dir] then
            pad.dirs[dir] = want
            emit(dir, key, want)
        end
    end
end

-- Touch offset from the pad centre → active cardinal directions (8-way: corners
-- light up two adjacent cardinals, giving overworld diagonals).
local function dirsFromOffset(dx, dy)
    local d = { up = false, down = false, left = false, right = false }
    local len = math.sqrt(dx * dx + dy * dy)
    if len > DPAD_DEAD then
        local nx, ny = dx / len, dy / len
        d.right = nx >  DIAG_THRESH
        d.left  = nx < -DIAG_THRESH
        d.down  = ny >  DIAG_THRESH
        d.up    = ny < -DIAG_THRESH
    end
    return d
end

local function clearAll()
    setPadDirs({})
    pad.id = nil
    for _, b in ipairs(BUTTONS) do
        if b.touchId then
            b.touchId = nil
            emit(b.action, b.key, false)
        end
    end
end

local function buttonAt(x, y)
    for _, b in ipairs(BUTTONS) do
        local dx, dy = x - b.x, y - b.y
        if dx * dx + dy * dy <= b.r * b.r then return b end
    end
    return nil
end

local function inPad(x, y)
    return math.abs(x - DPAD_CX) <= DPAD_CLAIM and math.abs(y - DPAD_CY) <= DPAD_CLAIM
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────
function TouchControls.load()
    local os = love.system.getOS()
    TouchControls.enabled = (os == "Android" or os == "iOS")
    loadSkin()
end

-- Force on/off (F6 from main.lua) so the overlay can be tested on desktop.
function TouchControls.toggle()
    TouchControls.enabled = not TouchControls.enabled
    if not TouchControls.enabled then clearAll() end
    return TouchControls.enabled
end

function TouchControls.update(dt)
    -- D-pad directions are event-driven (set on press/move), so nothing to poll.
end

-- ── Input events (coords already in virtual space) ───────────────────────────
-- Each returns true when it consumes the pointer, so main.lua skips scene routing.
function TouchControls.pressed(id, x, y)
    if not TouchControls.enabled then return false end

    local b = buttonAt(x, y)
    if b then
        b.touchId = id
        emit(b.action, b.key, true)
        return true
    end

    if pad.id == nil and inPad(x, y) then
        pad.id = id
        setPadDirs(dirsFromOffset(x - DPAD_CX, y - DPAD_CY))
        return true
    end

    return false
end

function TouchControls.moved(id, x, y)
    if not TouchControls.enabled then return false end
    if pad.id == id then
        setPadDirs(dirsFromOffset(x - DPAD_CX, y - DPAD_CY))
        return true
    end
    for _, b in ipairs(BUTTONS) do
        if b.touchId == id then return true end
    end
    return false
end

function TouchControls.released(id)
    if not TouchControls.enabled then return false end
    if pad.id == id then
        pad.id = nil
        setPadDirs({})
        return true
    end
    for _, b in ipairs(BUTTONS) do
        if b.touchId == id then
            b.touchId = nil
            emit(b.action, b.key, false)
            return true
        end
    end
    return false
end

-- ── Draw (inside a virtual-space transform set up by main.lua) ────────────────

-- Bounding rect of one d-pad arm (also used for the highlight overlay).
local function armRect(dir)
    local cx, cy, L, W = DPAD_CX, DPAD_CY, DPAD_ARM_L, DPAD_ARM_W
    if dir == "up"    then return cx - W/2, cy - L,   W, L end
    if dir == "down"  then return cx - W/2, cy,       W, L end
    if dir == "left"  then return cx - L,   cy - W/2, L, W end
    if dir == "right" then return cx,       cy - W/2, L, W end
end

local function drawArm(dir, on)
    local x, y, w, h = armRect(dir)
    love.graphics.setColor(1, 1, 1, on and 0.45 or 0.16)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(1, 1, 1, on and 0.95 or 0.5)
    love.graphics.rectangle("line", x, y, w, h)
end

-- Draw an image centred at (cx,cy), scaled to fit w×h.
local function drawImageFit(img, cx, cy, w, h, alpha)
    local iw, ih = img:getDimensions()
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(img, cx, cy, 0, w / iw, h / ih, iw / 2, ih / 2)
end

local function drawDpad()
    local base = loadImage(SKIN.dpadBase)
    if base then
        local size = DPAD_ARM_L * 2
        drawImageFit(base, DPAD_CX, DPAD_CY, size, size, 0.9)
        local overlay = { up = SKIN.dpadUp, down = SKIN.dpadDown, left = SKIN.dpadLeft, right = SKIN.dpadRight }
        for dir, path in pairs(overlay) do
            if pad.dirs[dir] then
                local img = loadImage(path)
                if img then
                    drawImageFit(img, DPAD_CX, DPAD_CY, size, size, 1)
                else
                    local x, y, w, h = armRect(dir)  -- no per-dir art: faint highlight
                    love.graphics.setColor(1, 1, 1, 0.35)
                    love.graphics.rectangle("fill", x, y, w, h)
                end
            end
        end
    else
        for dir in pairs(DIR_KEY) do
            drawArm(dir, pad.dirs[dir])
        end
    end
end

local function drawButton(b)
    local held = b.touchId ~= nil
    local idle = loadImage(SKIN[b.id])
    if idle then
        local img = (held and loadImage(SKIN[b.id .. "_pressed"])) or idle
        drawImageFit(img, b.x, b.y, b.r * 2, b.r * 2, held and 1 or 0.92)
    else
        love.graphics.setColor(1, 1, 1, held and 0.4 or 0.18)
        love.graphics.circle("fill", b.x, b.y, b.r)
        love.graphics.setColor(1, 1, 1, held and 0.95 or 0.6)
        love.graphics.circle("line", b.x, b.y, b.r)
        love.graphics.printf(b.label, b.x - b.r, b.y - 5, b.r * 2, "center")
    end
end

function TouchControls.draw()
    if not TouchControls.enabled then return end

    love.graphics.push("all")
    love.graphics.setLineWidth(1)

    drawDpad()
    for _, b in ipairs(BUTTONS) do drawButton(b) end

    love.graphics.pop()
end

return TouchControls
