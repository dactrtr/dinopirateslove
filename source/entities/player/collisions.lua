-- entities/player/collisions.lua
-- Collision-related functions for Player

local collisions = {}

-- Get the collision box position and dimensions
function collisions.getCollisionRect(player)
	return player.x + player.collisionOffsetX, player.y + player.collisionOffsetY, player.width, player.height
end

-- Get the sprite position and dimensions (for drawing)
function collisions.getSpriteRect(player)
	return player.x, player.y, player.spriteWidth, player.spriteHeight
end

-- Update collision box position in BUMP world
function collisions.updateCollisionPosition(player)
	local collisionX = player.x + player.collisionOffsetX
	local collisionY = player.y + player.collisionOffsetY
	player.world:update(player, collisionX, collisionY, player.width, player.height)
end

-- Returns a table of colliding objects within the specified rectangle
-- @param x, y: top-left corner of the rectangle
-- @param w, h: width and height of the rectangle
-- @param filter: optional collision filter function
function collisions.collideRect(player, x, y, w, h, filter)
	local items, len = player.world:queryRect(x, y, w, h, filter)
	
	-- Format results similar to Playdate SDK
	local collisionList = {}
	for i = 1, len do
		local item = items[i]
		if item ~= player then -- Don't include self in collisions
			local itemX, itemY, itemW, itemH = player.world:getRect(item)
			table.insert(collisionList, {
				object = item,
				x = itemX,
				y = itemY,
				width = itemW,
				height = itemH
			})
		end
	end
	
	return collisionList, #collisionList
end

-- Check for collisions at the player's current collision box position
function collisions.checkCollisions(player)
	local collisionX, collisionY = player.x + player.collisionOffsetX, player.y + player.collisionOffsetY
	
	-- Debug query rect when tiny
	if PlayerData.isTiny then
		-- Only log once every few seconds for specific objects if needed, 
		-- but for diagnosis we'll log most collisions briefly
		-- printDebug("🔍 checkCollisions (Tiny): x="..collisionX..", y="..collisionY..", w="..player.width..", h="..player.height .. ", offX=" .. player.collisionOffsetX)
	end
	
	return collisions.collideRect(player, collisionX, collisionY, player.width, player.height)
end

-- Check for collisions at a specific sprite position (converts to collision box position)
function collisions.checkCollisionsAt(player, spriteX, spriteY)
	local collisionX = spriteX + player.collisionOffsetX
	local collisionY = spriteY + player.collisionOffsetY
	return collisions.collideRect(player, collisionX, collisionY, player.width, player.height)
end

-- Check for collisions in a specific direction from current position
function collisions.checkCollisionsInDirection(player, direction, distance)
	local checkX, checkY = player.x, player.y
	
	if direction == "up" then
		checkY = checkY - distance
	elseif direction == "down" then
		checkY = checkY + distance
	elseif direction == "left" then
		checkX = checkX - distance
	elseif direction == "right" then
		checkX = checkX + distance
	end
	
	return collisions.checkCollisionsAt(player, checkX, checkY)
end

-- Get all objects within a radius of the player (uses collision box center)
function collisions.getObjectsInRadius(player, radius)
	local centerX = player.x + player.collisionOffsetX + player.width / 2
	local centerY = player.y + player.collisionOffsetY + player.height / 2
	
	-- Create a square area around the player
	local x = centerX - radius
	local y = centerY - radius
	local w = radius * 2
	local h = radius * 2
	
	local collisionList, count = collisions.collideRect(player, x, y, w, h)
	
	-- Filter by actual distance for circular radius
	local filtered = {}
	for i = 1, count do
		local collision = collisionList[i]
		local objCenterX = collision.x + collision.width / 2
		local objCenterY = collision.y + collision.height / 2
		
		local distance = math.sqrt((centerX - objCenterX)^2 + (centerY - objCenterY)^2)
		if distance <= radius then
			collision.distance = distance
			table.insert(filtered, collision)
		end
	end
	
	return filtered, #filtered
end


-- Pure function for BUMP filters (no side effects)
function collisions.getType(player, other)
	if other.class and (other.class.name == "Enemy" or other.class.name == "Brocorat") then
		return 'cross'
	elseif other.class and other.class.name == "CrewMember" then
		return 'cross'
	elseif other.class and other.class.name == "Box" then
		return 'touch'
	elseif other.isTrigger then
		return 'cross'
	elseif other.class and other.class.name == 'Items' then
		return 'cross'
	elseif other.isProp then
		if other.isHole or other.isSlime or other.type == 'minifier' then
			return 'cross'
		elseif other.isTube then
			return PlayerData.isTiny and 'cross' or 'touch'
		end
		return 'touch'
	elseif other.class and other.class.name == "Door" then
		return 'cross'
	end

	return 'slide'
end

-- Side-effect and logic handling
function collisions.resolve(player, other)
	if other.class and (other.class.name == "Enemy" or other.class.name == "Brocorat") then
		local enemy = other
		PlayerData.lastEnemyTouched.type = "Brocorat"
		PlayerData.lastEnemyTouched.id = enemy.id
		PlayerData.lastEnemyTouched.x = enemy.x
		PlayerData.lastEnemyTouched.y = enemy.y
		
		if not player.isInvincible then
			PlayerData.healthPoints = math.max(0, PlayerData.healthPoints - (enemy.damage or 1))
			printDebug("💥 Player hit! HP:", PlayerData.healthPoints)
			if PlayerData.healthPoints < (PlayerData.danceThresholdHP or 5) then
				collisions.fight(player)
			else
				collisions.startInvincibility(player, (Config and Config.Invincibility and Config.Invincibility.duration) or 1000)
			end
		end

	elseif other.class and other.class.name == "CrewMember" then
		-- Tiny mode: just set as current trigger
		if PlayerData.isTiny then
			player.currentTrigger = other
		else
			-- Normal mode: capture the crewmember
			if PlayerData.CrewMemberData.amountTaken == 0 then
				-- Show special dialog on first capture
				if player.dialogUI then
					player.dialogUI:addScreen("gotcha", other.sourceFeed)
				end
			end
			if other.taken then other:taken(player) end
		end

	elseif other.isTrigger then
		local trigger = other
		if trigger.type == "Cutscene" then
			PlayerData.isGaming = false
			PlayerData.isCutscene = true
			if trigger.sourceData then
				if not trigger.sourceData.customFields then trigger.sourceData.customFields = {} end
				trigger.sourceData.customFields.usedTrigger = true
			end
			local sceneManager = require 'sceneManager'
			local gs = sceneManager.getScene("game")
			if gs and gs.removeTrigger then gs.removeTrigger(trigger) end
		elseif trigger.type == "Search" or trigger.type == "Call" or trigger.type == nil then
			player.currentTrigger = trigger
		elseif trigger.type == "Story" then
			PlayerData.isGaming = false
			if player.dialogUI then player.dialogUI:addScreen(trigger.script) end
			if trigger.sourceData then
				if not trigger.sourceData.customFields then trigger.sourceData.customFields = {} end
				trigger.sourceData.customFields.usedTrigger = true
			end
			local sceneManager = require 'sceneManager'
			local gs = sceneManager.getScene("game")
			if gs and gs.removeTrigger then gs.removeTrigger(trigger) end
		elseif trigger.type == "Counter" then
			PlayerData.storyCounter = (PlayerData.storyCounter or 0) + 1
			local sceneManager = require 'sceneManager'
			local gs = sceneManager.getScene("game")
			if gs and gs.removeTrigger then gs.removeTrigger(trigger) end
		end

	elseif other.class and other.class.name == 'Items' then
		local item = other
		if item.type == 'keycard' then
			collisions.grabKey(player, item.keyNumber or 1)
			item:removeAll()
		elseif item.type == 'lamp' then
			collisions.grabLamp(player)
			item:removeAll()
		elseif item.type == 'radio' then
			collisions.grabRadio(player)
			item:removeAll()
		elseif item.type == 'notes' then
			collisions.grabNotes(player, item.grants)
			item:removeAll()
		elseif item.type == 'itemgift' or item.type == 'itemGift' then
			collisions.grabItemGift(player, item.grants)
			item:removeAll()
		elseif item.type == 'bag' or item.type == 'honk' then
			collisions.grabBag(player)
			item:removeAll()
		elseif item.type == 'tools' then
			collisions.grabTools(player)
			item:removeAll()
		elseif item.type == 'boots' then
			collisions.grabBoots(player)
			item:removeAll()
		elseif item.type == 'plunger' then
			collisions.grabPlunger(player)
			item:removeAll()
		end

	elseif other.isProp and other.isHole then
		if PlayerData.items.hasBoots == true and PlayerData.battery > 0 then
			local bat = Config and Config.Battery or {}
		collisions.drainBattery(player, PlayerData.isTiny and (bat.drainHoleTiny or 0.2) or (bat.drainHoleNormal or 0.5))
		else
			collisions.fallBelow(player)
		end
	
	elseif other.isProp and other.type == 'minifier' then
		player.currentMinifier = other
		PlayerData.readyToShrink = true

	elseif other.isProp and other.isTube then
		if PlayerData.isTiny == true then
			local tubeCenterX = other.x + 16
			if math.abs(player.x - tubeCenterX) < 10 then
				collisions.riseAbove(player)
			end
		end
	end
end

-- Backward compatibility wrapper for the filter
function collisions.response(player, other)
	return collisions.getType(player, other)
end

-- Helper functions for vertical navigation using neighbourLevels

-- Check if vertical movement is allowed based on DoorsConnection permissions
local function canMoveVertically(currentRoom, direction)
	if not currentRoom or not currentRoom.customFields then
		return false
	end
	
	local doorsConnection = currentRoom.customFields.DoorsConnection or {}
	
	-- Map direction symbols to permission strings
	local directionMap = {
		["<"] = "lower",  -- Fall downwards
		[">"] = "upper"   -- Climb upwards
	}
	
	local requiredPermission = directionMap[direction]
	if not requiredPermission then
		return false
	end
	
	-- Check if permission exists in DoorsConnection array
	for _, allowed in ipairs(doorsConnection) do
		if allowed:lower() == requiredPermission then
			return true
		end
	end
	
	return false
end

-- Find a neighbor room by direction in the neighbourLevels array
local function findNeighborByDirection(currentRoom, direction)
	if not currentRoom or not currentRoom.neighbourLevels then
		return nil
	end
	
	for _, neighbor in ipairs(currentRoom.neighbourLevels) do
		if neighbor.dir == direction then
			return neighbor
		end
	end
	
	return nil
end

function collisions.fallBelow(player)
	if not levelsLDTK then
		printDebug("❌ Player:fallBelow() failed: levelsLDTK is nil!")
		return
	end
	
	-- Get current room data using PlayerData.floor index
	local currentRoomIndex = PlayerData.floor
	if not currentRoomIndex or not levelsLDTK[currentRoomIndex] then
		printDebug("❌ Player:fallBelow() failed: Invalid room index " .. tostring(currentRoomIndex))
		return
	end
	
	local currentRoom = levelsLDTK[currentRoomIndex]
	
	-- 1. Check permission: Does this room allow falling to lower floor?
	if not canMoveVertically(currentRoom, "<") then
		printDebug("❌ Player:fallBelow() failed: Room " .. currentRoom.identifier .. " doesn't have 'Lower' permission")
		return
	end
	
	-- 2. Find the lower neighbor using direction "<"
	local lowerNeighbor = findNeighborByDirection(currentRoom, "<")
	if not lowerNeighbor then
		printDebug("❌ Player:fallBelow() failed: No lower neighbor found in neighbourLevels for " .. currentRoom.identifier)
		return
	end
	
	-- 3. Get the levelIid of the lower room
	local nextLevelIid = lowerNeighbor.levelIid
	
	printDebug("🕳️ Player:fallBelow() -> " .. nextLevelIid .. " from " .. currentRoom.identifier)

	-- 4. Preserve exact player position (lands at same X,Y in the lower room)
	PlayerData.playerSpawn.x = player.x
	PlayerData.playerSpawn.y = player.y

	-- 5. Trigger level transition (no enterDirection so spawn is not overridden)
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")
	if gameScene then
		gameScene.changeLevel(nextLevelIid, nil, player, nil, "animated", "transitionFall")
	end
end

function collisions.riseAbove(player)
	if not levelsLDTK then
		printDebug("❌ Player:riseAbove() failed: levelsLDTK is nil!")
		return
	end
	
	-- Get current room data using PlayerData.floor index
	local currentRoomIndex = PlayerData.floor
	if not currentRoomIndex or not levelsLDTK[currentRoomIndex] then
		printDebug("❌ Player:riseAbove() failed: Invalid room index " .. tostring(currentRoomIndex))
		return
	end
	
	local currentRoom = levelsLDTK[currentRoomIndex]
	
	-- 1. Check permission: Does this room allow climbing to upper floor?
	if not canMoveVertically(currentRoom, ">") then
		printDebug("❌ Player:riseAbove() failed: Room " .. currentRoom.identifier .. " doesn't have 'Upper' permission")
		return
	end
	
	-- 2. Find the upper neighbor using direction ">"
	local upperNeighbor = findNeighborByDirection(currentRoom, ">")
	if not upperNeighbor then
		printDebug("❌ Player:riseAbove() failed: No upper neighbor found in neighbourLevels for " .. currentRoom.identifier)
		return
	end
	
	-- 3. Get the levelIid of the upper room
	local nextLevelIid = upperNeighbor.levelIid
	
	printDebug("🚀 Player:riseAbove() -> " .. nextLevelIid .. " from " .. currentRoom.identifier)

	-- 4. Preserve exact player position (appears at same X,Y in the upper room)
	PlayerData.playerSpawn.x = player.x
	PlayerData.playerSpawn.y = player.y

	-- 5. Trigger level transition (no enterDirection so spawn is not overridden)
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")
	if gameScene then
		gameScene.changeLevel(nextLevelIid, nil, player, nil, "animated", "transitionFall")
	end
end

function collisions.drainBattery(player, amount)
	local batteryFloor = (Config and Config.Battery and Config.Battery.floor) or 10
	PlayerData.battery = math.max(batteryFloor, PlayerData.battery - amount)
end

function collisions.startInvincibility(player, durationMs)
	player.isInvincible = true
	local Timer = require 'libraries/hump/timer'
	Timer.after(durationMs / 1000, function()
		player.isInvincible = false
	end)
end

function collisions.fight(player)
	printDebug("⚔️ Player:fight() triggered!")
end

function collisions.startSliding(player, direction)
	if PlayerData.isSliding then return end

	if player.slideBounce then
		if not player.manualMovement then
			return
		else
			player.slideBounce = false
		end
	end

	local dx, dy = 0, 0
	if direction == "up" then dy = -1
	elseif direction == "down" then dy = 1
	elseif direction == "left" then dx = -1
	elseif direction == "right" then dx = 1
	end

	if dx == 0 and dy == 0 then
		dy = 1 -- Fallback just in case
	end

	printDebug("🧊 Player:startSliding(" .. tostring(direction) .. ")")
	PlayerData.isSliding = true
	player.slideDX = dx
	player.slideDY = dy
end

-- Grab helpers
function collisions.grabKey(player, num) PlayerData.keys[num] = true end
function collisions.grabLamp(player)
	PlayerData.items.hasLamp = true
	PlayerData.skills.canFlash = true
	local FXshadow = require 'entities.UI.FXshadow'
	FXshadow.markDirty()
end
function collisions.grabRadio(player) PlayerData.items.hasRadio = true end
function collisions.grabTools(player) PlayerData.items.hasTools = true end
function collisions.grabBoots(player) 
	PlayerData.items.hasBoots = true 
	PlayerData.skills.canDash = true
end
function collisions.grabPlunger(player) 
	PlayerData.items.hasPlunger = true 
	PlayerData.skills.canPlungerang = true
	PlayerData.activeItem = 3 -- Auto-equip plunger
	printDebug("🪠 Plunger collected and equipped!")
end
function collisions.grabBag(player) PlayerData.items.hasBag = true end

function collisions.grabNotes(player, grants)
	if grants then
		for key, val in grants:gmatch("([^:,]+):([^:,]+)") do
			local boolVal = (val == "true")
			PlayerData.skills[key] = boolVal
		end
	end
	PlayerData.items.hasNotes = true
end

function collisions.grabItemGift(player, grants)
	if grants then
		for key, val in grants:gmatch("([^:,]+):([^:,]+)") do
			local boolVal = (val == "true")
			PlayerData.items[key] = boolVal
		end
	end
end

return collisions
