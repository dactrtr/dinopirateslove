local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local PropItem = Class('PropItem')

-- Static assets
local propsImage = nil
local propsGrid = nil
local TILE_SIZE = 32
local SHEET_COLS = 7 -- 224 / 32

-- State name to frame indices/animations mapping.
-- New props sheet layout (props-table-32-32.png, 224x32 = 7 frames, 1 row).
-- Holes and slime are now TILE-based (see utilities HOLE/SLIME tile ids), not props.
local propConfigs = {
    box           = { frame = 1 },
    pneumaticTube = { frame = 2, isTube = true, isEdible = false, collideRect = {4, 10, 24, 22} },
    Tube          = { frame = 3, nocollide = true },   -- decorative overlay, no collision
    TubeExit      = { frame = 4, nocollide = true },   -- decorative overlay, no collision
    minifier      = { frames = {5, 6}, duration = 0.4, collideRect = {0, 12, 32, 18} },
    microwave     = { frame = 7, collideRect = {0, 12, 32, 18} },
}

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
    if self.nocollide or self.isDestroyed or self.isHole or self.isSlime or self.isTube or self.type == 'minifier' or self.type == 'microwave' then
        self.zIndex = ZIndex.props  -- always below gameplay entities
    end
end

function PropItem:update(dt)
    if self.animation then
        self.animation:update(dt)
    end
    
    -- Dynamic Z-depth update if moving or not a static background-like prop
    if not (self.nocollide or self.isDestroyed or self.isHole or self.isSlime or self.isTube or self.type == 'minifier' or self.type == 'microwave') then
        self.zIndex = self.y + self.height
    end
end

function PropItem:draw(debug)
    if propsImage and self.animation then
        self.animation:draw(propsImage, self.x, self.y)
    end
    
    -- Debug draw
    if debug and not self.nocollide and not self.isDestroyed then
        -- Sprite boundaries (Blue) for holes and tubes
        if self.isHole or self.isTube then
            love.graphics.setColor(0, 0, 1, 0.5) -- Semi-transparent blue
            love.graphics.rectangle("line", self.x, self.y, TILE_SIZE, TILE_SIZE)
        end

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
    -- No debris frame in the new props sheet: just drop collision and depth.
    self.nocollide = true
    self.zIndex = ZIndex.props
end

function PropItem:remove()
    if self.world and self.world:hasItem(self) then
        self.world:remove(self)
    end
end

return PropItem