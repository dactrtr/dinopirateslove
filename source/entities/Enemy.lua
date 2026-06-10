-- entities/Enemy.lua
-- Ported from Playdate to Love2D
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'
local playerCollisions = require 'entities.player.collisions'

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

	-- Turn-based token budget
	self.movementFrames    = 0
	self.maxMovementFrames = 90

	-- Enemy properties
	self.powerLevel = 0
	self.id = math.random(1000, 9999)
	self.enemyType = enemyType or "generic"
	self.damage    = (Config and Config.Enemy and Config.Enemy.damage) or 1
	self.Zindex = ZIndex.enemy
	
	-- BUMP physics
	self.world = world
	if world then
		world:add(self, self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height)
	end
	
end

-- Returns a speed multiplier (0.25–1.0) based on the player's current battery level.
-- 4-tier system: >= 75 → full speed, >= 50 → 3/4, >= 25 → 1/2, < 25 → 1/4.
local function getBatterySpeedMultiplier()
	local bat = PlayerData and PlayerData.battery or 100
	if     bat >= 75 then return 1.0
	elseif bat >= 50 then return 0.75
	elseif bat >= 25 then return 0.5
	else                   return 0.25
	end
end

-- Adjusts moveSpeed based on PlayerData battery (4-tier) and darkness state.
-- Call once per update tick, before any movement method.
function Enemy:updateMoveSpeed()
	local multiplier = getBatterySpeedMultiplier()
	self.moveSpeed = self.initialSpeed * multiplier

	-- Additional hard slowdown when battery is critically low AND in darkness
	if PlayerData.isInDarkness then
		local bat = PlayerData and PlayerData.battery or 100
		if bat == 0 then
			self.moveSpeed = (Config and Config.Enemy and Config.Enemy.moveSpeedBatteryEmpty) or 0.2
		elseif bat < 10 then
			self.moveSpeed = (Config and Config.Enemy and Config.Enemy.moveSpeedCritical) or 0.5
		end
	end
end

-- Add raw frames directly (synchronized with player movement).
-- Frames accumulate up to maxMovementFrames (default 90).
function Enemy:addMovementFrames(frames)
	self.movementFrames = math.min(
		self.maxMovementFrames,
		self.movementFrames + frames
	)
end

-- Add movement tokens (1 token = framesPerToken raw frames, default 30).
function Enemy:addMovementTokens(amount)
	local fpt = (Config and Config.CrewMember and Config.CrewMember.framesPerToken) or 30
	self:addMovementFrames(amount * fpt)
end

-- Prevents the enemy from moving for `frames` update ticks.
-- Called on Plungerang hit or light flash.
function Enemy:blind(frames)
	self.blindFrames    = frames or 60
	self.isBlinded      = true
	self.movementFrames = 0   -- cancel pending movement immediately
end

-- Apply a knockback push by `distance` pixels in the (dx, dy) direction.
-- Uses world:move for safe, collision-resolved displacement.
function Enemy:knockback(dx, dy, distance)
	distance = distance or 16
	if not (self.world and self.world:hasItem(self)) then return end
	local newX = self.x + dx * distance
	local newY = self.y + dy * distance
	local actualX, actualY = self.world:move(
		self,
		newX + (self.collisionOffsetX or 0),
		newY + (self.collisionOffsetY or 0),
		function(item, other) return 'slide' end
	)
	self.x = actualX - (self.collisionOffsetX or 0)
	self.y = actualY - (self.collisionOffsetY or 0)
end

-- Holes are TILE-based, not bump colliders (see propItem.lua note), so without an
-- explicit tile probe the enemy would walk straight across any gap the player
-- falls into. Returns true if the enemy's feet at sprite position (spriteX, spriteY)
-- would rest on a hole tile. Mirrors Player:feetOnTile sampling. Tiny-holes are
-- ignored: they only swallow the shrunk player, a full-size enemy walks over them.
function Enemy:isOverHole(spriteX, spriteY)
	local utilities    = require 'utilities'
	local sceneManager = require 'sceneManager'
	local gameScene    = sceneManager.getScene("game")
	if not gameScene or not gameScene.tileMapData then return false end

	local tileSize = gameScene.tileSize
	local startX = VIRTUAL_WIDTH  / 2 - (gameScene.mapWidth  * tileSize) / 2
	local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * tileSize) / 2

	-- Sample the lower-center of the 32×32 sprite (the "feet").
	local feetX = spriteX + (self.spriteWidth  or 32) / 2
	local feetY = spriteY + (self.spriteHeight or 32) - 6
	for _, dx in ipairs({ -8, 0, 8 }) do
		local tileId = utilities.getTileUnderPlayer(gameScene.tileMapData, tileSize, feetX + dx, feetY, startX, startY)
		if tileId and utilities.HOLE_TILE_IDS[tileId] then
			return true
		end
	end
	return false
end

-- Blind search: enemy moves towards player regardless of obstacles
function Enemy:blindSearch(player, dt)
	-- Expects updateMoveSpeed() to have been called this tick.
	-- "blind" here means no obstacle avoidance, unrelated to the blindFrames status effect.
	self.player = player
	-- Clamp dt so a frame hitch (e.g. the big delta right after a scene transition
	-- or room load) can't multiply into a huge step and teleport the enemy onto the
	-- player. Capped at 1/30 s → at most moveSpeed/30 px in a single tick.
	dt = math.min(dt or 1/60, 1/30)

	local step = self.moveSpeed * dt
	local targetX = self.player.x <= self.x and self.x - step or self.x + step
	local targetY = self.player.y <= self.y and self.y - step or self.y + step

	-- Block any axis whose step would carry the enemy over a hole tile (gaps act
	-- like walls for enemies). Checked per-axis so it can still slide along an edge.
	local finalX = self:isOverHole(targetX, self.y) and self.x or targetX
	local finalY = self:isOverHole(self.x, targetY) and self.y or targetY

	if finalX ~= self.x or finalY ~= self.y then
		self:moveCollision(finalX, finalY, self.player)
	end
end

-- Lineal search: enemy only moves when aligned with player (horizontal or vertical)
function Enemy:linealSearch(player, dt)
	-- Expects updateMoveSpeed() to have been called this tick.
	dt = dt or 1/60 -- Default to 60fps if dt not provided

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
	-- Calculate collision box position
	local newCollisionX = movementX + self.collisionOffsetX
	local newCollisionY = movementY + self.collisionOffsetY
	
	-- Move with BUMP collision detection. Enemy:filter returns 'touch' for the
	-- Player: the enemy stops exactly at contact (no overshoot/lunge) and the
	-- collision is still reported in the list below so the hit logic runs.
	local actualX, actualY, cols, length = self.world:move(self, newCollisionX, newCollisionY,
		function(item, other) return self:filter(other) end)
	
	-- Convert back to sprite position
	self.x = actualX - self.collisionOffsetX
	self.y = actualY - self.collisionOffsetY
	
	local bounceFactor = 3
	
	if length > 0 then
		for index = 1, length do
			local collision = cols[index]
			local collideObject = collision.other
			local collideType = collideObject.class and collideObject.class.name or "unknown"
			
			-- Player collision: run the centralized hit handler (HP drain → dance or
			-- death, gated by canDance/threshold). Handles invincibility internally.
			if collideType == "Player" then
				playerCollisions.handleEnemyContact(collideObject, self)
			end

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
		-- 'touch' stops the enemy at the moment of contact and STILL reports the
		-- collision (moveCollision reads it from the returned list and runs the hit
		-- logic). 'cross' was used before but let the enemy slide through and
		-- overshoot, so on contact it looked like it lunged onto/past the player.
		return 'touch'
	else
		return 'slide'
	end
end

-- Switches to shine animation when off-screen (> 60px X) while player is focused and in darkness.
function Enemy:sonar()
	local offScreenLeft  = (PlayerData.x - 60) > self.x
	local offScreenRight = (PlayerData.x + 60) < self.x
	if (offScreenLeft or offScreenRight)
	   and PlayerData.isFocused
	   and PlayerData.isInDarkness
	   and (PlayerData.sanity or 0) > 0
	then
		if self.animations and self.animations.shine then
			self.currentAnimation = self.animations.shine
		end
	else
		if self.animations and self.animations.shine
		   and self.currentAnimation == self.animations.shine then
			self.currentAnimation = self.animations.idle
		end
	end
end

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
