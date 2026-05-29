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
local conditionEval = require 'utilities.conditionEval'


local FXshadow    = require 'entities.UI.FXshadow'
local ComicPlayer = require 'entities.UI.ComicPlayer'
local SanitySystem = require 'entities.player.sanity'

-- Load comic data (defines global `comics` table and Panels stubs)
require 'assets.comics.comicsData'

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
	tileSize = (Config and Config.Tiles and Config.Tiles.size) or 16,
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
	-- NPCs
	npcs = {},
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
	globalLightAmount = 0,    -- 0 = full bright, 1 = full dark
	-- Room index: iid string -> levelsLDTK index (built at startup for O(1) lookup)
	roomsByIid = {}
}

local padding = 8

-- MARK: Trigger Helpers
-- Returns (scriptName, isTerminal) for a trigger.
-- Evaluates conditionalScripts top-to-bottom. Falls back to trigger.script.
local function getTriggerScript(trigger)
	if trigger.conditionalScripts and #trigger.conditionalScripts > 0 then
		local scriptName, isTerminal = conditionEval.evaluateTrigger(trigger.conditionalScripts)
		if scriptName then
			return scriptName, isTerminal
		end
	end
	local isTerminalFallback = (trigger.type ~= "Search")
	return trigger.script, isTerminalFallback
end

function gameScene.clearCurrentRoom()
	printDebug("🧹 Clearing current room entities...")
	gameScene.roomImage       = nil
	gameScene.foregroundImage = nil
	
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

	-- Clear NPCs
	for _, npc in ipairs(gameScene.npcs or {}) do npc:remove() end
	gameScene.npcs = {}
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

local function handleTriggerActivation(trigger, script, isTerminal)
	if not script then return end

	-- Prevent double activation if already used in this interaction
	if trigger.isCurrentlyActive then return end

	local isOneTime = isTerminal or false
	local cleanScript = script

	if script:sub(-1) == "!" then
		isOneTime = true
		cleanScript = script:sub(1, -2)
	end
	
	-- Mark as active to prevent loop
	trigger.isCurrentlyActive = true
	
	if trigger.type == "Counter" then
		PlayerData.storyCounter = (PlayerData.storyCounter or 0) + 1
		isOneTime = true
		printDebug("📈 Story Counter incremented: " .. PlayerData.storyCounter)
	elseif trigger.type == "Cutscene" then
		printDebug("🎬 Triggering cutscene: " .. cleanScript)
		if comics and comics[cleanScript] then
			PlayerData.isGaming   = false
			PlayerData.isCutscene = true
			ComicPlayer.start(comics[cleanScript], function()
				PlayerData.isGaming   = true
				PlayerData.isCutscene = false
			end)
		else
			printDebug("⚠️ Comic not found: " .. cleanScript)
		end
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


-- MARK: Room Index
-- Build roomsByIid hash for O(1) UUID lookup
function gameScene.buildRoomIndex()
	gameScene.roomsByIid = {}
	if not levelsLDTK then return end
	for roomId, roomData in pairs(levelsLDTK) do
		if roomData.uniqueIdentifer then
			gameScene.roomsByIid[roomData.uniqueIdentifer] = roomId
		end
	end
	local count = 0
	for _ in pairs(gameScene.roomsByIid) do count = count + 1 end
	printDebug("📦 Room index built: " .. count .. " entries")
end

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

	-- Build room index for O(1) IID lookups
	gameScene.buildRoomIndex()

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
	-- Garantizar estado limpio de diálogo al entrar (safety net para transiciones abruptas)
	if gameScene.player and gameScene.player.dialogUI then
		gameScene.player.dialogUI:reset()
	end
	PlayerData.isTalking = false
	-- Set PlayerData gaming status
	PlayerData.isGaming = true
	gameScene.hasActed = false  -- reset so first room load won't auto-save

	-- Full reload of current floor state
	if gameScene.transitionData then
		local td = gameScene.transitionData
		gameScene.transitionData = nil
		printDebug("Performing deferred level change during transition enter")
		gameScene.performChangeLevel(td.iid, td.dir, td.px, td.py)
	else
		-- Normal entry (e.g. from Title) - Load from save or defaults
		-- Room 407 = level 4, room 7 (the starting room, same as Playdate Floor407)
		local startRoom = PlayerData.saveLevel or 7
		local startLevel = PlayerData.actualLevel or 4
		
		-- Restore player position (playerSpawn is source of truth, x/y is fallback for old saves)
		local spawnX = (PlayerData.playerSpawn and PlayerData.playerSpawn.x) or PlayerData.x or 200
		local spawnY = (PlayerData.playerSpawn and PlayerData.playerSpawn.y) or PlayerData.y or 120
		gameScene.player:moveTo(spawnX, spawnY)

		-- Force sync player dimensions
		gameScene.player:syncDimensions()

		gameScene.setFloor(startLevel, startRoom)

		printDebug("gameScene: Entered (Normal Load)")
	end
end

function gameScene.exit()
	printDebug("🚪 gameScene: Exited")
	-- Forzar cierre del diálogo antes de salir para que no persista entre sesiones
	if gameScene.player and gameScene.player.dialogUI then
		gameScene.player.dialogUI:reset()
	end
	PlayerData.isTalking = false
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

	-- Mark this room as visited (drives the minimap)
	if gameScene.currentLevelData and gameScene.currentLevelData.customFields then
		gameScene.currentLevelData.customFields.visited = true
	end

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

	-- Mark: npcs - Create NPCs from level data
	gameScene.loadNPCs()

	-- Update room info in pause menu
	gameScene.updateRoomInfo()

	-- Read darkness config from the new room
	SanitySystem.reset()   -- restart 2s tick on each room entry
	if gameScene.currentLevelData and gameScene.currentLevelData.customFields then
		local cf = gameScene.currentLevelData.customFields
		PlayerData.isInDarkness = cf.shadow == true
		gameScene.globalLightAmount = cf.light or 0
		printDebug("🌑 Darkness: " .. tostring(PlayerData.isInDarkness) .. " | Light: " .. tostring(gameScene.globalLightAmount))
	end
	FXshadow.markDirty()

	-- Room-entry comic: play once if the room has a comic_name field
	if gameScene.currentLevelData and gameScene.currentLevelData.customFields then
		local cf = gameScene.currentLevelData.customFields
		if cf.comic_name and cf.play == "Enter" and not cf.comic_wasPlayed and comics and comics[cf.comic_name] then
			PlayerData.isGaming   = false
			PlayerData.isCutscene = true
			ComicPlayer.start(comics[cf.comic_name], function()
				PlayerData.isGaming   = true
				PlayerData.isCutscene = false
				cf.comic_wasPlayed    = true
			end)
		end
	end
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
			local x = enemy.x - (enemy.width or 32) / 2
			local y = enemy.y - (enemy.height or 32) / 2
			local speed = cf.speed or 1
			local dead = cf.dead or false
			local id = enemy.iid

			if not dead then
				printDebug("🥦 Creating Brocorat at (" .. x .. ", " .. y .. ")")
				local brocorat = Brocorat(x, y, nil, nil, gameScene.player, id, gameScene.world)
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
			local crewID = cf.crewID   -- "CM001", "CM002", etc.

			-- Check if already captured (keyed by crewID string, not iid)
			if not PlayerData.CrewMemberData.idNumbers[crewID] then
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

-- Removes the enemy with the given id from the world and the enemies table.
-- Called by DanceScene on win to clean up the defeated enemy.
function gameScene.findAndKillEnemyById(id)
	if not id then return end
	for i, enemy in ipairs(gameScene.enemies) do
		if enemy.id == id then
			if gameScene.world and gameScene.world.hasItem and gameScene.world:hasItem(enemy) then
				gameScene.world:remove(enemy)
			end
			table.remove(gameScene.enemies, i)
			printDebug("⚔️ findAndKillEnemyById: killed enemy id=" .. tostring(id))
			return
		end
	end
	printDebug("⚠️ findAndKillEnemyById: enemy id=" .. tostring(id) .. " not found")
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

	printDebug("🔍 DEBUG: Loading doors for " .. gameScene.currentLevelData.identifier)

	if not gameScene.currentLevelData.entities or not gameScene.currentLevelData.entities.Doors then
		printDebug("ℹ️ No Doors entities in this level")
		return
	end

	-- Calculate tile-map offsets (same formula used everywhere else)
	local startX = VIRTUAL_WIDTH  / 2 - (gameScene.mapWidth  * gameScene.tileSize) / 2
	local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * gameScene.tileSize) / 2

	-- Build door parameter tables via utility (handles IID lookup + leadsTo resolution)
	local doorParams = utilities.CreateDoorsFromLDTK(
		gameScene.currentLevelData, startX, startY, gameScene.world
	)

	-- Instantiate Door objects from the parameter tables
	for _, p in ipairs(doorParams) do
		-- Resolve nextLevelIid from neighbourLevels using the original connection direction
		local connectionToDir = { Top = "n", Down = "s", Left = "w", Right = "e" }
		local cardinalDir = connectionToDir[p.direction]
		local nextLevelIid = nil
		local neighbourLevels = gameScene.currentLevelData.neighbourLevels
		if cardinalDir and neighbourLevels then
			for _, neighbour in ipairs(neighbourLevels) do
				if neighbour.dir == cardinalDir then
					nextLevelIid = neighbour.levelIid
					break
				end
			end
		end

		-- Resolve human-readable destination room number (for debug display)
		local nextRoomNumber = nil
		if nextLevelIid and levelsLDTK then
			local destIdx = gameScene.roomsByIid[nextLevelIid]
			if destIdx and levelsLDTK[destIdx] and levelsLDTK[destIdx].customFields then
				nextRoomNumber = levelsLDTK[destIdx].customFields.roomNumber
			end
		end

		local door = Door.new(
			p.x,
			p.y,
			p.width,
			p.height,
			p.direction,    -- DoorsConnection string; Door.new converts it internally
			"open",
			nextLevelIid,
			gameScene.world,
			nextRoomNumber,
			p.leadsTo       -- resolved levelsLDTK index
		)
		-- Carry lock metadata onto the door instance
		door.isLocked  = p.isLocked
		door.keyNumber = p.keyNumber
		door.iid       = p.iid
		table.insert(gameScene.doors, door)

		printDebug("🚪 Created door: " .. tostring(p.direction) ..
			" -> " .. tostring(nextLevelIid) ..
			" (Room " .. tostring(nextRoomNumber) .. ")" ..
			" leadsTo[" .. tostring(p.leadsTo) .. "]" ..
			" at (" .. door.x .. ", " .. door.y .. ")" ..
			" [" .. door.width .. "x" .. door.height .. "]")
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
	local startX = VIRTUAL_WIDTH / 2 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * gameScene.tileSize) / 2

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
			local cf = entity.customFields or {}
			-- Use custom field type or entity name to resolve prop type
			local propType = PropItem:getConfigKey(cf.type or typeName)
			if propType then
				local x, y = entity.x, entity.y
				local nocollide = cf.nocollider or false
				local isDestroyed = cf.destroyed or false
				local id = entity.iid

				local prop = PropItem(x, y, propType, nil, nocollide, isDestroyed, id, gameScene.world)
				prop.sourceData = entity
				prop.zIndex = prop.y + prop.height

				table.insert(gameScene.props, prop)
			end
		end
	end
	
	printDebug("✅ Loaded " .. #gameScene.props .. " props")

end

-- MARK: Items Loading

-- Returns true if an item of this type should be spawned based on PlayerData.
-- Mirrors the Playdate shouldGenerate logic: PlayerData is the source of truth,
-- not a per-entity "collected" flag (which is stale across session resets).
local itemRequirements = {
	lamp    = "hasLamp",
	radio   = "hasRadio",
	notes   = "hasNotes",
	boots   = "hasBoots",
	plunger = "hasPlunger",
}

local function shouldSpawnItem(itemType, keyNumber, grants)
	if itemType == "keycard" then
		-- Spawn if the player doesn't already have this specific key
		local keyNum = keyNumber or 1
		return not PlayerData.keys[keyNum]

	elseif grants and grants ~= "" then
		-- Spawn if the player doesn't already have ALL the granted items/skills
		for pair in string.gmatch(grants, "([^,]+)") do
			local key = string.match(pair, "([^:]+):")
			if key then
				key = key:gsub("%s+", "")
				if PlayerData.items[key] == true or PlayerData.skills[key] == true then
					return false  -- player already has this grant
				end
			end
		end
		return true

	elseif itemRequirements[itemType] then
		-- Spawn if the player doesn't already have the item
		return PlayerData.items[itemRequirements[itemType]] ~= true

	end

	-- Unknown type — spawn it (bag, honk, tools, etc.)
	return true
end

function gameScene.loadItems()
	if not gameScene.currentLevelData then return end

	for _, item in ipairs(gameScene.items) do
		if item.removeAll then item:removeAll() end
	end
	gameScene.items = {}

	local entities = gameScene.currentLevelData.entities
	if not entities then return end

	local startX = VIRTUAL_WIDTH / 2 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * gameScene.tileSize) / 2

	local validItemTypes = {
		boots=true, plunger=true, lamp=true, notes=true, keycard=true, itemgift=true
	}

	for typeName, entityList in pairs(entities) do
		for _, entity in ipairs(entityList) do
			local cf = entity.customFields or {}
			local resolvedType = (cf.type or typeName):lower()
			local isKey  = (typeName == "Keys")
			local isItem = not isKey and validItemTypes[resolvedType]

			if isItem or isKey then
				local itemType
				if isKey then
					itemType = "keycard"
				else
					itemType = resolvedType
				end

				local keyNumber = cf.KeyNumber or cf.keyNumber
				local grants    = cf.grants

				if shouldSpawnItem(itemType, keyNumber, grants) then
					local worldX = entity.x + startX
					local worldY = entity.y + startY

					local item = Items(worldX, worldY, itemType, keyNumber, grants, gameScene.world)
					item.sourceData = entity

					table.insert(gameScene.items, item)
					printDebug("🎁 Item spawned: " .. itemType .. " at (" .. worldX .. ", " .. worldY .. ")")
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
	
	local startX = VIRTUAL_WIDTH / 2 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * gameScene.tileSize) / 2
	
	for _, triggerEntity in ipairs(entities.Triggers) do
		local cf = triggerEntity.customFields or {}
		
		-- Skip if this trigger has already been used (persisted state)
		if cf.usedTrigger then
			goto continue
		end
		
		local trigger = {
			iid = triggerEntity.iid,
			x = triggerEntity.x + startX - triggerEntity.width / 2,
			y = triggerEntity.y + startY - triggerEntity.height / 2,
			width = triggerEntity.width,
			height = triggerEntity.height,
			script = cf.script,
			type = cf.type,
			conditionalScripts = cf.conditionalScripts or {},
			usedTrigger = cf.usedTrigger or false,
			mapPercent = cf.mapPercent or 0,
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

-- MARK: NPC Loading
function gameScene.loadNPCs()
	if not gameScene.currentLevelData then return end
	gameScene.npcs = {}
	local entities = gameScene.currentLevelData.entities
	if not entities or not entities.NPC then return end
	local NPC = require 'entities.props.npc'
	local startX = VIRTUAL_WIDTH / 2 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = VIRTUAL_HEIGHT / 2 - (gameScene.mapHeight * gameScene.tileSize) / 2
	for _, npcEntity in ipairs(entities.NPC) do
		local cf = npcEntity.customFields or {}
		local npc = NPC.new(gameScene.world, npcEntity.x + startX, npcEntity.y + startY,
			cf.type or "computer", npcEntity.iid, gameScene.currentRoom, cf.sourceFeed or 0)
		table.insert(gameScene.npcs, npc)
	end
	printDebug("✅ Loaded " .. #gameScene.npcs .. " NPCs")
end


-- MARK: Level Transition
function gameScene.performChangeLevel(nextLevelIid, enterDirection, capturedX, capturedY)
	printDebug("🔄 Changing level to IID: " .. nextLevelIid .. " (dir: " .. tostring(enterDirection) .. ", capturedX: " .. tostring(capturedX) .. ", capturedY: " .. tostring(capturedY) .. ")")
	
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
	
	
	-- Reposition player based on entry direction (prevRoom logic)
	-- Lateral (left/right): preserve Y from previous room, fix X to opposite edge
	-- Vertical (top/down):  preserve X from previous room, fix Y to opposite edge
	if enterDirection and gameScene.player then
		local sc = (Config and Config.Doors and Config.Doors.spawnCoords) or {
			top   = {x=196, y=196},
			down  = {x=196, y=32 },
			right = {x=32,  y=116},
			left  = {x=364, y=116},
		}
		local spawnX, spawnY
		if     enterDirection == "top"   then
			spawnX = capturedX or sc.top.x
			spawnY = sc.top.y
		elseif enterDirection == "down"  then
			spawnX = capturedX or sc.down.x
			spawnY = sc.down.y
		elseif enterDirection == "right" then
			spawnX = sc.right.x
			spawnY = capturedY or sc.right.y
		elseif enterDirection == "left"  then
			spawnX = sc.left.x
			spawnY = capturedY or sc.left.y
		end

		if spawnX and spawnY then
			PlayerData.playerSpawn.x = spawnX
			PlayerData.playerSpawn.y = spawnY
			PlayerData.lastRoom = enterDirection
			gameScene.player:moveTo(spawnX, spawnY)
			printDebug("📍 Player spawn: (" .. spawnX .. ", " .. spawnY .. ") entering from " .. enterDirection)
		end
	end
end

function gameScene.changeLevel(nextLevelIid, enterDirection, px, py, transitionType, animationName)
	-- Defer the level change to avoid breaking BUMP physics loops
	gameScene.pendingLevelChange = {
		iid = nextLevelIid,
		dir = enterDirection,
		px  = px,
		py  = py,
		transitionType = transitionType or "fade",
		animationName = animationName
	}
	printDebug("⏳ Level change queued for: " .. nextLevelIid .. " (Transition: " .. tostring(transitionType) .. ")")
end


function gameScene.loadFloor()
	if not gameScene.currentLevelData then
		printDebug("❌ ERROR: No level data loaded. Call setFloor() first.")
		return
	end

	local cf       = gameScene.currentLevelData.customFields
	local tileIdx  = cf.tile  or 1
	local level    = cf.level or 4
	local floorDir = 'assets/images/rooms/floor' .. level .. '/'

	printDebug("📍 Loading tilemap index: " .. tileIdx)

	-- Background PNG (drawn behind everything)
	local bgPath = floorDir .. 'room_' .. tileIdx .. '.png'
	local ok, img = pcall(love.graphics.newImage, bgPath)
	gameScene.roomImage = ok and img or nil
	if not ok then printDebug("⚠️ Room image not found: " .. bgPath) end

	-- Foreground PNG (drawn above entities, below HUD) — only when the room needs it
	gameScene.foregroundImage = nil
	if cf.hasForeground then
		local fgPath = floorDir .. 'foreground_' .. tileIdx .. '.png'
		local fok, fimg = pcall(love.graphics.newImage, fgPath)
		gameScene.foregroundImage = fok and fimg or nil
		if not fok then printDebug("⚠️ Foreground image not found: " .. fgPath) end
	end

	-- Tile matrix → collision only (passed to loadWalls via gameScene.tileMapData)
	gameScene.tileMapData = tileMapData[tileIdx]
	if gameScene.tileMapData then
		gameScene.mapHeight = #gameScene.tileMapData
		-- Tilemap rows have a trailing 0-padding element (26 wide instead of 25).
		-- Using #tileData[1] = 26 would give startX = 200-(26*16)/2 = -8,
		-- shifting all wall colliders 8px left of the room image.
		gameScene.mapWidth  = 25
	end
end

function gameScene.drawFloor()
	if gameScene.roomImage then
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(gameScene.roomImage, 0, 0)
	end
end

function gameScene.drawForeground()
	if gameScene.foregroundImage then
		love.graphics.setColor(1, 1, 1)
		love.graphics.draw(gameScene.foregroundImage, 0, 0)
	end
end

function gameScene.update(dt)
	-- Comic cutscene takes full control while active
	if ComicPlayer.isActive() then
		ComicPlayer.update(dt)
		return
	end

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

		-- Update NPCs
		for _, npc in ipairs(gameScene.npcs or {}) do npc:update(dt) end

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

		-- Sanity tick (every 2s)
		SanitySystem.update(dt)

	-- Check for pending level changes (safe to do here)
		if gameScene.pendingLevelChange then
			local plc = gameScene.pendingLevelChange
			gameScene.pendingLevelChange = nil
			
			-- Store data for the enter() call that will come mid-transition
			gameScene.transitionData = {
				iid = plc.iid,
				dir = plc.dir,
				px  = plc.px,
				py  = plc.py,
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

	-- Add NPCs
	for _, npc in ipairs(gameScene.npcs or {}) do
		table.insert(drawables, { obj = npc, y = npc.zIndex or (npc.spriteY + npc.spriteH), type = "npc" })
	end

	-- Sort by Y position (back to front)
	table.sort(drawables, function(a, b) return a.y < b.y end)
	
	-- Draw all entities in sorted order
	for _, drawable in ipairs(drawables) do
		if drawable.type == "npc" then
			drawable.obj:draw()
		else
			drawable.obj:draw(gameScene.debugMode)
		end
	end
	
	-- Foreground PNG — occludes entities, drawn above the player
	gameScene.drawForeground()

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

	-- Comic cutscene draws over everything
	if ComicPlayer.isActive() then
		ComicPlayer.draw()
	end
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
				local script, isTerminal = getTriggerScript(item)
				if script then
					printDebug("🔍 Manually triggering: " .. script .. " (Type: " .. tostring(item.type) .. ")")
					handleTriggerActivation(item, script, isTerminal)
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
					local script, isTerminal = getTriggerScript(item)
					if script then
						printDebug("🎭 Automatically triggering: " .. script .. " (Type: " .. tostring(item.type) .. ")")
						handleTriggerActivation(item, script, isTerminal)
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
	if ComicPlayer.isActive() then
		ComicPlayer.keypressed(key)
		return
	end

	-- Si está hablando, AButton avanza el diálogo
	if PlayerData.isTalking then
		if Input.is(key, "AButton") then
			gameScene.player:displayDialog()
			return
		end
	else
		-- AButton interactúa con triggers
		if Input.is(key, "AButton") then
			gameScene.checkTriggerInteraction()
		end

		-- BButton activa el item equipado (plungerang, dash, flash, etc.)
		if Input.is(key, "BButton") then
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
		-- BButton o pause cierra el menú de equipo
		if Input.is(key, "BButton") or Input.is(key, "pause") then
			PlayerData.isGaming = true
			PlayerData.isEquiping = false
		else
			InGameMenu:keypressed(key)
		end
	elseif Input.is(key, "menuOpen") and PlayerData.isGaming and PlayerData.items.hasDWatch then
		-- Abre menú de equipo (evento sintético del hold timer de AButton)
		PlayerData.isGaming = false
		PlayerData.isEquiping = true
		if PlayerData.activeItem == 0 or PlayerData.activeItem == nil then
			InGameMenu:nextItem()
		end
	elseif Input.is(key, "pause") and not PlayerData.isTalking then
		gameScene.pauseMenu:show()
	elseif Input.is(key, "resize") then
		PlayerData.battery = 100
		FXshadow.markDirty()
		printDebug("🔋 DEBUG: Battery charged to 100")
	end
end

function gameScene.gamepadInput(input)
	-- Cutscene takes full control
	if ComicPlayer.isActive() then
		ComicPlayer.gamepadInput()
		return
	end

	-- Crank via right stick
	local cd = Input.getCrankDelta()
	if cd ~= 0 and gameScene.player and gameScene.player.handleCrankInput then
		gameScene.player:handleCrankInput(cd)
	end

	-- Let pause menu handle gamepad input first
	local action = gameScene.pauseMenu:gamepadInput(input)
	if action then
		-- Handle menu actions
		gameScene.handleMenuAction(action)
		return
	end
	
	-- Pass gamepad input to In-Game Menu or game
	if PlayerData.isEquiping then
		if Input.wasPressed("menuOpen") or Input.wasPressed("BButton") then
			-- Close Menu on B or Y
			PlayerData.isGaming = true
			PlayerData.isEquiping = false
		else
			InGameMenu:gamepadInput(input)
		end
	elseif not gameScene.pauseMenu:isVisible() then
		if Input.wasPressed("menuOpen") and PlayerData.isGaming and PlayerData.items.hasDWatch then
			-- Open In-Game Menu for equipment (requires D-Watch, only while gaming)
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
		if Input.wasPressed("AButton") then
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
