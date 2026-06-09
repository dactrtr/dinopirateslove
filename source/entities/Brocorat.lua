-- entities/Brocorat.lua
-- Ported from Playdate to Love2D
local Class = require 'libraries/middleclass'
local Enemy = require 'entities.Enemy'
local anim8 = require 'libraries/anim8'

local Brocorat = Class('Brocorat', Enemy)

function Brocorat:initialize(x, y, moveSpeed, zIndex, player, id, world)
	-- Call parent constructor with world parameter
	Enemy.initialize(self, x, y, world, "Brocorat")
	
	-- Brocorat specific properties
	self.type = "Enemy"
	self.id = id or math.random(1000, 9999)
	
	self.powerLevel = (PlayerData.EnemiesData and PlayerData.EnemiesData.powerLevel or 0) + 
	                  (PlayerData.sanityCounter or 0)
	
	-- Use speed from EnemyData table (fallback to parameter or default)
	local baseSpeed = 40
	self.moveSpeed = moveSpeed or baseSpeed
	self.initialSpeed = self.moveSpeed
	self.stunProc = self.moveSpeed * 20 -- if speed is below 0.5 the enemy doesn't move
	self.damage   = (Config and Config.Enemy and Config.Enemy.damage) or 1
	self.player = player
	self.Zindex = zIndex or ZIndex.enemy
	self.sightRadius = ((PlayerData.EnemiesData and PlayerData.EnemiesData.sightRadius) or 50) +
	                   self.powerLevel * 3

	-- Turn-based token budget (initialized explicitly; also set in Enemy base but repeated here
	-- to survive the sync block below which re-uses the Enemy.initialize values)
	self.movementFrames    = 0
	self.maxMovementFrames = 90

	-- Performance: frame counter for throttling AI (runs every 3 frames)
	self.updateFrameCounter = math.random(0, 2)
	
	-- Load spritesheet and setup animations
	self.spritesheet = love.graphics.newImage('assets/images/enemies/brocorat-table-32-32.png')
	local grid = anim8.newGrid(32, 32, self.spritesheet:getWidth(), self.spritesheet:getHeight())
	
	-- Animation states
	self.animations = {
		idle = anim8.newAnimation(grid('4-4', 1), 6/60),
		walk = anim8.newAnimation(grid('1-8', 1), 6/60), -- Removed 'pauseAtEnd' to allow looping
		empty = anim8.newAnimation(grid('15-15', 1), 6/60),
		shine = anim8.newAnimation(grid('9-14', 1), 6/60),
		eaten = anim8.newAnimation(grid('16-16', 1), 6/60)
	}
	
	self.currentAnimation = self.animations.idle
	
	-- Set collision properties
	self.spriteWidth = 32
	self.spriteHeight = 32
	self.width = 32
	self.height = 32
	self.collisionOffsetX = 0
	self.collisionOffsetY = 0
	
	-- Enemy:initialize() added us to bump with its default (offset 2, size 28x28).
	-- Sync now that we've overridden offset and size.
	if self.world and self.world:hasItem(self) then
		self.world:update(self,
			self.x + self.collisionOffsetX,
			self.y + self.collisionOffsetY,
			self.width,
			self.height)
	end
	
	-- Movement tracking for animation
	self.isMoving = false
	self.lastX = x
	self.lastY = y
end

function Brocorat:search(player, dt)
	if self.stunProc > 1 then -- stun idea
		-- Tiny players are harder to see: halve the sight radius
		local effectiveSight = self.sightRadius
		if PlayerData.isTiny then
			effectiveSight = effectiveSight * 0.5
		end

		-- Check if player is within sight radius (AABB square check)
		if (player.x >= self.x - effectiveSight) and
		   (player.x <= self.x + effectiveSight) and
		   (player.y >= self.y - effectiveSight) and
		   (player.y <= self.y + effectiveSight) then
			-- Mark as moving, animation will be set in update()
			if not self._chasing then
				enemyLog("id=" .. tostring(self.id) .. " sees player → chasing")
				self._chasing = true
			end
			self.isMoving = true
			self:blindSearch(player, dt)
		else
			-- Player out of range, set idle
			if self._chasing then
				enemyLog("id=" .. tostring(self.id) .. " lost player → idle")
				self._chasing = false
			end
			self.isMoving = false
		end
	else
		-- Stunned, set idle
		self.isMoving = false
	end
end

function Brocorat:empty()
	self.currentAnimation = self.animations.empty
end

function Brocorat:onHitByProjectile(projectile)
	printDebug("Brocorat blinded for 60 frames!")
	self:blind(60)

	-- Apply knockback away from the projectile's travel direction
	if projectile then
		local dx, dy = 0, 0
		if     projectile.direction == "right" then dx =  1
		elseif projectile.direction == "left"  then dx = -1
		elseif projectile.direction == "down"  then dy =  1
		elseif projectile.direction == "up"    then dy = -1
		end
		local kbDist = (Config and Config.Enemy and Config.Enemy.knockbackDistance) or 16
		self:knockback(dx, dy, kbDist)
	end
end

function Brocorat:update(dt)
	-- Advance throttle counter every frame (AI runs every 3 frames)
	self.updateFrameCounter = (self.updateFrameCounter + 1) % 3

	-- [1] Blinded state: countdown, no AI or movement
	if self.isBlinded then
		self.blindFrames = self.blindFrames - 1
		if self.blindFrames <= 0 then
			self.isBlinded = false
		end
		if self.animations and self.currentAnimation ~= self.animations.idle then
			self.currentAnimation = self.animations.idle
		end
		if self.currentAnimation then self.currentAnimation:update(dt) end
		-- Early return suppresses AI and sonar while blinded (intentional).
		return
	end

	-- Store previous position to detect actual movement
	local prevX, prevY = self.x, self.y

	-- [2] Movement frame budget (turn-based token system)
	if self.movementFrames > 0 then
		self.movementFrames = self.movementFrames - 1
		-- AI throttle: only run search() every 3 frames
		if self.updateFrameCounter == 0 then
			self:updateMoveSpeed()
			self:search(self.player, dt)
		end
	else
		-- No frames available — go idle
		self.isMoving = false
	end

	-- Check if enemy actually moved this frame
	local didMove = (math.abs(self.x - prevX) > 0.1 or math.abs(self.y - prevY) > 0.1)

	-- If shine was set by sonar() on a previous frame, don't overwrite it with walk/idle.
	local isShining = self.animations and self.currentAnimation == self.animations.shine
	if not isShining then
		if self.isMoving and didMove then
			if self.currentAnimation ~= self.animations.walk then
				self.currentAnimation = self.animations.walk
			end
		else
			if self.currentAnimation ~= self.animations.idle then
				self.currentAnimation = self.animations.idle
			end
			self.isMoving = false
		end
	end

	self:sonar()

	-- Update animation AFTER selecting the correct one
	if self.currentAnimation then
		self.currentAnimation:update(dt)
	end
end

function Brocorat:draw()
	-- Draw sprite
	if self.spritesheet and self.currentAnimation then
		self.currentAnimation:draw(self.spritesheet, self.x, self.y)
	else
		-- Fallback placeholder
		love.graphics.setColor(0.8, 0.3, 0.1, 0.7)
		love.graphics.rectangle("fill", self.x, self.y, self.spriteWidth, self.spriteHeight)
		love.graphics.setColor(1, 1, 1, 1)
	end
	
	-- Debug: Draw collision box and sight radius
	-- love.graphics.setColor(0, 1, 0, 0.3)
	-- love.graphics.rectangle("fill", self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height)
	-- love.graphics.setColor(1, 1, 0, 0.2)
	-- love.graphics.circle("line", self.x + self.width/2, self.y + self.height/2, self.sightRadius)
	-- love.graphics.setColor(1, 1, 1, 1)
end

return Brocorat
