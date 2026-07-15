-- entities/UI/InGameMenu.lua
-- In-game D-Watch menu. Singleton called with colon syntax.
-- Purely visual (Playdate parity): it shows the run map and the captured crew
-- hats. There is no skill/item selection — abilities fire from the B button
-- directly (Player:useAbility picks lamp in darkness, plunge otherwise).

local MapDrawer = require 'entities.UI.MapDrawer'

local InGameMenu = {}
InGameMenu.__index = InGameMenu

-- ── Assets ────────────────────────────────────────────────────────────────────
local menuImg   = nil   -- ingame-menu.png
local hatsSheet = nil   -- hats-table-20-16.png (21 frames × 20×16)

local HAT_W, HAT_H = 20, 16

-- ── Layout constants (Playdate screen coords, 400×240 virtual) ────────────────
local HAT_START_X   = 43
local HAT_START_Y   = 108
local HAT_SPACING_X = 20
local HAT_SPACING_Y = 20
local HAT_PER_ROW   = 7

local hatQuads = {}   -- [1]...[21] = CM001…CM021

-- ── Map canvas (cached while menu is open) ────────────────────────────────────
-- Stored as field so it persists across frames while isEquiping == true.
InGameMenu.mapCanvas = nil

-- ── Load ──────────────────────────────────────────────────────────────────────
function InGameMenu:load()
    menuImg   = love.graphics.newImage("assets/images/ui/menu/ingame-menu.png")
    hatsSheet = love.graphics.newImage("assets/images/props/hats-table-20-16.png")

    local hw = hatsSheet:getWidth()
    local hh = hatsSheet:getHeight()
    for i = 0, 20 do
        hatQuads[i + 1] = love.graphics.newQuad(i * HAT_W, 0, HAT_W, HAT_H, hw, hh)
    end
end

-- ── Map canvas builder ────────────────────────────────────────────────────────
function InGameMenu:_buildMapCanvas()
    local canvas = love.graphics.newCanvas(400, 240)
    local prev   = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    -- Render the procedural run graph at Config.Map.panel offsets in virtual coords.
    MapDrawer.draw()

    love.graphics.setCanvas(prev)
    love.graphics.setColor(1, 1, 1, 1)
    return canvas
end

-- ── Draw ──────────────────────────────────────────────────────────────────────
function InGameMenu:draw()
    if not PlayerData.isEquiping or not PlayerData.items.hasDWatch then
        self.mapCanvas = nil   -- clear cache when menu is closed
        return
    end

    -- Build map canvas once per menu opening
    if not self.mapCanvas then
        self.mapCanvas = self:_buildMapCanvas()
    end

    -- 1. Dark overlay
    love.graphics.setColor(0.196, 0.184, 0.161, 0.7)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    -- 2. Menu base image (centered)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(menuImg,
        200 - menuImg:getWidth()  / 2,
        120 - menuImg:getHeight() / 2)

    -- 3. Map
    love.graphics.draw(self.mapCanvas, 0, 0)

    -- 4. Crew hats
    self:_drawHats()

    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Hats ──────────────────────────────────────────────────────────────────────
function InGameMenu:_drawHats()
    local cmd = PlayerData.CrewMemberData
    if not cmd or cmd.amountTaken == 0 then return end

    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, 21 do
        local crewId = string.format("CM%03d", i)
        if cmd.idNumbers[crewId] == true then
            local slot = i - 1
            local col  = slot % HAT_PER_ROW
            local row  = math.floor(slot / HAT_PER_ROW)
            love.graphics.draw(hatsSheet, hatQuads[i],
                HAT_START_X + col * HAT_SPACING_X,
                HAT_START_Y + row * HAT_SPACING_Y)
        end
    end
end

return InGameMenu
