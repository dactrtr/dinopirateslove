-- entities/Player.lua
local Class = require 'libraries/middleclass'
local anim8 = require 'libraries/anim8'

local Player = Class('Player')

function Player:initialize(x, y, world)
	self.x = x
	self.y = y
	
	-- Sprite dimensions (for drawing)
	self.spriteWidth = 48
	self.spriteHeight = 48
	
	-- Collision box dimensions (can be different from sprite)
	self.width = 32  -- Smaller collision box
	self.height = 40
	
	-- Collision box offset from sprite position
	self.collisionOffsetX = 8  -- Center the collision box horizontally
	self.collisionOffsetY = 8  -- Offset collision box vertically
	
	self.speed = 100
	
	-- BUMP physics - use collision dimensions and offset position
	self.world = world
	world:add(self, self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height)
	
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

-- Get the collision box position and dimensions
function Player:getCollisionRect()
	return self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height
end

-- Get the sprite position and dimensions (for drawing)
function Player:getSpriteRect()
	return self.x, self.y, self.spriteWidth, self.spriteHeight
end

-- Update collision box position in BUMP world
function Player:updateCollisionPosition()
	local collisionX = self.x + self.collisionOffsetX
	local collisionY = self.y + self.collisionOffsetY
	self.world:update(self, collisionX, collisionY)
end
-- Returns a table of colliding objects within the specified rectangle
-- @param x, y: top-left corner of the rectangle
-- @param w, h: width and height of the rectangle
-- @param filter: optional collision filter function
function Player:collideRect(x, y, w, h, filter)
	local items, len = self.world:queryRect(x, y, w, h, filter)
	
	-- Format results similar to Playdate SDK
	local collisions = {}
	for i = 1, len do
		local item = items[i]
		if item ~= self then -- Don't include self in collisions
			local itemX, itemY, itemW, itemH = self.world:getRect(item)
			table.insert(collisions, {
				object = item,
				x = itemX,
				y = itemY,
				width = itemW,
				height = itemH
			})
		end
	end
	
	return collisions, #collisions
end

-- Check for collisions at the player's current collision box position
function Player:checkCollisions()
	local collisionX, collisionY = self.x + self.collisionOffsetX, self.y + self.collisionOffsetY
	return self:collideRect(collisionX, collisionY, self.width, self.height)
end

-- Check for collisions at a specific sprite position (converts to collision box position)
function Player:checkCollisionsAt(spriteX, spriteY)
	local collisionX = spriteX + self.collisionOffsetX
	local collisionY = spriteY + self.collisionOffsetY
	return self:collideRect(collisionX, collisionY, self.width, self.height)
end

-- Check for collisions in a specific direction from current position
function Player:checkCollisionsInDirection(direction, distance)
	local checkX, checkY = self.x, self.y
	
	if direction == "up" then
		checkY = checkY - distance
	elseif direction == "down" then
		checkY = checkY + distance
	elseif direction == "left" then
		checkX = checkX - distance
	elseif direction == "right" then
		checkX = checkX + distance
	end
	
	return self:checkCollisionsAt(checkX, checkY)
end

-- Get all objects within a radius of the player (uses collision box center)
function Player:getObjectsInRadius(radius)
	local centerX = self.x + self.collisionOffsetX + self.width / 2
	local centerY = self.y + self.collisionOffsetY + self.height / 2
	
	-- Create a square area around the player
	local x = centerX - radius
	local y = centerY - radius
	local w = radius * 2
	local h = radius * 2
	
	local collisions, count = self:collideRect(x, y, w, h)
	
	-- Filter by actual distance for circular radius
	local filtered = {}
	for i = 1, count do
		local collision = collisions[i]
		local objCenterX = collision.x + collision.width / 2
		local objCenterY = collision.y + collision.height / 2
		
		local distance = math.sqrt((centerX - objCenterX)^2 + (centerY - objCenterY)^2)
		if distance <= radius then
			collision.distance = distance
			table.insert(filtered, collision)
		end
	end
	
	return filtered, #filtered
end

function Player:update(dt)
	local dx, dy = 0, 0

	-- Keyboard movement (WASD and arrow keys)
	if love.keyboard.isDown("w") or love.keyboard.isDown("up") then dy = -self.speed * dt end
	if love.keyboard.isDown("s") or love.keyboard.isDown("down") then dy = self.speed * dt end
	if love.keyboard.isDown("a") or love.keyboard.isDown("left") then dx = -self.speed * dt end
	if love.keyboard.isDown("d") or love.keyboard.isDown("right") then dx = self.speed * dt end

	-- Gamepad movement (left stick)
	local joysticks = love.joystick.getJoysticks()
	if #joysticks > 0 then
		local joy = joysticks[1]
		local axisX = joy:getAxis(1) -- left stick X
		local axisY = joy:getAxis(2) -- left stick Y

		-- Apply deadzone
		local deadzone = 0.2
		if math.abs(axisX) > deadzone then
			dx = dx + axisX * self.speed * dt
		end
		if math.abs(axisY) > deadzone then
			dy = dy + axisY * self.speed * dt
		end
	end

	-- Example usage: Check for collisions before moving
	if dx ~= 0 or dy ~= 0 then
		local futureCollisions, collisionCount = self:checkCollisionsAt(self.x + dx, self.y + dy)
		
		-- You can add custom logic here based on what you collide with
		-- For example:
		-- for i = 1, collisionCount do
		--     local collision = futureCollisions[i]
		--     if collision.object.type == "enemy" then
		--         -- Handle enemy collision
		--     elseif collision.object.type == "powerup" then
		--         -- Handle powerup collision
		--     end
		-- end
	end

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

	-- BUMP collision - move collision box and get sprite position back
	local newCollisionX = self.x + self.collisionOffsetX + dx
	local newCollisionY = self.y + self.collisionOffsetY + dy
	local actualCollisionX, actualCollisionY, cols, len = self.world:move(self, newCollisionX, newCollisionY)
	
	-- Convert collision box position back to sprite position
	self.x = actualCollisionX - self.collisionOffsetX
	self.y = actualCollisionY - self.collisionOffsetY

	-- Update animation
	self.currentAnimation:update(dt)
end

function Player:draw()
	-- Draw the sprite at sprite position
	self.currentAnimation:draw(self.spritesheet, self.x, self.y)
	
	-- Optional: Draw collision box for debugging (remove in production)
	-- love.graphics.setColor(1, 0, 0, 0.3) -- Red with transparency
	-- love.graphics.rectangle("fill", self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height)
	-- love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

return Player