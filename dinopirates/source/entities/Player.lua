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
	self.spritesheet = love.graphics.newImage("assets/player.png")
	local grid = anim8.newGrid(48, 48, self.spritesheet:getWidth(), self.spritesheet:getHeight())
	
	self.animations = {
		idle = anim8.newAnimation(grid('1-4', 1), 0.1),
		walk = anim8.newAnimation(grid('1-8', 1), 0.1)
	}
	
	self.currentAnimation = self.animations.idle
end

function Player:update(dt)
	local dx, dy = 0, 0
	
	-- Movement input
	if love.keyboard.isDown("w") then dy = -self.speed * dt end
	if love.keyboard.isDown("s") then dy = self.speed * dt end
	if love.keyboard.isDown("a") then dx = -self.speed * dt end
	if love.keyboard.isDown("d") then dx = self.speed * dt end
	
	-- Update animation
	if dx ~= 0 or dy ~= 0 then
		self.currentAnimation = self.animations.walk
	else
		self.currentAnimation = self.animations.idle
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