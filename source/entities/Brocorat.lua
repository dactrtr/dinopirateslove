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
	self.player = player
	self.Zindex = zIndex or ZIndex.enemy
	self.sightRadius = ((PlayerData.EnemiesData and PlayerData.EnemiesData.sightRadius) or 50) + 
	                   self.powerLevel * 3
	
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
		-- Check if player is within sight radius
		if (player.x >= self.x - self.sightRadius) and 
		   (player.x <= self.x + self.sightRadius) and 
		   (player.y >= self.y - self.sightRadius) and 
		   (player.y <= self.y + self.sightRadius) then
			-- Mark as moving, animation will be set in update()
			self.isMoving = true
			self:blindSearch(player, dt)
		else
			-- Player out of range, set idle
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

function Brocorat:update(dt)
	-- Store previous position to detect movement
	local prevX, prevY = self.x, self.y
	
	-- Turn-based AI: move when player is moving OR has just moved
	if self.player and (self.player.isMoving or self.player.hasMoved) then
		self:search(self.player, dt)
	else
		-- Player not moving, enemy should be idle
		self.isMoving = false
	end
	
	-- Check if enemy actually moved
	local didMove = (math.abs(self.x - prevX) > 0.1 or math.abs(self.y - prevY) > 0.1)
	
	-- Update animation based on movement state
	if self.isMoving and didMove then
		-- Enemy is moving, use walk animation
		if self.currentAnimation ~= self.animations.walk then
			self.currentAnimation = self.animations.walk
		end
	else
		-- Enemy is not moving, use idle animation
		if self.currentAnimation ~= self.animations.idle then
			self.currentAnimation = self.animations.idle
		end
		self.isMoving = false
	end
	
	-- Update animation AFTER setting the correct one
	if self.currentAnimation then
		self.currentAnimation:update(dt)
	end
	
	-- Sonar effect (commented out)
	-- self:sonar()
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
