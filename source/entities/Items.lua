-- entities/Items.lua
-- Ported from Playdate to Love2D
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local Items = Class('Items')

function Items:initialize(x, y, itemType, world)
	self.x = x
	self.y = y
	
	-- Sprite and collision dimensions
	self.spriteWidth = 32
	self.spriteHeight = 32
	self.width = 32
	self.height = 32
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
	
	self.removed = false
	
	-- Load spritesheet and setup animations
	self.spritesheet = love.graphics.newImage('assets/images/items/items-key-table-32-32.png')
	local grid = anim8.newGrid(32, 32, self.spritesheet:getWidth(), self.spritesheet:getHeight())
	
	-- Animation states (matching Playdate sequential frame numbering)
	-- Spritesheet is 6 columns x 3 rows = 18 frames total
	-- Playdate uses sequential numbering: frames 1-18
	-- Row 1: frames 1-6, Row 2: frames 7-12, Row 3: frames 13-18
	self.animations = {
		boots = anim8.newAnimation(grid('1-3', 1), 8/60),      -- frames 1-3 (Playdate: 1-3)
		plunger = anim8.newAnimation(grid('4-6', 1), 8/60),    -- frames 4-6 (Playdate: 4-6)
		lamp = anim8.newAnimation(grid('1-3', 2), 8/60),       -- frames 7-9 (Playdate: 7-9)
		notes = anim8.newAnimation(grid('4-6', 2), 8/60),      -- frames 10-12 (Playdate: 10-12)
		keycard = anim8.newAnimation(grid('1-3', 3), 8/60),    -- frames 13-15 (Playdate: 13-15)
		itemgift = anim8.newAnimation(grid('4-6', 3), 8/60)    -- frames 16-18 (Playdate: 16-18)
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
	-- Remove from BUMP world (only if still in world)
	if self.world and self.world:hasItem(self) then
		self.world:remove(self)
	end
	
	self.removed = true
	
	-- Disable sonar effect (commented out)
	-- if self.sonar then
	-- 	self.sonar:disableFX()
	-- end
end

function Items:getCollisionRect()
	return self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height
end

return Items
