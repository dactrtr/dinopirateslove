local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local PropItem = Class('PropItem')

-- Static assets
local propsImage = nil
local propsGrid = nil
local TILE_SIZE = 32
local SHEET_COLS = 7 -- 224 / 32

-- State name to frame indices/animations mapping
local propConfigs = {
    -- Basic items
    chair = { frame = 1 },
    fellchair = { frame = 2 },
    box = { frame = 3 },
    trash = { frame = 4 },
    toxic = { frame = 5 },
    table = { frame = 6 },
    fellTable = { frame = 7 },
    blood = { frame = 8, nocollide = true },
    blood2 = { frame = 9, nocollide = true },
    deadrat = { frame = 10 },
    ["xtree-1"] = { frame = 11, collideRect = {2, 30, 28, 12} },
    ["xtree-2"] = { frame = 12, collideRect = {2, 30, 28, 12} },
    ["xtree-3"] = { frame = 13 },
    ["xtree-4"] = { frame = 14 },
    microwave = { frame = 15 },
    gifts = { frame = 16 },
    gift = { frame = 17 },
    smallTable = { frame = 18 },
    fridge1 = { frame = 19 },
    fridge2 = { frame = 20 },
    kitchenStorage = { frame = 21 },
    pot = { frame = 22 },
    knifeKettle = { frame = 23 },
    
    -- Holes
    holeTopLeft     = { frame = 24, isHole = true, isEdible = false, collideRect = {10, 10, 22, 22} },
    holeLeft        = { frame = 25, isHole = true, isEdible = false, collideRect = {10, 0, 22, 32} },
    holeBottomLeft  = { frame = 26, isHole = true, isEdible = false, collideRect = {10, 0, 22, 22} },
    holeTop         = { frame = 27, isHole = true, isEdible = false, collideRect = {0, 10, 32, 22} },
    holeCenter      = { frame = 28, isHole = true, isEdible = false, collideRect = {0, 0, 32, 32} },
    holeBottom      = { frame = 29, isHole = true, isEdible = false, collideRect = {0, 0, 32, 22} },
    holeTopRight    = { frame = 30, isHole = true, isEdible = false, collideRect = {0, 10, 22, 22} },
    holeRight       = { frame = 31, isHole = true, isEdible = false, collideRect = {0, 0, 22, 32} },
    holeBottomRight = { frame = 32, isHole = true, isEdible = false, collideRect = {0, 0, 22, 22} },
    
    debris = { frame = 33, nocollide = true },
    
    -- PC family
    pcBase      = { frame = 34 },
    pcScreen    = { frame = 35, collideRect = {2, 30, 28, 12} },
    pcBase2     = { frame = 36 },
    pcLoad      = { frames = {37, 38, 39}, duration = 0.2, collideRect = {2, 30, 28, 12} },
    pcBase3     = { frame = 40 },
    pcScreen2   = { frame = 41, collideRect = {2, 30, 28, 12} },
    pcScreen3   = { frame = 42, collideRect = {2, 30, 28, 12} },
    pcSiriSad   = { frame = 43, collideRect = {2, 30, 28, 12} },
    pcSiriHappy = { frame = 44, collideRect = {2, 30, 28, 12} },
    
    minifier    = { frame = 45, collideRect = {0, 12, 32, 18} },
    slime       = { frame = 46, isSlime = true, isEdible = false, collideRect = {0, 0, 32, 32} },
    pneumaticTube = { frame = 47, isTube = true, isEdible = false, collideRect = {8, 2, 16, 16} }, -- Centered 16px wide, full height
    Tube        = { frame = 48, nocollide = true }, -- Decorative only, no collision
}

function PropItem.static:isValidType(type)
    if propConfigs[type] then return true end
    local norm = getNormalizedConfigs()
    return norm[type:lower()] ~= nil
end

function PropItem.static:getConfigKey(type)
    if propConfigs[type] then return type end
    local norm = getNormalizedConfigs()
    return norm[type:lower()]
end

-- Mappings an index to col, row
local normalizedConfigs = nil
local function getNormalizedConfigs()
    if not normalizedConfigs then
        normalizedConfigs = {}
        for k, v in pairs(propConfigs) do
            normalizedConfigs[k:lower()] = k
        end
    end
    return normalizedConfigs
end

local function f(n)
    local row = math.ceil(n / SHEET_COLS)
    local col = n - (row - 1) * SHEET_COLS
    return col, row
end

function PropItem:initialize(x, y, type, zIndex, nocollide, isDestroyed, id, world)
    -- LDtk center pivot correction
    self.x = x - (TILE_SIZE / 2)
    self.y = y - (TILE_SIZE / 2)
    self.type = type
    self.id = id
    self.world = world
    self.isProp = true
    
    -- Load static assets once
    if not propsImage then
        propsImage = love.graphics.newImage('assets/images/props/props-table-32-32.png')
        propsImage:setFilter("nearest", "nearest")
        propsGrid = anim8.newGrid(TILE_SIZE, TILE_SIZE, propsImage:getWidth(), propsImage:getHeight())
    end
    
    local config = propConfigs[type] or {}
    
    -- Setup Animation using linear mapping
    if config.frames then
        local frames = {}
        for _, frameIdx in ipairs(config.frames) do
            local col, row = f(frameIdx)
            table.insert(frames, propsGrid(col, row)[1])
        end
        self.animation = anim8.newAnimation(frames, config.duration or 0.1)
    else
        local fIdx = config.frame or 1
        local col, row = f(fIdx)
        self.animation = anim8.newAnimation(propsGrid(col, row), 1)
    end
    
    -- Properties
    self.isEdible = config.isEdible ~= false
    self.isHole = config.isHole or false
    self.isSlime = config.isSlime or false
    self.isTube = config.isTube or false
    self.nocollide = (nocollide == true or config.nocollide == true)
    self.isDestroyed = (isDestroyed == true)
    
    -- Collision setup directly on PropItem
    self.width = TILE_SIZE
    self.height = TILE_SIZE
    
    -- BUMP uses top-left, we calculate collider relative to self.x, self.y
    local cr = config.collideRect or {2, 10, 28, 18} -- Default prop collider
    self.colOffsetX = cr[1]
    self.colOffsetY = cr[2]
    self.colWidth = cr[3]
    self.colHeight = cr[4]
    
    if not self.nocollide and not self.isDestroyed then
        world:add(self, self.x + self.colOffsetX, self.y + self.colOffsetY, self.colWidth, self.colHeight)
    end
    
    -- Z-Index logic
    self.zIndex = zIndex or (self.y + self.height)
    if self.nocollide or self.isDestroyed or self.isHole or self.isSlime or self.isTube or self.type == 'minifier' then
        -- Low static Z
        self.zIndex = 50 -- Below characters
    end
end

function PropItem:update(dt)
    if self.animation then
        self.animation:update(dt)
    end
    
    -- Dynamic Z-depth update if moving or not a static background-like prop
    if not (self.nocollide or self.isDestroyed or self.isHole or self.isSlime or self.isTube or self.type == 'minifier') then
        self.zIndex = self.y + self.height
    end
end

function PropItem:draw(debug)
    if propsImage and self.animation then
        self.animation:draw(propsImage, self.x, self.y)
    end
    
    -- Debug draw
    if debug and not self.nocollide and not self.isDestroyed then
        love.graphics.setColor(1, 0, 1, 0.4) -- Purple for props
        love.graphics.rectangle("fill", self.x + self.colOffsetX, self.y + self.colOffsetY, self.colWidth, self.colHeight)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function PropItem:destroyProp()
    self.isDestroyed = true
    if self.sourceData and self.sourceData.customFields then
        self.sourceData.customFields.destroyed = true
    end
    if self.world and self.world:hasItem(self) then
        self.world:remove(self)
    end
    -- Switch to debris animation state
    local fIdx = propConfigs.debris.frame
    local col, row = f(fIdx)
    self.animation = anim8.newAnimation(propsGrid(col, row), 1)
    self.nocollide = true
    self.zIndex = 50
end

function PropItem:remove()
    if self.world and self.world:hasItem(self) then
        self.world:remove(self)
    end
end

return PropItem