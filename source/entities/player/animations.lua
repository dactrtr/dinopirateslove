-- entities/player/animations.lua
-- Animation-related functions for Player

local anim8 = require 'libraries/anim8'

local animations = {}

-- Load all player animations
function animations.load(spritesheet)
	local grid = anim8.newGrid(48, 48, spritesheet:getWidth(), spritesheet:getHeight())
	
	return {
		idle = anim8.newAnimation(grid('1-4', 1), 0.4),
		right = anim8.newAnimation(grid('5-7', 1), 0.2),
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
end

-- Get initial animation based on player state
function animations.getInitialAnimation(animList)
	if PlayerData.hasLamp and PlayerData.isInDarkness then
		return animList.lampIdle
	else
		return animList.idle
	end
end

-- Update animation based on movement direction
function animations.updateAnimation(player, dx, dy)
	if dx > 0 then
		player.currentAnimation = PlayerData.hasLamp and player.animations.lampRight or player.animations.right
	elseif dx < 0 then
		player.currentAnimation = PlayerData.hasLamp and player.animations.lampLeft or player.animations.left
	elseif dy > 0 then
		player.currentAnimation = PlayerData.hasLamp and player.animations.lampDown or player.animations.down
	elseif dy < 0 then
		player.currentAnimation = player.animations.up
	else
		player.currentAnimation = PlayerData.hasLamp and player.animations.lampIdle or player.animations.idle
	end
end

return animations
