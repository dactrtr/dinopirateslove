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
	
	-- Capture the player's absolute position at the moment of collision.
	-- For vertical doors (top/down): X is preserved in the new room.
	-- For lateral doors (left/right): Y is preserved in the new room.
	local capturedX = player.x
	local capturedY = player.y

	-- Trigger level transition with captured coords and fade
	DoorHandler.gameScene.changeLevel(door.nextLevelIid, door.direction, capturedX, capturedY, "fade")

	printDebug("🚪 Transitioning through door: " .. door.direction .. " at (" .. capturedX .. ", " .. capturedY .. ")")
end

return DoorHandler
