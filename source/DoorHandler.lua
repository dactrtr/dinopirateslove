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
	
	-- Set spawn position for next room
	door:prevRoom(door.direction)
	
	-- Trigger level transition
	local enterDirection = door.direction
	DoorHandler.gameScene.changeLevel(door.nextLevelIid, enterDirection)
	
	print("🚪 Transitioning through door: " .. door.direction)
end

return DoorHandler
