local sceneManager = require "sceneManager"
local Timer = require 'libraries/hump/timer'
local bump = require 'libraries/bump'
local Player = require 'entities.Player'

-- Simple require for PauseMenu
local PauseMenu = require 'PauseMenu'

local gameScene = {
	player = nil,
	world = nil,
	timer = nil,
	pauseMenu = nil,
	-- Floor rendering components
	tilesImage = nil,
	tileQuads = {},
	map = {},
	mapWidth = 16,
	mapHeight = 9,
	tileSize = 24
}

local padding = 8
local playerSize = 48

-- Placeholder levels data - you'll need to replace this with your actual levels data
local levels = {
	room = {
		floor = {
			tile = 1 -- Default tile index, adjust as needed
		}
	}
}
local room = "room" -- Current room identifier

function gameScene.load()
	-- Initialize BUMP world for physics
	gameScene.world = bump.newWorld(32) -- 32 = cell size
	
	-- Initialize HUMP timer
	gameScene.timer = Timer.new()
	
	-- Create player
	gameScene.player = Player(200, 120, gameScene.world)
	
	-- Initialize pause menu with custom buttons for this scene
	gameScene.pauseMenu = PauseMenu.new({
		{text = "Resume", action = "resume"},
		{text = "Return to Title", action = "title"},
		{text = "Quit Game", action = "quit"}
	})
	
	-- Mark: floor - Load tile spritesheet and create floor
	gameScene.loadFloor()
end

function gameScene.loadFloor()
	-- Load the tile spritesheet
	gameScene.tilesImage = love.graphics.newImage('assets/tile/tile.png')
	
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
	
	-- Initialize the map array
	gameScene.map = {}
	for y = 1, gameScene.mapHeight do
		gameScene.map[y] = {}
		for x = 1, gameScene.mapWidth do
			-- Set each tile to the floor tile from levels data
			gameScene.map[y][x] = levels[room].floor.tile
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
		
		-- Keep player on screen (boundary check)
		gameScene.player.x = math.max(padding, math.min(VIRTUAL_WIDTH - padding - playerSize, gameScene.player.x))
		gameScene.player.y = math.max(padding, math.min(VIRTUAL_HEIGHT - padding - playerSize, gameScene.player.y))
	end
end

function gameScene.draw()
	-- Draw floor first (background layer)
	gameScene.drawFloor()
	
	-- Draw boundary box
	love.graphics.setColor(1, 0, 0, 1)
	love.graphics.rectangle("line", padding, padding, VIRTUAL_WIDTH - 2 * padding, VIRTUAL_HEIGHT - 2 * padding)
	
	-- Draw player collision box
	love.graphics.setColor(0, 1, 1, 0.5)
	love.graphics.rectangle("line", gameScene.player.x, gameScene.player.y, playerSize, playerSize)
	
	-- Draw player
	love.graphics.setColor(1, 1, 1) -- Reset color before player draw
	gameScene.player:draw()
	
	-- Draw instructions (only if menu is not shown)
	if not gameScene.pauseMenu:isVisible() then
		love.graphics.setColor(1, 1, 1)
		love.graphics.printf("Press ESC or START for menu", 10, VIRTUAL_HEIGHT - 30, VIRTUAL_WIDTH - 20, "left")
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
	elseif action == "title" then
		sceneManager.startTransition("game", "title", "slide")
	elseif action == "quit" then
		love.event.quit()
	end
end

return gameScene