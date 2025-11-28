local Class = require 'libraries/middleclass'
local PropCollider = require 'entities.props.propCollider'

local PropItem = Class('PropItem')

-- Static assets
local propsImage = nil
local propsQuads = {}
local TILE_SIZE = 32

-- Animation state mapping (name -> frame index)
-- Based on Playdate code: addState('name', start, end)
local propStates = {
    chair = 1,
    fellchair = 2,
    box = 3,
    trash = 4,
    toxic = 5,
    table = 6,
    fellTable = 7,
    blood = 8,
    blood2 = 9,
    deadrat = 10,
    ["xtree-1"] = 11,
    ["xtree-2"] = 12,
    ["xtree-3"] = 13,
    ["xtree-4"] = 14,
    microwave = 15,
    gifts = 16,
    gift = 17,
    smallTable = 18,
    fridge1 = 19,
    fridge2 = 20,
    kitchenStorage = 21,
    pot = 22,
    knifeKettle = 23,
    holeTopLeft = 24,
    holeLeft = 25,
    holeBottomLeft = 26,
    holeTop = 27,
    holeCenter = 28,
    holeBottom = 29,
    holeTopRight = 30,
    holeRight = 31,
    holeBottomRight = 32,
    debris = 33
}

function PropItem:initialize(x, y, type, zIndex, nocollide, isDestroyed, id, world)
    self.x = x
    self.y = y
    self.type = type
    self.id = id
    self.world = world
    self.class = PropItem
    self.isProp = true
    
    -- Load assets if not loaded
    if not propsImage then
        propsImage = love.graphics.newImage('assets/images/props/props-table-32-32.png')
        propsImage:setFilter("nearest", "nearest")
        
        -- Generate quads
        local width, height = propsImage:getDimensions()
        local cols = math.floor(width / TILE_SIZE)
        local rows = math.floor(height / TILE_SIZE)
        
        for i = 0, rows * cols - 1 do
            local qx = (i % cols) * TILE_SIZE
            local qy = math.floor(i / cols) * TILE_SIZE
            table.insert(propsQuads, love.graphics.newQuad(qx, qy, TILE_SIZE, TILE_SIZE, width, height))
        end
    end
    
    self.currentFrame = propStates[type] or 1
    
    -- Default properties
    self.isEdible = true
    self.isHole = false
    self.width = 32
    self.height = 32
    self.nocollide = nocollide
    self.isDestroyed = isDestroyed
    
    -- Default collider setup
    if nocollide == false then
        -- Add self to world as the main collision body? 
        -- Or use PropCollider as a separate entity?
        -- The Playdate code uses a separate PropCollider for the physics body
        -- and the PropItem itself seems to be the sprite.
        -- In BUMP, we can just add the PropItem itself if it's simple, 
        -- but PropCollider allows for different collision rects.
        
        local cx, cy, cw, ch
        if type == "xtree-1" or type == "xtree-2" then
            cx, cy, cw, ch = x, y+16, 28, 4
        else
            cx, cy, cw, ch = x, y, 28, 18
        end
        
        self.propcollider = PropCollider(cx, cy, cw, ch, world)
    end
    
    -- HOLE TYPES CONFIGURATION
    local holeTypes = {
        -- Holes where player falls through (no collision, no prop collider)
        holeTop = { isHole = true, collideRect = nil, removePropCollider = true },
        holeCenter = { isHole = true, collideRect = nil, removePropCollider = true },
        holeBottom = { isHole = true, collideRect = nil, removePropCollider = true },
        holeTopLeft = { isHole = true, collideRect = nil, removePropCollider = true },
        holeBottomLeft = { isHole = true, collideRect = nil, removePropCollider = true },
        holeTopRight = { isHole = true, collideRect = nil, removePropCollider = true },
        holeBottomRight = { isHole = true, collideRect = nil, removePropCollider = true },
        
        -- Edge holes with partial collision
        holeLeft = { isHole = true, collideRect = {10, 0, 22, 32}, removePropCollider = true },
        holeRight = { isHole = true, collideRect = {0, 0, 22, 32}, removePropCollider = true },
        -- holeCenter duplicate in original code, ignoring the second one which had collision
        -- holeTopLeft duplicate...
        -- I'll stick to the logic: if it's a hole, we might want to remove the default collider
        -- and add a specific one.
    }
    
    -- Re-implementing the specific hole logic from Playdate code carefully
    -- The original code had duplicate keys in the table, Lua takes the last one.
    -- Let's look at the last definitions in the original file:
    -- holeLeft: collideRect = {10, 0, 22, 32}
    -- holeRight: collideRect = {0, 0, 22, 32}
    -- holeCenter: collideRect = {0, 0, 32, 32}
    -- holeTopLeft: collideRect = {10, 10, 22, 22}
    -- holeTop: collideRect = {0, 10, 32, 22}
    -- holeTopRight: collideRect = {0, 10, 22, 22}
    -- holeBottomRight: collideRect = {0, 0, 22, 22}
    -- holeBottom: collideRect = {0, 0, 32, 22}
    -- holeBottomLeft: collideRect = {10, 0, 22, 22}
    
    local specificHoles = {
         holeLeft = {10, 0, 22, 32},
         holeRight = {0, 0, 22, 32},
         holeCenter = {0, 0, 32, 32},
         holeTopLeft = {10, 10, 22, 22},
         holeTop = {0, 10, 32, 22},
         holeTopRight = {0, 10, 22, 22},
         holeBottomRight = {0, 0, 22, 22},
         holeBottom = {0, 0, 32, 22},
         holeBottomLeft = {10, 0, 22, 22}
    }
    
    if specificHoles[type] then
        self.isHole = true
        self.isEdible = false
        
        -- Remove default collider
        if self.propcollider then
            self.propcollider:remove()
            self.propcollider = nil
        end
        
        -- Add specific collider
        local rect = specificHoles[type]
        -- rect is {x_offset, y_offset, width, height}
        self.propcollider = PropCollider(x + rect[1], y + rect[2], rect[3], rect[4], world)
        
        print("🕳️  Hole created:", type, "at", x, y)
    end
    
    self.zIndex = zIndex
end

function PropItem:update(dt)
    -- Update zIndex if needed for sorting (gameScene handles sorting usually)
end

function PropItem:draw()
    if propsImage and propsQuads[self.currentFrame] then
        love.graphics.draw(propsImage, propsQuads[self.currentFrame], self.x, self.y)
    end
    
    -- Debug drawing
    if DRAW_DEBUG_DOORS and self.propcollider then
         love.graphics.setColor(1, 0, 1, 0.5) -- Purple for props
         love.graphics.rectangle("fill", self.propcollider.x, self.propcollider.y, self.propcollider.width, self.propcollider.height)
         love.graphics.setColor(1, 1, 1)
    end
end

function PropItem:remove()
    if self.propcollider then
        self.propcollider:remove()
    end
end

return PropItem