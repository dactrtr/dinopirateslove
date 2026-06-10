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

	-- Turn-based token budget. The cap is small on purpose: it bounds how long the
	-- enemy keeps moving after the player stops feeding it frames (see Config).
	self.movementFrames    = 0
	self.maxMovementFrames = (Config and Config.Enemy and Config.Enemy.movementFramesCap) or 6

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
	local cfg = (Config and Config.Enemy) or {}
	local inset = cfg.holeProbeFeetInset or 6
	local half  = cfg.holeProbeHalfWidth or 8
	local feetX = spriteX + (self.spriteWidth  or 32) / 2
	local feetY = spriteY + (self.spriteHeight or 32) - inset
	for _, dx in ipairs({ -half, 0, half }) do
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
	-- player. Capped at Config.Enemy.maxStepDt → at most moveSpeed*maxStepDt px/tick.
	local maxStepDt = (Config and Config.Enemy and Config.Enemy.maxStepDt) or 1/30
	dt = math.min(dt or 1/60, maxStepDt)

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
	
	local cfg = (Config and Config.Enemy) or {}
	local bounceFactor          = cfg.bounceFactor or 3
	local eatPropPowerThreshold = cfg.eatPropPowerThreshold or 25
	local eatPropPowerPenalty   = cfg.eatPropPowerPenalty or 5

	if length > 0 then
		for index = 1, length do
			local collision = cols[index]
			local collideObject = collision.other
			local cat = self:classifyOther(collideObject)

			-- Player collision: run the centralized hit handler (HP drain → dance or
			-- death, gated by canDance/threshold). Handles invincibility internally.
			if cat == "player" then
				playerCollisions.handleEnemyContact(collideObject, self)

			-- Bounce off walls, props, and other enemies (matches Playdate, which
			-- bounced on isa(Box)/isa(PropItem)/isa(Enemy)).
			elseif cat == "wall" or cat == "prop" or cat == "enemy" then

				-- Enemy eating edible props
				if cat == "prop" and collideObject.isEdible == true then
					self.powerLevel = self.powerLevel + 1
					if self.powerLevel > eatPropPowerThreshold then
						-- collideObject:destroyProp(collideObject.id)
						self.powerLevel = self.powerLevel - eatPropPowerPenalty
					end
				end

				-- Bounce back along the collision normal. Use world:move (collision-
				-- checked) rather than world:update (a raw teleport of the bump rect):
				-- a teleport let the 3 px push land the enemy inside/through a wall when
				-- bouncing in a corner. With world:move + the enemy filter, walls block
				-- the bounce so it can never cross them.
				local normal = collision.normal
				if normal then
					local bounceX = self.x + (normal.x * bounceFactor)
					local bounceY = self.y + (normal.y * bounceFactor)
					local ax, ay = self.world:move(self,
						bounceX + self.collisionOffsetX,
						bounceY + self.collisionOffsetY,
						function(item, other) return self:filter(other) end)
					self.x = ax - self.collisionOffsetX
					self.y = ay - self.collisionOffsetY
				end
			end
		end
	end
end

-- Classify a collided object into a Playdate collision category. Robust where the
-- old class.name checks were not:
--   • walls are plain {isWall=true} tables with no `.class` (utilities.lua),
--   • Brocorat/CrewMember are SUBCLASSES of Enemy (isInstanceOf respects that,
--     class.name == "Enemy" never matched them),
--   • triggers/props are identified by flags, not class names.
function Enemy:classifyOther(other)
	if other.isWall then return "wall" end
	if other.isInstanceOf and other:isInstanceOf(Enemy) then return "enemy" end
	if other.class and other.class.name == "Player" then return "player" end
	if other.isProp then return "prop" end
	if other.isTrigger then return "trigger" end
	if other.class and other.class.name == "Items" then return "item" end
	return "unknown"
end

-- Collision filter for BUMP (replaces Playdate's collisionResponse).
-- Playdate mapping: Items/Trigger → overlap, Box/Prop/Enemy → freeze, Player → overlap.
function Enemy:filter(other)
	local cat = self:classifyOther(other)

	if cat == "item" or cat == "trigger" then
		return 'cross' -- overlap: pass through (and don't get blocked by triggers)
	elseif cat == "player" then
		-- 'touch' stops the enemy at the moment of contact and STILL reports the
		-- collision (moveCollision reads it from the returned list and runs the hit
		-- logic). 'cross' was used before but let the enemy slide through and
		-- overshoot, so on contact it looked like it lunged onto/past the player.
		return 'touch'
	else
		-- wall / prop / enemy / unknown: solid. 'touch' is BUMP's equivalent of the
		-- Playdate 'freeze' response — the enemy stops dead at contact (no sliding),
		-- then the 3 px bounce in moveCollision pushes it back along the normal.
		return 'touch'
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
