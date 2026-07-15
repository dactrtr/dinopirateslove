-- entities/player/movements.lua
-- Movement-related functions for Player

local movements = {}

-- Handle keyboard and gamepad input for movement
function movements.handleInput(player, dt)
	local dx, dy = 0, 0

	-- Don't allow movement if talking, in cutscene, sliding, charging battery,
	-- locked into the minifier doing the size transformation, or while input is
	-- suppressed by an overlay (the analog stick below is read directly, so it
	-- bypasses Input's suppression and must be gated here too).
	if Input.isSuppressed() or PlayerData.isTalking or PlayerData.isCutscene or PlayerData.isSliding or PlayerData.isCharging or PlayerData.isMinifying then return dx, dy end


	-- Keyboard movement
	if Input.isDown("up")    then dy = -player.speed * dt end
	if Input.isDown("down")  then dy =  player.speed * dt end
	if Input.isDown("left")  then dx = -player.speed * dt end
	if Input.isDown("right") then dx =  player.speed * dt end

	-- Gamepad movement (left stick)
	local joysticks = love.joystick.getJoysticks()
	if #joysticks > 0 then
		local joy = joysticks[1]
		local axisX = joy:getAxis(1) -- left stick X
		local axisY = joy:getAxis(2) -- left stick Y

		-- Apply deadzone
		local deadzone = (Config and Config.Player and Config.Player.gamepadDeadzone) or 0.2
		if math.abs(axisX) > deadzone then
			dx = dx + axisX * player.speed * dt
		end
		if math.abs(axisY) > deadzone then
			dy = dy + axisY * player.speed * dt
		end
	end
	
	return dx, dy
end

-- Move player with BUMP collision detection
function movements.move(player, dx, dy, filter)
	-- No movement: skip world:move entirely (matches Playdate's button-driven model
	-- where player:move() is only called on explicit input, never when stationary).
	-- Calling world:move with dx=0,dy=0 causes Bump to detect static overlaps and
	-- emit collisions (bump.lua:149-174), causing wall bouncing and door loops on spawn.
	if dx == 0 and dy == 0 then
		return {}, 0
	end

	-- Clear slideHitWall when player voluntarily moves
	player.slideHitWall = false

	-- BUMP collision - move collision box and get sprite position back
	local newCollisionX = player.x + player.collisionOffsetX + dx
	local newCollisionY = player.y + player.collisionOffsetY + dy
	local actualCollisionX, actualCollisionY, cols, len = player.world:move(player, newCollisionX, newCollisionY, filter)

	-- Convert collision box position back to sprite position
	local prevX, prevY = player.x, player.y
	player.x = actualCollisionX - player.collisionOffsetX
	player.y = actualCollisionY - player.collisionOffsetY

	-- Track stats only when the player actually displaced
	if (dx ~= 0 or dy ~= 0) and (math.abs(player.x - prevX) + math.abs(player.y - prevY) > 0) then
		local bat = Config and Config.Battery or {}
		local ped = Config and Config.Pedometer or {}
		if PlayerData.isInDarkness then
			PlayerData.battery = math.max(bat.floor or 10,
				PlayerData.battery - (bat.drainMovementDark or 0.5))
		end
		PlayerData.steps = (PlayerData.steps or 0) + 1
		if PlayerData.steps % (ped.stepsToTrigger or 200) == 0 then
			PlayerData.calories = math.max(ped.calorieMin or 0,
				PlayerData.calories - (ped.caloriesPerBurn or 10))
		end
	end

	return cols, len
end

-- Track movement state for turn-based AI
function movements.updateMovementState(player, dx, dy)
	-- Track if player is moving
	local wasMoving = player.isMoving
	player.isMoving = (dx ~= 0 or dy ~= 0)
	
	-- Set hasMoved flag if player actually moved
	if player.isMoving and (dx ~= 0 or dy ~= 0) then
		player.hasMoved = true
	end
end

return movements
