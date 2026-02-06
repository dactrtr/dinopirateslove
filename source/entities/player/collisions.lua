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

-- Comprehensive collision response logic
function collisions.response(player, other)
	-- Debug: print collisions with props
	if other.isProp then
		-- printDebug("📍 Colliding with prop:", other.type, "isHole:", other.isHole)
	end

	if other.class and (other.class.name == "Enemy" or other.class.name == "Brocorat") then
		local enemy = other
		-- validate candance also
		PlayerData.lastEnemyTouched.type = "Brocorat"
		PlayerData.lastEnemyTouched.id = enemy.id
		PlayerData.lastEnemyTouched.x = enemy.x
		PlayerData.lastEnemyTouched.y = enemy.y
		
		-- Add damage logic
		if not player.isInvincible then
			PlayerData.healthPoints = math.max(0, PlayerData.healthPoints - (enemy.damage or 1))
			printDebug("💥 Player hit by " .. (other.class.name) .. "! HP:", PlayerData.healthPoints)
			
			-- Trigger dance only if HP < threshold
			if PlayerData.healthPoints < (PlayerData.danceThresholdHP or 5) then
				collisions.fight(player)
			else
				collisions.startInvincibility(player, 1000) -- 1 second cooldown
			end
		end
		
		return 'cross' -- overlap

	elseif other.class and other.class.name == "CrewMember" then
		-- Validate having the capture bag
		if PlayerData.CrewMemberData.amountTaken == 0 then
			if other.crewId == 'CM001' then
				-- custom screen here after validating the crewId
			end
			
			if player.dialogUI then
				player.dialogUI:addScreen("gotcha") -- default screen for the 1st time
			end
		end
		if other.taken then other:taken() end
		return 'cross'

	elseif other.class and other.class.name == "Box" then
		return 'touch' -- freeze

	elseif other.isTrigger then
		local trigger = other
		if trigger.type == "Cutscene" then
			-- Cutscenes trigger automatically
			PlayerData.isGaming = false
			PlayerData.isCutscene = true
			
			-- Persistence handled in gameScene
			if trigger.sourceData then
				if not trigger.sourceData.customFields then trigger.sourceData.customFields = {} end
				trigger.sourceData.customFields.usedTrigger = true
			end
			
			local sceneManager = require 'sceneManager'
			local gs = sceneManager.getScene("game")
			if gs and gs.removeTrigger then gs.removeTrigger(trigger) end

		elseif trigger.type == "Search" then
			player.currentTrigger = trigger
		elseif trigger.type == "Call" then
			player.currentTrigger = trigger
	elseif trigger.type == "Story" then
		PlayerData.isGaming = false
		if player.dialogUI then
			player.dialogUI:addScreen(trigger.script)
		end
		
		-- Mark as used in persistent data
		if trigger.sourceData then
			if not trigger.sourceData.customFields then trigger.sourceData.customFields = {} end
			trigger.sourceData.customFields.usedTrigger = true
		end
		
		local sceneManager = require 'sceneManager'
		local gs = sceneManager.getScene("game")
		if gs and gs.removeTrigger then gs.removeTrigger(trigger) end
		elseif trigger.type == nil then
			player.currentTrigger = trigger
		elseif trigger.type == "Counter" then
			PlayerData.storyCounter = (PlayerData.storyCounter or 0) + 1
			local sceneManager = require 'sceneManager'
			local gs = sceneManager.getScene("game")
			if gs and gs.removeTrigger then gs.removeTrigger(trigger) end
		end
		return 'cross'

	elseif other.class and other.class.name == 'Items' then
		local item = other
		if item.type == 'keycard' then
			local keyNumber = item.keyNumber or 1
			item:remove()
			collisions.grabKey(player, keyNumber)
			return 'cross'
		elseif item.type == 'lamp' then
			item:remove()
			collisions.grabLamp(player)
			return 'cross'
		elseif item.type == 'radio' then
			item:remove()
			collisions.grabRadio(player)
			return 'cross'
		elseif item.type == 'notes' then
			local grants = item.grants
			item:remove()
			collisions.grabNotes(player, grants)
			return 'cross'
		elseif item.type == 'itemgift' or item.type == 'itemGift' then
			local grants = item.grants
			item:remove()
			collisions.grabItemGift(player, grants)
			return 'cross'
		elseif item.type == 'bag' then
			item:remove()
			collisions.grabBag(player)
			return 'cross'
		elseif item.type == 'honk' then
			item:remove()
			collisions.grabBag(player)
			return 'cross'
		elseif item.type == 'tools' then
			item:remove()
			collisions.grabTools(player)
			return 'cross'
		elseif item.type == 'boots' then
			item:remove()
			collisions.grabBoots(player)
			return 'cross'
		elseif item.type == 'plunger' then
			item:remove()
			collisions.grabPlunger(player)
			return 'cross'
		end
		return 'cross'

	elseif other.isProp and other.isHole then
		printDebug("🕳️ HOLE collision detected!")
		-- If player has boots with battery, can walk over the hole
		if PlayerData.items.hasBoots == true and PlayerData.battery > 0 then
			if PlayerData.isTiny == true then
				collisions.drainBattery(player, 0.2)
			else
				collisions.drainBattery(player, 0.5)
			end
			return 'cross'
		else
			-- Without boots or without battery = fall
			printDebug("🕳️ Player:fallBelow() - no boots or battery!")
			collisions.fallBelow(player)
			return 'cross'
		end
	
	elseif other.isProp and other.isSlime then
		-- If player has plunger boots, can walk over slime (no battery required)
		if PlayerData.items.hasPlunger == true then
			return 'cross'
		else
			-- Without plunger = slide
			collisions.startSliding(player, PlayerData.direction)
			return 'cross'
		end
	
	elseif other.isProp and other.type == 'minifier' then
		player.currentMinifier = other
		PlayerData.readyToShrink = true
		return 'cross'

	elseif other.isProp and other.isTube then
		-- Pneumatic tube, allow climbing up if player is tiny
		if PlayerData.isTiny == true then
			-- Refinement: Only trigger if player is relatively centered on the tube
			-- Tube is 32x32 tile, collider is 16px wide centered (offset 8)
			-- Tube center X = other.x + 16 (since other.x is top-left of 32px tile)
			local tubeCenterX = other.x + 16
			local dist = math.abs(player.x - tubeCenterX)
			
			if dist < 6 then -- Player must be within 6px of the center
				collisions.riseAbove(player)
				return 'cross'
			else
				-- If tiny but not centered, just overlap without rising
				return 'cross'
			end
		else
			return 'touch' -- freeze
		end

	elseif other.isProp then
		return 'touch' -- freeze
	
	elseif other.class and other.class.name == "Door" then
		return 'cross'
	end

	return 'slide'
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
	
	-- 4. Trigger level transition
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")
	if gameScene then
		gameScene.changeLevel(nextLevelIid, "down", player, 0.5)
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
	
	-- 4. Trigger level transition
	local sceneManager = require 'sceneManager'
	local gameScene = sceneManager.getScene("game")
	if gameScene then
		gameScene.changeLevel(nextLevelIid, "top", player, 0.5)
	end
end

function collisions.drainBattery(player, amount)
	PlayerData.battery = math.max(0, PlayerData.battery - amount)
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
	printDebug("🧊 Player:startSliding(" .. tostring(direction) .. ")")
end

-- Grab helpers
function collisions.grabKey(player, num) PlayerData.keys[num] = true end
function collisions.grabLamp(player) PlayerData.items.hasLamp = true end
function collisions.grabRadio(player) PlayerData.items.hasRadio = true end
function collisions.grabTools(player) PlayerData.items.hasTools = true end
function collisions.grabBoots(player) 
	PlayerData.items.hasBoots = true 
	PlayerData.skills.canDash = true
end
function collisions.grabPlunger(player) 
	PlayerData.items.hasPlunger = true 
	PlayerData.skills.canPlungerang = true
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
