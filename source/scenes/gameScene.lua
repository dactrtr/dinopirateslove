local sceneManager = require "sceneManager"
local Timer = require 'libraries/hump/timer'
local bump = require 'libraries/bump'
local Player = require 'entities.player'
local PropItem = require 'entities.props.propItem'
local Brocorat = require 'entities.Brocorat'
local Door = require 'entities.Door'
local DoorHandler = require 'DoorHandler'
local utilities = require 'utilities'
local InteractionHUD = require 'entities.UI.interactionHUD'
local SaveSystem = require 'SaveSystem'


-- Simple require for PauseMenu
local PauseMenu = require 'PauseMenu'

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
	-- Doors
	doors = {},
	-- Walls
	walls = {},
	-- Props
	props = {},
	-- Triggers
	triggers = {},
	-- Interaction HUD
	interactionHUD = nil,
	-- Level management



	currentRoom = nil,        -- Index in levelsLDTK
	currentLevelData = nil,   -- Reference to current level
	-- Debug mode
	debugMode = false         -- Toggle for debug visualizations
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

function gameScene.removeTrigger(trigger)
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

local function handleTriggerActivation(trigger, script)
	if not script then return end
	
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
	
	if trigger.type == "Counter" then
		PlayerData.storyCounter = (PlayerData.storyCounter or 0) + 1
		isOneTime = true
		print("📈 Story Counter incremented: " .. PlayerData.storyCounter)
	elseif trigger.type == "Cutscene" then
		PlayerData.isCutscene = true
		-- TODO: Trigger actual cutscene / comic
		print("🎬 Triggering cutscene: " .. cleanScript)
	else
		-- Default: Dialog
		if gameScene.player and gameScene.player.dialogUI then
			gameScene.player.dialogUI:addScreen(cleanScript)
		end
	end
	
	if isOneTime then
		gameScene.removeTrigger(trigger)
	end
end


-- MARK: Level Management Functions
function gameScene.setFloor(levelNumber, roomNumber)
	for i, levelData in ipairs(levelsLDTK) do
		if levelData.customFields.level == levelNumber and levelData.customFields.roomNumber == roomNumber then
			gameScene.currentRoom = i
			gameScene.currentLevelData = levelsLDTK[i]
			print("✅ Level loaded: " .. levelData.identifier .. " (Level " .. levelNumber .. ", Room " .. roomNumber .. ")")
			
			-- Update save data
			PlayerData.saveLevel = roomNumber
			-- Auto-save on room entry
			SaveSystem.save()
			
			return
		end
	end
	print("⚠️ Warning: Level " .. levelNumber .. ", Room " .. roomNumber .. " not found")
end


-- Placeholder levels data - you'll need to replace this with your actual levels data

function gameScene.load()
	-- Debug mode starts disabled
	DRAW_DEBUG_DOORS = false
	
	-- Initialize BUMP world for physics
	gameScene.world = bump.newWorld(32) -- 32 = cell size
	
	-- Initialize HUMP timer
	gameScene.timer = Timer.new()
	
	-- Set initial level (Use saved level if exists, otherwise Level 4, Room 2)
	local startRoom = PlayerData.saveLevel or 2
	local startLevel = (PlayerData.saveLevel == nil) and 4 or 4 -- Default to Level 4 for now as per original code
	gameScene.setFloor(startLevel, startRoom)
	
	-- Create player
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
	
	-- Mark: triggers - Create triggers from level data
	gameScene.loadTriggers()
	
	-- Load interaction HUD icons
	gameScene.interactionHUD = InteractionHUD()
	
	-- Update room info in pause menu



	gameScene.updateRoomInfo()
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
		print("❌ ERROR: No level data loaded for enemies.")
		return
	end
	
	-- Clear existing enemies
	gameScene.enemies = {}
	
	local entities = gameScene.currentLevelData.entities
	
	if not entities then
		print("ℹ️ No entities in this level")
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
				print("🥦 Creating Brocorat at (" .. x .. ", " .. y .. ")")
				local brocorat = Brocorat(x, y, nil, speed, gameScene.player, id, gameScene.world)
				table.insert(gameScene.enemies, brocorat)
			else
				print("💀 Brocorat at (" .. x .. ", " .. y .. ") is dead, skipping")
			end
		end
	end
	
	-- TODO: Add support for other enemy types (Bosscolli, CrewMember, etc.)
	-- if entities.Bosscolli then ... end
	-- if entities.CrewMember then ... end
	
	print("✅ Loaded " .. #gameScene.enemies .. " enemies")
end

function gameScene.loadDoors()
	-- Ensure we have a level loaded
	if not gameScene.currentLevelData then
		print("❌ ERROR: No level data loaded for doors.")
		return
	end
	
	-- Clear existing doors
	for _, door in ipairs(gameScene.doors) do
		door:remove()
	end
	gameScene.doors = {}
	
	local entities = gameScene.currentLevelData.entities
	local neighbourLevels = gameScene.currentLevelData.neighbourLevels
	
	print("🔍 DEBUG: Loading doors for " .. gameScene.currentLevelData.identifier)
	
	if not entities or not entities.Doors then
		print("ℹ️ No Doors entities in this level")
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
			print("⚠️ WARNING: Unknown DoorsConnection '" .. tostring(connection) .. "'")
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
				
				print("🚪 Created door: " .. connection .. " (" .. direction .. ") -> " .. nextLevelIid .. 
					" (Room " .. tostring(nextRoomNumber) .. ") at (" .. door.x .. ", " .. door.y .. ") [" .. door.width .. "x" .. door.height .. "]")
			else
				print("⚠️ WARNING: No neighbour found for door direction '" .. direction .. "'")
			end
		end
	end
	
	print("✅ Loaded " .. #gameScene.doors .. " doors from entities")
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
		print("⚠️ Warning: No tile data for wall creation")
		return
	end

	-- Calculate offsets (same as in drawFloor)
	local startX = 200 - (gameScene.mapWidth * gameScene.tileSize) / 2
	local startY = 120 - (gameScene.mapHeight * gameScene.tileSize) / 2

	-- Create walls from tile data
	print("🧱 Generating walls from tilemap...")
	gameScene.walls = utilities.CreateTileColliders(
		gameScene.tileMapData, 
		gameScene.world, 
		gameScene.tileSize, 
		startX, 
		startY
	)
	
	print("✅ Created " .. #gameScene.walls .. " optimized wall segments from tilemap")
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
			-- Check if it's a prop (layer is "Props")
			if entity.layer == "Props" then
				local cf = entity.customFields or {}
				local x, y = entity.x, entity.y
				local type = cf.type or typeName:lower() -- Use custom field type or entity name
				local nocollide = cf.nocollider or false
				local isDestroyed = cf.destroyed or false
				local id = entity.iid
				
				-- Create the prop first to get adjusted positions
				local prop = PropItem(x, y, type, nil, nocollide, isDestroyed, id, gameScene.world)
				
				-- Calculate zIndex based on bottom of sprite (after position adjustment)
				-- This ensures consistent depth sorting that doesn't change
				prop.zIndex = prop.y + prop.height
				
				table.insert(gameScene.props, prop)
			end
		end
	end
	
	print("✅ Loaded " .. #gameScene.props .. " props")

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
			isTrigger = true
		}
		
		-- Add to BUMP world as a 'cross' type
		gameScene.world:add(trigger, trigger.x, trigger.y, trigger.width, trigger.height)
		table.insert(gameScene.triggers, trigger)
	end

	
	print("✅ Loaded " .. #gameScene.triggers .. " triggers")
end



-- MARK: Level Transition
function gameScene.changeLevel(nextLevelIid, enterDirection, player, exitRatio)
	print("🔄 Changing level to IID: " .. nextLevelIid .. " (Exit Ratio: " .. tostring(exitRatio) .. ")")
	
	-- Find the level by IID
	local nextRoomIndex = nil
	for i, levelData in ipairs(levelsLDTK) do
		if levelData.uniqueIdentifer == nextLevelIid then
			nextRoomIndex = i
			break
		end
	end
	
	if not nextRoomIndex then
		print("❌ ERROR: Level with IID " .. nextLevelIid .. " not found!")
		return
	end
	
	-- Clear current level entities from world and memory
	
	-- Clear enemies
	for _, enemy in ipairs(gameScene.enemies) do
		if gameScene.world and enemy.x then 
			if gameScene.world:hasItem(enemy) then
				gameScene.world:remove(enemy)
			end
		end
	end
	gameScene.enemies = {}
	
	-- Clear doors
	for _, door in ipairs(gameScene.doors) do
		if gameScene.world and gameScene.world:hasItem(door) then
			gameScene.world:remove(door)
		end
	end
	gameScene.doors = {}
	
	-- Clear walls
	for _, wall in ipairs(gameScene.walls) do
		if gameScene.world and gameScene.world:hasItem(wall) then
			gameScene.world:remove(wall)
		end
	end
	gameScene.walls = {}
	
	-- Clear props
	for _, prop in ipairs(gameScene.props) do
		if gameScene.world and gameScene.world:hasItem(prop) then
			gameScene.world:remove(prop)
		end
		if prop.remove then prop:remove() end
	end
	gameScene.props = {}

	-- Clear triggers from BUMP world
	for _, trigger in ipairs(gameScene.triggers) do
		if gameScene.world and gameScene.world:hasItem(trigger) then
			gameScene.world:remove(trigger)
		end
	end
	gameScene.triggers = {}

	
	-- Set new level
	gameScene.currentRoom = nextRoomIndex
	gameScene.currentLevelData = levelsLDTK[nextRoomIndex]
	
	print("✅ Switched to: " .. gameScene.currentLevelData.identifier)
	
	-- Reload level components
	gameScene.loadFloor()
	gameScene.loadEnemies()
	gameScene.loadDoors()
	gameScene.loadWalls()
	gameScene.loadProps()
	gameScene.loadTriggers()
	
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
			local offset = 20 -- Offset away from the wall to prevent immediate re-trigger
			
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
			
			gameScene.player.x = spawnX
			gameScene.player.y = spawnY
			-- Update collision position in BUMP
			gameScene.player:updateCollisionPosition()
			print("📍 Player aligned spawn at: (" .. spawnX .. ", " .. spawnY .. ") from " .. targetDir .. " door")
		else
			-- Fallback to old behavior if no matching door found
			print("⚠️ WARNING: No " .. tostring(targetDir) .. " door found in new room. Using fallback spawn.")
			local spawn = utilities.spawnCoordinates[enterDirection]
			if spawn then
				gameScene.player.x = spawn.x
				gameScene.player.y = spawn.y
				gameScene.player:updateCollisionPosition()
			end
		end
	end
end


function gameScene.loadFloor()
	-- Ensure we have a level loaded
	if not gameScene.currentLevelData then
		print("❌ ERROR: No level data loaded. Call setFloor() first.")
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
	print("📍 Loading tilemap index: " .. tileIndex)
	
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
	
	-- Only update game if menu is not shown
	if not gameScene.pauseMenu:isVisible() then
		-- Update timer and player
		gameScene.timer:update(dt)
		gameScene.player:update(dt)
		
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
				-- print("Colliding with:", collision.object)
			end
		end
		
		-- Update enemies (turn-based: move when player is moving)
		for i, enemy in ipairs(gameScene.enemies) do
			enemy:update(dt)
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
	
	-- Sort by Y position (back to front)
	table.sort(drawables, function(a, b) return a.y < b.y end)
	
	-- Draw all entities in sorted order
	for _, drawable in ipairs(drawables) do
		drawable.obj:draw(gameScene.debugMode)
	end
	
	-- Draw dialog UI on top of everything
	if gameScene.player and gameScene.player.dialogUI then
		gameScene.player.dialogUI:draw()
	end

	-- Draw interaction HUD icons above player
	if gameScene.interactionHUD and gameScene.player then
		gameScene.interactionHUD:draw(gameScene.player.x, gameScene.player.y)
	end
	
	-- Draw all debug visualizations using utilities module

	utilities.drawDebugInfo(gameScene)
	
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
					print("🔍 Manually triggering: " .. script .. " (Type: " .. tostring(item.type) .. ")")
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
	
	for i = 1, len do
		local item = items[i]
		if item.isTrigger then
			-- Automatic types
			if item.type == "Story" or item.type == "Cutscene" or item.type == "Counter" then
				local script = getTriggerScript(item)
				if script then
					print("🎭 Automatically triggering: " .. script .. " (Type: " .. tostring(item.type) .. ")")
					handleTriggerActivation(item, script)
					return -- Activate only one per frame
				end
			end
		end
	end
end


function gameScene.keypressed(key)
	-- If talking, any 'confirm' key advances dialog
	if PlayerData.isTalking then
		if key == "z" or key == "return" or key == "space" then
			gameScene.player:displayDialog()
			return
		end
	else
		-- Check for interaction on confirm keys
		if key == "z" or key == "return" or key == "space" then
			gameScene.checkTriggerInteraction()
		end
	end


	-- Let pause menu handle its own input first

	local action = gameScene.pauseMenu:keypressed(key)
	if action then
		-- Handle menu actions
		gameScene.handleMenuAction(action)
		return
	end
	
	-- Game input (when menu is not shown)
	if key == "escape" then
		-- Show menu
		gameScene.pauseMenu:show()
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
	
	-- Pass gamepad input to player when menu is not shown
	if not gameScene.pauseMenu:isVisible() then
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
		print("🔧 Debug mode: " .. (gameScene.debugMode and "ON" or "OFF"))
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
	
	if not foundTrigger and gameScene.interactionHUD then
		gameScene.interactionHUD:setVisible(false)
	end
end

return gameScene