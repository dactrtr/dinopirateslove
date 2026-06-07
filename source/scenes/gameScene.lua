local sceneManager = require "sceneManager"
local Timer = require 'libraries/hump/timer'
local bump = require 'libraries/bump'
local Player = require 'entities.player'
local PropItem = require 'entities.props.propItem'
local Items = require 'entities.Items'
local Brocorat = require 'entities.Brocorat'
local CrewMember = require 'entities.CrewMember'
local Door = require 'entities.Door'
local ProcDoor = require 'entities.props.Door'
local PortalDoor = require 'entities.props.PortalDoor'
local WallPlug = require 'entities.props.WallPlug'
local DoorHandler = require 'DoorHandler'
local utilities = require 'utilities'
local InteractionHUD = require 'entities.UI.interactionHUD'
local playerGrapple = require 'entities.player.grapple'
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
	-- Portal doors (link host rooms to paired secret rooms by PortalID)
	portals = {},
	-- Wall plugs (covers for unconnected door openings in procedural rooms)
	wallPlugs = {},
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
	suppressInteractionHUD = false,   -- true while the grapple crankClock HUD owns the indicator
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

	-- Clear portal doors
	for _, portal in ipairs(gameScene.portals or {}) do
		if gameScene.world and gameScene.world:hasItem(portal) then
			gameScene.world:remove(portal)
		end
	end
	gameScene.portals = {}

	-- Clear wall plugs
	for _, plug in ipairs(gameScene.wallPlugs or {}) do
		if gameScene.world and gameScene.world:hasItem(plug) then
			gameScene.world:remove(plug)
		end
	end
	gameScene.wallPlugs = {}

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

-- MARK: Procedural run-graph helpers

-- Point gameScene.currentRoom/currentLevelData at the template for a graph node.
function gameScene.bindNode(node)
	local template = node and node.poolRoom
	if not template then return false end
	for i, lvl in ipairs(levelsLDTK) do
		if lvl == template then
			gameScene.currentRoom = i
			gameScene.currentLevelData = lvl
			PlayerData.floor = i  -- Sync for collisions.lua
			PlayerData.saveLevel  = lvl.customFields.roomNumber
			PlayerData.actualRoom = lvl.customFields.roomNumber
			PlayerData.actualLevel = lvl.customFields.level
			lvl.customFields.visited = true
			return true
		end
	end
	return false
end

-- Compute the player spawn for the room being entered, based on the door we left
-- through (PlayerData.lastRoom = exit side, PlayerData.lastDoorCross = which door on
-- that side). Ported from DOCS MazeScene.lua:132-194. Writes PlayerData.playerSpawn
-- unless PlayerData.returningInPlace is set (portal/fight return keeps its own spawn).
function gameScene.computeSpawn(node)
	local template = node and node.poolRoom
	if not template then return end

	-- Entry side = opposite of the door we left. Among that side's doors, pick the one
	-- whose cross-axis center matches the door we used. Fresh run → first authored door.
	local entrySide = PlayerData.lastRoom and MapGenerator.opposite(PlayerData.lastRoom) or nil
	local spawnDoor, spawnSide
	if entrySide then
		local sideDoors = MapGenerator.doorsForSide(template, entrySide)
		if #sideDoors > 0 then
			spawnSide = entrySide
			local cross = PlayerData.lastDoorCross
			if cross then
				local horizontal = (entrySide == "top" or entrySide == "down")
				local bestDist
				for _, de in ipairs(sideDoors) do
					local c = horizontal and de.x or de.y
					local dist = math.abs(c - cross)
					if not bestDist or dist < bestDist then spawnDoor, bestDist = de, dist end
				end
			else
				spawnDoor = sideDoors[1]
			end
		end
	end
	if not spawnDoor then
		local doors = template.entities and template.entities.Doors
		if doors and doors[1] then
			spawnDoor = doors[1]
			spawnSide = (spawnDoor.customFields and spawnDoor.customFields.DoorsConnection or ""):lower()
		end
	end

	if spawnDoor and not PlayerData.returningInPlace then
		local inset = Config.Doors.spawnInset
		-- The player sprite is 48x48 anchored at its centre, but its collide rect is
		-- offset within it. Align the player's body to the door's centre on the cross
		-- axis, pushing it 'inset' inward on the main axis (away from the door).
		local cr = Config.Player and Config.Player.collideRect or { x = 12, y = 24, w = 24, h = 24 }
		local spriteHalf = 24
		local bodyDX = (cr.x + cr.w / 2) - spriteHalf
		local bodyDY = (cr.y + cr.h / 2) - spriteHalf
		local sx, sy = spawnDoor.x, spawnDoor.y
		if spawnSide == "left" then
			sx = spawnDoor.x + inset
			sy = spawnDoor.y - bodyDY
		elseif spawnSide == "right" then
			sx = spawnDoor.x - inset
			sy = spawnDoor.y - bodyDY
		elseif spawnSide == "top" then
			sy = spawnDoor.y + inset
			sx = spawnDoor.x - bodyDX
		elseif spawnSide == "down" then
			sy = spawnDoor.y - inset
			sx = spawnDoor.x - bodyDX
		end
		PlayerData.playerSpawn.x = sx
		PlayerData.playerSpawn.y = sy
	end
	PlayerData.returningInPlace = false
end

-- Door/portal crossing entry point: consume the pending node, bind it, and run the
-- same-scene transition. sceneManager.startTransition("game","game",...) re-runs
-- gameScene.enter() at its midpoint (sceneManager.lua:147-148), which re-binds the
-- node and rebuilds the room via reloadCurrentRoom — so the room is rebuilt exactly
-- once, after the transition swaps. We set a flag so enter() takes the node path.
function gameScene.enterPendingNode()
	gameScene.pendingNodeTransition = true
	sceneManager.startTransition("game", "game", "slide")
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

	gameScene.pendingNodeTransition = nil
	gameScene.endgameTriggered = false

	-- Procedural: resolve the room from the active run graph. Consume the node a door/
	-- portal (or title NewGame / save Continue) staged as pending, bind it, spawn at the
	-- entry door, then rebuild the room. Falls back to starting a fresh run if no node.
	if RunState then
		RunState.consumePending()
		if not RunState.currentNode() then
			RunState.startRun()
			RunState.consumePending()
		end
		gameScene.bindNode(RunState.currentNode())
		gameScene.computeSpawn(RunState.currentNode())

		-- Endgame: entering the final room (revealed once all crew are recruited) ends the
		-- run. We flag it here and fire the transition from update() once the room is active
		-- — firing now would clobber the in-progress scene transition.
		local curNode = RunState.currentNode()
		gameScene.pendingEndgame = (curNode and curNode.content and curNode.content.isFinal) or false

		local spawnX = (PlayerData.playerSpawn and PlayerData.playerSpawn.x) or PlayerData.x or 200
		local spawnY = (PlayerData.playerSpawn and PlayerData.playerSpawn.y) or PlayerData.y or 120
		gameScene.player:moveTo(spawnX, spawnY)
		gameScene.player:syncDimensions()

		gameScene.reloadCurrentRoom()
		PlayerData.x = gameScene.player.x
		PlayerData.y = gameScene.player.y
		PlayerData.direction = 'idle'
		printDebug("gameScene: Entered (procedural node " .. tostring(RunState.currentNodeId) .. ")")
		return
	end

	-- No RunState available — should never happen (RunState is a global module loaded
	-- at boot). Start a fresh run as a safety net rather than the removed fixed-map path.
	printDebug("⚠️ gameScene.enter: RunState unavailable — cannot load a procedural room")
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

-- Enemies and crew are rolled per-run by the generator and live on the current node:
--   node.content.enemies  — which enemies are active this run (already rolled)
--   node.cleared.enemies  — enemies killed earlier this run (don't respawn on revisit)
--   node.content.crewId    — the crew identity assigned to this room this run
--   node.cleared.crewTaken — true once captured this run
function gameScene.loadEnemies()
	gameScene.enemies = {}
	gameScene.crewMembers = {}

	local node = RunState and RunState.currentNode()
	if not node then
		printDebug("ℹ️ loadEnemies: no current run node")
		return
	end

	node.cleared = node.cleared or {}
	node.cleared.enemies = node.cleared.enemies or {}
	node.content = node.content or {}

	-- Enemies from node content. The generator gives center coords (LDtk); Brocorat
	-- expects top-left, so convert by half the 32px sprite. e.key is the stable id used
	-- to mark the kill in node.cleared (so it stays dead on revisit within the run).
	for _, e in ipairs(node.content.enemies or {}) do
		if node.cleared.enemies[e.key] then
			-- Killed earlier this run: leave the slot empty (no corpse sprite in this
			-- port's props sheet — see Phase 2 report note).
			printDebug("💀 Enemy " .. tostring(e.key) .. " already cleared this run, skipping")
		elseif e.kind == "Brocorat" then
			local x = e.x - 16
			local y = e.y - 16
			local brocorat = Brocorat(x, y, e.speed, nil, gameScene.player, e.key, gameScene.world)
			brocorat.runNode = node
			table.insert(gameScene.enemies, brocorat)
		else
			-- Bosscolli and other kinds not yet ported to the LÖVE build.
			printDebug("ℹ️ loadEnemies: skipping unported enemy kind " .. tostring(e.kind))
		end
	end

	-- Crew: spawn the assigned identity if not already captured this run (or meta).
	if node.content.crewId and not (node.cleared and node.cleared.crewTaken) then
		local cs = node.content.crewSpawn or { x = 200, y = 120 }
		local crewId = node.content.crewId
		if not PlayerData.CrewMemberData.idNumbers[crewId] then
			-- Synthesize a marker carrying the assigned identity so CrewMember picks the
			-- right hat/dialog (it reads data.customFields.crewID / roomNumber).
			local data = {
				customFields = {
					crewID = crewId,
					roomNumber = gameScene.currentLevelData
						and gameScene.currentLevelData.customFields.roomNumber or nil,
				},
			}
			local iid = "node" .. tostring(node.id) .. "-crew"
			local crewMember = CrewMember(cs.x, cs.y, gameScene.world, gameScene.player, iid, data)
			crewMember.runNode = node
			table.insert(gameScene.crewMembers, crewMember)
			printDebug("🏴‍☠️ Spawned crew " .. crewId .. " for node " .. tostring(node.id))
		end
	end

	printDebug("✅ Loaded " .. #gameScene.enemies .. " enemies, " .. #gameScene.crewMembers .. " crewmembers")
end

-- Removes the enemy with the given id from the world and the enemies table.
-- Called by DanceScene on win to clean up the defeated enemy.
function gameScene.findAndKillEnemyById(id)
	if not id then return end
	for i, enemy in ipairs(gameScene.enemies) do
		if enemy.id == id then
			-- Record the kill on the run node so it stays dead on revisit within the run.
			local node = enemy.runNode or (RunState and RunState.currentNode())
			if node then
				node.cleared = node.cleared or {}
				node.cleared.enemies = node.cleared.enemies or {}
				node.cleared.enemies[id] = { x = enemy.x, y = enemy.y }
			end
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

-- Doors & wall plugs are driven by the active run-graph node: a door is created only
-- on sides the graph connected (node.edges); every other authored door opening is
-- sealed with a WallPlug. Crossing a door transitions to its target node.
function gameScene.loadDoors()
	-- Clear existing doors
	for _, d in ipairs(gameScene.doors or {}) do d:remove() end
	gameScene.doors = {}
	-- Clear existing wall plugs
	for _, p in ipairs(gameScene.wallPlugs or {}) do p:remove() end
	gameScene.wallPlugs = {}
	-- Clear existing portal doors
	for _, p in ipairs(gameScene.portals or {}) do p:remove() end
	gameScene.portals = {}

	local node = RunState and RunState.currentNode()
	if not node then
		printDebug("ℹ️ loadDoors: no current run node")
		return
	end

	ProcDoor.createFromNode(node, gameScene.world, gameScene.doors)
	WallPlug.createFromNode(node, gameScene.world, gameScene.wallPlugs)
	PortalDoor.createFromNode(node, gameScene.world, gameScene.portals)

	printDebug("🚪 doors:" .. #gameScene.doors .. " plugs:" .. #gameScene.wallPlugs ..
		" portals:" .. #gameScene.portals)
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

	-- Utilities (microwave/minifier) only appear if the generator rolled them for this
	-- run's node (keyed by the authored entity iid).
	local node = RunState and RunState.currentNode()
	local utilities = (node and node.content and node.content.utilities) or nil

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

				-- Gate utilities by the per-run roll: skip minifier/microwave not selected.
				local isUtility = (propType == "minifier" or propType == "microwave")
				if not (isUtility and not (utilities and utilities[id])) then
					local prop = PropItem(x, y, propType, nil, nocollide, isDestroyed, id, gameScene.world)
					prop.sourceData = entity
					prop.zIndex = prop.y + prop.height

					table.insert(gameScene.props, prop)
				end
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

				-- spawnConditions: a per-run render gate (e.g. {"run>=4","items.hasLamp"}).
				-- nil/empty = always allowed, so authored items without it are unaffected.
				local conditionsOk = Conditions.met(cf.spawnConditions or cf.SpawnConditions)

				if conditionsOk and shouldSpawnItem(itemType, keyNumber, grants) then
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

		-- spawnConditions: per-run render gate (same as items). nil/empty = allowed.
		-- The trigger's conditionalScripts (which dialog to show) are still evaluated
		-- later on interaction; this only gates whether the trigger is created at all.
		if not Conditions.met(cf.spawnConditions or cf.SpawnConditions) then
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
	-- Endgame: the player has entered the final room (full crew recruited). End the run.
	-- Run complete (full roster → final room): play the end credits, then title.
	if gameScene.pendingEndgame and not gameScene.endgameTriggered then
		gameScene.endgameTriggered = true
		gameScene.pendingEndgame = false
		printDebug("🏁 Run complete — endgame → credits")
		if RunState then RunState.clear() end
		sceneManager.startTransition("game", "credits", "slide")
		return
	end

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

		-- Grapple charge indicator (crankClock), shown once the charge is armed.
		if gameScene.player and gameScene.player.isGrappleCharging
			and playerGrapple.isArmed(gameScene.player) and gameScene.interactionHUD then
			gameScene.interactionHUD:setState("crankClock")
			gameScene.interactionHUD:setVisible(true)
			gameScene.suppressInteractionHUD = true
		else
			gameScene.suppressInteractionHUD = false
		end

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

	-- Add wall plugs (baked brick canvas, depth-sorted as props)
	for _, plug in ipairs(gameScene.wallPlugs or {}) do
		table.insert(drawables, { obj = plug, y = plug.zIndex or (plug.y + plug.height), type = "plug" })
	end

	-- Add doors (invisible except in debug; drawn last so debug rects overlay)
	for _, door in ipairs(gameScene.doors or {}) do
		table.insert(drawables, { obj = door, y = door.zIndex or (door.y + door.height), type = "door" })
	end

	-- Add portal doors (invisible except in debug, like doors)
	for _, portal in ipairs(gameScene.portals or {}) do
		table.insert(drawables, { obj = portal, y = portal.zIndex or (portal.y + portal.height), type = "portal" })
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

	-- Draw player HUD (battery, health, sanity) above player
	if gameScene.playerHud and gameScene.player then
		gameScene.playerHud:draw(gameScene.player)
	end

	-- Draw interaction HUD icons above player
	if gameScene.interactionHUD and gameScene.player then
		gameScene.interactionHUD:draw(gameScene.player.x, gameScene.player.y)
	end

	-- Draw dialog UI above HUD
	if gameScene.player and gameScene.player.dialogUI then
		gameScene.player.dialogUI:draw()
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

	-- Minifier: press A while standing on it to lock in and start transforming.
	if PlayerData.readyToShrink and not PlayerData.isMinifying and PlayerData.isGaming then
		gameScene.player:startMinifying()
		return true
	end

	return false
end

-- Handle automatic triggers
function gameScene.checkAutomaticTriggers()
	if not gameScene.player or PlayerData.isTalking or PlayerData.isCutscene or PlayerData.isMinifying then return end
	
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

		-- BButton: cancela el minifier si está bloqueado, si no inicia la carga
		-- del plungerang/grapple (el disparo se resuelve al soltar B).
		if Input.is(key, "BButton") then
			if PlayerData.isMinifying then
				gameScene.player:finishMinifying()
			elseif gameScene.player then
				playerGrapple.beginCharge(gameScene.player)
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

function gameScene.keyreleased(key)
	if not (Input.is(key, "BButton") and gameScene.player) then return end
	-- During a blocking UI state, cancel any in-progress charge (fire nothing) so
	-- the player can't get stuck mid-charge. Otherwise resolve normally
	-- (endCharge fires a grapple if armed, else a tap-plunge — works in light or dark).
	if ComicPlayer.isActive() or PlayerData.isTalking or PlayerData.isEquiping
		or (gameScene.pauseMenu and gameScene.pauseMenu:isVisible()) then
		playerGrapple.cancelCharge(gameScene.player)
	else
		playerGrapple.endCharge(gameScene.player)
	end
end

function gameScene.gamepadInput(input)
	-- Cutscene takes full control
	if ComicPlayer.isActive() then
		ComicPlayer.gamepadInput()
		return
	end

	-- Crank via right stick → grapple charge while charging, else minifier
	local cd = Input.getCrankDelta()
	if cd ~= 0 and gameScene.player then
		if gameScene.player.isGrappleCharging then
			playerGrapple.addCrankDelta(gameScene.player, cd)
		elseif gameScene.player.handleCrankInput then
			gameScene.player:handleCrankInput(cd)
		end
	end

	-- B release: resolve a grapple charge / tap-plunge regardless of menu/talk state
	-- so the player can't get stuck mid-charge. Cancel (no fire) during blocking UI.
	if Input.wasReleased("BButton") and gameScene.player and not PlayerData.isMinifying then
		if PlayerData.isTalking or PlayerData.isEquiping or ComicPlayer.isActive()
			or (gameScene.pauseMenu and gameScene.pauseMenu:isVisible()) then
			playerGrapple.cancelCharge(gameScene.player)
		else
			playerGrapple.endCharge(gameScene.player)
		end
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

		-- BButton: cancel minifier if locked in, otherwise begin charge (fires on release)
		if Input.wasPressed("BButton") then
			if PlayerData.isMinifying then
				gameScene.player:finishMinifying()
			elseif gameScene.player then
				playerGrapple.beginCharge(gameScene.player)
			end
		end

		-- AButton: interact with triggers or advance dialog
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
	
	-- Check if player is on a minifier. Show the crank direction prompt:
	-- counter-clockwise to shrink (normal), clockwise to grow back (when tiny).
	if not foundTrigger and PlayerData.readyToShrink and gameScene.interactionHUD then
		gameScene.interactionHUD:setState(PlayerData.isTiny and "crankClock" or "crankAntiClock")
		gameScene.interactionHUD:setVisible(true)
		foundTrigger = true
	end
	
	if not foundTrigger and gameScene.interactionHUD and not gameScene.suppressInteractionHUD then
		gameScene.interactionHUD:setVisible(false)
	end
end

-- Handle mouse wheel input (simulating Crank)
function gameScene.wheelmoved(x, y)
	-- Only process if not talking/cutscene/paused
	if PlayerData.isTalking or PlayerData.isCutscene or (gameScene.pauseMenu and gameScene.pauseMenu:isVisible()) then
		return
	end

	if gameScene.player and gameScene.player.isGrappleCharging then
		playerGrapple.addCrankDelta(gameScene.player, y * math.rad(30))
	elseif gameScene.player and gameScene.player.handleCrankInput then
		gameScene.player:handleCrankInput(y)
	end
end

return gameScene
