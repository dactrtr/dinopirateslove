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
		print("❌ ERROR: Door or gameScene not available")
		return
	end
	
	-- Calculate relative position ratio within the door to preserve alignment
	-- If moving vertically, we care about X. If moving horizontally, we care about Y.
	local exitRatio = 0.5 -- Default to center
	if door.direction == "top" or door.direction == "down" then
		exitRatio = (player.x - door.x) / door.width
	else
		exitRatio = (player.y - door.y) / door.height
	end
	
	-- Trigger level transition with alignment info
	DoorHandler.gameScene.changeLevel(door.nextLevelIid, door.direction, player, exitRatio)
	
	print("🚪 Transitioning through door: " .. door.direction)
end

return DoorHandler
