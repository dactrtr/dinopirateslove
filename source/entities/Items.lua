-- entities/Items.lua
-- Ported from Playdate to Love2D
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local Items = Class('Items')

function Items:initialize(x, y, itemType, world)
	self.x = x
	self.y = y
	
	-- Sprite and collision dimensions
	self.spriteWidth = 48
	self.spriteHeight = 48
	self.width = 48
	self.height = 48
	self.collisionOffsetX = 0
	self.collisionOffsetY = 0
	
	-- Item properties
	self.type = itemType or "keycard"
	self.zIndex = 3 -- ZIndex.items equivalent
	
	-- BUMP physics
	self.world = world
	if world then
		world:add(self, self.x, self.y, self.width, self.height)
	end
	
	-- Load spritesheet and setup animations
	self.spritesheet = love.graphics.newImage('assets/images/items/item-key-table-48-48.png')
	local grid = anim8.newGrid(48, 48, self.spritesheet:getWidth(), self.spritesheet:getHeight())
	
	-- Animation states (matching Playdate frame ranges)
	self.animations = {
		keycard = anim8.newAnimation(grid('1-20', 1), 8/60),  -- frames 1-20, 8 frame duration
		lamp = anim8.newAnimation(grid('21-25', 1), 8/60),    -- frames 21-25
		radio = anim8.newAnimation(grid('26-29', 1), 8/60),   -- frames 26-29
		notes = anim8.newAnimation(grid('30-33', 1), 8/60),   -- frames 30-33
		tools = anim8.newAnimation(grid('34-37', 1), 8/60),   -- frames 34-37
		bag = anim8.newAnimation(grid('38-41', 1), 8/60)      -- frames 38-41
	}
	
	-- Set current animation based on type
	self.currentAnimation = self.animations[self.type] or self.animations.keycard
	
	-- Sonar effect (commented out as in original)
	-- self.sonar = FXsonar(self.x, self.y)
end

function Items:update(dt)
	-- Update animation
	if self.currentAnimation then
		self.currentAnimation:update(dt)
	end
	
	-- Sonar effect (commented out)
	-- if PlayerData.sonarActive == true then
	-- 	self:sonar('key')
	-- end
end

function Items:draw()
	-- Draw sprite
	if self.spritesheet and self.currentAnimation then
		self.currentAnimation:draw(self.spritesheet, self.x, self.y)
	else
		-- Fallback placeholder
		love.graphics.setColor(1, 1, 0, 0.7)
		love.graphics.rectangle("fill", self.x, self.y, self.spriteWidth, self.spriteHeight)
		love.graphics.setColor(1, 1, 1, 1)
	end
	
	-- Debug: Draw collision box
	-- love.graphics.setColor(0, 1, 1, 0.3)
	-- love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	-- love.graphics.setColor(1, 1, 1, 1)
end

function Items:sonar(x, y)
	-- Sonar effect (commented out)
	-- self.sonar:activate(self.x, self.y, 'key')
end

function Items:removeAll()
	-- Remove from BUMP world
	if self.world then
		self.world:remove(self)
	end
	
	-- Disable sonar effect (commented out)
	-- if self.sonar then
	-- 	self.sonar:disableFX()
	-- end
end

function Items:getCollisionRect()
	return self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height
end

return Items
