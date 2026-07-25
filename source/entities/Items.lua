-- entities/Items.lua
-- Ported from Playdate to Love2D
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local Items = Class('Items')

function Items:initialize(x, y, itemType, keyNumber, grants, world)
	-- LDtk exports entity position as CENTER; convert to top-left for drawing (matches PropItem)
	self.spriteWidth = 32
	self.spriteHeight = 32
	self.width = 32
	self.height = 32
	self.x = x - self.spriteWidth / 2
	self.y = y - self.spriteHeight / 2
	self.collisionOffsetX = 0
	self.collisionOffsetY = 0

	-- Item properties (normalize type to lowercase for animation lookup)
	self.type = itemType and itemType:lower() or "keycard"
	self.keyNumber = keyNumber  -- used by keycard collision
	self.grants = grants        -- used by notes / itemgift collision
	self.zIndex = ZIndex.items

	-- BUMP physics (self.x, self.y is already top-left)
	self.world = world
	if world then
		world:add(self, self.x, self.y, self.width, self.height)
	end

	self.removed = false

	-- Load spritesheet and setup animations
	-- Spritesheet: 192×128 px, 6 cols × 4 rows at 32×32 per frame (24 frames total)
	-- Frame layout matches Playdate sequential numbering 1–24:
	--   Row 1 (cols 1-6): boots(1-3), plunger(4-6)
	--   Row 2 (cols 1-6): lamp(7-9), notes(10-12)
	--   Row 3 (cols 1-6): keycard(13-15), itemgift(16-18)
	--   Row 4 (cols 1-6): radio(19-21), food(22-24)
	self.spritesheet = love.graphics.newImage('assets/images/items/items-key-table-32-32.png')
	local grid = anim8.newGrid(32, 32, self.spritesheet:getWidth(), self.spritesheet:getHeight())

	self.animations = {
		boots    = anim8.newAnimation(grid('1-3', 1), 8/60),
		plunger  = anim8.newAnimation(grid('4-6', 1), 8/60),
		lamp     = anim8.newAnimation(grid('1-3', 2), 8/60),
		notes    = anim8.newAnimation(grid('4-6', 2), 8/60),
		keycard  = anim8.newAnimation(grid('1-3', 3), 8/60),
		itemgift = anim8.newAnimation(grid('4-6', 3), 8/60),
		radio    = anim8.newAnimation(grid('1-3', 4), 8/60),
		food     = anim8.newAnimation(grid('4-6', 4), 8/60),
	}

	-- Set current animation based on type
	self.currentAnimation = self.animations[self.type] or self.animations.keycard
end

function Items:update(dt)
	-- Update animation
	if self.currentAnimation then
		self.currentAnimation:update(dt)
	end
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
end

function Items:getCollisionRect()
	return self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height
end

return Items
