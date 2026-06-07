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

	-- Procedural run-graph door: crossing it enters the connected node.
	if door.isDoor and door.targetNodeId then
		-- Remember the side we exit through and which door on that side, so the
		-- destination room spawns the player at the matching door (computeSpawn).
		PlayerData.lastRoom = door.direction
		PlayerData.lastDoorCross = door.posCross
		printDebug("🚪 Crossing proc door " .. tostring(door.direction) ..
			" → node " .. tostring(door.targetNodeId))
		RunState.goTo(door.targetNodeId)
		DoorHandler.gameScene.enterPendingNode()
		return
	end

	-- All doors in procedural mode are run-graph doors (isDoor + targetNodeId). A door
	-- that reaches here lacks a target node and is ignored (no legacy fixed-map path).
	printDebug("⚠️ DoorHandler: door without targetNodeId ignored (no legacy fixed-map)")
end

-- Procedural portal crossing: route to the paired secret-room node when the portal's
-- Conditions pass (e.g. "isTiny:true" → player is tiny). Mirrors handleDoorCollision
-- but keeps the portal's authored SpawnX/SpawnY via PlayerData.returningInPlace so
-- computeSpawn doesn't override it. On a failed gate, show the authored BlockedDialog.
function DoorHandler.handlePortalCollision(portal, player)
	if not portal or not DoorHandler.gameScene then
		printDebug("❌ ERROR: Portal or gameScene not available")
		return
	end
	if not portal.targetNodeId then
		printDebug("🌀 Portal has no target node (secret room not in this run)")
		return
	end

	if Conditions.met(portal.conditions) then
		PlayerData.returningInPlace = true
		if portal.spawnX then PlayerData.playerSpawn.x = portal.spawnX end
		if portal.spawnY then PlayerData.playerSpawn.y = portal.spawnY end
		printDebug("🌀 Crossing portal → node " .. tostring(portal.targetNodeId))
		RunState.goTo(portal.targetNodeId)
		DoorHandler.gameScene.enterPendingNode()
	else
		printDebug("🚫 Portal blocked (conditions not met)")
		if player and player.dialogUI and portal.blockedDialog then
			player.dialogUI:addScreen(portal.blockedDialog)
		end
	end
end

return DoorHandler
