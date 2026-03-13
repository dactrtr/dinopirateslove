-- entities/UI/InGameMenu.lua
-- In-game equipment menu (D-Watch). Singleton called with colon syntax.

local InGameMenu = {}
InGameMenu.__index = InGameMenu

-- ── Assets ────────────────────────────────────────────────────────────────────
local menuImg    = nil   -- ingame-menu.png
local itemsSheet = nil   -- menuitems-table-32-32.png  (6 frames × 32×32)
local skillSheet = nil   -- skillinfo-table-145-42.png (3 frames × 145×42)
local hatsSheet  = nil   -- hats-table-20-16.png       (21 frames × 20×16)

local ITEM_W,  ITEM_H  = 32,  32
local SKILL_W, SKILL_H = 145, 42
local HAT_W,   HAT_H   = 20,  16

-- ── Layout constants (Playdate screen coords, 400×240 virtual) ────────────────
local ITEM_POSITIONS = {
    lamp    = { x = 320, y = 64  },
    boot    = { x = 288, y = 128 },
    plunger = { x = 256, y = 128 },
}
local SKILL_INFO_POS = { x = 220, y = 180 }

local HAT_START_X   = 43
local HAT_START_Y   = 108
local HAT_SPACING_X = 20
local HAT_SPACING_Y = 20
local HAT_PER_ROW   = 7

-- ── Map constants ─────────────────────────────────────────────────────────────
local MAP_ROOM_SIZE = 7
local MAP_SPACING   = 6
local floorConfig = {
    [1] = { cols = 5, rows = 3, posX = 142, posY = 73,  startRoom = 66 },
    [2] = { cols = 7, rows = 5, posX = 131, posY = 18,  startRoom = 31 },
    [3] = { cols = 5, rows = 3, posX = 32,  posY = 65,  startRoom = 16 },
    [4] = { cols = 5, rows = 3, posX = 32,  posY = 29,  startRoom = 1  },
}

-- ── Quad tables ───────────────────────────────────────────────────────────────
local itemQuads  = {}   -- [1]=plunger [2]=plungerSel [3]=boot [4]=bootSel [5]=lamp [6]=lampSel
local skillQuads = {}   -- [1]=plunder [2]=dash [3]=flash
local hatQuads   = {}   -- [1]...[21] = CM001…CM021

-- ── Map canvas (cached while menu is open) ────────────────────────────────────
-- Stored as field so it persists across frames while isEquiping == true.
InGameMenu.mapCanvas = nil

-- ── Load ──────────────────────────────────────────────────────────────────────
function InGameMenu:load()
    menuImg    = love.graphics.newImage("assets/images/ui/menu/ingame-menu.png")
    itemsSheet = love.graphics.newImage("assets/images/ui/menu/menuitems-table-32-32.png")
    skillSheet = love.graphics.newImage("assets/images/ui/menu/skillinfo-table-145-42.png")
    hatsSheet  = love.graphics.newImage("assets/images/props/hats-table-20-16.png")

    local iw = itemsSheet:getWidth()
    local ih = itemsSheet:getHeight()
    for i = 0, 5 do
        itemQuads[i + 1] = love.graphics.newQuad(i * ITEM_W, 0, ITEM_W, ITEM_H, iw, ih)
    end

    local sw = skillSheet:getWidth()
    local sh = skillSheet:getHeight()
    for i = 0, 2 do
        skillQuads[i + 1] = love.graphics.newQuad(i * SKILL_W, 0, SKILL_W, SKILL_H, sw, sh)
    end

    local hw = hatsSheet:getWidth()
    local hh = hatsSheet:getHeight()
    for i = 0, 20 do
        hatQuads[i + 1] = love.graphics.newQuad(i * HAT_W, 0, HAT_W, HAT_H, hw, hh)
    end
end

-- ── Skill navigation helpers ──────────────────────────────────────────────────
local function getActiveSkillIds()
    local ids = {}
    if PlayerData.skills.canFlash      then table.insert(ids, 1) end
    if PlayerData.skills.canDash       then table.insert(ids, 2) end
    if PlayerData.skills.canPlungerang then table.insert(ids, 3) end
    return ids
end

-- legacy helper kept for external callers (gameScene uses :getActiveSkills())
function InGameMenu:getActiveSkills()
    local items = {
        { id = 1, name = "Lamp",       hasItem = "hasLamp"    },
        { id = 2, name = "Boots",      hasItem = "hasBoots"   },
        { id = 3, name = "Plungerang", hasItem = "hasPlunger" },
    }
    local active = {}
    for _, item in ipairs(items) do
        if PlayerData.items[item.hasItem] then
            table.insert(active, item)
        end
    end
    return active
end

-- ── Navigation ────────────────────────────────────────────────────────────────
function InGameMenu:nextItem()
    local ids = getActiveSkillIds()
    if #ids == 0 then return end
    local idx = 1
    for i, id in ipairs(ids) do
        if PlayerData.activeItem == id then idx = i; break end
    end
    idx = idx % #ids + 1
    PlayerData.activeItem = ids[idx]
end

function InGameMenu:prevItem()
    local ids = getActiveSkillIds()
    if #ids == 0 then return end
    local idx = 1
    for i, id in ipairs(ids) do
        if PlayerData.activeItem == id then idx = i; break end
    end
    idx = idx - 1
    if idx < 1 then idx = #ids end
    PlayerData.activeItem = ids[idx]
end

-- ── Input ─────────────────────────────────────────────────────────────────────
function InGameMenu:keypressed(key)
    if not PlayerData.isEquiping then return false end
    if Input.is(key, "right") then self:nextItem(); return true end
    if Input.is(key, "left")  then self:prevItem(); return true end
    return false
end

function InGameMenu:gamepadInput(input)
    if not PlayerData.isEquiping then return false end
    if input.right or (input.leftx and input.leftx > 0.5) then
        self:nextItem(); return true
    elseif input.left or (input.leftx and input.leftx < -0.5) then
        self:prevItem(); return true
    end
    return false
end

-- ── Map canvas builder ────────────────────────────────────────────────────────
function InGameMenu:_buildMapCanvas()
    local canvas = love.graphics.newCanvas(400, 240)
    local prev   = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    -- All possible room cells (dark background)
    for _, cfg in pairs(floorConfig) do
        love.graphics.setColor(0.196, 0.184, 0.161, 0.5)
        for i = 0, cfg.cols * cfg.rows - 1 do
            local col = i % cfg.cols
            local row = math.floor(i / cfg.cols)
            love.graphics.rectangle("fill",
                cfg.posX + col * MAP_SPACING,
                cfg.posY + row * MAP_SPACING,
                MAP_ROOM_SIZE, MAP_ROOM_SIZE)
        end
    end

    -- Visited rooms and player position
    for _, levelData in ipairs(levelsLDTK) do
        local cf      = levelData.customFields or {}
        local level   = cf.level
        local roomNum = cf.roomNumber
        if not level or not roomNum then goto continue end

        local cfg = floorConfig[level]
        if not cfg then goto continue end

        local roomIndex = roomNum - cfg.startRoom
        if roomIndex < 0 or roomIndex >= cfg.cols * cfg.rows then goto continue end

        local col = roomIndex % cfg.cols
        local row = math.floor(roomIndex / cfg.cols)
        local bx  = cfg.posX + col * MAP_SPACING
        local by  = cfg.posY + row * MAP_SPACING

        if cf.visited then
            -- Visited rooms: transparent (dark background shows through)
            -- Only the current room gets a white square + dot
            if PlayerData.actualLevel == level and PlayerData.actualRoom == roomNum then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", bx + 1, by + 1, 5, 5)
                love.graphics.setColor(0.196, 0.184, 0.161, 1)
                love.graphics.rectangle("fill", bx + 2, by + 2, 3, 3)
            end
        end

        ::continue::
    end

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

    -- 4. Item icons
    love.graphics.setColor(1, 1, 1, 1)
    if PlayerData.items.hasLamp then
        local frame = (PlayerData.activeItem == 1) and 6 or 5
        love.graphics.draw(itemsSheet, itemQuads[frame],
            ITEM_POSITIONS.lamp.x, ITEM_POSITIONS.lamp.y)
    end
    if PlayerData.items.hasBoots then
        local frame = (PlayerData.activeItem == 2) and 4 or 3
        love.graphics.draw(itemsSheet, itemQuads[frame],
            ITEM_POSITIONS.boot.x, ITEM_POSITIONS.boot.y)
    end
    if PlayerData.items.hasPlunger then
        local frame = (PlayerData.activeItem == 3) and 2 or 1
        love.graphics.draw(itemsSheet, itemQuads[frame],
            ITEM_POSITIONS.plunger.x, ITEM_POSITIONS.plunger.y)
    end

    -- 5. Skill info banner
    local ai = PlayerData.activeItem
    if ai and ai > 0 then
        -- activeItem: 1=flash→frame3, 2=dash→frame2, 3=plunder→frame1
        local frame = 4 - ai   -- 1→3, 2→2, 3→1
        love.graphics.draw(skillSheet, skillQuads[frame],
            SKILL_INFO_POS.x, SKILL_INFO_POS.y)
    end

    -- 6. Crew hats
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
