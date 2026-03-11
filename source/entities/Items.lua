-- entities/Items.lua
-- Ported from Playdate to Love2D
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local Items = Class('Items')

function Items:initialize(x, y, itemType, keyNumber, grants, world)
	self.x = x
	self.y = y

	-- Sprite and collision dimensions
	self.spriteWidth = 32
	self.spriteHeight = 32
	self.width = 32
	self.height = 32
	self.collisionOffsetX = 0
	self.collisionOffsetY = 0

	-- Item properties (normalize type to lowercase for animation lookup)
	self.type = itemType and itemType:lower() or "keycard"
	self.keyNumber = keyNumber  -- used by keycard collision
	self.grants = grants        -- used by notes / itemgift collision
	self.zIndex = 3 -- ZIndex.items equivalent

	-- BUMP physics  (x,y is the CENTER of the sprite, so register top-left offset)
	self.world = world
	if world then
		world:add(self, self.x - self.width / 2, self.y - self.height / 2, self.width, self.height)
	end

	self.removed = false

	-- Load spritesheet and setup animations
	-- Spritesheet: 192×96 px, 6 cols × 3 rows at 32×32 per frame (18 frames total)
	-- Frame layout matches Playdate sequential numbering 1–18:
	--   Row 1 (cols 1-6): boots(1-3), plunger(4-6)
	--   Row 2 (cols 1-6): lamp(7-9), notes(10-12)
	--   Row 3 (cols 1-6): keycard(13-15), itemgift(16-18)
	self.spritesheet = love.graphics.newImage('assets/images/items/items-key-table-32-32.png')
	local grid = anim8.newGrid(32, 32, self.spritesheet:getWidth(), self.spritesheet:getHeight())

	self.animations = {
		boots    = anim8.newAnimation(grid('1-3', 1), 8/60),
		plunger  = anim8.newAnimation(grid('4-6', 1), 8/60),
		lamp     = anim8.newAnimation(grid('1-3', 2), 8/60),
		notes    = anim8.newAnimation(grid('4-6', 2), 8/60),
		keycard  = anim8.newAnimation(grid('1-3', 3), 8/60),
		itemgift = anim8.newAnimation(grid('4-6', 3), 8/60),
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
		self.currentAnimation:draw(self.spritesheet, self.x, self.y, 0, 1, 1, self.spriteWidth / 2, self.spriteHeight / 2)
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
	-- Mark as collected in levelsLDTK so SaveSystem persists the state
	if self.sourceData and self.sourceData.customFields then
		self.sourceData.customFields.collected = true
	end

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
