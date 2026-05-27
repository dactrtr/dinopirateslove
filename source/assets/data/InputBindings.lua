-- assets/data/InputBindings.lua
-- Keyboard/gamepad input bindings for LÖVE 2D.
-- Input.is(key, action)   → true if `key` is bound to `action`
-- Input.isDown(action)    → true if any key/button for `action` is held
-- Input.danceKeys         → map of key → dance button name (for DanceScene)

local Input = {}

-- Action → list of keyboard keys
local keyBindings = {
    AButton    = { "z", "return", "space" },
    BButton    = { "x", "lshift" },
    up         = { "up",    "w" },
    down       = { "down",  "s" },
    left       = { "left",  "a" },
    right      = { "right", "d" },
    pause      = { "escape", "p" },
    toggleCRT  = { "f1" },
    fullscreen = { "f11" },
    res1       = { "f2" },
    res2       = { "f3" },
    res3       = { "f4" },
}

-- Action → list of gamepad buttons
local padBindings = {
    AButton = { "a" },
    BButton = { "b" },
    up      = { "dpup" },
    down    = { "dpdown" },
    left    = { "dpleft" },
    right   = { "dpright" },
    pause   = { "start", "back" },
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

return Input
