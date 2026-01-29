-- entities/player/movements.lua
-- Movement-related functions for Player

local movements = {}

-- Handle keyboard and gamepad input for movement
function movements.handleInput(player, dt)
	local dx, dy = 0, 0

	-- Don't allow movement if talking or in cutscene
	if PlayerData.isTalking or PlayerData.isCutscene then return dx, dy end


	-- Keyboard movement (WASD and arrow keys)

	if love.keyboard.isDown("w") or love.keyboard.isDown("up") then dy = -player.speed * dt end
	if love.keyboard.isDown("s") or love.keyboard.isDown("down") then dy = player.speed * dt end
	if love.keyboard.isDown("a") or love.keyboard.isDown("left") then dx = -player.speed * dt end
	if love.keyboard.isDown("d") or love.keyboard.isDown("right") then dx = player.speed * dt end

	-- Gamepad movement (left stick)
	local joysticks = love.joystick.getJoysticks()
	if #joysticks > 0 then
		local joy = joysticks[1]
		local axisX = joy:getAxis(1) -- left stick X
		local axisY = joy:getAxis(2) -- left stick Y

		-- Apply deadzone
		local deadzone = 0.2
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
	-- BUMP collision - move collision box and get sprite position back
	local newCollisionX = player.x + player.collisionOffsetX + dx
	local newCollisionY = player.y + player.collisionOffsetY + dy
	local actualCollisionX, actualCollisionY, cols, len = player.world:move(player, newCollisionX, newCollisionY, filter)
	
	-- Convert collision box position back to sprite position
	player.x = actualCollisionX - player.collisionOffsetX
	player.y = actualCollisionY - player.collisionOffsetY
	
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
