-- entities/UI/CRTDebugMenu.lua
-- In-game CRT parameter debug overlay (N key). Draws to real framebuffer.

local CRTDebugMenu = {}

local visible = false
local cursor  = 1

-- True while the overlay is open. main.lua uses this to suppress all game input
-- so the player can't move/act while adjusting filters.
function CRTDebugMenu.isVisible() return visible end

local DEFAULTS = {
    crtEnabled = true,
    onebit     = { enabled=true, threshold=0.5, dither=false, dark={15,5,10}, light={160,155,135} },
    scanlines  = { opacity=0.45, thickness=0.9, frequency=480, phase=2.30,   width=0.25  },
    crt        = { distortionFactor=1.02, feather=0.02 },
    chromasep  = { radius=1.0, angle=0 },
    glow       = { strength=0, min_luma=0.95 }
}

local ITEMS = {
    { label="CRT Enabled",  type="toggle", toggleId="crt" },
    { section="1-BIT (PLAYDATE)" },
    { label="1-Bit Enabled", type="toggle", toggleId="onebit" },
    { label="Dither",        type="toggle", toggleId="dither" },
    { label="Threshold",  group="onebit",  key="threshold",       min=0,   max=1,    step=0.05, big=0.1  },
    { label="Dark R",     group="onebitC", key="dark",  idx=1,    min=0,   max=255,  step=5,    big=25   },
    { label="Dark G",     group="onebitC", key="dark",  idx=2,    min=0,   max=255,  step=5,    big=25   },
    { label="Dark B",     group="onebitC", key="dark",  idx=3,    min=0,   max=255,  step=5,    big=25   },
    { label="Light R",    group="onebitC", key="light", idx=1,    min=0,   max=255,  step=5,    big=25   },
    { label="Light G",    group="onebitC", key="light", idx=2,    min=0,   max=255,  step=5,    big=25   },
    { label="Light B",    group="onebitC", key="light", idx=3,    min=0,   max=255,  step=5,    big=25   },
    { section="SCANLINES" },
    { label="Opacity",    group="scanlines", key="opacity",         min=0,   max=1,    step=0.05, big=0.1  },
    { label="Thickness",  group="scanlines", key="thickness",       min=0,   max=5,    step=0.1,  big=0.5  },
    { label="Frequency",  group="scanlines", key="frequency",       min=60,  max=480,  step=10,   big=60   },
    { label="Phase",      group="scanlines", key="phase",           min=0,   max=6.28, step=0.1,  big=0.5  },
    { label="Width",      group="scanlines", key="width",           min=0,   max=1,    step=0.05, big=0.1  },
    { section="CRT" },
    { label="Distortion", group="crt",       key="distortionFactor",min=1.0, max=1.2,  step=0.01, big=0.05 },
    { label="Feather",    group="crt",       key="feather",         min=0,   max=0.1,  step=0.005,big=0.02 },
    { section="CHROMASEP" },
    { label="Radius",     group="chromasep", key="radius",          min=0,   max=10,   step=0.5,  big=2    },
    { label="Angle",      group="chromasep", key="angle",           min=0,   max=6.28, step=0.1,  big=0.5  },
    { section="GLOW" },
    { label="Strength",   group="glow",      key="strength",        min=0,   max=20,   step=0.5,  big=2    },
    { label="Min Luma",   group="glow",      key="min_luma",        min=0,   max=1,    step=0.05, big=0.1  },
}

-- flat list of navigable items (excludes section headers)
local nav = {}
for _, item in ipairs(ITEMS) do
    if not item.section then nav[#nav+1] = item end
end

local function getValue(item)
    if item.type == "toggle" then
        if item.toggleId == "crt"    then return crtEnabled end
        if item.toggleId == "onebit" then return moonshinSettings.onebit.enabled end
        if item.toggleId == "dither" then return moonshinSettings.onebit.dither end
    end
    if item.group == "onebitC" then
        return moonshinSettings.onebit[item.key][item.idx]
    end
    return moonshinSettings[item.group][item.key]
end

local function setValue(item, v)
    if item.type == "toggle" then
        if     item.toggleId == "crt"    then crtEnabled = v
        elseif item.toggleId == "onebit" then moonshinSettings.onebit.enabled = v
        elseif item.toggleId == "dither" then moonshinSettings.onebit.dither = v end
    elseif item.group == "onebitC" then
        moonshinSettings.onebit[item.key][item.idx] = v
    else
        moonshinSettings[item.group][item.key] = v
    end
    applyCRTSettings()
end

local function roundTo(v, step)
    local f = 1 / step
    return math.floor(v * f + 0.5) / f
end

local function makeBar(value, mn, mx)
    local t = (mx > mn) and (value - mn) / (mx - mn) or 0
    t = math.max(0, math.min(1, t))
    local filled = math.floor(t * 10 + 0.5)
    local s = ""
    for i = 1, 10 do s = s .. (i <= filled and "█" or "░") end
    return s
end

local function fmtVal(item, val)
    if item.step >= 1        then return string.format("%d",   math.floor(val + 0.5))
    elseif item.step >= 0.01 then return string.format("%.2f", val)
    else                          return string.format("%.3f", val) end
end

local PANEL_W = 230
local PAD     = 8
local LINE_H  = 15

local function getFont()
    if not CRTDebugMenu._font then
        CRTDebugMenu._font = love.graphics.newFont(10)
    end
    return CRTDebugMenu._font
end

-- Draws to the real framebuffer (not the 400x240 virtual canvas) — called
-- from love.draw() after the canvas blit so CRT effects are visible beneath.
function CRTDebugMenu.draw()
    if not visible then return end

    local sw  = love.graphics.getWidth()
    local px  = sw - PANEL_W - 6
    local py  = 6

    -- title(LINE_H) + sep(6) + items(#ITEMS * LINE_H) + footer_gap(4) + footer_sep_pad(5) + footer_lines(2*LINE_H)
    local panelH = PAD * 2 + LINE_H + 6 + #ITEMS * LINE_H + 4 + 5 + LINE_H * 2

    love.graphics.setFont(getFont())

    -- background + border
    love.graphics.setColor(0.05, 0.05, 0.12, 0.93)
    love.graphics.rectangle("fill", px, py, PANEL_W, panelH, 4)
    love.graphics.setColor(0.35, 0.7, 1, 0.7)
    love.graphics.rectangle("line", px, py, PANEL_W, panelH, 4)

    local y = py + PAD
    local x = px + PAD

    -- title
    love.graphics.setColor(0.4, 0.85, 1, 1)
    love.graphics.print("POST-FX DEBUG", x, y)
    love.graphics.setColor(0.45, 0.45, 0.55, 1)
    love.graphics.print("[N] cerrar", px + PANEL_W - PAD - 62, y)
    y = y + LINE_H

    -- title separator
    love.graphics.setColor(0.25, 0.35, 0.5, 1)
    love.graphics.line(px + 4, y, px + PANEL_W - 4, y)
    y = y + 6

    local navIdx = 0
    for _, item in ipairs(ITEMS) do
        if item.section then
            love.graphics.setColor(0.55, 0.55, 0.3, 1)
            love.graphics.print("─ " .. item.section .. " ─", x, y)
        else
            navIdx = navIdx + 1
            local active = (navIdx == cursor)

            if active then
                love.graphics.setColor(0.9, 0.85, 0.1, 0.18)
                love.graphics.rectangle("fill", px + 3, y - 1, PANEL_W - 6, LINE_H)
            end

            local cCol = active and {1, 1, 0.3, 1} or {0.75, 0.75, 0.75, 1}

            if item.type == "toggle" then
                local val    = getValue(item)
                local valCol = val and {0.3, 1, 0.4, 1} or {1, 0.35, 0.35, 1}
                love.graphics.setColor(unpack(cCol))
                love.graphics.print((active and "> " or "  ") .. item.label .. ":", x, y)
                love.graphics.setColor(unpack(valCol))
                love.graphics.print(val and "ON" or "OFF", x + 110, y)
            else
                local val  = getValue(item)
                local bar  = makeBar(val, item.min, item.max)
                local fval = fmtVal(item, val)
                love.graphics.setColor(unpack(cCol))
                love.graphics.print((active and "> " or "  ") .. string.format("%-11s", item.label), x, y)
                love.graphics.setColor(active and {0.3, 1, 0.55, 1} or {0.2, 0.7, 0.35, 0.85})
                love.graphics.print(bar, x + 92, y)
                love.graphics.setColor(unpack(cCol))
                love.graphics.print(fval, x + 164, y)
            end
        end
        y = y + LINE_H
    end

    -- footer
    y = y + 4
    love.graphics.setColor(0.25, 0.35, 0.5, 1)
    love.graphics.line(px + 4, y, px + PANEL_W - 4, y)
    y = y + 5
    love.graphics.setColor(0.5, 0.8, 0.5, 1)
    love.graphics.print("[←/→] ajustar  [Shift] paso grande", x, y)
    y = y + LINE_H
    love.graphics.print("[S] Guardar   [R] Reset", x, y)

    love.graphics.setColor(1, 1, 1, 1)
end

function CRTDebugMenu.keypressed(key)
    if key == "n" then visible = not visible; return true end
    if not visible then return false end

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    if key == "escape" then
        visible = false
    elseif key == "up" then
        cursor = cursor - 1
        if cursor < 1 then cursor = #nav end
    elseif key == "down" then
        cursor = cursor + 1
        if cursor > #nav then cursor = 1 end
    elseif key == "left" or key == "right" then
        local item = nav[cursor]
        if item.type ~= "toggle" then
            local delta = (key == "right" and 1 or -1) * (shift and item.big or item.step)
            local val = roundTo(
                math.max(item.min, math.min(item.max, getValue(item) + delta)),
                item.step
            )
            setValue(item, val)
        end
    elseif key == "return" then
        local item = nav[cursor]
        if item.type == "toggle" then setValue(item, not getValue(item)) end
    elseif key == "r" then
        crtEnabled = DEFAULTS.crtEnabled
        for group, params in pairs(DEFAULTS) do
            if type(params) == "table" and moonshinSettings[group] then
                for k, v in pairs(params) do
                    if type(v) == "table" then
                        -- clone (e.g. color {r,g,b}) so live edits don't mutate DEFAULTS
                        local copy = {}
                        for i, c in ipairs(v) do copy[i] = c end
                        moonshinSettings[group][k] = copy
                    else
                        moonshinSettings[group][k] = v
                    end
                end
            end
        end
        applyCRTSettings()
    elseif key == "s" then
        CRTDebugMenu.saveToDisk()
    end
    return true
end

function CRTDebugMenu.saveToDisk()
    local s = moonshinSettings
    local lines = {
        "-- CRT Debug Settings",
        "-- Guardado: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "return {",
        string.format("    crtEnabled = %s,",              tostring(crtEnabled)),
        "    onebit = {",
        string.format("        enabled = %s,",             tostring(s.onebit.enabled)),
        string.format("        threshold = %.4f,",          s.onebit.threshold),
        string.format("        dither = %s,",              tostring(s.onebit.dither)),
        string.format("        dark = {%d, %d, %d},",       s.onebit.dark[1],  s.onebit.dark[2],  s.onebit.dark[3]),
        string.format("        light = {%d, %d, %d}",       s.onebit.light[1], s.onebit.light[2], s.onebit.light[3]),
        "    },",
        "    scanlines = {",
        string.format("        opacity = %.4f,",            s.scanlines.opacity),
        string.format("        thickness = %.4f,",          s.scanlines.thickness),
        string.format("        frequency = %.4f,",          s.scanlines.frequency),
        string.format("        phase = %.4f,",              s.scanlines.phase),
        string.format("        width = %.4f",               s.scanlines.width),
        "    },",
        "    crt = {",
        string.format("        distortionFactor = %.4f,",   s.crt.distortionFactor),
        string.format("        feather = %.4f",             s.crt.feather),
        "    },",
        "    chromasep = {",
        string.format("        radius = %.4f,",             s.chromasep.radius),
        string.format("        angle = %.4f",               s.chromasep.angle),
        "    },",
        "    glow = {",
        string.format("        strength = %.4f,",           s.glow.strength),
        string.format("        min_luma = %.4f",            s.glow.min_luma),
        "    }",
        "}"
    }
    local ok, werr = love.filesystem.write("crt_settings.lua", table.concat(lines, "\n"))
    if ok then
        printDebug("CRT settings guardado en: " .. love.filesystem.getSaveDirectory() .. "/crt_settings.lua")
    else
        printDebug("CRTDebugMenu save error: " .. tostring(werr))
    end
end

function CRTDebugMenu.loadFromDisk()
    if not love.filesystem.getInfo("crt_settings.lua") then return end
    local chunk, err = love.filesystem.load("crt_settings.lua")
    if not chunk then
        printDebug("CRTDebugMenu load error: " .. tostring(err))
        return
    end
    local ok, data = pcall(chunk)
    if not ok then printDebug("CRTDebugMenu pcall error: " .. tostring(data)); return end
    if type(data) ~= "table" then return end
    if data.crtEnabled ~= nil then crtEnabled = data.crtEnabled end
    for group, params in pairs(data) do
        if type(params) == "table" and moonshinSettings[group] then
            for k, v in pairs(params) do
                if moonshinSettings[group][k] ~= nil then
                    moonshinSettings[group][k] = v
                end
            end
        end
    end
    applyCRTSettings()
    printDebug("CRT settings cargado desde disco")
end

return CRTDebugMenu
