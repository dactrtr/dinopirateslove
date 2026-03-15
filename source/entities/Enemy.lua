-- entities/Enemy.lua
-- Ported from Playdate to Love2D
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local Enemy = Class('Enemy')

function Enemy:initialize(x, y, world, enemyType)
	self.x = x
	self.y = y
	
	-- Sprite dimensions
	self.spriteWidth = 32
	self.spriteHeight = 32
	
	-- Collision box dimensions
	self.width = 28
	self.height = 28
	
	-- Collision box offset
	self.collisionOffsetX = 2
	self.collisionOffsetY = 2
	
	-- Movement properties
	self.initialSpeed = 30
	self.moveSpeed = self.initialSpeed
	self.viewRange = 100
	
	-- Enemy properties
	self.powerLevel = 0
	self.id = math.random(1000, 9999)
	self.enemyType = enemyType or "generic"
	self.Zindex = ZIndex.enemy
	
	-- BUMP physics
	self.world = world
	if world then
		world:add(self, self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height)
	end
	
	-- Animation setup (placeholder - customize per enemy type)
	-- self.spritesheet = love.graphics.newImage("assets/images/enemies/" .. enemyType .. ".png")
	-- local grid = anim8.newGrid(32, 32, self.spritesheet:getWidth(), self.spritesheet:getHeight())
	-- self.animations = {
	-- 	idle = anim8.newAnimation(grid('1-2', 1), 0.5),
	-- 	walk = anim8.newAnimation(grid('3-4', 1), 0.3),
	-- 	shine = anim8.newAnimation(grid('5-6', 1), 0.2)
	-- }
	-- self.currentAnimation = self.animations.idle
end

-- Blind search: enemy moves towards player regardless of obstacles
function Enemy:blindSearch(player, dt)
	self.player = player
	dt = dt or 1/60 -- Default to 60fps if dt not provided
	local movementX = self.player.x <= self.x and self.x - self.moveSpeed * dt or self.x + self.moveSpeed * dt
	local movementY = self.player.y <= self.y and self.y - self.moveSpeed * dt or self.y + self.moveSpeed * dt
	
	-- self.currentAnimation = self.animations.walk
	self:moveCollision(movementX, movementY, self.player)
end

-- Lineal search: enemy only moves when aligned with player (horizontal or vertical)
function Enemy:linealSearch(player, dt)
	dt = dt or 1/60 -- Default to 60fps if dt not provided
	
	if PlayerData.battery <= 10 then
		self.moveSpeed = 0
	elseif PlayerData.battery > 60 then
		self.moveSpeed = self.initialSpeed
	end
	
	self.player = player
	local movementX = self.x
	local movementY = self.y
	
	-- Move horizontally if vertically aligned
	if math.abs(self.y - self.player.y) < self.viewRange then
		movementX = self.player.x <= self.x and self.x - self.moveSpeed * dt or self.x + self.moveSpeed * dt
		self:moveCollision(movementX, self.y, self.player)
	end
	
	-- Move vertically if horizontally aligned
	if math.abs(self.x - self.player.x) < self.viewRange then
		movementY = self.player.y <= self.y and self.y - self.moveSpeed * dt or self.y + self.moveSpeed * dt
		self:moveCollision(self.x, movementY, self.player)
	end
end

-- Move with collision detection and response
function Enemy:moveCollision(movementX, movementY, player)
	if PlayerData.battery < 10 and PlayerData.isInDarkness == true then
		self.moveSpeed = 0.5
	elseif PlayerData.battery > 60 and PlayerData.isInDarkness == true then
		self.moveSpeed = self.initialSpeed
	end
	
	-- Calculate collision box position
	local newCollisionX = movementX + self.collisionOffsetX
	local newCollisionY = movementY + self.collisionOffsetY
	
	-- Move with BUMP collision detection
	local actualX, actualY, cols, length = self.world:move(self, newCollisionX, newCollisionY)
	
	-- Convert back to sprite position
	self.x = actualX - self.collisionOffsetX
	self.y = actualY - self.collisionOffsetY
	
	local bounceFactor = 3
	
	if length > 0 then
		for index = 1, length do
			local collision = cols[index]
			local collideObject = collision.other
			local collideType = collideObject.class and collideObject.class.name or "unknown"
			
			-- Player collision (commented out as in original)
			-- if collideType == "Player" and self.player.isAlive then
			-- 	PlayerData.lastEnemyTouched = {
			-- 		type = self.enemyType,
			-- 		id = self.id,
			-- 		x = self.x,
			-- 		y = self.y
			-- 	}
			-- 	self.player:fight()
			-- end
			
			-- Bounce effect on collision with boxes, props, or other enemies
			if collideType == "Box" or collideType == "PropItem" or collideType == "Enemy" then
				
				-- Enemy eating props
				if collideType == "PropItem" and collideObject.isEdible == true then
					self.powerLevel = self.powerLevel + 1
					
					-- Destroy edible props if power level is high enough
					local notHole = collideObject.type ~= "holeLeft" and 
					               collideObject.type ~= "holeRight" and 
					               collideObject.type ~= "holeDown" and 
					               collideObject.type ~= "holeTop"
					
					if notHole and self.powerLevel > 25 then
						-- collideObject:destroyProp(collideObject.id)
						self.powerLevel = self.powerLevel - 5
					end
				end
				
				-- Bounce back
				local normal = collision.normal
				if normal then
					local bounceX = self.x + (normal.x * bounceFactor)
					local bounceY = self.y + (normal.y * bounceFactor)
					
					-- Update position in world
					local collisionX = bounceX + self.collisionOffsetX
					local collisionY = bounceY + self.collisionOffsetY
					self.world:update(self, collisionX, collisionY)
					
					self.x = bounceX
					self.y = bounceY
				end
			end
		end
	end
end

-- Collision filter for BUMP (replaces Playdate's collisionResponse)
function Enemy:filter(other)
	local otherType = other.class and other.class.name or "unknown"
	
	if otherType == "Items" or otherType == "Trigger" then
		return 'cross' -- BUMP equivalent to 'overlap'
	elseif otherType == "Box" or otherType == "PropItem" then
		return 'slide' -- BUMP equivalent to 'freeze'
	elseif otherType == "Player" then
		return 'cross' -- BUMP equivalent to 'overlap'
	else
		return 'slide'
	end
end

-- Sonar effect (commented out as requested)
-- function Enemy:sonar()
-- 	if (PlayerData.x - 60) > self.x or (PlayerData.x + 60) < self.x then
-- 		if PlayerData.isFocused == true and PlayerData.isInDarkness == true and PlayerData.sanity > 0 then
-- 			-- self.currentAnimation = self.animations.shine
-- 			-- self.currentAnimation.frameDuration = math.random(1, 16) / 60
-- 			-- Set Z-index equivalent (draw order)
-- 		else
-- 			-- self.currentAnimation = self.animations.idle
-- 		end
-- 	end
-- end

function Enemy:update(dt)
	-- Update animation if it exists
	if self.currentAnimation then
		self.currentAnimation:update(dt)
	end
	
	-- Add AI behavior here
	-- Example: self:linealSearch(player)
end

function Enemy:draw()
	-- Draw sprite if it exists
	if self.spritesheet and self.currentAnimation then
		self.currentAnimation:draw(self.spritesheet, self.x, self.y)
	else
		-- Placeholder rectangle
		love.graphics.setColor(1, 0, 0, 0.7)
		love.graphics.rectangle("fill", self.x, self.y, self.spriteWidth, self.spriteHeight)
		love.graphics.setColor(1, 1, 1, 1)
	end
	
	-- Debug: Draw collision box
	-- love.graphics.setColor(0, 1, 0, 0.3)
	-- love.graphics.rectangle("fill", self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height)
	-- love.graphics.setColor(1, 1, 1, 1)
end

-- Get collision box position
function Enemy:getCollisionRect()
	return self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height
end

-- Update collision position in BUMP world
function Enemy:updateCollisionPosition()
	local collisionX = self.x + self.collisionOffsetX
	local collisionY = self.y + self.collisionOffsetY
	self.world:update(self, collisionX, collisionY)
end

return Enemy
