-- entities/player/init.lua
-- Main Player class using modular components
local Class = require 'libraries/middleclass'

-- Load player modules
local playerCollisions = require 'entities.player.collisions'
local playerMovements = require 'entities.player.movements'
local playerAnimations = require 'entities.player.animations'
local DialogScreen = require 'entities.UI.dialog.dialogScreen'


local Player = Class('Player')

function Player:initialize(x, y, world)
	self.x = x
	self.y = y
	
	-- Sprite dimensions (for drawing)
	self.spriteWidth = 48
	self.spriteHeight = 48
	
	-- Collision box dimensions (can be different from sprite)
	if PlayerData.isTiny then
		-- Tiny Box: 14x14
		self.width = 14
		self.height = 14
		-- Center horizontally: -7 offset
		-- Align to character (character is centered 48px sprite, bottom is at y+24)
		-- offsetY = 0 puts the 14px collider at [0, 14] relative to center
		self.collisionOffsetX = -(self.width / 2)
		self.collisionOffsetY = 0
	else
		-- Normal Box: 30x24
		self.width = 30
		self.height = 24
		
		-- Collision box offset from sprite position
		self.collisionOffsetX = -(self.width / 2)  -- Center the collision box horizontally
		self.collisionOffsetY = 0                 -- Align to bottom
	end
	
	-- Use speed from PlayerData (convert from Playdate speed to Love2D pixels/second)
	-- Playdate speed 1.7 ~= 100 pixels/second in Love2D
	self.speed = (PlayerData.speed or 1.7) * 60 -- Convert to pixels per second
	
	-- BUMP physics - use collision dimensions and offset position
	self.world = world
	world:add(self, self.x + self.collisionOffsetX, self.y + self.collisionOffsetY, self.width, self.height)
	
	-- Load animations
	self.spritesheet = love.graphics.newImage("assets/images/player/player-table-48-48.png")
	self.animations = playerAnimations.load(self.spritesheet)
	self.currentAnimation = playerAnimations.getInitialAnimation(self.animations)
	
	-- Movement tracking for turn-based enemy AI
	self.isMoving = false
	self.hasMoved = false -- Flag to trigger enemy movement
	
	-- Initialize dialog system
	self.dialogUI = DialogScreen()
end


-- Collision methods (delegate to collisions module)
function Player:getCollisionRect()
	return playerCollisions.getCollisionRect(self)
end

function Player:getSpriteRect()
	return playerCollisions.getSpriteRect(self)
end

function Player:updateCollisionPosition()
	playerCollisions.updateCollisionPosition(self)
end

function Player:collideRect(x, y, w, h, filter)
	return playerCollisions.collideRect(self, x, y, w, h, filter)
end

function Player:checkCollisions()
	return playerCollisions.checkCollisions(self)
end

function Player:checkCollisionsAt(spriteX, spriteY)
	return playerCollisions.checkCollisionsAt(self, spriteX, spriteY)
end

function Player:checkCollisionsInDirection(direction, distance)
	return playerCollisions.checkCollisionsInDirection(self, direction, distance)
end

function Player:getObjectsInRadius(radius)
	return playerCollisions.getObjectsInRadius(self, radius)
end

-- Update function
function Player:update(dt)
	-- Handle input and get movement delta
	local dx, dy = playerMovements.handleInput(self, dt)

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
	
	-- Update animation based on movement
	playerAnimations.updateAnimation(self, dx, dy)
	
	-- Move player with collision detection
	local cols, len = playerMovements.move(self, dx, dy, function(item, other)
		return playerCollisions.response(self, other)
	end)
	
	-- Handle collisions
	for i = 1, len do
		local col = cols[i]
		local other = col.other
		
		-- Check for Door collision
		if other.class and other.class.name == "Door" then
			-- Use DoorHandler to handle transition
			local DoorHandler = require 'DoorHandler'
			DoorHandler.handleDoorCollision(other, self)
		end
	end
	
	-- Update movement state for turn-based AI
	playerMovements.updateMovementState(self, dx, dy)

	-- Update animation
	self.currentAnimation:update(dt)

	-- Update dialog UI
	if self.dialogUI then
		self.dialogUI:update(dt)
	end
	
	-- Check for prop interactions (e.g. Minifier)
	self:checkPropInteractions()
end


-- Draw function
function Player:draw(debug)
	-- Draw the sprite at sprite position, using center as origin
	-- ox, oy parameters set the origin to the center of the sprite
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
	
	-- Draw collision box for debugging (violet color)
	if debug then
		-- Get the actual collision box from BUMP world to ensure accuracy
		local bumpX, bumpY, bumpW, bumpH = self.world:getRect(self)
		
		love.graphics.setColor(0.58, 0, 0.82, 0.5) -- Violet with transparency
		love.graphics.rectangle("fill", bumpX, bumpY, bumpW, bumpH)
		
		-- Also draw the sprite bounds in a different color for reference
		love.graphics.setColor(1, 1, 0, 0.3) -- Yellow with transparency
		love.graphics.rectangle("line", self.x - self.spriteWidth/2, self.y - self.spriteHeight/2, self.spriteWidth, self.spriteHeight)
		
		love.graphics.setColor(1, 1, 1, 1) -- Reset color
	end
end


-- Dialog navigation
function Player:displayDialog()
	if self.dialogUI and self.dialogUI.active then
		self.dialogUI:nextDialog()
	end
end

function Player:checkPropInteractions()
	-- Reset state frame by frame
	PlayerData.readyToShrink = false
	
	-- Check for overlaps with props using centralized logic
	local collisions, count = self:checkCollisions()
	
	for i = 1, count do
		local col = collisions[i]
		local other = col.object
		
		-- Trigger collision response for side effects (like setting readyToShrink)
		playerCollisions.response(self, other)
	end
end


function Player:handleCrankInput(delta)
	-- Only allow size change if on a minifier
	if not PlayerData.readyToShrink then
		return
	end

	-- Threshold for activation (accumulate delta if needed, but for wheel usually 1 click is enough)
	if math.abs(delta) > 0 then
		self:toggleSize()
	end
end

function Player:toggleSize()
	-- Toggle state
	PlayerData.isTiny = not PlayerData.isTiny
	printDebug("🤏 Player size toggled. isTiny: " .. tostring(PlayerData.isTiny))
	
	-- Update dimensions based on state
	if PlayerData.isTiny then
		-- Tiny Box: 14x14
		self.width = 14
		self.height = 14
		-- Center horizontally: -7 offset
		-- Align to character (character is centered 48px sprite, bottom is at y+24)
		-- offsetY = 0 puts the 14px collider at [0, 14] relative to center
		self.collisionOffsetX = -(self.width / 2)
		self.collisionOffsetY = 0 
		printDebug("  📦 Tiny collision box: width=" .. self.width .. ", height=" .. self.height .. ", offsetX=" .. self.collisionOffsetX .. ", offsetY=" .. self.collisionOffsetY)
	else
		-- Normal Box: 30x24
		self.width = 30
		self.height = 24
		self.collisionOffsetX = -(self.width / 2)
		self.collisionOffsetY = 0  -- Align to bottom: 24 - 24 = 0
		printDebug("  📦 Normal collision box: width=" .. self.width .. ", height=" .. self.height .. ", offsetX=" .. self.collisionOffsetX .. ", offsetY=" .. self.collisionOffsetY)
	end
	
	-- Update BUMP world with new dimensions
	self:updateCollisionPosition()
	
	-- Verify BUMP world update
	local bumpX, bumpY, bumpW, bumpH = self.world:getRect(self)
	printDebug("  🌍 BUMP world collision: x=" .. bumpX .. ", y=" .. bumpY .. ", w=" .. bumpW .. ", h=" .. bumpH)
	printDebug("  🎮 Player sprite position: x=" .. self.x .. ", y=" .. self.y)
	
	-- Update animation state immediately
	playerAnimations.updateAnimation(self, 0, 0)
end

function Player:moveTo(x, y)
	self.x = x
	self.y = y
	if self.world:hasItem(self) then
		self:updateCollisionPosition() 
	end
end

return Player
