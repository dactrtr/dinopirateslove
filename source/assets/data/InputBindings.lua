-- assets/data/InputBindings.lua
-- Keyboard/gamepad input bindings for LÖVE 2D.
-- Input.is(key, action)   → true if `key` is bound to `action`
-- Input.isDown(action)    → true if any key/button for `action` is held
-- Input.danceKeys         → map of key → dance button name (for DanceScene)

local ControllerConfig = require 'assets.data.ControllerConfig'

local Input = {}

-- Frame state for edge detection
local prevState          = {}
local curState           = {}

-- Crank emulation state (right stick)
local pendingCrankDelta  = 0
local prevCrankAngle     = nil
local crankAccum         = 0
local CRANK_THRESHOLD    = math.rad(30)

-- Action → list of keyboard keys
local keyBindings = {
    AButton    = { "z", "return", "space" },
    BButton    = { "x", "lshift" },
    up         = { "up",    "w" },
    down       = { "down",  "s" },
    left       = { "left",  "a" },
    right      = { "right", "d" },
    pause      = { "escape", "p" },
    menuOpen   = { "i" },
    toggleCRT  = { "f1" },
    fullscreen = { "f11" },
    res1       = { "f2" },
    res2       = { "f3" },
    res3       = { "f4" },
}

-- Action → list of gamepad buttons
-- "y" = gamepad Y button (button 1 on many controllers in LÖVE's gamepad mapping)
local padBindings = {
    AButton  = { "a" },
    BButton  = { "b" },
    menuOpen = { "y" },
    up       = { "dpup" },
    down     = { "dpdown" },
    left     = { "dpleft" },
    right    = { "dpright" },
    pause    = { "start", "back" },
}

-- Dance mode: key → button label shown on screen
Input.danceKeys = {
    ["z"]      = "A",
    ["return"] = "A",
    ["x"]      = "B",
    ["up"]     = "up",
    ["down"]   = "down",
    ["left"]   = "left",
    ["right"]  = "right",
}

-- Returns true if `key` (string from love.keypressed) is bound to `action`.
function Input.is(key, action)
    local binds = keyBindings[action]
    if not binds then return false end
    for _, k in ipairs(binds) do
        if k == key then return true end
    end
    return false
end

-- Returns true if any key or gamepad button for `action` is currently held.
function Input.isDown(action)
    local binds = keyBindings[action]
    if binds then
        for _, k in ipairs(binds) do
            if love.keyboard.isDown(k) then return true end
        end
    end
    local pads = padBindings[action]
    if pads then
        local joysticks = love.joystick.getJoysticks()
        for _, js in ipairs(joysticks) do
            if js:isGamepad() then
                for _, btn in ipairs(pads) do
                    if js:isGamepadDown(btn) then return true end
                end
            end
        end
    end
    return false
end

-- Call once per love.update frame, before sceneManager.update.
-- Snapshots current button state for wasPressed queries.
function Input.update(joystick)
    prevState = curState
    curState  = {}

    -- Keyboard polling
    for action, keys in pairs(keyBindings) do
        for _, k in ipairs(keys) do
            if love.keyboard.isDown(k) then
                curState[action] = true
                break
            end
        end
    end

    if joystick then
        local deadzone = ControllerConfig.getDeadzone(joystick)

        -- Gamepad button polling (SDL standard layout via padBindings)
        if joystick:isGamepad() then
            for action, buttons in pairs(padBindings) do
                for _, btn in ipairs(buttons) do
                    if joystick:isGamepadDown(btn) then
                        curState[action] = true
                        break
                    end
                end
            end
        end

        -- Left stick → directional actions (OR'd with d-pad above)
        local lx = ControllerConfig.getAxis(joystick, "horizontal")
        local ly = ControllerConfig.getAxis(joystick, "vertical")
        if lx < -deadzone then curState["left"]  = true end
        if lx >  deadzone then curState["right"] = true end
        if ly < -deadzone then curState["up"]    = true end
        if ly >  deadzone then curState["down"]  = true end

        -- Right stick → crank accumulation
        local rx = ControllerConfig.getAxis(joystick, "crankX")
        local ry = ControllerConfig.getAxis(joystick, "crankY")
        if rx * rx + ry * ry > deadzone * deadzone then
            local angle = math.atan2(ry, rx)
            if prevCrankAngle ~= nil then
                local delta = angle - prevCrankAngle
                if delta >  math.pi then delta = delta - 2 * math.pi end
                if delta < -math.pi then delta = delta + 2 * math.pi end
                crankAccum = crankAccum + delta
                if math.abs(crankAccum) >= CRANK_THRESHOLD then
                    pendingCrankDelta = crankAccum
                    crankAccum = 0
                end
            end
            prevCrankAngle = angle
        else
            prevCrankAngle = nil
            crankAccum     = 0
        end
    end
end

-- Returns true only on the first frame an action goes from not-held to held.
-- Works for both keyboard and gamepad.
function Input.wasPressed(action)
    return (curState[action] == true) and not (prevState[action] == true)
end

-- Returns accumulated right-stick crank rotation in radians (positive = clockwise).
-- Clears the pending value; call at most once per frame.
function Input.getCrankDelta()
    local d = pendingCrankDelta
    pendingCrankDelta = 0
    return d
end

return Input
