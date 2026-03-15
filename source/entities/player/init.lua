-- entities/player/init.lua
-- Main Player class using modular components
local Class = require 'libraries/middleclass'
local utilities = require 'utilities'

-- Load player modules
local playerCollisions = require 'entities.player.collisions'
local playerMovements = require 'entities.player.movements'
local playerAnimations = require 'entities.player.animations'
local playerPlunge = require 'entities.player.plunge'
local DialogScreen = require 'entities.UI.dialog.dialogScreen'


local Player = Class('Player')

function Player:initialize(x, y, world)
	self.x = x
	self.y = y
	
	-- Sprite dimensions (for drawing)
	self.spriteWidth = 48
	self.spriteHeight = 48
	
	-- Set initial dimensions based on PlayerData
	self:syncDimensions(true) -- Pass true to skip BUMP update during init (manual add follows)
	
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

	-- Outline effect
	local moonshine = require 'libraries/moonshine'
	self.outlineEffect = moonshine(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, moonshine.effects.outline)
	
	-- Apply settings from global moonshinSettings (defined in main.lua)
	if moonshinSettings and moonshinSettings.playerOutline then
		self.outlineEffect.outline.color = moonshinSettings.playerOutline.color
		self.outlineEffect.outline.thickness = moonshinSettings.playerOutline.thickness
	else
		self.outlineEffect.outline.color = {1, 1, 1, 1}
		self.outlineEffect.outline.thickness = 1
	end
	
	-- Movement tracking for turn-based enemy AI
	self.isMoving = false
	self.hasMoved = false -- Flag to trigger enemy movement
	
	-- Plungerang state
	self.isPlunging = false
	self.projectile = nil
	
	-- Initialize dialog system
	self.dialogUI = DialogScreen()

	-- Dash state
	local dashCfg = Config and Config.Dash or {}
	self.isDashing            = false
	self.dashDir              = "right"
	self.dashDistanceTraveled = 0
	self.dashSpeed            = dashCfg.speed          or 6
	self.dashMaxDistance      = dashCfg.totalDistance  or 56
	self.dashBounceDistance   = dashCfg.bounceDistance or 16
	-- Sanity ticking is handled by SanitySystem.update(dt) in gameScene — no timer here.
end

function Player:syncDimensions(skipBumpUpdate)
	if PlayerData.isTiny then
		-- Tiny Box: 14x14
		self.width = 14
		self.height = 14
		-- Center horizontally: -7 offset
		-- Align to character (character is centered 48px sprite, bottom is at y+24)
		-- offsetY = 10 puts the 14px collider at [10, 24] relative to center, aligned to bottom
		self.collisionOffsetX = -(self.width / 2)
		self.collisionOffsetY = 10
	else
		-- Normal Box: 30x24
		self.width = 30
		self.height = 24
		
		-- Collision box offset from sprite position
		self.collisionOffsetX = -(self.width / 2)  -- Center the collision box horizontally
		self.collisionOffsetY = 0                 -- Align to bottom
	end
	
	printDebug(string.format("📐 Syncing Player Dimensions (isTiny: %s): %dx%d, offset: %d, %d", 
		tostring(PlayerData.isTiny), self.width, self.height, self.collisionOffsetX, self.collisionOffsetY))

	if not skipBumpUpdate and self.world and self.world:hasItem(self) then
		self:updateCollisionPosition()
	end
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
	-- Update projectile if active
	if self.projectile then
		playerPlunge.update(self, dt)
	end
	
	if self.isDashing then
		self:updateDash()
	elseif PlayerData.isSliding then
		self:updateSliding(dt)
	else
		-- Handle input and get movement delta (skip if plunging)
		local dx, dy = 0, 0
		self.manualMovement = false

		if not self.isPlunging then
			self.slideDX = 0
			self.slideDY = 0
			dx, dy = playerMovements.handleInput(self, dt)
			self.manualMovement = (dx ~= 0 or dy ~= 0)
		else
			-- While plunging, force idle animation
			playerAnimations.updateAnimation(self, 0, 0)
		end

		-- Derive direction from current input so checkSlimeTile uses fresh direction
		local inputDir
		if     dx > 0 then inputDir = "right"
		elseif dx < 0 then inputDir = "left"
		elseif dy > 0 then inputDir = "down"
		elseif dy < 0 then inputDir = "up"
		end
		self:checkSlimeTile(inputDir)

		-- If slide just started, hand off to updateSliding (skip normal movement)
		if PlayerData.isSliding then
			self:updateSliding(dt)
		else
			-- Example usage: Check for collisions before moving
			if dx ~= 0 or dy ~= 0 then
				local futureCollisions, collisionCount = self:checkCollisionsAt(self.x + dx, self.y + dy)
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

				-- Use centralized physics resolution for side effects
				playerCollisions.resolve(self, other)

				-- Specialized Door collision
				if other.class and other.class.name == "Door" then
					local DoorHandler = require 'DoorHandler'
					DoorHandler.handleDoorCollision(other, self)
				end
			end

			-- Update movement state for turn-based AI
			playerMovements.updateMovementState(self, dx, dy)

			-- Distribute movement frames to all enemies after player moves
			if self.manualMovement then
				self:distributeMovementFrames(3) -- 3 frames per player move
			end
		end
	end

	-- Update animation
	self.currentAnimation:update(dt)

	-- Update dialog UI
	if self.dialogUI then
		self.dialogUI:update(dt)
	end
	
	-- Check for prop interactions (e.g. Minifier)
	self:checkPropInteractions()
end

function Player:updateSliding(dt)
	local slideVelocity = PlayerData.slidingSpeed or 1.5
	local dx = (self.slideDX or 0) * slideVelocity * 60 * dt
	local dy = (self.slideDY or 0) * slideVelocity * 60 * dt

	-- Update animation based on movement
	playerAnimations.updateAnimation(self, dx, dy)
	
	-- Move player with collision detection
	local cols, len = playerMovements.move(self, dx, dy, function(item, other)
		return playerCollisions.response(self, other)
	end)
	
	local hitSolid = false
	-- Handle collisions
	for i = 1, len do
		local col = cols[i]
		local other = col.other
		
		if col.type == 'slide' or col.type == 'touch' then
			hitSolid = true
		end
		
		-- Ensure triggers still process, but don't resolve heavy physics
		playerCollisions.resolve(self, other)
		
		if other.class and other.class.name == "Door" then
			local DoorHandler = require 'DoorHandler'
			DoorHandler.handleDoorCollision(other, self)
		end
	end
	
	playerMovements.updateMovementState(self, dx, dy)

	-- Stop if hitting a solid or leaving slime
	if hitSolid or not self:onSlime() then
		self:stopSliding()
	end
end

-- Handle action button (X key) for plungerang
function Player:handleActionButton()
	if self.isPlunging then
		return -- Already plunging
	end
	
	-- Try to activate plungerang
	playerPlunge.tryActivate(self)
end


-- Draw function
function Player:draw(debug)
	-- Draw the sprite at sprite position, using center as origin
	-- ox, oy parameters set the origin to the center of the sprite
	self.outlineEffect(function()
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
	end)
	
	-- Draw projectile if active
	if self.projectile and not self.projectile.destroyed then
		self.projectile:draw()
	end
	
	-- Draw collision box for debugging (violet color)
	if debug then
		-- Get the actual collision box from BUMP world to ensure accuracy
		local bumpX, bumpY, bumpW, bumpH = self.world:getRect(self)
		
		love.graphics.setColor(0.58, 0, 0.82, 0.5) -- Violet with transparency
		love.graphics.rectangle("fill", bumpX, bumpY, bumpW, bumpH)
		
		-- Also draw the sprite bounds in a different color for reference
		love.graphics.setColor(1, 1, 0, 0.3) -- Yellow with transparency
		love.graphics.rectangle("line", self.x - self.spriteWidth/2, self.y - self.spriteHeight/2, self.spriteWidth, self.spriteHeight)
		
		-- Draw projectile debug
		if self.projectile and not self.projectile.destroyed then
			self.projectile:drawDebug()
		end
		
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
	local collisionsList, count = self:checkCollisions()
	
	for i = 1, count do
		local col = collisionsList[i]
		local other = col.object
		
		-- Trigger collision resolution for side effects (like setting readyToShrink)
		playerCollisions.resolve(self, other)
	end
	
	if not self:onSlime() then
		self.slideBounce = false
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
	self:syncDimensions()
	
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

function Player:getTileCoords()
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")
	if not gameScene or not gameScene.tileMapData then return nil end

	local startX = 200 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = 120 - (gameScene.mapHeight * gameScene.tileSize) / 2
	
	-- Calculate the center of the player's collision box (the feet)
	local feetX = self.x + self.collisionOffsetX + (self.width / 2)
	local feetY = self.y + self.collisionOffsetY + (self.height / 2)

	return utilities.getTileUnderPlayer(gameScene.tileMapData, gameScene.tileSize, feetX, feetY, startX, startY)
end

function Player:onSlime()
	local tileId = self:getTileCoords()
	return tileId and utilities.SLIME_TILE_IDS[tileId] or false
end

function Player:checkSlimeTile(direction)
	if PlayerData.isSliding or not self:onSlime() then return end

	if not PlayerData.items.hasPlunger then
		playerCollisions.startSliding(self, direction or PlayerData.direction)
	end
end

function Player:stopSliding()
	PlayerData.isSliding = false
	self.slideDX = 0
	self.slideDY = 0
	self.slideBounce = true
	self.slideExitFrames = true
	printDebug("🛑 Player:stopSliding()")
end

function Player:idle()
	local anims = self.animations
	if PlayerData.isTiny then
		self.currentAnimation = anims.tinyIdle
	elseif PlayerData.items.hasLamp then
		self.currentAnimation = anims.lampIdle
	else
		self.currentAnimation = anims.idle
	end
end

function Player:setDashAnimation(direction)
	local anims = self.animations
	if direction == "right" then self.currentAnimation = anims.dashRight
	elseif direction == "left" then self.currentAnimation = anims.dashLeft
	elseif direction == "up" then self.currentAnimation = anims.dashUp
	else self.currentAnimation = anims.dashDown
	end
end

function Player:startDash(direction)
	if not PlayerData.skills.canDash then return end
	local bat      = Config and Config.Battery or {}
	local dashCost = (Config and Config.Dash and Config.Dash.batteryCost) or 10
	if PlayerData.battery <= (bat.floor or 10) then return end
	if self.isDashing or self.isPlunging or PlayerData.isSliding then return end
	PlayerData.battery = math.max(bat.floor or 10, PlayerData.battery - dashCost)
	self.isDashing = true
	self.dashDir = direction
	self.dashDistanceTraveled = 0
	self:setDashAnimation(direction)
	printDebug("💨 Dash started: " .. direction)
end

function Player:updateDash()
	local dx, dy = 0, 0
	if self.dashDir == "left" then dx = -self.dashSpeed
	elseif self.dashDir == "right" then dx = self.dashSpeed
	elseif self.dashDir == "up" then dy = -self.dashSpeed
	elseif self.dashDir == "down" then dy = self.dashSpeed end

	local newCollisionX = self.x + self.collisionOffsetX + dx
	local newCollisionY = self.y + self.collisionOffsetY + dy
	local actualX, actualY, cols, len = self.world:move(self, newCollisionX, newCollisionY, function(item, other)
		return playerCollisions.response(self, other)
	end)

	local prevX, prevY = self.x, self.y
	self.x = actualX - self.collisionOffsetX
	self.y = actualY - self.collisionOffsetY
	self:updateCollisionPosition()

	local moved = math.abs(self.x - prevX) + math.abs(self.y - prevY)
	self.dashDistanceTraveled = self.dashDistanceTraveled + moved

	if len > 0 then
		-- Bounce back on wall hit
		local ratio = self.dashBounceDistance / self.dashSpeed
		local bounceColX = self.x + self.collisionOffsetX - dx * ratio
		local bounceColY = self.y + self.collisionOffsetY - dy * ratio
		local bx, by = self.world:move(self, bounceColX, bounceColY, function(item, other)
			return playerCollisions.response(self, other)
		end)
		self.x = bx - self.collisionOffsetX
		self.y = by - self.collisionOffsetY
		self:updateCollisionPosition()
		self.isDashing = false
		self:idle()
	elseif self.dashDistanceTraveled >= self.dashMaxDistance then
		self.isDashing = false
		self:idle()
	end
end

-- Distribute movement frames to all enemies and crewmembers
function Player:distributeMovementFrames(frames)
	-- Get scene and distribute to all enemies
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")

	if gameScene then
		-- Distribute to regular enemies
		if gameScene.enemies then
			for _, enemy in ipairs(gameScene.enemies) do
				if enemy.addMovementFrames then
					enemy:addMovementFrames(frames)
				end
			end
		end

		-- Distribute to crewmembers
		if gameScene.crewMembers then
			for _, crewMember in ipairs(gameScene.crewMembers) do
				if crewMember.addMovementFrames then
					crewMember:addMovementFrames(frames)
				end
			end
		end
	end
end

-- Distribute movement tokens to all enemies and crewmembers
function Player:distributeMovementTokens(tokens)
	-- Get scene and distribute to all enemies
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")

	if gameScene then
		-- Distribute to regular enemies
		if gameScene.enemies then
			for _, enemy in ipairs(gameScene.enemies) do
				if enemy.addMovementTokens then
					enemy:addMovementTokens(tokens)
				end
			end
		end

		-- Distribute to crewmembers
		if gameScene.crewMembers then
			for _, crewMember in ipairs(gameScene.crewMembers) do
				if crewMember.addMovementTokens then
					crewMember:addMovementTokens(tokens)
				end
			end
		end
	end
end

return Player
