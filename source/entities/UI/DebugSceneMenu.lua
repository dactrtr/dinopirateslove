-- entities/UI/DebugSceneMenu.lua
-- Debug scene-jump menu (F8), mirroring Playdate's TitleScene "debugMenu" PLAYGROUND list:
-- a quick way to warp to any scene, or straight into a specific room in isolation
-- (RunState.startDebugRoom), to test functionality without playing through a full run.
-- Draws to the real framebuffer (not the 400x240 virtual canvas), same as CRTDebugMenu.

local DebugSceneMenu = {}

local visible = false
local cursor  = 1
local items   = nil   -- built lazily on first open (levelsLDTK must be loaded)

function DebugSceneMenu.isVisible() return visible end

local function sceneManager() return require 'sceneManager' end

local function warpTo(sceneName)
    visible = false
    local from = sceneManager().getCurrentSceneName()
    if from == sceneName then return end
    sceneManager().startTransition(from, sceneName, "fade")
end

local function buildItems()
    local list = {}

    list[#list + 1] = { section = "SCENES" }

    list[#list + 1] = { label = "New Game", action = function()
        local SaveSystem = require 'SaveSystem'
        SaveSystem.reset()
        RunState.clear()   -- gameScene.enter() auto-starts a fresh run when graph is nil
        PlayerData.returningInPlace = false
        warpTo("game")
    end }

    list[#list + 1] = { label = "Continue (load save)", action = function()
        local SaveSystem = require 'SaveSystem'
        if SaveSystem.load() and RunState.graph then
            PlayerData.returningInPlace = true
            warpTo("game")
        else
            printDebug("⚠️ DebugSceneMenu: no compatible save to load")
        end
    end }

    list[#list + 1] = { label = "Cockpit", action = function() warpTo("cockpit") end }

    list[#list + 1] = { label = "Dance Battle", action = function()
        local ds = sceneManager().getScene("dance")
        if ds then ds.debugMode = true end
        warpTo("dance")
    end }

    list[#list + 1] = { label = "Credits", action = function() warpTo("credits") end }
    list[#list + 1] = { label = "Dead Scene", action = function() warpTo("dead") end }
    list[#list + 1] = { label = "Title", action = function() warpTo("title") end }

    -- Rooms: one entry per authored room, jumped to in isolation (sealed, no doors —
    -- every enemy/utility force-spawned) via RunState.startDebugRoom.
    list[#list + 1] = { section = "ROOMS" }
    local rooms = {}
    for _, tmpl in ipairs(levelsLDTK or {}) do
        local cf = tmpl.customFields
        if cf and cf.level and cf.roomNumber then
            rooms[#rooms + 1] = { level = cf.level, roomNumber = cf.roomNumber, identifier = tmpl.identifier }
        end
    end
    table.sort(rooms, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.roomNumber < b.roomNumber
    end)
    for _, r in ipairs(rooms) do
        local level, roomNumber = r.level, r.roomNumber
        list[#list + 1] = {
            label = string.format("L%d R%d — %s", level, roomNumber, r.identifier),
            action = function()
                if RunState.startDebugRoom(level, roomNumber) then
                    warpTo("game")
                else
                    printDebug("⚠️ DebugSceneMenu: room L" .. level .. " R" .. roomNumber .. " not found")
                end
            end,
        }
    end

    return list
end

-- flat list of navigable (non-section) indices into `items`
local function navIndices()
    local nav = {}
    for i, item in ipairs(items) do
        if not item.section then nav[#nav + 1] = i end
    end
    return nav
end

local PANEL_W  = 260
local PANEL_H  = 220
local PAD      = 8
local LINE_H   = 14

local function getFont()
    if not DebugSceneMenu._font then
        DebugSceneMenu._font = love.graphics.newFont(10)
    end
    return DebugSceneMenu._font
end

function DebugSceneMenu.draw()
    if not visible then return end

    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local px = math.floor((sw - PANEL_W) / 2)
    local py = math.floor((sh - PANEL_H) / 2)

    love.graphics.setFont(getFont())
    love.graphics.setColor(0.05, 0.05, 0.12, 0.95)
    love.graphics.rectangle("fill", px, py, PANEL_W, PANEL_H, 4)
    love.graphics.setColor(0.35, 1, 0.55, 0.7)
    love.graphics.rectangle("line", px, py, PANEL_W, PANEL_H, 4)

    local x, y = px + PAD, py + PAD
    love.graphics.setColor(0.4, 1, 0.6, 1)
    love.graphics.print("DEBUG: JUMP TO SCENE", x, y)
    love.graphics.setColor(0.45, 0.45, 0.55, 1)
    love.graphics.print("[F8] cerrar", px + PANEL_W - PAD - 58, y)
    y = y + LINE_H
    love.graphics.setColor(0.25, 0.5, 0.35, 1)
    love.graphics.line(px + 4, y, px + PANEL_W - 4, y)
    y = y + 6

    -- Scroll window: keep the cursor's row visible.
    local nav = navIndices()
    local curItemIdx = nav[cursor]
    local visibleRows = math.floor((PANEL_H - (y - py) - PAD) / LINE_H)
    local startIdx = 1
    if curItemIdx > visibleRows then
        startIdx = curItemIdx - visibleRows + 1
    end

    local navPos = 0
    for i = startIdx, #items do
        local item = items[i]
        if item.section then
            love.graphics.setColor(0.5, 0.55, 0.3, 1)
            love.graphics.print("─ " .. item.section .. " ─", x, y)
        else
            navPos = navPos + 1
            local active = (i == curItemIdx)
            if active then
                love.graphics.setColor(0.3, 1, 0.5, 0.18)
                love.graphics.rectangle("fill", px + 3, y - 1, PANEL_W - 6, LINE_H)
            end
            love.graphics.setColor(active and {0.4, 1, 0.6, 1} or {0.8, 0.8, 0.8, 1})
            love.graphics.print((active and "> " or "  ") .. item.label, x, y)
        end
        y = y + LINE_H
        if y > py + PANEL_H - PAD - LINE_H then break end
    end

    love.graphics.setColor(0.5, 0.8, 0.6, 1)
    love.graphics.print("[↑/↓] mover  [Enter] ir", x, py + PANEL_H - PAD - LINE_H + 2)

    love.graphics.setColor(1, 1, 1, 1)
end

function DebugSceneMenu.keypressed(key)
    if key == "f8" then
        visible = not visible
        if visible and not items then items = buildItems() end
        return true
    end
    if not visible then return false end

    local nav = navIndices()

    if key == "escape" then
        visible = false
    elseif key == "up" then
        cursor = cursor - 1
        if cursor < 1 then cursor = #nav end
    elseif key == "down" then
        cursor = cursor + 1
        if cursor > #nav then cursor = 1 end
    elseif key == "return" or key == "kpenter" then
        local item = items[nav[cursor]]
        if item and item.action then item.action() end
    end
    return true
end

return DebugSceneMenu
