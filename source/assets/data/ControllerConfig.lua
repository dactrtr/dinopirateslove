-- assets/data/ControllerConfig.lua
-- Per-controller button mapping profiles.
-- Each profile matches controllers by a name substring (case-insensitive).
-- sdl  = SDL gamepad button name  (used when joystick:isGamepad() == true)
-- raw  = raw button index         (fallback when SDL doesn't recognize the controller)
--
-- SDL button names: "a","b","x","y","back","guide","start",
--                   "leftstick","rightstick","leftshoulder","rightshoulder",
--                   "dpup","dpdown","dpleft","dpright"
--
-- To find raw button indices for your controller, set DEBUG_CONTROLLER = true
-- in main.lua and press each button – indices print to the LÖVE console.

local ControllerConfig = {}

-- Global deadzone override (nil = use profile's value)
ControllerConfig.deadzoneOverride = nil

-- ── Profiles ─────────────────────────────────────────────────────────────────
-- Checked top-to-bottom; first name match wins. "default" is always last.
ControllerConfig.profiles = {
    -- 8BitDo in PS4 mode on iPad/iOS. It spoofs Sony's DualShock 4 VID/PID
    -- (054c:09cc), so we can't tell it apart from a real DS4 by name — we match
    -- the exact GUID instead. On iOS this pad reports L2/R2 on raw axes 3 and 6
    -- (rather than the standard trigger axes), so triggerRawL/triggerRawR pin the
    -- crank's alternating-trigger input to the real physical axes for this pad.
    {
        name        = "8BitDo (PS4 mode, iOS)",
        guid        = "05001ea34c050000cc090000ff870001",
        deadzone    = 0.20,
        axes        = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
        triggerRawL = 3,   -- L2 on this pad (1-indexed raw axis)
        triggerRawR = 6,   -- R2 on this pad
        buttons     = {
            AButton  = { sdl = "a",            raw = 0 },
            BButton  = { sdl = "b",            raw = 1 },
            XButton  = { sdl = "x",            raw = 2 },
            menuOpen = { sdl = "y",            raw = 3 },
            L1       = { sdl = "leftshoulder", raw = 4 },
            R1       = { sdl = "rightshoulder",raw = 5 },
            back     = { sdl = "back",         raw = 8 },
            pause    = { sdl = "start",        raw = 9 },
            dpup     = { sdl = "dpup",         raw = 11 },
            dpdown   = { sdl = "dpdown",       raw = 12 },
            dpleft   = { sdl = "dpleft",       raw = 13 },
            dpright  = { sdl = "dpright",      raw = 14 },
        },
    },

    -- PlayStation 5 DualSense
    {
        name     = "DualSense",
        deadzone = 0.15,
        axes     = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
        buttons  = {
            AButton  = { sdl = "a",            raw = 0  },  -- Cross  ×
            BButton  = { sdl = "b",            raw = 1  },  -- Circle ○
            XButton  = { sdl = "x",            raw = 2  },  -- Square □
            menuOpen = { sdl = "y",            raw = 3  },  -- Triangle △
            L1       = { sdl = "leftshoulder", raw = 4  },
            R1       = { sdl = "rightshoulder",raw = 5  },
            back     = { sdl = "back",         raw = 8  },  -- Create
            pause    = { sdl = "start",        raw = 9  },  -- Options
            dpup     = { sdl = "dpup",         raw = 14 },
            dpdown   = { sdl = "dpdown",       raw = 15 },
            dpleft   = { sdl = "dpleft",       raw = 16 },
            dpright  = { sdl = "dpright",      raw = 17 },
        },
    },

    -- PlayStation 4 DualShock 4
    {
        name     = "DualShock 4",
        deadzone = 0.15,
        axes     = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
        buttons  = {
            AButton  = { sdl = "a",            raw = 0  },  -- Cross  ×
            BButton  = { sdl = "b",            raw = 1  },  -- Circle ○
            XButton  = { sdl = "x",            raw = 2  },  -- Square □
            menuOpen = { sdl = "y",            raw = 3  },  -- Triangle △
            L1       = { sdl = "leftshoulder", raw = 4  },
            R1       = { sdl = "rightshoulder",raw = 5  },
            back     = { sdl = "back",         raw = 8  },  -- Share
            pause    = { sdl = "start",        raw = 9  },  -- Options
            dpup     = { sdl = "dpup",         raw = 14 },
            dpdown   = { sdl = "dpdown",       raw = 15 },
            dpleft   = { sdl = "dpleft",       raw = 16 },
            dpright  = { sdl = "dpright",      raw = 17 },
        },
    },

    -- Xbox Series / One / 360
    {
        name     = "Xbox",
        deadzone = 0.20,
        axes     = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
        buttons  = {
            AButton  = { sdl = "a",            raw = 0 },  -- A
            BButton  = { sdl = "b",            raw = 1 },  -- B
            XButton  = { sdl = "x",            raw = 2 },  -- X
            menuOpen = { sdl = "y",            raw = 3 },  -- Y
            L1       = { sdl = "leftshoulder", raw = 4 },
            R1       = { sdl = "rightshoulder",raw = 5 },
            back     = { sdl = "back",         raw = 6 },  -- View
            pause    = { sdl = "start",        raw = 7 },  -- Menu
            dpup     = { sdl = "dpup",         raw = 11 },
            dpdown   = { sdl = "dpdown",       raw = 12 },
            dpleft   = { sdl = "dpleft",       raw = 13 },
            dpright  = { sdl = "dpright",      raw = 14 },
        },
    },

    -- Nintendo Switch Pro Controller
    {
        name     = "Pro Controller",
        deadzone = 0.20,
        axes     = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
        buttons  = {
            AButton  = { sdl = "a",            raw = 0 },  -- B (SDL remaps to cross)
            BButton  = { sdl = "b",            raw = 1 },  -- A
            XButton  = { sdl = "x",            raw = 2 },  -- Y
            menuOpen = { sdl = "y",            raw = 3 },  -- X
            L1       = { sdl = "leftshoulder", raw = 4 },
            R1       = { sdl = "rightshoulder",raw = 5 },
            back     = { sdl = "back",         raw = 8 },  -- -
            pause    = { sdl = "start",        raw = 9 },  -- +
            dpup     = { sdl = "dpup",         raw = 13 },
            dpdown   = { sdl = "dpdown",       raw = 14 },
            dpleft   = { sdl = "dpleft",       raw = 15 },
            dpright  = { sdl = "dpright",      raw = 16 },
        },
    },

    -- 8BitDo (SN30/Pro/Ultimate/etc.) — relies on the SDL controller DB for the
    -- actual mapping; this profile mainly gives it a slightly larger deadzone.
    {
        name     = "8BitDo",
        deadzone = 0.22,
        axes     = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
        buttons  = {
            AButton  = { sdl = "a",            raw = 0 },
            BButton  = { sdl = "b",            raw = 1 },
            XButton  = { sdl = "x",            raw = 2 },
            menuOpen = { sdl = "y",            raw = 3 },
            L1       = { sdl = "leftshoulder", raw = 4 },
            R1       = { sdl = "rightshoulder",raw = 5 },
            back     = { sdl = "back",         raw = 10 },
            pause    = { sdl = "start",        raw = 11 },
            dpup     = { sdl = "dpup",         raw = 11 },
            dpdown   = { sdl = "dpdown",       raw = 12 },
            dpleft   = { sdl = "dpleft",       raw = 13 },
            dpright  = { sdl = "dpright",      raw = 14 },
        },
    },

    -- Generic / default fallback (SDL standard layout)
    {
        name     = "default",
        deadzone = 0.25,
        axes     = { horizontal = "leftx", vertical = "lefty", crankX = "rightx", crankY = "righty" },
        buttons  = {
            AButton  = { sdl = "a",            raw = 0 },
            BButton  = { sdl = "b",            raw = 1 },
            XButton  = { sdl = "x",            raw = 2 },
            menuOpen = { sdl = "y",            raw = 3 },
            L1       = { sdl = "leftshoulder", raw = 4 },
            R1       = { sdl = "rightshoulder",raw = 5 },
            back     = { sdl = "back",         raw = 6 },
            pause    = { sdl = "start",        raw = 7 },
            dpup     = { sdl = "dpup",         raw = 11 },
            dpdown   = { sdl = "dpdown",       raw = 12 },
            dpleft   = { sdl = "dpleft",       raw = 13 },
            dpright  = { sdl = "dpright",      raw = 14 },
        },
    },
}

-- ── API ───────────────────────────────────────────────────────────────────────

-- Returns the matching profile for a joystick (never nil).
-- Matching order: exact GUID first (lets us target a specific physical pad that
-- shares a generic name like "DualShock 4"), then name substring, then default.
function ControllerConfig.getProfile(joystick)
    if not joystick then
        return ControllerConfig.profiles[#ControllerConfig.profiles]
    end
    local guid = (joystick.getGUID and joystick:getGUID()) or ""
    if guid ~= "" then
        for _, profile in ipairs(ControllerConfig.profiles) do
            if profile.guid and profile.guid == guid then
                return profile
            end
        end
    end
    local name = (joystick:getName() or ""):lower()
    for _, profile in ipairs(ControllerConfig.profiles) do
        if profile.name ~= "default" and name:find(profile.name:lower(), 1, true) then
            return profile
        end
    end
    return ControllerConfig.profiles[#ControllerConfig.profiles]
end

-- Returns the L2/R2 trigger value as 0..1 (0 = released, 1 = fully pressed).
-- side = "left" or "right". Uses the SDL "triggerleft"/"triggerright" axes by
-- default; a profile may pin a trigger to an explicit 1-indexed raw axis via
-- triggerRawL/triggerRawR (for pads whose triggers sit on non-standard axes —
-- e.g. the 8BitDo PS4-mode pad on iOS reports them on raw axes 3 and 6).
function ControllerConfig.getTrigger(joystick, side)
    if not joystick then return 0 end
    local profile = ControllerConfig.getProfile(joystick)
    local raw = (side == "left") and profile.triggerRawL or profile.triggerRawR
    if raw then
        -- Raw trigger axes rest near -1 (released) and rise toward +1 (pressed).
        local v = joystick:getAxis(raw)
        return (v + 1) * 0.5
    end
    if joystick:isGamepad() then
        local name = (side == "left") and "triggerleft" or "triggerright"
        return joystick:getGamepadAxis(name)   -- already 0..1
    end
    return 0
end

-- Returns true if an action button is currently held on the joystick.
-- Tries SDL gamepad API first; falls back to raw button index.
function ControllerConfig.isDown(joystick, action)
    if not joystick then return false end
    local profile = ControllerConfig.getProfile(joystick)
    local binding = profile.buttons[action]
    if not binding then return false end

    if joystick:isGamepad() and binding.sdl then
        return joystick:isGamepadDown(binding.sdl)
    elseif binding.raw then
        return joystick:isDown(binding.raw)
    end
    return false
end

-- Returns a deadzone value for the joystick.
function ControllerConfig.getDeadzone(joystick)
    if ControllerConfig.deadzoneOverride then
        return ControllerConfig.deadzoneOverride
    end
    local profile = ControllerConfig.getProfile(joystick)
    return profile.deadzone or 0.25
end

-- Returns axis value using SDL if available, raw axis index otherwise.
-- axisName: "horizontal" or "vertical"
function ControllerConfig.getAxis(joystick, axisName)
    if not joystick then return 0 end
    local profile = ControllerConfig.getProfile(joystick)
    local sdlAxis = profile.axes and profile.axes[axisName]

    if joystick:isGamepad() and sdlAxis then
        return joystick:getGamepadAxis(sdlAxis)
    else
        local axisMap = { horizontal = 0, vertical = 1, crankX = 2, crankY = 3 }
        local rawIndex = axisMap[axisName] or 0
        return joystick:getAxis(rawIndex + 1)  -- LÖVE raw axes are 1-indexed
    end
end

return ControllerConfig
