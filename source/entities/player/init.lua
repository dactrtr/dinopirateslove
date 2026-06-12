-- entities/player/init.lua
-- Main Player class using modular components
local Class = require 'libraries/middleclass'
local utilities = require 'utilities'

-- Load player modules
local playerCollisions = require 'entities.player.collisions'
local playerGrapple = require 'entities.player.grapple'
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
	-- Playdate speed 1.7 ~= 100 pixels/second in Love2D.
	-- initialSpeed is the unmodified base; self.speed is recomputed each frame in
	-- updateSpeedModifiers() (darkness / low-battery slowdowns, ported from Playdate).
	self.initialSpeed = (PlayerData.speed or 1.7) * 60 -- Convert to pixels per second
	self.speed = self.initialSpeed
	
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
	self.hasProjectile = true   -- owns the plungerang (set false when a CrewMember steals it)
	
	-- Initialize dialog system
	self.dialogUI = DialogScreen()

	-- Sliding state
	self.slideHitWall     = false
	self.slideDX          = 0
	self.slideDY          = 0
	self.slideExitFrames  = false
	self.committedSlideDir = nil   -- latched slide direction; input can't re-steer

	-- Falling state (set when dropping through a hole; blocks hole re-entry while
	-- the room transition is in progress; cleared on moveTo into the next room)
	self.isFalling = false

	-- Grapple state
	self.isGrappleCharging = false
	self.isGrappling       = false
	self.isGrapplePulling  = false
	self.grappleCrankAccum = 0
	self.grappleChargeStart = 0
	self.grappleHook       = nil
	self.grappleTargetX    = 0
	self.grappleTargetY    = 0

	-- Charge state
	self.chargeTimer = 0

	-- Transform animation state
	self.transformAnimTimer = 0

	-- Minifier state: prop the player is currently standing on (if any)
	self.currentMinifier = nil
	-- Counts down while cranking inside the minifier; when it hits 0 the player
	-- reverts to idle (mirrors Playdate's crankStopTimer / crankIsMoving logic).
	self.minifyCrankTimer = 0

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
	-- Config rects are relative to sprite top-left (Playdate convention).
	-- In LÖVE, player.x/y is sprite center (48x48 sprite, so half = 24px).
	-- Convert: offsetX = config.x - 24, offsetY = config.y - 24
	if PlayerData.isTiny then
		local cfg = Config.Player.collideRectTiny
		self.width  = cfg.w
		self.height = cfg.h
		self.collisionOffsetX = cfg.x - 24
		self.collisionOffsetY = cfg.y - 24
	else
		local cfg = Config.Player.collideRect
		self.width  = cfg.w
		self.height = cfg.h
		self.collisionOffsetX = cfg.x - 24
		self.collisionOffsetY = cfg.y - 24
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
-- Recalculate self.speed from self.initialSpeed based on darkness and battery,
-- ported faithfully from the Playdate (player/state.lua):
--   • in darkness WITHOUT a lamp        → ×speedDarkNoLamp (0.7)
--   • in darkness WITH a lamp + low batt → ×speedLowBattery (0.8)
--   • otherwise                          → full initialSpeed
-- (The port also resets cleanly to full speed once out of darkness, which the
-- original Playdate code did not always do.)
function Player:updateSpeedModifiers()
	local cfgP = (Config and Config.Player) or {}
	local thresholdLow = (Config and Config.Battery and Config.Battery.thresholdLow) or 20
	local darkNoLamp   = cfgP.speedDarkNoLamp or 0.7
	local lowBattery   = cfgP.speedLowBattery or 0.8

	local hasLamp = PlayerData.items and PlayerData.items.hasLamp

	if PlayerData.isInDarkness and not hasLamp then
		self.speed = darkNoLamp * self.initialSpeed
	elseif PlayerData.isInDarkness and hasLamp and PlayerData.battery < thresholdLow then
		self.speed = lowBattery * self.initialSpeed
	else
		self.speed = self.initialSpeed
	end
end

function Player:update(dt)
	-- Recompute walk speed from the current lighting/battery state (Playdate parity).
	self:updateSpeedModifiers()

	-- Post-hit invincibility countdown (ms), ported from the Playdate (state.lua).
	-- Replaces the old hump Timer.after, whose module-global timer the game loop
	-- never updated — so the player stayed invincible forever after one hit and
	-- stopped taking damage. dt-based here, so it always ticks.
	-- Only count down a timed invincibility. collisions.dead() sets isInvincible
	-- without a timer to block hits permanently during the death transition; that
	-- case is left untouched (no timer → no countdown, no flicker).
	if self.isInvincible and self.invincibilityTimer then
		self.invincibilityTimer = self.invincibilityTimer - dt * 1000
		local flickerRate = (Config and Config.Invincibility and Config.Invincibility.flickerRate) or 100
		self.visible = (math.floor(self.invincibilityTimer / flickerRate) % 2 == 0)
		if self.invincibilityTimer <= 0 then
			self.isInvincible       = false
			self.invincibilityTimer = nil
			self.visible            = true
		end
	end

	-- Tick charge timer
	if self.chargeTimer > 0 then
		self.chargeTimer = math.max(0, self.chargeTimer - dt)
		PlayerData.isCharging = self.chargeTimer > 0
	end

	-- Tick transform animation timer
	if self.transformAnimTimer > 0 then
		self.transformAnimTimer = math.max(0, self.transformAnimTimer - dt)
	end

	-- Minifier crank-stop detection: transformCycle plays while cranking (set by
	-- handleCrankInput, which keeps minifyCrankTimer fed); once the player stops
	-- cranking the timer runs out and we revert to idle. Skipped while transformTo
	-- is playing (transformAnimTimer > 0) so the shrink animation isn't cut short.
	if PlayerData.isMinifying and self.transformAnimTimer <= 0 then
		if self.minifyCrankTimer > 0 then
			self.minifyCrankTimer = math.max(0, self.minifyCrankTimer - dt)
		else
			self:idle()  -- not cranking → idle (respects isTiny / lamp)
		end
	end

	-- Update projectile if active
	if self.projectile then
		playerPlunge.update(self, dt)
	end

	-- Update grapple hook if active
	playerGrapple.update(self, dt)

	if self.isDashing then
		self:updateDash()
	elseif self.isGrapplePulling then
		playerGrapple.updatePull(self, dt)
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

		-- Derive direction from current input so checkSlimeTile uses fresh direction.
		-- Diagonals resolve to the axis that isn't blocked by a wall, so the player
		-- slides straight down a corridor instead of squeezing out sideways at a corner.
		local inputDir = self:resolveInputDirection(dx, dy)
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
			local stepPrevX, stepPrevY = self.x, self.y
			local cols, len = playerMovements.move(self, dx, dy, function(item, other)
				return playerCollisions.response(self, other)
			end)

			-- Handle collisions
			for i = 1, len do
				local col = cols[i]
				local other = col.other

				-- Use centralized physics resolution for side effects
				playerCollisions.resolve(self, other)

				-- Specialized Door collision: only fire when player newly enters the door
				-- (col.overlaps = false means player crossed from outside to inside this frame).
				-- col.overlaps = true means player was already inside the door's rect at move
				-- start (spawn case) — don't fire to avoid immediate room loop.
				if other.class and other.class.name == "Door" and not col.overlaps then
					local DoorHandler = require 'DoorHandler'
					DoorHandler.handleDoorCollision(other, self)
				end

				-- Specialized PortalDoor collision: only fire on newly-entered overlap
				-- (same guard as Door). Routed through DoorHandler (which holds the
				-- gameScene ref) to gate on Conditions and transition to the secret node.
				if other.isPortal and other.targetNodeId and not col.overlaps then
					local DoorHandler = require 'DoorHandler'
					DoorHandler.handlePortalCollision(other, self)
				end
			end

			-- Update movement state for turn-based AI
			playerMovements.updateMovementState(self, dx, dy)

			-- Turn-based token feed: enemies/crew earn movement frames in proportion to
			-- how far the player ACTUALLY displaced (per discrete step), not per game
			-- frame. Pressing into a wall (no displacement) feeds nothing, and the enemy
			-- stops shortly after the player does (bounded by Config.Enemy.movementFramesCap).
			local moved = math.abs(self.x - stepPrevX) + math.abs(self.y - stepPrevY)
			if moved > 0 then
				self:distributeMovementFramesForStep(moved)
			end
		end
	end

	-- Hole tile detection (fall to the room below, or drain battery with boots).
	-- Runs after movement so it tests the player's resolved position.
	self:checkHoleTile()
	self:checkTinyHoleTile()

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
	local slideVelocity = (Config and Config.Slide and Config.Slide.speed) or 4
	local dx = (self.slideDX or 0) * slideVelocity * 60 * dt
	local dy = (self.slideDY or 0) * slideVelocity * 60 * dt

	-- Update animation based on movement
	playerAnimations.updateAnimation(self, dx, dy)

	-- Move player with collision detection
	local cols, len = playerMovements.move(self, dx, dy, function(item, other)
		return playerCollisions.response(self, other)
	end)

	local hitSolid = false
	for i = 1, len do
		local col = cols[i]
		local other = col.other

		-- Walls ('slide' response) and solid props/boxes ('touch') stop the slide
		-- Doors return 'cross' from the filter but still stop the slide
		if col.type == 'slide' or col.type == 'touch' then
			hitSolid = true
		elseif other.class and other.class.name == "Door" then
			hitSolid = true
		end

		playerCollisions.resolve(self, other)

		if other.class and other.class.name == "Door" then
			local DoorHandler = require 'DoorHandler'
			DoorHandler.handleDoorCollision(other, self)
		end
	end

	playerMovements.updateMovementState(self, dx, dy)

	if hitSolid or not self:onSlime() then
		self:endSliding(hitSolid)
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
	-- ox, oy parameters set the origin to the center of the sprite.
	-- Skipped while flickering (invincibility blink); self.visible is toggled in
	-- Player:update, nil means visible. Only the player sprite blinks — the
	-- projectile/grapple below keep drawing.
	if self.visible ~= false then
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
	end
	
	-- Draw projectile if active
	if self.projectile and not self.projectile.destroyed then
		self.projectile:draw()
	end

	-- Draw grapple hook (with rope) if active
	playerGrapple.draw(self)
	
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
	-- Reset state frame by frame. While locked into the minifier the player stays
	-- centered on it, so the overlap below re-asserts readyToShrink/currentMinifier.
	PlayerData.readyToShrink = false
	self.currentMinifier     = nil

	-- Check for overlaps with props using centralized logic
	local collisionsList, count = self:checkCollisions()
	
	for i = 1, count do
		local col = collisionsList[i]
		local other = col.object
		
		-- Trigger collision resolution for side effects (like setting readyToShrink)
		playerCollisions.resolve(self, other)
	end
	
end


-- Minifier crank tuning (mirrors Playdate's getCrankTicks(4)/actualPlayerSize loop).
-- One "tick" ≈ 30° of crank rotation (matches Input.CRANK_THRESHOLD); each tick moves
-- actualPlayerSize by MINIFY_SIZE_STEP. playerSize is 10, so a full transform takes
-- ~5 ticks (≈150° of cranking).
local MINIFY_CRANK_TICK = math.rad(30)
local MINIFY_SIZE_STEP  = 2
-- Seconds of crank inactivity before the minifying player reverts to idle.
-- (Playdate uses 0.1s; a slightly larger window avoids flicker between crank ticks.)
local MINIFY_CRANK_STOP = 0.2

function Player:handleCrankInput(delta)
	if delta == 0 then return end

	-- Locked into the minifier: crank gradually transforms the player's size.
	-- Counter-clockwise (negative) shrinks; clockwise (positive) grows.
	if PlayerData.isMinifying then
		-- Show the spinning animation and keep it alive until the crank stops.
		self:transformCycle()
		self.minifyCrankTimer = MINIFY_CRANK_STOP

		local ticks  = math.max(1, math.floor(math.abs(delta) / MINIFY_CRANK_TICK + 0.5))
		local amount = ticks * MINIFY_SIZE_STEP

		if not PlayerData.isTiny then
			-- Shrinking (counter-clockwise)
			if delta < 0 then
				PlayerData.actualPlayerSize = PlayerData.actualPlayerSize - amount
				if PlayerData.actualPlayerSize <= 0 then
					PlayerData.actualPlayerSize = 0
					self:shrink()
				end
			end
		else
			-- Growing (clockwise)
			if delta > 0 then
				PlayerData.actualPlayerSize = PlayerData.actualPlayerSize + amount
				if PlayerData.actualPlayerSize >= PlayerData.playerSize then
					PlayerData.actualPlayerSize = PlayerData.playerSize
					self:grow()
				end
			end
		end
		return
	end

	-- Standing on a minifier but not locked in yet: crank does nothing.
	-- The player must press A (startMinifying) to begin transforming.
	if PlayerData.readyToShrink then return end

	-- Normal gameplay: clockwise (positive delta) charges battery (not while tiny).
	-- Blocked for a few seconds after a dark reveal (rechargeBlocked).
	if PlayerData.isGaming and not PlayerData.isTiny and not PlayerData.rechargeBlocked
		and delta > 0 and PlayerData.battery < 100 then
		PlayerData.battery = math.min(100, PlayerData.battery + 3)
		PlayerData.isActive   = true
		PlayerData.isCharging = true
		self.chargeTimer      = 0.5  -- hold charge state for 0.5s after last crank tick
	end
end

-- Lock the player onto the minifier and begin the size-change sequence.
-- Triggered by pressing A while standing on a minifier (readyToShrink + isGaming).
function Player:startMinifying()
	if not self.currentMinifier or PlayerData.isTalking or not PlayerData.isGaming then return end

	PlayerData.isMinifying = true
	PlayerData.isGaming    = false

	-- Auto-center on the minifier (prop x/y is top-left of a 32×32 tile).
	local targetX = self.currentMinifier.x + 16
	local targetY = self.currentMinifier.y + 16 - 10
	self:moveTo(targetX, targetY)

	-- Reset progress: full size when shrinking, zero when growing.
	PlayerData.actualPlayerSize = PlayerData.isTiny and 0 or PlayerData.playerSize

	-- Show idle while locked in; transformCycle only plays once the player cranks.
	self.minifyCrankTimer = 0
	self:idle()

	printDebug("🌀 startMinifying (isTiny: " .. tostring(PlayerData.isTiny) .. ")")
end

-- Release the minifier lock (transform completed or cancelled with B).
function Player:finishMinifying()
	PlayerData.isMinifying = false
	PlayerData.isGaming    = true
	printDebug("✅ finishMinifying")
end

-- Looping animation shown while the player cranks inside the minifier.
function Player:transformCycle()
	local anim = self.animations.transformCycle
	if self.currentAnimation ~= anim then
		anim:gotoFrame(1)
		anim:resume()
		self.currentAnimation = anim
	end
end

-- Complete the shrink: become tiny, swap the collision box, play transformTo.
function Player:shrink()
	PlayerData.isTiny = true
	self:syncDimensions()
	PlayerData.actualPlayerSize = 0

	local anim = self.animations.transformTo
	anim:gotoFrame(1)
	anim:resume()
	self.currentAnimation   = anim
	self.transformAnimTimer = 0.8  -- block updateAnimation until transformTo finishes

	self:finishMinifying()
	printDebug("🤏 Player shrank. isTiny: true")
end

-- Complete the grow: return to full size and idle.
function Player:grow()
	PlayerData.isTiny = false
	self:syncDimensions()
	PlayerData.actualPlayerSize = PlayerData.playerSize
	self:idle()

	self:finishMinifying()
	printDebug("🌱 Player grew. isTiny: false")
end

function Player:moveTo(x, y)
	self.x = x
	self.y = y
	-- Landed in a (new) position: clear the falling latch so hole detection works again.
	self.isFalling = false
	if self.world:hasItem(self) then
		self:updateCollisionPosition()
	end
end

function Player:getTileCoords()
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")
	if not gameScene or not gameScene.tileMapData then return nil end

	local startX = VIRTUAL_WIDTH / 2 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * gameScene.tileSize) / 2

	-- Calculate the center of the player's collision box (the feet)
	local feetX = self.x + self.collisionOffsetX + (self.width / 2)
	local feetY = self.y + self.collisionOffsetY + (self.height / 2)

	return utilities.getTileUnderPlayer(gameScene.tileMapData, gameScene.tileSize, feetX, feetY, startX, startY)
end

-- Sample a 3×3 grid at the player's feet and return true if any sampled tile is
-- in idSet. Shared by slime and hole detection (matches Playdate IsPlayerOn* helpers).
function Player:feetOnTile(idSet)
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")
	if not gameScene or not gameScene.tileMapData then return false end

	local tileSize = gameScene.tileSize
	local startX = VIRTUAL_WIDTH  / 2 - (gameScene.mapWidth  * tileSize) / 2
	local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * tileSize) / 2

	local feetY  = self.y + 12
	local halfW  = PlayerData.isTiny and 5 or 8
	local xOff   = { -halfW, 0, halfW }
	local yOff   = { -4, 0, 4 }

	for _, dx in ipairs(xOff) do
		for _, dy in ipairs(yOff) do
			local tileId = utilities.getTileUnderPlayer(gameScene.tileMapData, tileSize, self.x + dx, feetY + dy, startX, startY)
			if tileId and idSet[tileId] then
				return true
			end
		end
	end
	return false
end

function Player:onSlime()
	return self:feetOnTile(utilities.SLIME_TILE_IDS)
end

function Player:onHole()
	return self:feetOnTile(utilities.HOLE_TILE_IDS)
end

function Player:onTinyHole()
	return self:feetOnTile(utilities.TINY_HOLE_TILE_IDS)
end

-- True while standing on any hole the player can fall through. Used to gate
-- skill activation / battery recharge (the player may only walk while over a hole).
function Player:isOnHole()
	if self:onHole() then return true end
	if PlayerData.isTiny and self:onTinyHole() then return true end
	return false
end

-- Non-destructive probe: is there a solid wall/prop/door a short step away in
-- the given cardinal direction? Used to resolve diagonal slide input.
function Player:isSolidInDirection(direction, probe)
	probe = probe or 4
	local gx = self.x + ((direction == "right" and probe) or (direction == "left" and -probe) or 0)
	local gy = self.y + ((direction == "down"  and probe) or (direction == "up"   and -probe) or 0)
	local cx = gx + self.collisionOffsetX
	local cy = gy + self.collisionOffsetY
	local _, _, cols, len = self.world:check(self, cx, cy, function(item, other)
		return playerCollisions.response(self, other)
	end)
	for i = 1, len do
		local c = cols[i]
		if c.type == 'slide' or c.type == 'touch' then return true end
		if c.other.class and c.other.class.name == "Door" then return true end
	end
	return false
end

-- Resolve a (possibly diagonal) movement delta to a single cardinal direction.
-- For diagonals, prefer the axis that isn't blocked by a wall; if both or neither
-- are blocked, keep the previous horizontal-first behaviour.
function Player:resolveInputDirection(dx, dy)
	local horiz = (dx > 0 and "right") or (dx < 0 and "left") or nil
	local vert  = (dy > 0 and "down")  or (dy < 0 and "up")   or nil

	if horiz and vert then
		local hBlocked = self:isSolidInDirection(horiz)
		local vBlocked = self:isSolidInDirection(vert)
		if hBlocked and not vBlocked then return vert  end
		if vBlocked and not hBlocked then return horiz end
		return horiz
	end

	return horiz or vert
end

function Player:checkSlimeTile(direction)
	if PlayerData.isSliding then return end
	if self.isDashing then return end
	if self.isPlunging then return end

	if not self:onSlime() then
		-- Genuinely off the slime: forget the committed direction and the wall
		-- latch so the next slide starts fresh.
		self.committedSlideDir = nil
		self.slideHitWall = false
		return
	end

	if self.slideHitWall then return end
	if PlayerData.items.hasPlunger then return end

	-- Reuse the committed direction if a slide is already in progress (survives a
	-- one-frame onSlime() flicker at tile edges); input cannot re-steer it.
	local dir = self.committedSlideDir or direction or PlayerData.direction
	if not dir or dir == "idle" then return end

	playerCollisions.startSliding(self, dir)
end

-- Hole tiles (everyone falls). Wearing boots with battery lets the player walk
-- across, draining battery while moving; otherwise they fall to the room below.
function Player:checkHoleTile()
	if PlayerData.isSliding or self.isPlunging or self.isFalling or self.isGrapplePulling then return end
	if not self:onHole() then return end

	if PlayerData.items.hasBoots == true and PlayerData.battery > 0 then
		-- Only drain while actively moving ("time moves when you move").
		if self.manualMovement then
			local bat = Config and Config.Battery or {}
			playerCollisions.drainBattery(self,
				PlayerData.isTiny and (bat.drainHoleTiny or 0.2) or (bat.drainHoleNormal or 0.5))
		end
	else
		-- Latch BEFORE fallBelow() so subsequent frames don't re-trigger the fall
		-- while the transition is queued/in progress. Clear it if the fall can't
		-- happen (room has no lower neighbor) so the player isn't stuck.
		self.isFalling = true
		if not playerCollisions.fallBelow(self) then
			self.isFalling = false
		end
	end
end

-- Tiny-only hole tiles (IntGrid 32). Normal-size players walk over them as floor;
-- only the shrunk player interacts.
function Player:checkTinyHoleTile()
	if not PlayerData.isTiny then return end
	if PlayerData.isSliding or self.isPlunging or self.isFalling or self.isGrapplePulling then return end
	if not self:onTinyHole() then return end

	if PlayerData.items.hasBoots == true and PlayerData.battery > 0 then
		if self.manualMovement then
			local bat = Config and Config.Battery or {}
			playerCollisions.drainBattery(self, bat.drainHoleTiny or 0.2)
		end
	else
		self.isFalling = true
		if not playerCollisions.fallBelow(self) then
			self.isFalling = false
		end
	end
end

function Player:endSliding(hitWall)
	PlayerData.isSliding = false
	self.slideDX = 0
	self.slideDY = 0

	if hitWall then
		self.slideHitWall = true
		-- Hit a wall: drop the committed direction so the player can pick a new
		-- one after moving away (instead of re-sliding back into the wall).
		self.committedSlideDir = nil
	end

	if PlayerData.isTiny then
		-- Tiny: go directly to tinyIdle, no exit animation
		self.slideExitFrames = false
		self.currentAnimation = self.animations.tinyIdle
		self.animations.tinyIdle:gotoFrame(1)
		self.animations.tinyIdle:resume()
	else
		-- Normal: trigger exit animation
		self.slideExitFrames = true
	end

	printDebug("🛑 Player:endSliding(hitWall=" .. tostring(hitWall) .. ")")
end

local lightburstCooldownEnd = 0

-- Schedule a callback on the room timer instance (gameScene.timer), which IS
-- ticked each frame — unlike the hump module-global Timer, which the game loop
-- never updates (see the invincibility note above). Falls back to running the
-- callback immediately if the timer isn't available.
local function scheduleOnRoomTimer(seconds, fn)
    local sceneManager = require 'sceneManager'
    local gameScene = sceneManager.getScene("game")
    if gameScene and gameScene.timer then
        gameScene.timer:after(seconds, fn)
    else
        fn()
    end
end

-- ── Light Burst (lamp flash) ────────────────────────────────────────────────
-- Directional flash that blinds enemies/crew inside the light cone. Ported from
-- the Playdate lightburst.lua. Costs battery (and optionally HP via selfDamage).
function Player:lightBurst()
    local cfg = Config.LightBurst

    -- Guards (the port gates gameplay with isGaming; there is no self.isAlive)
    if PlayerData.isGaming ~= true then return end
    if not PlayerData.items.hasLamp or not PlayerData.skills.canFlash then return end
    if love.timer.getTime() < lightburstCooldownEnd then return end

    -- Directional flash. Fall back to the last faced direction so a stationary
    -- tap still flashes (same approach the grapple/plunge use); only bail if we
    -- have no direction at all.
    local dir = PlayerData.direction
    if dir == 'idle' or dir == nil or dir == '' then dir = PlayerData.lastDirection end
    if not dir or dir == 'idle' or dir == '' then return end

    if PlayerData.battery < (cfg.minBattery or cfg.batteryCost) then return end

    -- Block the flash if its self-damage would leave the player without life.
    local selfDamage = cfg.selfDamage or 0
    if selfDamage > 0 and (PlayerData.healthPoints - selfDamage) < (PlayerData.danceThresholdHP or 1) then
        printDebug("🚫 Flash blocked: not enough HP")
        return
    end

    -- Consume battery + show the cone
    PlayerData.battery = math.max(0, PlayerData.battery - (cfg.batteryCost or 10))
    PlayerData.showLightCone = true
    lightburstCooldownEnd = love.timer.getTime() + (cfg.cooldown or 1000) / 1000

    -- Hide the cone after displayTime (on the room timer, not the global one)
    scheduleOnRoomTimer((cfg.displayTime or 1000) / 1000, function()
        PlayerData.showLightCone = false
    end)

    -- Blind entities inside the cone
    local FXshadow = require 'entities.UI.FXshadow'
    local pts = FXshadow.buildConeVertices(PlayerData.x, PlayerData.y, dir,
        cfg.coneDistance or 200, cfg.coneHeight or 12)
    if pts then
        local gameScene = require 'scenes.gameScene'
        local blind = cfg.blindDuration or 60
        for _, enemy in ipairs(gameScene.enemies or {}) do
            if utilities.pointInPolygon(pts, enemy.x, enemy.y) and enemy.blind then enemy:blind(blind) end
        end
        for _, cm in ipairs(gameScene.crewMembers or {}) do
            if utilities.pointInPolygon(pts, cm.x, cm.y) and cm.blind then cm:blind(blind) end
        end
    end

    -- Self-damage (ignores invincibility; lethal case already rejected above)
    if selfDamage > 0 then
        PlayerData.healthPoints = PlayerData.healthPoints - selfDamage
    end

    -- Tokens granted because the flash actually fired
    self:distributeMovementTokens((Config.Player and Config.Player.movementTokensPerAction) or 5)
end

-- ── Ability dispatch (B tap) ────────────────────────────────────────────────
-- In darkness the lamp flashes; in light the plungerang fires. Mirrors the
-- Playdate abilities.lua useAbility().
function Player:useAbility()
    if PlayerData.isGaming ~= true then return end
    if self:isOnHole() then return end  -- on a hole the player may only walk
    if PlayerData.isInDarkness then
        self:lightBurst()
    else
        playerPlunge.tryActivate(self)
    end
end

-- ── Dark Reveal (B hold + crank in darkness) ────────────────────────────────
-- Mirrors the grapple charge model: begin on B-press, accumulate crank, resolve
-- on B-release. A long-enough hold WITH enough crank floods the room with light
-- (activateDarkReveal); otherwise it falls back to a quick lamp flash.
function Player:beginDarkCharge()
    if PlayerData.isGaming ~= true then return end
    if self:isOnHole() then return end
    if not PlayerData.isInDarkness or not PlayerData.items.hasLamp then return end
    if not PlayerData.skills.canFlash then return end
    if self.isDarkCharging or self.isGrappleCharging or self.isPlunging then return end

    self.isDarkCharging   = true
    self.darkCrankAccum   = 0
    self.darkChargeStart  = love.timer.getTime()
    self.lastDarkCrankTime = 0   -- no crank yet → HUD only shakes once cranking starts
end

function Player:addDarkCrankDelta(delta)
    if not self.isDarkCharging then return end
    if delta and delta > 0 then
        self.darkCrankAccum = (self.darkCrankAccum or 0) + delta
        self.lastDarkCrankTime = love.timer.getTime()  -- HUD shakes only while actively cranking
    end
end

function Player:endDarkCharge()
    if not self.isDarkCharging then return end
    self.isDarkCharging = false

    local dr = Config.DarkReveal
    local holdDelay = (dr.holdDelay or 400) / 1000
    local armed = (love.timer.getTime() - (self.darkChargeStart or 0)) >= holdDelay
    local crankDeg = math.deg(self.darkCrankAccum or 0)
    self.darkCrankAccum = 0

    local willReveal = armed and crankDeg >= (dr.crankThreshold or 720) and PlayerData.battery >= (dr.minBattery or 80)

    if self:isOnHole() then return end  -- walked onto a hole mid-charge: cancel

    if willReveal then
        self:activateDarkReveal()
    else
        self:lightBurst()  -- tap / insufficient charge → quick flash
    end
end

-- Abort an in-progress dark charge without firing (blocking UI interrupted it).
function Player:cancelDarkCharge()
    self.isDarkCharging = false
    self.darkCrankAccum = 0
end

function Player:activateDarkReveal()
    local dr = Config.DarkReveal
    local selfDamage = dr.selfDamage or 0

    -- Block the reveal if its self-damage would leave the player without life.
    if selfDamage > 0 and (PlayerData.healthPoints - selfDamage) < (PlayerData.danceThresholdHP or 1) then
        printDebug("🚫 Dark reveal blocked: not enough HP")
        return
    end

    PlayerData.battery         = 0
    PlayerData.rechargeBlocked = true
    PlayerData.showFullLight   = true

    if selfDamage > 0 then
        PlayerData.healthPoints = PlayerData.healthPoints - selfDamage
    end

    self:distributeMovementTokens((Config.Player and Config.Player.movementTokensPerAction) or 5)
    printDebug("🌟 Dark reveal activated!")

    -- After revealDuration, fade the light; then unblock recharge after another delay.
    scheduleOnRoomTimer((dr.revealDuration or 3000) / 1000, function()
        PlayerData.showFullLight = false
        local FXshadow = require 'entities.UI.FXshadow'
        FXshadow.markDirty()  -- force the darkness overlay to recompute now the reveal is over
        scheduleOnRoomTimer((dr.rechargeBlockDuration or 3000) / 1000, function()
            PlayerData.rechargeBlocked = false
        end)
    end)
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

-- Turn-based contract from the Playdate port, translated to real time: accumulate
-- the player's displacement and emit one "action" (movementFramesPerAction frames
-- handed to every enemy/crew) per movementStepDistance pixels moved. The enemy's
-- movement budget therefore mirrors the player's actual displacement instead of the
-- frame rate, so it tracks you while you move and freezes when you stop.
function Player:distributeMovementFramesForStep(distance)
	local cfg = (Config and Config.Player) or {}
	local stepDist  = cfg.movementStepDistance    or 3
	local perAction = cfg.movementFramesPerAction  or 3
	self.stepAccumulator = (self.stepAccumulator or 0) + distance
	while self.stepAccumulator >= stepDist do
		self.stepAccumulator = self.stepAccumulator - stepDist
		self:distributeMovementFrames(perAction)
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
