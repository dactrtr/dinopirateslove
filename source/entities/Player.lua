-- entities/Player.lua
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local Player = Class('Player')

function Player:initialize(x, y, world)
	self.x = x
	self.y = y
	self.width = 48
	self.height = 48
	self.speed = 100
	
	-- BUMP physics
	self.world = world
	world:add(self, self.x, self.y, self.width, self.height)
	
	-- Anim8 animations
	-- Anim8 animations
	self.spritesheet = love.graphics.newImage("assets/player.png")
	local grid = anim8.newGrid(48, 48, self.spritesheet:getWidth(), self.spritesheet:getHeight())
	
	self.animations = {
		idle = anim8.newAnimation(grid('1-4', 1), 0.4),              -- frameDuration = 24 (0.4s a 60fps)
		right = anim8.newAnimation(grid('5-7', 1), 0.2),             -- frameDuration = 12 (0.2s)
		left = anim8.newAnimation(grid('8-10', 1), 0.2),
		down = anim8.newAnimation(grid('11-13', 1), 0.2),
		up = anim8.newAnimation(grid('14-16', 1), 0.2),
		deadBrocolli = anim8.newAnimation(grid('17-18', 1), 0.2),
		lampIdle = anim8.newAnimation(grid('19-22', 1), 0.4),
		lampRight = anim8.newAnimation(grid('23-25', 1), 0.2),
		lampLeft = anim8.newAnimation(grid('26-28', 1), 0.2),
		lampDown = anim8.newAnimation(grid('29-31', 1), 0.2),
		charge = anim8.newAnimation(grid('32-35', 1), 0.2)
	}
	
	-- Elegir animación inicial según estado
	if PlayerData.hasLamp and PlayerData.isInDarkness then
		self.currentAnimation = self.animations.lampIdle
	else
		self.currentAnimation = self.animations.idle
	end
end

function Player:update(dt)
	local dx, dy = 0, 0
	
	-- Movement input
	if love.keyboard.isDown("w") then dy = -self.speed * dt end
	if love.keyboard.isDown("s") then dy = self.speed * dt end
	if love.keyboard.isDown("a") then dx = -self.speed * dt end
	if love.keyboard.isDown("d") then dx = self.speed * dt end
	
	-- Update animation
	if dx > 0 then
		self.currentAnimation = PlayerData.hasLamp and self.animations.lampRight or self.animations.right
	elseif dx < 0 then
		self.currentAnimation = PlayerData.hasLamp and self.animations.lampLeft or self.animations.left
	elseif dy > 0 then
		self.currentAnimation = PlayerData.hasLamp and self.animations.lampDown or self.animations.down
	elseif dy < 0 then
		self.currentAnimation = self.animations.up
	else
		self.currentAnimation = PlayerData.hasLamp and self.animations.lampIdle or self.animations.idle
	end
	
	-- BUMP collision
	local actualX, actualY, cols, len = self.world:move(self, self.x + dx, self.y + dy)
	self.x, self.y = actualX, actualY
	
	-- Update animation
	self.currentAnimation:update(dt)
end

function Player:draw()
	self.currentAnimation:draw(self.spritesheet, self.x, self.y)
end

return Player