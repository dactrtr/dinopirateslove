local sceneManager = require "sceneManager"
local Timer = require 'libraries/hump/timer'
local bump = require 'libraries/bump'
local Player = require 'entities.Player'
local Brocorat = require 'entities.Brocorat'
local Door = require 'entities.Door'
local DoorHandler = require 'DoorHandler'

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
	-- Level management
	currentRoom = nil,        -- Index in levelsLDTK
	currentLevelData = nil,   -- Reference to current level
	-- Debug mode
	debugMode = false         -- Toggle for debug visualizations
}

local padding = 12

-- MARK: Level Management Functions
function gameScene.setFloor(levelNumber, roomNumber)
	for i, levelData in ipairs(levelsLDTK) do
		if levelData.customFields.level == levelNumber and levelData.customFields.roomNumber == roomNumber then
			gameScene.currentRoom = i
			gameScene.currentLevelData = levelsLDTK[i]
			print("✅ Level loaded: " .. levelData.identifier .. " (Level " .. levelNumber .. ", Room " .. roomNumber .. ")")
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
	
	-- Set initial level (Level 4, Room 2 as example - you can change this)
	gameScene.setFloor(4, 2)
	
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
	
	local customFields = gameScene.currentLevelData.customFields
	local doorsConnection = customFields and customFields.DoorsConnection
	local neighbourLevels = gameScene.currentLevelData.neighbourLevels
	
	print("🔍 DEBUG: Loading doors for " .. gameScene.currentLevelData.identifier)
	print("🔍 DEBUG: DoorsConnection:", doorsConnection and table.concat(doorsConnection, ", ") or "nil")
	
	if not doorsConnection or #doorsConnection == 0 then
		print("ℹ️ No doors in this level (no DoorsConnection)")
		return
	end
	
	-- Map DoorsConnection strings to direction codes
	local directionMap = {
		Top = "n",
		Down = "s",
		Left = "w",
		Right = "e"
	}
	
	-- Create doors based on DoorsConnection
	for _, doorName in ipairs(doorsConnection) do
		local direction = directionMap[doorName]
		
		if not direction then
			print("⚠️ WARNING: Unknown door name '" .. doorName .. "'")
		else
			-- Find the neighbour in that direction
			local nextLevelIid = nil
			
			if neighbourLevels then
				-- Priority 1: Exact match ONLY
				for _, neighbour in ipairs(neighbourLevels) do
					local neighbourDir = neighbour.dir
					local isExactMatch = false
					
					if direction == "n" and neighbourDir == "n" then isExactMatch = true
					elseif direction == "s" and neighbourDir == "s" then isExactMatch = true
					elseif direction == "e" and neighbourDir == "e" then isExactMatch = true
					elseif direction == "w" and neighbourDir == "w" then isExactMatch = true
					end
					
					if isExactMatch then
						nextLevelIid = neighbour.levelIid
						break
					end
				end
			end
			
			if nextLevelIid then
				-- Find the room number for this IID
				local nextRoomNumber = nil
				if levelsLDTK then
					for _, level in ipairs(levelsLDTK) do
						if level.uniqueIdentifer == nextLevelIid then
							if level.customFields and level.customFields.roomNumber then
								nextRoomNumber = level.customFields.roomNumber
							end
							break
						end
					end
				end
				
				-- Create door
				local door = Door.new(direction, "open", nextLevelIid, gameScene.world, nextRoomNumber)
				table.insert(gameScene.doors, door)
				
				print("🚪 Created door: " .. doorName .. " (" .. direction .. ") -> " .. nextLevelIid .. " (Room " .. tostring(nextRoomNumber) .. ") at (" .. door.x .. ", " .. door.y .. ")")
			else
				print("⚠️ WARNING: No neighbour found for door '" .. doorName .. "' (direction: " .. direction .. ")")
			end
		end
	end
	
	print("✅ Loaded " .. #gameScene.doors .. " doors")
end

-- MARK: Wall Creation
function gameScene.loadWalls()
	-- Clear existing walls
	for _, wall in ipairs(gameScene.walls) do
		if gameScene.world then
			gameScene.world:remove(wall)
		end
	end
	gameScene.walls = {}
	
	-- Get door positions to create gaps
	local hasDoorTop = false
	local hasDoorDown = false
	local hasDoorLeft = false
	local hasDoorRight = false
	
	if gameScene.currentLevelData and gameScene.currentLevelData.customFields then
		local doorsConnection = gameScene.currentLevelData.customFields.DoorsConnection
		if doorsConnection then
			for _, doorName in ipairs(doorsConnection) do
				if doorName == "Top" then hasDoorTop = true
				elseif doorName == "Down" then hasDoorDown = true
				elseif doorName == "Left" then hasDoorLeft = true
				elseif doorName == "Right" then hasDoorRight = true
				end
			end
		end
	end
	
	local wallThickness = 8
	
	-- Top wall (with gap if door exists)
	if not hasDoorTop then
		-- Full top wall
		local wall = {x = 0, y = 0, w = VIRTUAL_WIDTH, h = wallThickness, isWall = true}
		gameScene.world:add(wall, wall.x, wall.y, wall.w, wall.h)
		table.insert(gameScene.walls, wall)
	else
		-- Top wall with gap in center
		local gapCenter = 203
		local gapWidth = 50
		-- Left segment
		local wallLeft = {x = 0, y = 0, w = gapCenter - gapWidth/2, h = wallThickness, isWall = true}
		gameScene.world:add(wallLeft, wallLeft.x, wallLeft.y, wallLeft.w, wallLeft.h)
		table.insert(gameScene.walls, wallLeft)
		-- Right segment
		local wallRight = {x = gapCenter + gapWidth/2, y = 0, w = VIRTUAL_WIDTH - (gapCenter + gapWidth/2), h = wallThickness, isWall = true}
		gameScene.world:add(wallRight, wallRight.x, wallRight.y, wallRight.w, wallRight.h)
		table.insert(gameScene.walls, wallRight)
	end
	
	-- Bottom wall (with gap if door exists)
	if not hasDoorDown then
		-- Full bottom wall
		local wall = {x = 0, y = VIRTUAL_HEIGHT - wallThickness, w = VIRTUAL_WIDTH, h = wallThickness, isWall = true}
		gameScene.world:add(wall, wall.x, wall.y, wall.w, wall.h)
		table.insert(gameScene.walls, wall)
	else
		-- Bottom wall with gap in center
		local gapCenter = 203
		local gapWidth = 50
		-- Left segment
		local wallLeft = {x = 0, y = VIRTUAL_HEIGHT - wallThickness, w = gapCenter - gapWidth/2, h = wallThickness, isWall = true}
		gameScene.world:add(wallLeft, wallLeft.x, wallLeft.y, wallLeft.w, wallLeft.h)
		table.insert(gameScene.walls, wallLeft)
		-- Right segment
		local wallRight = {x = gapCenter + gapWidth/2, y = VIRTUAL_HEIGHT - wallThickness, w = VIRTUAL_WIDTH - (gapCenter + gapWidth/2), h = wallThickness, isWall = true}
		gameScene.world:add(wallRight, wallRight.x, wallRight.y, wallRight.w, wallRight.h)
		table.insert(gameScene.walls, wallRight)
	end
	
	-- Left wall (with gap if door exists)
	if not hasDoorLeft then
		-- Full left wall
		local wall = {x = 0, y = 0, w = wallThickness, h = VIRTUAL_HEIGHT, isWall = true}
		gameScene.world:add(wall, wall.x, wall.y, wall.w, wall.h)
		table.insert(gameScene.walls, wall)
	else
		-- Left wall with gap in center
		local gapCenter = 122
		local gapHeight = 50
		-- Top segment
		local wallTop = {x = 0, y = 0, w = wallThickness, h = gapCenter - gapHeight/2, isWall = true}
		gameScene.world:add(wallTop, wallTop.x, wallTop.y, wallTop.w, wallTop.h)
		table.insert(gameScene.walls, wallTop)
		-- Bottom segment
		local wallBottom = {x = 0, y = gapCenter + gapHeight/2, w = wallThickness, h = VIRTUAL_HEIGHT - (gapCenter + gapHeight/2), isWall = true}
		gameScene.world:add(wallBottom, wallBottom.x, wallBottom.y, wallBottom.w, wallBottom.h)
		table.insert(gameScene.walls, wallBottom)
	end
	
	-- Right wall (with gap if door exists)
	if not hasDoorRight then
		-- Full right wall
		local wall = {x = VIRTUAL_WIDTH - wallThickness, y = 0, w = wallThickness, h = VIRTUAL_HEIGHT, isWall = true}
		gameScene.world:add(wall, wall.x, wall.y, wall.w, wall.h)
		table.insert(gameScene.walls, wall)
	else
		-- Right wall with gap in center
		local gapCenter = 122
		local gapHeight = 50
		-- Top segment
		local wallTop = {x = VIRTUAL_WIDTH - wallThickness, y = 0, w = wallThickness, h = gapCenter - gapHeight/2, isWall = true}
		gameScene.world:add(wallTop, wallTop.x, wallTop.y, wallTop.w, wallTop.h)
		table.insert(gameScene.walls, wallTop)
		-- Bottom segment
		local wallBottom = {x = VIRTUAL_WIDTH - wallThickness, y = gapCenter + gapHeight/2, w = wallThickness, h = VIRTUAL_HEIGHT - (gapCenter + gapHeight/2), isWall = true}
		gameScene.world:add(wallBottom, wallBottom.x, wallBottom.y, wallBottom.w, wallBottom.h)
		table.insert(gameScene.walls, wallBottom)
	end
	
	print("✅ Created " .. #gameScene.walls .. " wall segments")
end


-- MARK: Level Transition
function gameScene.changeLevel(nextLevelIid, enterDirection)
	print("🔄 Changing level to IID: " .. nextLevelIid)
	
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
	
	-- Clear current level
	for _, enemy in ipairs(gameScene.enemies) do
		if enemy.remove then
			enemy:remove()
		end
	end
	gameScene.enemies = {}
	
	for _, door in ipairs(gameScene.doors) do
		door:remove()
	end
	gameScene.doors = {}
	
	-- Set new level
	gameScene.currentRoom = nextRoomIndex
	gameScene.currentLevelData = levelsLDTK[nextRoomIndex]
	
	print("✅ Switched to: " .. gameScene.currentLevelData.identifier)
	
	-- Reload level components
	gameScene.loadFloor()
	gameScene.loadEnemies()
	gameScene.loadDoors()
	gameScene.loadWalls()
	
	-- Update room info in pause menu
	gameScene.updateRoomInfo()
	
	-- Reposition player based on entry direction
	if enterDirection and gameScene.player then
		local spawnCoordinates = {
			top = {x = 196, y = 156},
			down = {x = 196, y = 32},
			right = {x = 32, y = 116},
			left = {x = 364, y = 116}
		}
		
		local spawn = spawnCoordinates[enterDirection]
		if spawn then
			gameScene.player.x = spawn.x
			gameScene.player.y = spawn.y
			-- Update collision position in BUMP
			gameScene.player:updateCollisionPosition()
			print("📍 Player spawned at: (" .. spawn.x .. ", " .. spawn.y .. ")")
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
	end
end

function gameScene.draw()
	-- Draw floor first (background layer)
	gameScene.drawFloor()

	love.graphics.setColor(1, 1, 1) -- Reset color before player draw
	
	-- Draw walls (red rectangles) - only in debug mode
	if gameScene.debugMode then
		love.graphics.setColor(1, 0, 0, 1) -- Red color
		for _, wall in ipairs(gameScene.walls) do
			love.graphics.rectangle("fill", wall.x, wall.y, wall.w, wall.h)
		end
		love.graphics.setColor(1, 1, 1) -- Reset color
	end
	
	-- Draw enemies
	for i, enemy in ipairs(gameScene.enemies) do
		enemy:draw()
	end
	
	-- Draw doors (for debugging) - only in debug mode
	if gameScene.debugMode then
		for i, door in ipairs(gameScene.doors) do
			if door.draw then
				door:draw()
			end
		end
	end
	
	-- Draw player on top of enemies
	gameScene.player:draw()
	
	-- Draw collision boxes in debug mode
	if gameScene.debugMode then
		love.graphics.setColor(0, 1, 1, 0.3) -- Cyan semi-transparent
		
		-- Draw player collision box
		local px, py, pw, ph = gameScene.player:getCollisionRect()
		love.graphics.rectangle("line", px, py, pw, ph)
		
		-- Draw enemy collision boxes
		for _, enemy in ipairs(gameScene.enemies) do
			if enemy.x and enemy.y and enemy.width and enemy.height then
				love.graphics.rectangle("line", enemy.x, enemy.y, enemy.width, enemy.height)
			end
		end
		
		love.graphics.setColor(1, 1, 1) -- Reset color
	end
	
	-- Draw pause menu overlay
	gameScene.pauseMenu:draw()
end

function gameScene.keypressed(key)
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

return gameScene