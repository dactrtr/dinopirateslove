-- DoorHandler.lua
-- Handles door collision responses and level transitions

local DoorHandler = {}

-- Reference to gameScene (will be set by gameScene)
DoorHandler.gameScene = nil

function DoorHandler.setGameScene(scene)
	DoorHandler.gameScene = scene
end

function DoorHandler.handleDoorCollision(door, player)
	if not door or not DoorHandler.gameScene then
		printDebug("❌ ERROR: Door or gameScene not available")
		return
	end
	
	-- Calculate relative position ratio within the door to preserve alignment.
	-- Clamp to [0,1] so a player at the door edge never spawns outside door bounds
	-- (which could be inside a wall in the destination room).
	-- For vertical doors (top/down): preserve X using collision center (= player.x
	--   because collisionOffsetX = -width/2).
	-- For lateral doors (left/right): preserve Y using collision box center Y
	--   (= player.y + height/2) for accurate alignment, not the sprite top-left.
	local exitRatio = 0.5 -- Default to center
	if door.direction == "top" or door.direction == "down" then
		exitRatio = (player.x - door.x) / door.width
	else
		local colCenterY = player.y + (player.height or 0) * 0.5
		exitRatio = (colCenterY - door.y) / door.height
	end
	exitRatio = math.max(0, math.min(1, exitRatio))
	
	-- Trigger level transition with alignment info and fade
	DoorHandler.gameScene.changeLevel(door.nextLevelIid, door.direction, player, exitRatio, "fade")
	
	printDebug("🚪 Transitioning through door: " .. door.direction)
end

return DoorHandler
