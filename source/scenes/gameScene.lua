local sceneManager = require "sceneManager"
local Timer = require 'libraries/hump/timer'
local bump = require 'libraries/bump'
local Player = require 'entities.player'
local PropItem = require 'entities.props.propItem'
local Items = require 'entities.Items'
local Brocorat = require 'entities.Brocorat'
local CrewMember = require 'entities.CrewMember'
local Door = require 'entities.Door'
local DoorHandler = require 'DoorHandler'
local utilities = require 'utilities'
local InteractionHUD = require 'entities.UI.interactionHUD'
local PlayerHud = require 'entities.UI.playerHud'
local SaveSystem = require 'SaveSystem'


local FXshadow = require 'entities.UI.FXshadow'

-- Simple require for PauseMenu
local PauseMenu = require 'PauseMenu'
local InGameMenu = require 'entities.UI.InGameMenu'

-- Load level data
require 'assets.data.levels'  -- levelsLDTK
require 'assets.data.tilemap' -- tileMapData

local gameScene = {
	player = nil,
	world = nil,
	timer = nil,
	pauseMenu = nil,
	-- Floor rendering components
	tilesImage = nil,
	tileQuads = {},
	map = {},
	mapWidth = 25,  -- Updated from 16 to 25
	mapHeight = 15, -- Updated from 9 to 15
	tileSize = 16,
	-- Tilemap data storage
	tileMapData = {},
	-- Enemies
	enemies = {},
	-- CrewMembers
	crewMembers = {},
	-- Doors
	doors = {},
	-- Walls
	walls = {},
	-- Props
	props = {},
	-- Items (collectibles)
	items = {},
	-- Triggers
	triggers = {},
	-- Interaction HUD
	interactionHUD = nil,
	-- Player HUD (battery, health, sanity)
	playerHud = nil,
	-- True after the player has moved at least once (prevents auto-save on fresh New Game load)
	hasActed = false,
	-- Level management



	currentRoom = nil,        -- Index in levelsLDTK
	currentLevelData = nil,   -- Reference to current level
	-- Debug mode
	debugMode = false,        -- Toggle for debug visualizations
	-- Darkness overlay
	globalLightAmount = 0     -- 0 = full bright, 1 = full dark
}

local padding = 8

-- MARK: Trigger Helpers
local function checkCondition(condition)
	if condition == "isTiny" then return PlayerData.isTiny end
	if condition == "!isTiny" then return not PlayerData.isTiny end
	
	-- items.hasLamp
	local itemKey = condition:match("^items%.(.+)")
	if itemKey then return PlayerData.items[itemKey] end
	
	-- skills.canFlash
	local skillKey = condition:match("^skills%.(.+)")
	if skillKey then return PlayerData.skills[skillKey] end
	
	-- Numerical comparisons: battery < 20, mapPercent > 50
	local var, op, val = condition:match("([%a%d]+)([><!=]=?)(%d+)")
	if var and op and val then
		local currentVal = PlayerData[var]
		val = tonumber(val)
		if currentVal then
			if op == ">" then return currentVal > val
			elseif op == "<" then return currentVal < val
			elseif op == ">=" then return currentVal >= val
			elseif op == "<=" then return currentVal <= val
			elseif op == "==" then return currentVal == val
			elseif op == "!=" then return currentVal ~= val
			end
		end
	end
	
	return false
end

local function getTriggerScript(trigger)
	if trigger.conditionalScripts and #trigger.conditionalScripts > 0 then
		for _, entry in ipairs(trigger.conditionalScripts) do
			local condition, script = entry:match("([^:]+):(.+)")
			if condition and script then
				if checkCondition(condition) then
					return script
				end
			end
		end
	end
	
	if PlayerData.isTiny and trigger.tinyScript then
		return trigger.tinyScript
	end
	
	return trigger.script
end

function gameScene.clearCurrentRoom()
	printDebug("🧹 Clearing current room entities...")
	
	-- Clear enemies
	for _, enemy in ipairs(gameScene.enemies or {}) do
		if gameScene.world and gameScene.world:hasItem(enemy) then
			gameScene.world:remove(enemy)
		end
	end
	gameScene.enemies = {}

	-- Clear crewmembers
	for _, crewMember in ipairs(gameScene.crewMembers or {}) do
		if gameScene.world and gameScene.world:hasItem(crewMember) then
			gameScene.world:remove(crewMember)
		end
	end
	gameScene.crewMembers = {}

	-- Clear doors
	for _, door in ipairs(gameScene.doors or {}) do
		if gameScene.world and gameScene.world:hasItem(door) then
			gameScene.world:remove(door)
		end
	end
	gameScene.doors = {}
	
	-- Clear walls
	for _, wall in ipairs(gameScene.walls or {}) do
		if gameScene.world and gameScene.world:hasItem(wall) then
			gameScene.world:remove(wall)
		end
	end
	gameScene.walls = {}
	
	-- Clear props
	for _, prop in ipairs(gameScene.props or {}) do
		if gameScene.world and gameScene.world:hasItem(prop) then
			gameScene.world:remove(prop)
		end
		if prop.remove then prop:remove() end
	end
	gameScene.props = {}
	
	-- Clear items
	for _, item in ipairs(gameScene.items or {}) do
		if item.removeAll then
			item:removeAll()
		end
	end
	gameScene.items = {}

	-- Clear triggers
	for _, trigger in ipairs(gameScene.triggers or {}) do
		if gameScene.world and gameScene.world:hasItem(trigger) then
			gameScene.world:remove(trigger)
		end
	end
	gameScene.triggers = {}
end

function gameScene.performRemoveTrigger(trigger)
	for i, t in ipairs(gameScene.triggers) do
		if t == trigger then
			if gameScene.world and gameScene.world:hasItem(trigger) then
				gameScene.world:remove(trigger)
			end
			table.remove(gameScene.triggers, i)
			break
		end
	end
end

function gameScene.removeTrigger(trigger)
	if not gameScene.pendingTriggerRemovals then
		gameScene.pendingTriggerRemovals = {}
	end
	table.insert(gameScene.pendingTriggerRemovals, trigger)
end

local function handleTriggerActivation(trigger, script)
	if not script then return end
	
	-- Prevent double activation if already used in this interaction
	if trigger.isCurrentlyActive then return end
	
	local isOneTime = false
	local cleanScript = script
	
	if script:sub(-1) == "!" then
		isOneTime = true
		cleanScript = script:sub(1, -2)
	end
	
	-- Automatic Story triggers are one-time by default if legacy field used
	if not trigger.conditionalScripts or #trigger.conditionalScripts == 0 then
		if trigger.type == "Story" or trigger.type == "Cutscene" or trigger.type == "Counter" then
			isOneTime = true
		end
	end
	
	-- Mark as active to prevent loop
	trigger.isCurrentlyActive = true
	
	if trigger.type == "Counter" then
		PlayerData.storyCounter = (PlayerData.storyCounter or 0) + 1
		isOneTime = true
		printDebug("📈 Story Counter incremented: " .. PlayerData.storyCounter)
	elseif trigger.type == "Cutscene" then
		PlayerData.isCutscene = true
		printDebug("🎬 Triggering cutscene: " .. cleanScript)
	else
		-- Default: Dialog
		if gameScene.player and gameScene.player.dialogUI then
			gameScene.player.dialogUI:addScreen(cleanScript)
		end
	end
	
	if isOneTime then
		-- Update the source data to persist the used state
		if trigger.sourceData then
			if not trigger.sourceData.customFields then
				trigger.sourceData.customFields = {}
			end
			trigger.sourceData.customFields.usedTrigger = true
			printDebug("💾 Trigger marked as used for persistence: " .. tostring(trigger.sourceData.iid))
		end
		
		gameScene.removeTrigger(trigger)
	end
end


-- MARK: Level Management Functions
function gameScene.setFloor(levelNumber, roomNumber)
	for i, levelData in ipairs(levelsLDTK) do
		if levelData.customFields.level == levelNumber and levelData.customFields.roomNumber == roomNumber then
			gameScene.currentRoom = i
			PlayerData.floor = i  -- Sync for collisions.lua
			gameScene.currentLevelData = levelsLDTK[i]
			printDebug("✅ Level loaded: " .. levelData.identifier .. " (Level " .. levelNumber .. ", Room " .. roomNumber .. ")")
			
			-- Update save data
			PlayerData.saveLevel = roomNumber
			PlayerData.actualRoom = roomNumber
			PlayerData.actualLevel = levelNumber
			
			if gameScene.player then
				PlayerData.x = gameScene.player.x
				PlayerData.y = gameScene.player.y
			end

			-- Auto-save on room entry (skip on the very first load of a fresh session)
			if gameScene.hasActed then
				printDebug("💾 gameScene: Saving state for Level " .. levelNumber .. ", Room " .. roomNumber)
				SaveSystem.save()
			end
			
			-- Trigger full visual/entity reload
			gameScene.reloadCurrentRoom()
			
			return
		end
	end
	printDebug("⚠️ Warning: Level " .. levelNumber .. ", Room " .. roomNumber .. " not found")
end


-- Placeholder levels data - you'll need to replace this with your actual levels data

function gameScene.load()
	-- Debug mode starts disabled
	DRAW_DEBUG_DOORS = false

	-- Darkness default (can be overridden per-room via customFields.light)
	gameScene.globalLightAmount = 0.7

	-- Initialize BUMP world for physics
	gameScene.world = bump.newWorld(32) -- 32 = cell size
	
	-- Initialize HUMP timer
	gameScene.timer = Timer.new()
	
	-- Create player (always same world reference)
	gameScene.player = Player(200, 120, gameScene.world)
	
	-- Initialize DoorHandler with gameScene reference
	DoorHandler.setGameScene(gameScene)
	
	-- Initialize pause menu with custom buttons for this scene
	gameScene.pauseMenu = PauseMenu.new({
		{text = "Resume", action = "resume"},
		{text = "Toggle Debug", action = "toggledebug"},
		{text = "Return to Title", action = "title"},
		{text = "Quit Game", action = "quit"}
	})
	
	-- Load interaction HUD icons
	gameScene.interactionHUD = InteractionHUD()

	-- Load player HUD (battery, health, sanity)
	gameScene.playerHud = PlayerHud()
	
	-- Load In-Game menu
	InGameMenu:load()
end

function gameScene.enter()
	-- Set PlayerData gaming status
	PlayerData.isGaming = true
	gameScene.hasActed = false  -- reset so first room load won't auto-save

	-- Full reload of current floor state
	if gameScene.transitionData then
		local td = gameScene.transitionData
		gameScene.transitionData = nil
		printDebug("Performing deferred level change during transition enter")
		gameScene.performChangeLevel(td.iid, td.dir, td.player, td.ratio)
	else
		-- Normal entry (e.g. from Title) - Load from save or defaults
		local startRoom = PlayerData.saveLevel or 2
		local startLevel = PlayerData.actualLevel or 4
		
		-- Restore player position (playerSpawn is source of truth, x/y is fallback for old saves)
		local spawnX = (PlayerData.playerSpawn and PlayerData.playerSpawn.x) or PlayerData.x or 200
		local spawnY = (PlayerData.playerSpawn and PlayerData.playerSpawn.y) or PlayerData.y or 120
		gameScene.player:moveTo(spawnX, spawnY)

		-- Force sync player dimensions
		gameScene.player:syncDimensions()

		gameScene.setFloor(startLevel, startRoom)
		
		-- Full reload of current floor state
		gameScene.reloadCurrentRoom()
		
		printDebug("gameScene: Entered (Normal Load)")
	end
end

function gameScene.exit()
	printDebug("🚪 gameScene: Exited")
	-- Capture exit position for possible return from DanceScene
	if gameScene.player then
		PlayerData.playerExit.x = gameScene.player.x
		PlayerData.playerExit.y = gameScene.player.y
	end
	-- Save on exit if gaming
	if PlayerData.isGaming then
		SaveSystem.save()
	end
end

function gameScene.reloadCurrentRoom()
	-- Helper to perform a full reload of the current room
	
	-- First, clear everything to avoid leaks
	gameScene.clearCurrentRoom()
	
	-- Mark: floor - Load tile spritesheet and create floor
	gameScene.loadFloor()
	
	-- Mark: enemies - Create example enemies
	gameScene.loadEnemies()
	
	-- Mark: doors - Create doors from neighbourLevels
	gameScene.loadDoors()
	
	-- Mark: walls - Create walls with gaps for doors
	gameScene.loadWalls()
	
	-- Mark: props - Create props from level data
	gameScene.loadProps()
	
	-- Mark: items - Create collectible items from level data
	gameScene.loadItems()
	
	-- Mark: triggers - Create triggers from level data
	gameScene.loadTriggers()
	
	-- Update room info in pause menu
	gameScene.updateRoomInfo()

	-- Read darkness config from the new room
	if gameScene.currentLevelData and gameScene.currentLevelData.customFields then
		local cf = gameScene.currentLevelData.customFields
		PlayerData.isInDarkness = cf.shadow == true
		gameScene.globalLightAmount = cf.light or 0
		printDebug("🌑 Darkness: " .. tostring(PlayerData.isInDarkness) .. " | Light: " .. tostring(gameScene.globalLightAmount))
	end
	FXshadow.markDirty()
end

-- Update room information in pause menu
function gameScene.updateRoomInfo()
	if gameScene.pauseMenu and gameScene.currentLevelData then
		local level = gameScene.currentLevelData.customFields.level or "?"
		local room = gameScene.currentLevelData.customFields.roomNumber or "?"
		local roomName = gameScene.currentLevelData.identifier or "Unknown"
		
		local info = string.format("Level %s - Room %s", level, room)
		gameScene.pauseMenu:setRoomInfo(info)
	end
end

function gameScene.loadEnemies()
	-- Ensure we have a level loaded
	if not gameScene.currentLevelData then
		printDebug("❌ ERROR: No level data loaded for enemies.")
		return
	end
	
	-- Clear existing enemies
	gameScene.enemies = {}
	
	local entities = gameScene.currentLevelData.entities
	
	if not entities then
		printDebug("ℹ️ No entities in this level")
		return
	end
	
	-- Load Brocorat enemies
	if entities.Brocorat then
		for _, enemy in ipairs(entities.Brocorat) do
			local cf = enemy.customFields or {}
			local x, y = enemy.x, enemy.y
			local speed = cf.speed or 1
			local dead = cf.dead or false
			local id = enemy.iid
			
			if not dead then
				printDebug("🥦 Creating Brocorat at (" .. x .. ", " .. y .. ")")
				local brocorat = Brocorat(x, y, nil, speed, gameScene.player, id, gameScene.world)
				brocorat.sourceData = enemy -- Link to levelsLDTK entry
				table.insert(gameScene.enemies, brocorat)
			else
				printDebug("💀 Brocorat at (" .. x .. ", " .. y .. ") is dead, skipping")
			end
		end
	end
	
	-- Load CrewMembers
	if entities.CrewMember then
		for _, crewData in ipairs(entities.CrewMember) do
			local cf = crewData.customFields or {}
			local x, y = crewData.x, crewData.y
			local id = crewData.iid

			-- Check if already captured
			if not PlayerData.CrewMemberData.idNumbers[id] then
				printDebug("🏴‍☠️ Creating CrewMember at (" .. x .. ", " .. y .. ")")
				local crewMember = CrewMember(x, y, gameScene.world, gameScene.player, id, crewData)
				table.insert(gameScene.crewMembers, crewMember)
			else
				printDebug("✅ CrewMember at (" .. x .. ", " .. y .. ") already captured, skipping")
			end
		end
	end

	-- TODO: Add support for other enemy types (Bosscolli, etc.)

	printDebug("✅ Loaded " .. #gameScene.enemies .. " enemies, " .. #gameScene.crewMembers .. " crewmembers")
end

function gameScene.loadDoors()
	-- Ensure we have a level loaded
	if not gameScene.currentLevelData then
		printDebug("❌ ERROR: No level data loaded for doors.")
		return
	end
	
	-- Clear existing doors
	for _, door in ipairs(gameScene.doors) do
		door:remove()
	end
	gameScene.doors = {}
	
	local entities = gameScene.currentLevelData.entities
	local neighbourLevels = gameScene.currentLevelData.neighbourLevels
	
	printDebug("🔍 DEBUG: Loading doors for " .. gameScene.currentLevelData.identifier)
	
	if not entities or not entities.Doors then
		printDebug("ℹ️ No Doors entities in this level")
		return
	end
	
	-- Map DoorsConnection strings to cardinal direction codes used in neighbourLevels
	local connectionToDir = {
		Top = "n",
		Down = "s",
		Left = "w",
		Right = "e"
	}
	
	-- Create doors based on Doors entities
	for _, doorEntity in ipairs(entities.Doors) do
		local cf = doorEntity.customFields or {}
		local connection = cf.DoorsConnection -- e.g., "Down"
		local direction = connectionToDir[connection]
		
		if not direction then
			printDebug("⚠️ WARNING: Unknown DoorsConnection '" .. tostring(connection) .. "'")
		else
			-- Find the neighbour level matching this direction
			local nextLevelIid = nil
			if neighbourLevels then
				for _, neighbour in ipairs(neighbourLevels) do
					if neighbour.dir == direction then
						nextLevelIid = neighbour.levelIid
						break
					end
				end
			end
			
			if nextLevelIid then
				-- Find the room number for this IID if possible (for debug)
				local nextRoomNumber = nil
				if levelsLDTK then
					for _, room in ipairs(levelsLDTK) do
						if room.uniqueIdentifer == nextLevelIid then
							if room.customFields then
								nextRoomNumber = room.customFields.roomNumber
							end
							break
						end
					end
				end
				
				-- Calculate offsets (same as in drawFloor)
				local startX = 200 - (gameScene.mapWidth * gameScene.tileSize) / 2
				local startY = 120 - (gameScene.mapHeight * gameScene.tileSize) / 2
				
				-- Create door using entity position and dimensions
				-- We use the entity's x, y, width, height directly from LDtk, + screen offsets
				-- Subtract half dimensions to center the hitbox on the coordinate
				local door = Door.new(
					doorEntity.x + startX - doorEntity.width / 2, 
					doorEntity.y + startY - doorEntity.height / 2, 
					doorEntity.width, 
					doorEntity.height,
					connection, 
					"open", 
					nextLevelIid, 
					gameScene.world, 
					nextRoomNumber
				)
				table.insert(gameScene.doors, door)
				
				printDebug("🚪 Created door: " .. connection .. " (" .. direction .. ") -> " .. nextLevelIid .. 
					" (Room " .. tostring(nextRoomNumber) .. ") at (" .. door.x .. ", " .. door.y .. ") [" .. door.width .. "x" .. door.height .. "]")
			else
				printDebug("⚠️ WARNING: No neighbour found for door direction '" .. direction .. "'")
			end
		end
	end
	
	printDebug("✅ Loaded " .. #gameScene.doors .. " doors from entities")
end

-- MARK: Wall Creation
function gameScene.loadWalls()
	-- Clear existing walls from world
	for _, wall in ipairs(gameScene.walls) do
		if gameScene.world and gameScene.world:hasItem(wall) then
			gameScene.world:remove(wall)
		end
	end
	gameScene.walls = {}
	
	-- Ensure we have tile data
	if not gameScene.tileMapData then
		printDebug("⚠️ Warning: No tile data for wall creation")
		return
	end

	-- Calculate offsets (same as in drawFloor)
	local startX = 200 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = 120 - (gameScene.mapHeight * gameScene.tileSize) / 2

	-- Create walls from tile data
	printDebug("🧱 Generating walls from tilemap...")
	gameScene.walls = utilities.CreateTileColliders(
		gameScene.tileMapData, 
		gameScene.world, 
		gameScene.tileSize, 
		startX, 
		startY
	)
	
	printDebug("✅ Created " .. #gameScene.walls .. " optimized wall segments from tilemap")
end

-- MARK: Props Loading
function gameScene.loadProps()
	-- Ensure we have a level loaded
	if not gameScene.currentLevelData then return end
	
	-- Clear existing props
	for _, prop in ipairs(gameScene.props) do
		if prop.remove then prop:remove() end
	end
	gameScene.props = {}
	
	local entities = gameScene.currentLevelData.entities
	if not entities then return end
	
	-- Iterate over all entity types
	for typeName, entityList in pairs(entities) do
		for _, entity in ipairs(entityList) do
			-- Check if it's a prop (layer is "Props" or "Holes")
			if entity.layer == "Props" or entity.layer == "Holes" then
				local cf = entity.customFields or {}
				local x, y = entity.x, entity.y
				-- Use custom field type or entity name
				local type = PropItem:getConfigKey(cf.type or typeName) or typeName:lower()
				local nocollide = cf.nocollider or false
				local isDestroyed = cf.destroyed or false
				local id = entity.iid
				
				-- Create the prop first to get adjusted positions
				local prop = PropItem(x, y, type, nil, nocollide, isDestroyed, id, gameScene.world)
				prop.sourceData = entity -- Link to levelsLDTK entry
				
				-- Calculate zIndex based on bottom of sprite (after position adjustment)
				-- This ensures consistent depth sorting that doesn't change
				prop.zIndex = prop.y + prop.height
				
				table.insert(gameScene.props, prop)
			end
		end
	end
	
	printDebug("✅ Loaded " .. #gameScene.props .. " props")

end

-- MARK: Items Loading
function gameScene.loadItems()
	-- Ensure we have a level loaded
	if not gameScene.currentLevelData then return end
	
	-- Clear existing items
	for _, item in ipairs(gameScene.items) do
		if item.removeAll then item:removeAll() end
	end
	gameScene.items = {}
	
	local entities = gameScene.currentLevelData.entities
	if not entities then return end
	
	-- Calculate offsets (same as in drawFloor)
	local startX = 200 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = 120 - (gameScene.mapHeight * gameScene.tileSize) / 2
	
	-- Iterate over all entity types looking for items
	for typeName, entityList in pairs(entities) do
		for _, entity in ipairs(entityList) do
			-- Check if it's an item (layer is "Items")
			if entity.layer == "Items" then
				local cf = entity.customFields or {}

				-- Skip already-collected items (persisted by SaveSystem)
				if not cf.collected then
					local itemType = cf.type or typeName:lower()
					local worldX = entity.x + startX
					local worldY = entity.y + startY

					local item = Items(worldX, worldY, itemType, cf.keyNumber, cf.grants, gameScene.world)
					item.sourceData = entity

					table.insert(gameScene.items, item)
					printDebug("🎁 Created item: " .. itemType .. " at (" .. worldX .. ", " .. worldY .. ")")
				end
			end
		end
	end
	
	printDebug("✅ Loaded " .. #gameScene.items .. " items")
end

-- MARK: Triggers Loading
function gameScene.loadTriggers()
	if not gameScene.currentLevelData then return end
	
	-- Clear existing triggers
	gameScene.triggers = {}
	
	local entities = gameScene.currentLevelData.entities
	if not entities or not entities.Triggers then return end
	
	local startX = 200 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = 120 - (gameScene.mapHeight * gameScene.tileSize) / 2
	
	for _, triggerEntity in ipairs(entities.Triggers) do
		local cf = triggerEntity.customFields or {}
		
		-- Skip if this trigger has already been used (persisted state)
		if cf.usedTrigger then
			goto continue
		end
		
		local trigger = {
			x = triggerEntity.x + startX - triggerEntity.width / 2,
			y = triggerEntity.y + startY - triggerEntity.height / 2,
			width = triggerEntity.width,
			height = triggerEntity.height,
			script = cf.script,
			type = cf.type or "Search",
			conditionalScripts = cf.conditionalScripts or {},
			usedTrigger = cf.usedTrigger or false,
			mapPercent = cf.mapPercent or 0,
			tinyScript = cf.tinyScript,
			isTrigger = true,
			sourceData = triggerEntity -- Store reference to source data for persistence
		}
		
		-- Add to BUMP world as a 'cross' type
		gameScene.world:add(trigger, trigger.x, trigger.y, trigger.width, trigger.height)
		table.insert(gameScene.triggers, trigger)
		
		::continue::
	end

	
	printDebug("✅ Loaded " .. #gameScene.triggers .. " triggers")
end



-- MARK: Level Transition
function gameScene.performChangeLevel(nextLevelIid, enterDirection, player, exitRatio)
	printDebug("🔄 Changing level to IID: " .. nextLevelIid .. " (Exit Ratio: " .. tostring(exitRatio) .. ")")
	
	-- Find the level by IID
	local nextRoomIndex = nil
	for i, levelData in ipairs(levelsLDTK) do
		if levelData.uniqueIdentifer == nextLevelIid then
			nextRoomIndex = i
			break
		end
	end
	
	if not nextRoomIndex then
		printDebug("❌ ERROR: Level with IID " .. nextLevelIid .. " not found!")
		return
	end
	
	-- Update state
	gameScene.currentRoom = nextRoomIndex
	PlayerData.floor = nextRoomIndex  -- Sync for collisions.lua
	gameScene.currentLevelData = levelsLDTK[nextRoomIndex]
	
	-- Save progress
	PlayerData.saveLevel = gameScene.currentLevelData.customFields.roomNumber
	PlayerData.actualRoom = PlayerData.saveLevel
	PlayerData.actualLevel = gameScene.currentLevelData.customFields.level
	if gameScene.player then
		PlayerData.x = gameScene.player.x
		PlayerData.y = gameScene.player.y
	end
	SaveSystem.save()
	
	printDebug("✅ Switched to: " .. gameScene.currentLevelData.identifier)
	
	-- Reload level components (this also clears old ones)
	gameScene.reloadCurrentRoom()
	
	-- Update room info in pause menu

	gameScene.updateRoomInfo()
	
	
	-- Reposition player based on entry direction
	if enterDirection and gameScene.player then
		-- Map enter direction to the expected door direction in the NEW room
		local oppositeDir = {
			top = "down",
			down = "top",
			left = "right",
			right = "left"
		}
		local targetDir = oppositeDir[enterDirection]
		
		-- Find the door in the new room that we are entering from
		local entranceDoor = nil
		for _, door in ipairs(gameScene.doors) do
			if door.direction == targetDir then
				entranceDoor = door
				break
			end
		end
		
		if entranceDoor then
			-- Spawn player centered relative to the door width/height based on exitRatio
			local spawnX, spawnY
			local offset = 32 -- Offset away from the wall to prevent immediate re-trigger

			if targetDir == "top" then
				spawnX = entranceDoor.x + exitRatio * entranceDoor.width
				spawnY = entranceDoor.y + entranceDoor.height + offset
			elseif targetDir == "down" then
				spawnX = entranceDoor.x + exitRatio * entranceDoor.width
				spawnY = entranceDoor.y - offset
			elseif targetDir == "left" then
				spawnX = entranceDoor.x + entranceDoor.width + offset
				spawnY = entranceDoor.y + exitRatio * entranceDoor.height
			elseif targetDir == "right" then
				spawnX = entranceDoor.x - offset
				spawnY = entranceDoor.y + exitRatio * entranceDoor.height
			end

			-- Write to playerSpawn (source of truth) and record entry direction
			PlayerData.playerSpawn.x = spawnX
			PlayerData.playerSpawn.y = spawnY
			PlayerData.lastRoom = enterDirection

			gameScene.player:moveTo(spawnX, spawnY)
			printDebug("📍 Player aligned spawn at: (" .. spawnX .. ", " .. spawnY .. ") from " .. targetDir .. " door")
		else
			-- Fallback to old behavior if no matching door found
			printDebug("⚠️ WARNING: No " .. tostring(targetDir) .. " door found in new room. Using fallback spawn.")
			local spawn = utilities.spawnCoordinates[enterDirection]
			if spawn then
				PlayerData.playerSpawn.x = spawn.x
				PlayerData.playerSpawn.y = spawn.y
				PlayerData.lastRoom = enterDirection
				gameScene.player:moveTo(spawn.x, spawn.y)
			end
		end
	end
end

function gameScene.changeLevel(nextLevelIid, enterDirection, player, exitRatio, transitionType, animationName)
	-- Defer the level change to avoid breaking BUMP physics loops
	gameScene.pendingLevelChange = {
		iid = nextLevelIid,
		dir = enterDirection,
		player = player,
		ratio = exitRatio,
		transitionType = transitionType or "fade",
		animationName = animationName
	}
	printDebug("⏳ Level change queued for: " .. nextLevelIid .. " (Transition: " .. tostring(transitionType) .. ")")
end


function gameScene.loadFloor()
	-- Ensure we have a level loaded
	if not gameScene.currentLevelData then
		printDebug("❌ ERROR: No level data loaded. Call setFloor() first.")
		return
	end
	
	-- Load the tile spritesheet
	gameScene.tilesImage = love.graphics.newImage('assets/images/tile/tile-table-16-16.png')
	
	-- Calculate how many tiles are in the spritesheet
	local imageWidth = gameScene.tilesImage:getWidth()
	local imageHeight = gameScene.tilesImage:getHeight()
	local tilesPerRow = math.floor(imageWidth / gameScene.tileSize)
	local tilesPerCol = math.floor(imageHeight / gameScene.tileSize)
	
	-- Create quads for each tile in the spritesheet
	gameScene.tileQuads = {}
	local tileIndex = 1
	for row = 0, tilesPerCol - 1 do
		for col = 0, tilesPerRow - 1 do
			gameScene.tileQuads[tileIndex] = love.graphics.newQuad(
				col * gameScene.tileSize,
				row * gameScene.tileSize,
				gameScene.tileSize,
				gameScene.tileSize,
				imageWidth,
				imageHeight
			)
			tileIndex = tileIndex + 1
		end
	end
	
	-- Get tile index from current level's customFields
	local tileIndex = gameScene.currentLevelData.customFields.tile or 1
	printDebug("📍 Loading tilemap index: " .. tileIndex)
	
	-- Initialize tilemap data from the level's tile index
	gameScene.tileMapData = tileMapData[tileIndex]
	
	-- Create the map using tilemap data
	gameScene.renderTileMap(gameScene.tileMapData)
end

-- Convert Playdate renderTileMap function to Love2D
function gameScene.renderTileMap(tileData)
	local height = #tileData
	local width = #tileData[1]
	
	-- Update map dimensions based on tile data
	gameScene.mapHeight = height
	gameScene.mapWidth = width
	
	-- Initialize the map array
	gameScene.map = {}
	
	-- Populate map with tile data (Love2D uses 1-based indexing)
	for y = 1, height do
		gameScene.map[y] = {}
		for x = 1, width do
			-- Set tile from tileData (y,x because tileData is row-major)
			gameScene.map[y][x] = tileData[y][x]
		end
	end
end

function gameScene.drawFloor()
	if not gameScene.tilesImage or not gameScene.tileQuads then
		return
	end
	
	-- Calculate the starting position to center the map around (200, 120)
	local startX = 200 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = 120 - (gameScene.mapHeight * gameScene.tileSize) / 2
	
	-- Draw each tile in the map
	for y = 1, gameScene.mapHeight do
		for x = 1, gameScene.mapWidth do
			local tileId = gameScene.map[y][x]
			if tileId and gameScene.tileQuads[tileId] then
				local drawX = startX + (x - 1) * gameScene.tileSize
				local drawY = startY + (y - 1) * gameScene.tileSize
				
				love.graphics.draw(
					gameScene.tilesImage,
					gameScene.tileQuads[tileId],
					drawX,
					drawY
				)
			end
		end
	end
end

function gameScene.update(dt)
	-- Update pause menu
	gameScene.pauseMenu:update(dt)
	
	-- Update In-Game menu state if needed
	if PlayerData.isEquiping then
		-- Skip main game updates while equipping
	elseif not gameScene.pauseMenu:isVisible() then
		-- Update timer and player
		gameScene.timer:update(dt)
		gameScene.player:update(dt)

		-- Mark that the player has acted (unlocks auto-save for room transitions)
		if not gameScene.hasActed and (Input.isDown("up") or Input.isDown("down") or Input.isDown("left") or Input.isDown("right")) then
			gameScene.hasActed = true
		end
		
		-- Keep player collision box on screen (boundary check using collision rectangle)
		local collisionX, collisionY, collisionW, collisionH = gameScene.player:getCollisionRect()
		
		-- Calculate the required sprite position to keep collision box within bounds
		local minSpriteX = padding - gameScene.player.collisionOffsetX
		local maxSpriteX = VIRTUAL_WIDTH - padding - collisionW - gameScene.player.collisionOffsetX
		local minSpriteY = padding - gameScene.player.collisionOffsetY
		local maxSpriteY = VIRTUAL_HEIGHT - padding - collisionH - gameScene.player.collisionOffsetY
		
		-- Clamp player sprite position
		gameScene.player.x = math.max(minSpriteX, math.min(maxSpriteX, gameScene.player.x))
		gameScene.player.y = math.max(minSpriteY, math.min(maxSpriteY, gameScene.player.y))
		
		-- Update collision position in BUMP world after boundary correction
		gameScene.player:updateCollisionPosition()
		
		-- Example: Check for collisions with other objects
		local collisions, collisionCount = gameScene.player:checkCollisions()
		if collisionCount > 0 then
			-- Handle collisions here
			for i = 1, collisionCount do
				local collision = collisions[i]
				-- You can add logic based on collision.object type
				-- printDebug("Colliding with:", collision.object)
			end
		end
		
		-- Update enemies (turn-based: move when player is moving)
		for i, enemy in ipairs(gameScene.enemies) do
			enemy:update(dt)
		end

		-- Update crewmembers
		for i = #gameScene.crewMembers, 1, -1 do
			local crewMember = gameScene.crewMembers[i]
			crewMember:update(dt)
			if crewMember.isDead then
				table.remove(gameScene.crewMembers, i)
			end
		end

		-- Update items
		for i = #gameScene.items, 1, -1 do
			local item = gameScene.items[i]
			item:update(dt)
			if item.removed then
				table.remove(gameScene.items, i)
			end
		end
		
		-- Reset player movement flag only when player stops moving
		if gameScene.player.hasMoved and not gameScene.player.isMoving then
			gameScene.player.hasMoved = false
		end

		-- Handle automatic triggers
		gameScene.checkAutomaticTriggers()

		-- Update interaction HUD
		if gameScene.interactionHUD then
			gameScene.drawTriggerIcons() -- Updates visibility and state
			gameScene.interactionHUD:update(dt)
		end

		-- Update player HUD
		if gameScene.playerHud then
			gameScene.playerHud:update(dt)
		end

	-- Check for pending level changes (safe to do here)
		if gameScene.pendingLevelChange then
			local plc = gameScene.pendingLevelChange
			gameScene.pendingLevelChange = nil
			
			-- Store data for the enter() call that will come mid-transition
			gameScene.transitionData = {
				iid = plc.iid,
				dir = plc.dir,
				player = plc.player,
				ratio = plc.ratio
			}
			
			-- Start the transition via sceneManager
			printDebug("🎬 Starting scene transition: " .. tostring(plc.transitionType))
			sceneManager.startTransition("game", "game", plc.transitionType, plc.animationName)
		end
		
		-- Check for pending trigger removals
		if gameScene.pendingTriggerRemovals then
			for _, trigger in ipairs(gameScene.pendingTriggerRemovals) do
				gameScene.performRemoveTrigger(trigger)
			end
			gameScene.pendingTriggerRemovals = nil
		end
	end
end



function gameScene.draw()
	-- Draw floor first (background layer)
	gameScene.drawFloor()

	love.graphics.setColor(1, 1, 1) -- Reset color before player draw
	
	-- DEPTH SORTING: Combine all entities and sort by Y position (zIndex)
	-- This replicates Playdate's zIndex behavior
	local drawables = {}
	
	-- Add player
	table.insert(drawables, {
		obj = gameScene.player,
		y = gameScene.player.y + gameScene.player.collisionOffsetY + gameScene.player.height, -- Use bottom of collision box
		type = "player"
	})
	
	-- Add enemies
	for _, enemy in ipairs(gameScene.enemies) do
		table.insert(drawables, {
			obj = enemy,
			y = enemy.y + enemy.height, -- Use bottom of sprite
			type = "enemy"
		})
	end

	-- Add crewmembers
	for _, crewMember in ipairs(gameScene.crewMembers) do
		table.insert(drawables, {
			obj = crewMember,
			y = crewMember.y + crewMember.spriteHeight, -- Use bottom of sprite
			type = "crewmember"
		})
	end

	-- Add props
	for _, prop in ipairs(gameScene.props) do
		-- Props can have custom zIndex or use Y position
		local sortY = prop.zIndex or (prop.y + prop.height)
		table.insert(drawables, {
			obj = prop,
			y = sortY,
			type = "prop"
		})
	end
	
	-- Add items
	for _, item in ipairs(gameScene.items) do
		local sortY = item.y + item.height
		table.insert(drawables, {
			obj = item,
			y = sortY,
			type = "item"
		})
	end
	
	-- Sort by Y position (back to front)
	table.sort(drawables, function(a, b) return a.y < b.y end)
	
	-- Draw all entities in sorted order
	for _, drawable in ipairs(drawables) do
		drawable.obj:draw(gameScene.debugMode)
	end
	
	-- Darkness overlay (after all entities, before HUD/dialog)
	if PlayerData.isInDarkness and gameScene.player then
		FXshadow.draw(gameScene.player, gameScene.globalLightAmount or 0)
	end

	-- Draw dialog UI on top of everything
	if gameScene.player and gameScene.player.dialogUI then
		gameScene.player.dialogUI:draw()
	end

	-- Draw player HUD (battery, health, sanity) above player
	if gameScene.playerHud and gameScene.player then
		gameScene.playerHud:draw(gameScene.player)
	end

	-- Draw interaction HUD icons above player
	if gameScene.interactionHUD and gameScene.player then
		gameScene.interactionHUD:draw(gameScene.player.x, gameScene.player.y)
	end
	
	-- Draw all debug visualizations using utilities module

	utilities.drawDebugInfo(gameScene)
	
	InGameMenu:draw()
	gameScene.pauseMenu:draw()
end

-- Handle trigger interaction (Manual)
function gameScene.checkTriggerInteraction()
	if not gameScene.player or PlayerData.isTalking or PlayerData.isCutscene then return end
	
	-- Check what player is overlapping
	local px, py, pw, ph = gameScene.player:getCollisionRect()
	local items, len = gameScene.world:queryRect(px, py, pw, ph)
	
	for i = 1, len do
		local item = items[i]
		if item.isTrigger then
			-- Manual types or default
			if item.type == "Search" or item.type == "Call" or not item.type then
				local script = getTriggerScript(item)
				if script then
					printDebug("🔍 Manually triggering: " .. script .. " (Type: " .. tostring(item.type) .. ")")
					handleTriggerActivation(item, script)
					return true
				end
			end
		end
	end
	return false
end

-- Handle automatic triggers
function gameScene.checkAutomaticTriggers()
	if not gameScene.player or PlayerData.isTalking or PlayerData.isCutscene then return end
	
	local px, py, pw, ph = gameScene.player:getCollisionRect()
	local items, len = gameScene.world:queryRect(px, py, pw, ph)
	
	-- Track which triggers are currently overlapping
	local overlappingTriggers = {}
	
	for i = 1, len do
		local item = items[i]
		if item.isTrigger then
			overlappingTriggers[item] = true
			
			-- Automatic types
			if item.type == "Story" or item.type == "Cutscene" or item.type == "Counter" then
				if not item.isCurrentlyActive then
					local script = getTriggerScript(item)
					if script then
						printDebug("🎭 Automatically triggering: " .. script .. " (Type: " .. tostring(item.type) .. ")")
						handleTriggerActivation(item, script)
						return -- Activate only one per frame
					end
				end
			end
		end
	end
	
	-- Reset 'isCurrentlyActive' for triggers the player is NO LONGER overlapping
	for _, trigger in ipairs(gameScene.triggers) do
		if not overlappingTriggers[trigger] then
			trigger.isCurrentlyActive = false
		end
	end
end


function gameScene.keypressed(key)
	-- If talking, any 'confirm' key advances dialog
	if PlayerData.isTalking then
		if Input.is(key, "confirm") then
			gameScene.player:displayDialog()
			return
		end
	else
		-- Check for interaction on confirm keys
		if Input.is(key, "confirm") then
			gameScene.checkTriggerInteraction()
		end

		-- Action button for Plungerang
		if Input.is(key, "action") then
			if gameScene.player and gameScene.player.handleActionButton then
				gameScene.player:handleActionButton()
			end
		end
	end

	-- Let pause menu handle its own input first
	local action = gameScene.pauseMenu:keypressed(key)
	if action then
		gameScene.handleMenuAction(action)
		return
	end

	-- Game input (when menu is not shown)
	if PlayerData.isEquiping then
		-- Handle In-Game Menu inputs
		if Input.is(key, "menu") or Input.is(key, "pause") then
			PlayerData.isGaming = true
			PlayerData.isEquiping = false
		else
			InGameMenu:keypressed(key)
		end
	elseif Input.is(key, "menu") then
		-- Open In-Game Menu for equipment
		PlayerData.isGaming = false
		PlayerData.isEquiping = true
		if PlayerData.activeItem == 0 or PlayerData.activeItem == nil then
			InGameMenu:nextItem()
		end
	elseif Input.is(key, "pause") then
		gameScene.pauseMenu:show()
	elseif Input.is(key, "resize") then
		if PlayerData.readyToShrink and gameScene.player and gameScene.player.handleCrankInput then
			gameScene.player:handleCrankInput(1)
		end
	elseif Input.is(key, "dash") then
		if gameScene.player and PlayerData.skills.canDash then
			local dir = (PlayerData.direction ~= "idle") and PlayerData.direction or "right"
			gameScene.player:startDash(dir)
		end
	end
end

function gameScene.gamepadInput(input)
	-- Let pause menu handle gamepad input first
	local action = gameScene.pauseMenu:gamepadInput(input)
	if action then
		-- Handle menu actions
		gameScene.handleMenuAction(action)
		return
	end
	
	-- Pass gamepad input to In-Game Menu or game
	if PlayerData.isEquiping then
		if input.y or input.b then
			-- Close Menu on B or Y
			PlayerData.isGaming = true
			PlayerData.isEquiping = false
		else
			InGameMenu:gamepadInput(input)
		end
	elseif not gameScene.pauseMenu:isVisible() then
		if input.y then
			-- Open In-Game Menu for equipment
			PlayerData.isGaming = false
			PlayerData.isEquiping = true
			if PlayerData.activeItem == 0 or PlayerData.activeItem == nil then
				InGameMenu:nextItem()
			end
		end

		if gameScene.player and gameScene.player.handleGamepadInput then
			gameScene.player:handleGamepadInput(input)
		end
		
		-- Also check for 'A' button to interact or advance dialog
		if input.a then
			if PlayerData.isTalking then
				gameScene.player:displayDialog()
			else
				gameScene.checkTriggerInteraction()
			end
		end
	end
end


-- Handle actions returned by the pause menu
function gameScene.handleMenuAction(action)
	if action == "resume" then
		-- Menu is already hidden by the PauseMenu component
		-- Nothing else needed for resume
	elseif action == "toggledebug" then
		-- Toggle debug mode
		gameScene.debugMode = not gameScene.debugMode
		DRAW_DEBUG_DOORS = gameScene.debugMode
		printDebug("🔧 Debug mode: " .. (gameScene.debugMode and "ON" or "OFF"))
		-- Keep menu open so user can see the change
		gameScene.pauseMenu:show()
	elseif action == "title" then
		sceneManager.startTransition("game", "title", "slide")
	elseif action == "quit" then
		love.event.quit()
	end
end

-- Draw interaction HUD icons for manual triggers
function gameScene.drawTriggerIcons()
	if not gameScene.player or PlayerData.isTalking or PlayerData.isCutscene then 
		if gameScene.interactionHUD then gameScene.interactionHUD:setVisible(false) end
		return 
	end
	
	local px, py, pw, ph = gameScene.player:getCollisionRect()
	local items, len = gameScene.world:queryRect(px, py, pw, ph)
	
	local foundTrigger = false
	for i = 1, len do
		local item = items[i]
		if item.isTrigger then
			-- Manual triggers show icons
			if item.type == "Search" or item.type == "Call" or not item.type then
				if gameScene.interactionHUD then
					gameScene.interactionHUD:setState(item.type)
					gameScene.interactionHUD:setVisible(true)
					foundTrigger = true
					break
				end
			end
		end
	end
	
	-- Check if player is on a minifier
	if not foundTrigger and PlayerData.readyToShrink and gameScene.interactionHUD then
		gameScene.interactionHUD:setState("crankClock")
		gameScene.interactionHUD:setVisible(true)
		foundTrigger = true
	end
	
	if not foundTrigger and gameScene.interactionHUD then
		gameScene.interactionHUD:setVisible(false)
	end
end

-- Handle mouse wheel input (simulating Crank)
function gameScene.wheelmoved(x, y)
	-- Only process if not talking/cutscene/paused
	if PlayerData.isTalking or PlayerData.isCutscene or (gameScene.pauseMenu and gameScene.pauseMenu:isVisible()) then
		return
	end

	if gameScene.player and gameScene.player.handleCrankInput then
		gameScene.player:handleCrankInput(y)
	end
end

return gameScene
