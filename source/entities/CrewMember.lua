-- entities/CrewMember.lua
-- Ported from Playdate to Love2D
local Class = require 'libraries/middleclass'
local Enemy = require 'entities.Enemy'
local anim8 = require 'libraries/anim8'

local CrewMember = Class('CrewMember', Enemy)

function CrewMember:initialize(x, y, world, player, id, data)
	-- Store center position (from LDtk)
	self.x = x
	self.y = y

	-- CrewMember specific properties
	self.type = "CrewMember"
	self.id = id or math.random(1000, 9999)
	self.player = player
	self.sourceData = data or {}

	-- Sprite dimensions (for drawing from center)
	self.spriteWidth = 48
	self.spriteHeight = 48

	-- Set collision properties
	self.width = 40
	self.height = 40
	self.collisionOffsetX = -(self.width / 2)  -- Center horizontally
	self.collisionOffsetY = -(self.height / 2)  -- Center vertically

	-- Add to BUMP world using center position + offset
	self.world = world
	if world then
		world:add(self, self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height)
	end

	-- Load spritesheet and setup animations
	self.spritesheet = love.graphics.newImage('assets/images/enemies/crewmember-table-48-48.png')
	local imgW, imgH = self.spritesheet:getDimensions()
	local framesPerRow = math.floor(imgW / 48)
	local totalRows = math.floor(imgH / 48)

	-- Create grid - will safely use only available frames
	local grid = anim8.newGrid(48, 48, imgW, imgH)

	printDebug(string.format("CrewMember spritesheet: %dx%d, frames/row: %d, rows: %d", imgW, imgH, framesPerRow, totalRows))

	-- Animation states - adapt to available frames
	local frameStr = framesPerRow > 1 and ('1-' .. framesPerRow) or '1-1'
	self.animations = {
		idle = anim8.newAnimation(grid(frameStr, 1), 0.3),
		walk = anim8.newAnimation(grid(frameStr, 1), 0.15),
		hide = anim8.newAnimation(grid('1-1', 1), 0.3),
		stun = anim8.newAnimation(grid('1-1', 1), 0.3),
	}

	self.currentAnimation = self.animations.idle

	-- Movement system (token-based)
	self.movementFrames = 0
	self.maxMovementFrames = 90 -- Cap for frame accumulation
	self.moveSpeed = 40
	self.initialSpeed = self.moveSpeed

	-- Escape mode
	self.isEscaping = true -- Always tries to escape
	self.viewRange = 200

	-- Blind/stun state
	self.isBlinded = false
	self.blindFrames = 0
	self.isStunned = false
	self.stunInfiniteActive = false

	-- Bounce state
	self.isBouncing = false
	self.bounceTimer = 0
	self.bounceDuration = 20
	self.recentBounceCount = 0
	self.bounceCountResetTimer = 0
	self.bouncesRequiredToHide = 3
	self.bounceResetDuration = 60 -- frames to reset bounce count

	-- Hiding state
	self.isHiding = false
	self.hidingVisionRange = 80 -- Must be this far away to exit hiding
	self.hidingMovementTokensRequired = 3 -- Must accumulate this many tokens to exit
	self.hidingTokensAccumulated = 0

	-- Animation tracking
	self.isMoving = false
	self.lastX = x
	self.lastY = y

	-- Collision groups for BUMP
	self.collisionGroup = "crewMember"
end

-- Add movement frames (raw frames, capped at 90)
function CrewMember:addMovementFrames(frames)
	self.movementFrames = math.min(self.movementFrames + frames, self.maxMovementFrames)
end

-- Add movement tokens (1 token = 30 frames)
function CrewMember:addMovementTokens(tokens)
	local frames = tokens * 30
	self.movementFrames = math.min(self.movementFrames + frames, self.maxMovementFrames)
end

-- Blind the crewmember for a duration
function CrewMember:blind(frames)
	self.isBlinded = true
	self.blindFrames = frames
	self.currentAnimation = self.animations.idle
end

-- Permanently stun the crewmember
function CrewMember:stunInfinite()
	self.stunInfiniteActive = true
	self.isStunned = true
	self.currentAnimation = self.animations.stun
end

-- Mark crewmember as captured
function CrewMember:taken()
	if not PlayerData.CrewMemberData.idNumbers[self.id] then
		PlayerData.CrewMemberData.idNumbers[self.id] = true
		PlayerData.CrewMemberData.amountTaken = PlayerData.CrewMemberData.amountTaken + 1
		printDebug("🎯 CrewMember " .. self.id .. " captured! Total: " .. PlayerData.CrewMemberData.amountTaken)
	end

	-- Remove from world and scene
	if self.world then
		self.world:remove(self)
	end

	self.isRemoved = true
end

-- Escape mode: flee from player
function CrewMember:escape(dt)
	if self.player then
		-- Calculate direction away from player
		local dx = self.x - self.player.x
		local dy = self.y - self.player.y
		local distSq = dx * dx + dy * dy

		-- Only escape if player is within view range
		if distSq > 0 and distSq < (self.viewRange * self.viewRange) then
			local dist = math.sqrt(distSq)
			dx = dx / dist
			dy = dy / dist

			-- Move away from player
			local newX = self.x + dx * self.moveSpeed * dt
			local newY = self.y + dy * self.moveSpeed * dt

			self:moveCollision(newX, newY)
			self.isMoving = true
		else
			self.isMoving = false
		end
	end
end

-- Handle collision and bouncing
function CrewMember:moveCollision(newX, newY)
	-- Calculate collision box position
	local newCollisionX = newX + self.collisionOffsetX
	local newCollisionY = newY + self.collisionOffsetY

	-- Move with BUMP collision detection
	local actualX, actualY, cols, length = self.world:move(self, newCollisionX, newCollisionY)

	-- Convert back to sprite position
	self.x = actualX - self.collisionOffsetX
	self.y = actualY - self.collisionOffsetY

	-- Handle bouncing (only once per move, not for each collision)
	local shouldBounce = false
	local bounceNormal = nil

	if length > 0 then
		for index = 1, length do
			local collision = cols[index]
			local collideObject = collision.other
			local collideType = collideObject.class and collideObject.class.name or "unknown"

			-- Bounce on walls, props, and other enemies (take first solid collision)
			if (collideType == "Box" or collideType == "PropItem" or collideType == "Enemy" or collideType == "CrewMember") and not shouldBounce then
				shouldBounce = true
				bounceNormal = collision.normal
			end
		end
	end

	-- Process bounce if detected
	if shouldBounce and bounceNormal then
		self.recentBounceCount = self.recentBounceCount + 1
		self.bounceCountResetTimer = self.bounceResetDuration

		printDebug("🔄 CrewMember " .. self.id .. " bounce count: " .. self.recentBounceCount .. "/" .. self.bouncesRequiredToHide)

		-- Enter bounce state
		self.isBouncing = true
		self.bounceTimer = self.bounceDuration

		-- Bounce in opposite direction of the normal (away from obstacle)
		-- Move away from obstacle (opposite direction of normal)
		self.x = self.x + (-bounceNormal.x * 8)
		self.y = self.y + (-bounceNormal.y * 8)

		-- Update position in world with proper dimensions
		local collisionX = self.x + self.collisionOffsetX
		local collisionY = self.y + self.collisionOffsetY
		self.world:update(self, collisionX, collisionY, self.width, self.height)

		-- Check if should enter hiding (after 3 bounces)
		if self.recentBounceCount >= self.bouncesRequiredToHide then
			printDebug("🙈 CrewMember " .. self.id .. " entering hiding after " .. self.recentBounceCount .. " bounces")
			self:enterHiding()
		end
	end
end

-- Enter hiding state
function CrewMember:enterHiding()
	if not self.isHiding then
		self.isHiding = true
		self.hidingTokensAccumulated = 0
		self.currentAnimation = self.animations.hide

		-- Remove from BUMP world to make invisible
		if self.world and self.world:hasItem(self) then
			self.world:remove(self)
		end

		printDebug("🙈 CrewMember " .. self.id .. " entered hiding state")
	end
end

-- Exit hiding state
function CrewMember:exitHiding()
	if self.isHiding then
		self.isHiding = false
		self.recentBounceCount = 0
		self.currentAnimation = self.animations.idle

		-- Re-add to BUMP world with proper dimensions
		if self.world and not self.world:hasItem(self) then
			local collisionX = self.x + self.collisionOffsetX
			local collisionY = self.y + self.collisionOffsetY
			self.world:add(self, collisionX, collisionY, self.width, self.height)
		end

		printDebug("🚶 CrewMember " .. self.id .. " exited hiding state")
	end
end

-- Update collision position in BUMP world
function CrewMember:updateCollisionPosition()
	if self.world then
		local collisionX = self.x + self.collisionOffsetX
		local collisionY = self.y + self.collisionOffsetY
		self.world:update(self, collisionX, collisionY, self.width, self.height)
	end
end

-- Collision filter for BUMP
function CrewMember:filter(other)
	local otherType = other.class and other.class.name or "unknown"

	-- Different behavior when hiding
	if self.isHiding then
		return 'cross' -- No collision when hiding
	end

	if otherType == "Items" or otherType == "Trigger" then
		return 'cross'
	elseif otherType == "Box" or otherType == "PropItem" or otherType == "Enemy" or otherType == "CrewMember" then
		return 'slide'
	elseif otherType == "Minifier" then
		return 'cross' -- Pass through minifier
	elseif otherType == "Player" then
		return 'cross'
	else
		return 'slide'
	end
end

function CrewMember:update(dt)
	-- Skip if removed
	if self.isRemoved then
		return
	end

	-- Handle bounce state (decrement timer)
	if self.isBouncing then
		self.bounceTimer = self.bounceTimer - 1
		if self.bounceTimer <= 0 then
			self.isBouncing = false
		end
	end

	-- Reset bounce count if timer expires
	if self.bounceCountResetTimer > 0 then
		self.bounceCountResetTimer = self.bounceCountResetTimer - 1
	else
		self.recentBounceCount = 0
	end

	-- Handle different states
	if self.isBlinded then
		self.blindFrames = self.blindFrames - 1
		if self.blindFrames <= 0 then
			self.isBlinded = false
		end
		-- Don't move while blinded
		self.isMoving = false
	elseif self.stunInfiniteActive then
		-- Permanently stunned, don't move
		self.isMoving = false
	elseif self.isHiding then
		-- Handle hiding state
		-- Check if can exit hiding
		if self.player then
			local dx = self.x - self.player.x
			local dy = self.y - self.player.y
			local dist = math.sqrt(dx * dx + dy * dy)

			if dist > self.hidingVisionRange and self.hidingTokensAccumulated >= self.hidingMovementTokensRequired then
				self:exitHiding()
			end
		end
		self.isMoving = false
	else
		-- Normal AI behavior
		if self.movementFrames > 0 and self.player then
			self:escape(dt)
			self.movementFrames = self.movementFrames - 1
		else
			self.isMoving = false
		end
	end

	-- Track hiding tokens if hiding
	if self.isHiding and self.movementFrames > 0 then
		-- Accumulate tokens while in hiding (player is moving)
		if not self.lastWasMoving and self.movementFrames > 0 then
			self.hidingTokensAccumulated = self.hidingTokensAccumulated + 1
		end
	end
	self.lastWasMoving = self.movementFrames > 0

	-- Update animation based on state
	if self.isHiding then
		if self.currentAnimation ~= self.animations.hide then
			self.currentAnimation = self.animations.hide
		end
	elseif self.stunInfiniteActive then
		if self.currentAnimation ~= self.animations.stun then
			self.currentAnimation = self.animations.stun
		end
	elseif self.isBlinded then
		if self.currentAnimation ~= self.animations.idle then
			self.currentAnimation = self.animations.idle
		end
	elseif self.isMoving then
		if self.currentAnimation ~= self.animations.walk then
			self.currentAnimation = self.animations.walk
		end
	else
		if self.currentAnimation ~= self.animations.idle then
			self.currentAnimation = self.animations.idle
		end
	end

	-- Update animation frames
	if self.currentAnimation then
		self.currentAnimation:update(dt)
	end

	self.lastX = self.x
	self.lastY = self.y
end

function CrewMember:draw()
	if self.isRemoved then
		return
	end

	-- Draw sprite from center (like Player)
	if self.spritesheet and self.currentAnimation then
		self.currentAnimation:draw(
			self.spritesheet,
			self.x,
			self.y,
			0, -- rotation
			1, -- scaleX
			1, -- scaleY
			self.spriteWidth / 2, -- ox: origin X (center)
			self.spriteHeight / 2  -- oy: origin Y (center)
		)
	else
		-- Fallback placeholder (drawn from center)
		love.graphics.setColor(0.3, 0.7, 0.5, 0.7)
		love.graphics.rectangle("fill", self.x - self.spriteWidth/2, self.y - self.spriteHeight/2, self.spriteWidth, self.spriteHeight)
		love.graphics.setColor(1, 1, 1, 1)
	end

	-- Debug: Draw collision box
	-- love.graphics.setColor(0, 1, 0, 0.3)
	-- love.graphics.rectangle("fill", self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height)
	-- love.graphics.setColor(1, 1, 1, 1)
end

return CrewMember
